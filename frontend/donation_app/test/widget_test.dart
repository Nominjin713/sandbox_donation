import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:donation_app/app.dart';
import 'package:donation_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Home opens registration and back returns home', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Сайн үйлсэд хамтдаа'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Бүртгүүлэх'));
    await tester.pumpAndSettle();
    expect(find.text('Нууц үг давтах'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Сайн үйлсэд хамтдаа'), findsOneWidget);
  });
  testWidgets('Login validation and registration switch', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pump();
    expect(find.text('Зөв имэйл оруулна уу.'), findsOneWidget);
    await tester.tap(find.text('Бүртгэлгүй юу? Бүртгүүлэх'));
    await tester.pumpAndSettle();
    expect(find.text('Нэр'), findsOneWidget);
    expect(find.text('Нууц үг давтах'), findsOneWidget);
  });

  testWidgets('Login sends credentials and logout revokes the session', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final service = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/logout') return http.Response('{}', 200);
        return http.Response(
          jsonEncode({
            'token': 'test-token',
            'user': {'name': 'Болд', 'email': 'bold@example.com'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(MyApp(authService: service));
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'bold@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Strong!Pass483');
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pumpAndSettle();
    expect(requests.first.url.path, '/auth/login');
    expect(jsonDecode(requests.first.body)['password'], 'Strong!Pass483');
    expect(find.text('Тавтай морил!'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Гарах'));
    await tester.pumpAndSettle();
    expect(requests.last.headers['Authorization'], 'Bearer test-token');
    expect(find.widgetWithText(FilledButton, 'Нэвтрэх'), findsOneWidget);
  });

  testWidgets(
    'Registration rejects mismatched passwords and submits valid data',
    (tester) async {
      final requests = <http.Request>[];
      final service = AuthService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {'name': 'Болд', 'email': 'bold@example.com'},
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(MyApp(authService: service));
      await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Бүртгэлгүй юу? Бүртгүүлэх'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Болд');
      await tester.enterText(fields.at(1), 'bold@example.com');
      await tester.enterText(fields.at(2), 'Strong!Pass483');
      await tester.enterText(fields.at(3), 'Different483');
      final button = find.widgetWithText(FilledButton, 'Бүртгүүлэх');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Нууц үг таарахгүй байна.'), findsOneWidget);
      expect(requests, isEmpty);
      await tester.enterText(fields.at(3), 'Strong!Pass483');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(requests.single.url.path, '/auth/register');
      expect(jsonDecode(requests.single.body)['name'], 'Болд');
      expect(find.text('Тавтай морил!'), findsOneWidget);
    },
  );

  testWidgets('Backend errors appear on the login form', (tester) async {
    final service = AuthService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'Имэйл эсвэл нууц үг буруу байна.'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(service.close);
    await tester.pumpWidget(MyApp(authService: service));
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'bold@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'WrongPass483');
    await tester.tap(find.widgetWithText(FilledButton, 'Нэвтрэх'));
    await tester.pumpAndSettle();
    expect(find.text('Имэйл эсвэл нууц үг буруу байна.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Нэвтрэх'), findsOneWidget);
  });
}
