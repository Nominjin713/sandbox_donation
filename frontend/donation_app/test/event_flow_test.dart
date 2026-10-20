import 'dart:async';
import 'dart:convert';

import 'package:donation_app/app.dart';
import 'package:donation_app/screens/create_event_page.dart';
import 'package:donation_app/services/auth_service.dart';
import 'package:donation_app/services/event_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const session = AuthSession(
  token: 'test-token',
  name: 'Болд',
  email: 'bold@example.com',
);

Map<String, dynamic> fixture({String id = 'event-1'}) => {
  'argahemjeeniidugaar': id,
  'garchig': 'Мод тарих',
  'tailbar': 'Хамтдаа мод тарина.',
  'baiguullagiindugaar': 'Манай баг',
  'angilaliindugaar': 'environment',
  'bairshil': 'Улаанбаатар',
  'ehleh_ognoo': '2030-10-20T02:00:00Z',
  'duusah_ognoo': '2030-10-20T04:00:00Z',
  'oroltsohchdiin_too': 2,
  'participant_count': 0,
  'is_joined': false,
};

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Finder field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      350,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillEventForm(WidgetTester tester) async {
  await tester.enterText(field('Зохион байгуулагчийн нэр'), 'Манай баг');
  await tester.enterText(field('Жишээ: Мод тарих өдөрлөг'), 'Мод тарих');
  await tester.enterText(
    field('Үйл ажиллагааны зорилго, хийх ажлаа бичээрэй...'),
    'Хамтдаа мод тарина.',
  );
  await tester.enterText(field('Үйл ажиллагаа болох газар'), 'Улаанбаатар');
  for (final hint in ['Эхлэх огноо сонгох', 'Дуусах огноо сонгох']) {
    await tap(tester, field(hint));
    await tap(tester, find.text('Сонгох'));
    await tap(tester, find.text('Сонгох'));
  }
  await tester.enterText(field('Жишээ: 30'), '2');
}

