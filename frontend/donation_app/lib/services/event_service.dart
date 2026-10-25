import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'auth_service.dart';

const eventCategories = <String, String>{
  'environment': 'Байгаль орчин',
  'social': 'Нийгмийн халамж',
  'education': 'Боловсрол',
  'cleanup': 'Цэвэр орчин',
  'other': 'Бусад',
};

String categoryCode(String label) =>
    eventCategories.entries
        .where((entry) => entry.value == label)
        .firstOrNull
        ?.key ??
    label;

class EventRecord {
  EventRecord.fromJson(Map<String, dynamic> data)
    : id = data['argahemjeeniidugaar'] as String,
      title = data['garchig'] as String,
      description = data['tailbar'] as String,
      organization = data['baiguullagiindugaar'] as String,
      category = data['angilaliindugaar'] as String,
      status = data['tulwiindugaar'] as String? ?? 'open',
      location = data['bairshil'] as String,
      startsAt = DateTime.parse(data['ehleh_ognoo'] as String).toLocal(),
      endsAt = DateTime.parse(data['duusah_ognoo'] as String).toLocal(),
      capacity = data['oroltsohchdiin_too'] as int,
      participantCount = data['participant_count'] as int? ?? 0,
      isJoined = data['is_joined'] as bool? ?? false,
      // ШИНЭ: зургийн URL (байхгүй бол null)
      imageUrl = _cleanUrl(data['zurag']);

  final String id, title, description, organization, category, location, status;
  final DateTime startsAt, endsAt;
  final int capacity, participantCount;
  final bool isJoined;

  // ШИНЭ
  final String? imageUrl;

  // ШИНЭ: зураг байгаа эсэхийг шалгах туслах getter
  bool get hasImage => imageUrl != null;

  static String? _cleanUrl(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String dateLabel(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Map<String, String> toDisplay() => {
    'id': id,
    'title': title,
    'description': description,
    'organization': organization,
    'category': eventCategories[category] ?? category,
    'location': location,
    'date': dateLabel(startsAt),
    'endDate': dateLabel(endsAt),
    'slots': '$capacity',
    'participants': '$participantCount',
    'isJoined': '$isJoined',
    // ШИНЭ: зураггүй бол хоосон мөр
    'image': imageUrl ?? '',
  };
}

class EventPage {
  EventPage.fromJson(Map<String, dynamic> data)
    : events = (data['events'] as List)
          .map((item) => EventRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      count = data['count'] as int,
      nextOffset = data['next_offset'] as int?;
  final List<EventRecord> events;
  final int count;
  final int? nextOffset;
}

class EventService {
  EventService(this.api);
  final AuthService api;

  // ШИНЭ: зургийн дээд хэмжээ (5 MB)
  static const maxImageBytes = 5 * 1024 * 1024;

  T _read<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      throw const AuthException(
        'Үйл ажиллагааны мэдээллийг уншиж чадсангүй. Дахин оролдоно уу.',
      );
    }
  }

  static String newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<EventPage> list({
    String query = '',
    String category = '',
    int offset = 0,
    int limit = 20,
    bool upcoming = false,
  }) async {
    final params = Uri(
      queryParameters: {
        'q': query,
        'category': category,
        'offset': '$offset',
        'limit': '$limit',
        'upcoming': '$upcoming',
      },
    ).query;
    final data = await api.request('/events/?$params');
    return _read<EventPage>(() => EventPage.fromJson(data));
  }

  Future<EventRecord> detail(String id) async {
    final data = await api.request('/events/${Uri.encodeComponent(id)}/');
    return _read<EventRecord>(
      () => EventRecord.fromJson(data['event'] as Map<String, dynamic>),
    );
  }

  /// ШИНЭ: зургийг backend рүү илгээгээд URL-ыг нь буцаана.
  /// Web болон утсан дээр хоёуланд нь ажиллахын тулд bytes-ийг
  /// base64 болгож JSON-оор илгээнэ (dart:io File хэрэглэхгүй).
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    if (bytes.isEmpty) {
      throw const AuthException('Зураг хоосон байна.');
    }
    if (bytes.length > maxImageBytes) {
      throw const AuthException('Зургийн хэмжээ 5MB-аас хэтрэхгүй байх ёстой.');
    }
    final data = await api.request(
      '/events/upload-image',
      body: {'filename': filename, 'data': base64Encode(bytes)},
      post: true,
    );
    return _read<String>(() {
      final url = (data['url'] as String).trim();
      if (url.isEmpty) throw const FormatException();
      return url;
    });
  }

  Future<EventRecord> create({
    required String id,
    required String title,
    required String description,
    required String organization,
    required String category,
    required String location,
    required DateTime startsAt,
    required DateTime endsAt,
    required int capacity,
    String? imageUrl, // ШИНЭ: заавал биш
  }) async {
    final cleanImage = EventRecord._cleanUrl(imageUrl);
    final body = <String, dynamic>{
      'argahemjeeniidugaar': id,
      'garchig': title.trim(),
      'tailbar': description.trim(),
      'baiguullagiindugaar': organization.trim(),
      'angilaliindugaar': category,
      'bairshil': location.trim(),
      'ehleh_ognoo': startsAt.toUtc().toIso8601String(),
      'duusah_ognoo': endsAt.toUtc().toIso8601String(),
      'oroltsohchdiin_too': capacity,
      if (cleanImage != null) 'zurag': cleanImage, // ШИНЭ
    };
    try {
      final data = await api.request('/events/create', body: body, post: true);
      return _read<EventRecord>(
        () => EventRecord.fromJson(data['event'] as Map<String, dynamic>),
      );
    } on AuthException catch (error) {
      if (error.statusCode != 409) rethrow;
      final existing = await detail(id);
      if (existing.title != title.trim() ||
          existing.description != description.trim() ||
          existing.organization != organization.trim() ||
          existing.category != category ||
          existing.location != location.trim() ||
          !existing.startsAt.isAtSameMomentAs(startsAt) ||
          !existing.endsAt.isAtSameMomentAs(endsAt) ||
          existing.capacity != capacity ||
          existing.imageUrl != cleanImage) {
        // ШИНЭ: зураг ч бас таарах ёстой
        rethrow;
      }
      return existing;
    }
  }

  Future<EventRecord> participate(String id, {bool cancel = false}) async {
    final data = await api.request(
      '/events/${Uri.encodeComponent(id)}/${cancel ? 'leave' : 'join'}',
      post: true,
    );
    return _read<EventRecord>(
      () => EventRecord.fromJson(data['event'] as Map<String, dynamic>),
    );
  }
}