void main() {
  test(
    'Event service sends bearer token, native JSON types and UTC dates',
    () async {
      late http.Request sent;
      final api = AuthService(
        client: MockClient((request) async {
          sent = request;
          return response({
            'event': {
              ...fixture(),
              ...jsonDecode(request.body) as Map<String, dynamic>,
            },
          }, 201);
        }),
      )..currentSession = session;
      addTearDown(api.close);
      final event = await EventService(api).create(
        id: 'stable-id',
        title: ' Мод тарих ',
        description: 'Хамтдаа мод тарина.',
        organization: 'Манай баг',
        category: 'environment',
        location: 'Улаанбаатар',
        startsAt: DateTime.parse('2030-10-20T10:00:00+08:00'),
        endsAt: DateTime.parse('2030-10-20T12:00:00+08:00'),
        capacity: 2,
      );
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(sent.url.path, '/events/create');
      expect(sent.headers['Authorization'], 'Bearer test-token');
      expect(body['garchig'], 'Мод тарих');
      expect(body['oroltsohchdiin_too'], 2);
      expect(body['ehleh_ognoo'], '2030-10-20T02:00:00.000Z');
      expect(event.id, 'stable-id');
    },
  );

  test('Retrying a saved draft resolves a duplicate without creating another event', () async {
    final stored = fixture(id: 'stable-id');
    var creates = 0;
    final api = AuthService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          creates++;
          return response({'message': 'Давхардсан ID.'}, 409);
        }
        return response({'event': stored});
      }),
    )..currentSession = session;
    addTearDown(api.close);
    final result = await EventService(api).create(
      id: 'stable-id',
      title: stored['garchig'] as String,
      description: stored['tailbar'] as String,
      organization: stored['baiguullagiindugaar'] as String,
      category: 'environment',
      location: stored['bairshil'] as String,
      startsAt: DateTime.parse(stored['ehleh_ognoo'] as String),
      endsAt: DateTime.parse(stored['duusah_ognoo'] as String),
      capacity: 2,
    );
    expect(result.id, 'stable-id');
    expect(creates, 1);
  });

  test('Expired sessions clear local auth and malformed responses are readable errors', () async {
    final api = AuthService(
      client: MockClient(
        (_) async => response({'message': 'Дахин нэвтэрнэ үү.'}, 401),
      ),
    )..currentSession = session;
    addTearDown(api.close);
    await expectLater(
      EventService(api).participate('event-1'),
      throwsA(
        isA<AuthException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
    expect(api.currentSession, isNull);
    final broken = AuthService(
      client: MockClient((_) async => response({'unexpected': true})),
    );
    addTearDown(broken.close);
    await expectLater(
      EventService(broken).list(),
      throwsA(isA<AuthException>()),
    );
  });

  test('List query, category and pagination are sent to the backend', () async {
    late Uri uri;
    final api = AuthService(
      client: MockClient((request) async {
        uri = request.url;
        return response({
          'events': [fixture()],
          'count': 21,
          'next_offset': null,
        });
      }),
    );
    addTearDown(api.close);
    final page = await EventService(api)
        .list(query: 'Мод', category: 'environment', offset: 20);
    expect(uri.queryParameters['q'], 'Мод');
    expect(uri.queryParameters['offset'], '20');
    expect(uri.queryParameters['category'], 'environment');
    expect(page.events.single.title, 'Мод тарих');
  });

  testWidgets(
    'Publish, reload, list, join and cancel use persisted API results',
    (tester) async {
      final stored = <Map<String, dynamic>>[];
      final gate = Completer<void>();
      var creates = 0;
      final api = AuthService(
        client: MockClient((request) async {
          if (request.url.path == '/events/create') {
            creates++;
            expect(request.headers['Authorization'], 'Bearer test-token');
            final data = jsonDecode(request.body) as Map<String, dynamic>;
            await gate.future;
            stored.add({
              ...data,
              'participant_count': 0,
              'is_joined': false,
              'tulwiindugaar': 'open',
            });
            return response({'event': stored.single}, 201);
          }
          if (request.url.path == '/events/') {
            final query = request.url.queryParameters['q'] ?? '';
            final filtered = stored
                .where((event) => (event['garchig'] as String).contains(query))
                .toList();
            return response({
              'events': filtered,
              'count': filtered.length,
              'next_offset': null,
            });
          }
          if (request.url.path.endsWith('/join')) {
            stored.single['participant_count'] = 1;
            stored.single['is_joined'] = true;
          }
          if (request.url.path.endsWith('/leave')) {
            stored.single['participant_count'] = 0;
            stored.single['is_joined'] = false;
          }
          return response({'event': stored.single});
        }),
      )..currentSession = session;
      addTearDown(api.close);
      await tester.pumpWidget(MyApp(authService: api));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Үйл ажиллагаа нийтлэх'));
      await fillEventForm(tester);
      final publish = find.widgetWithText(
        ElevatedButton,
        'Үйл ажиллагаа нийтлэх',
      );
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      expect(creates, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(stored, hasLength(1));
      await tester.scrollUntilVisible(
        find.text('Мод тарих'),
        -350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Мод тарих'), findsOneWidget);
      await tap(tester, find.text('Бүгд →'));
      expect(find.text('Мод тарих'), findsOneWidget);
      await tap(tester, find.text('Мод тарих'));
      expect(find.text('Оролцогч: 0/2'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Оролцох'));
      expect(find.text('Оролцогч: 1/2'), findsOneWidget);
      await tap(tester, find.byTooltip('Шинэчлэх'));
      expect(find.text('Оролцогч: 1/2'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Оролцохоо цуцлах'));
      expect(find.text('Оролцогч: 0/2'), findsOneWidget);
    },
  );

  testWidgets('Server errors keep the publication form and entered values', (
    tester,
  ) async {
    var creates = 0;
    final api = AuthService(
      client: MockClient((_) async {
        creates++;
        return response({
          'message': 'Мэдээллээ шалгана уу.',
          'errors': {
            'garchig': ['Гарчиг тохирохгүй байна.'],
          },
        }, 400);
      }),
    )..currentSession = session;
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(home: CreateEventPage(authService: api)),
    );
    await fillEventForm(tester);
    await tap(
      tester,
      find.widgetWithText(ElevatedButton, 'Үйл ажиллагаа нийтлэх'),
    );
    expect(creates, 1);
    expect(find.text('Гарчиг тохирохгүй байна.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(field('Жишээ: Мод тарих өдөрлөг'))
          .controller!
          .text,
      'Мод тарих',
    );
  });
}
