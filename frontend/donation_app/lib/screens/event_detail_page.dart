import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';
import '../services/event_service.dart';
import 'auth_page.dart';
import 'create_event_page.dart';

const primaryBlue = Color(0xFF7353BA);
const darkBlue = Color(0xFF39275F);
const backgroundBlue = Color(0xFFF8F6FF);

// ШИНЭ: зураггүй үйл ажиллагаанд ангиллын зургийг харуулна
const Map<String, String> _categoryAssets = {
  'environment': 'assets/images/environment.jpg',
  'social': 'assets/images/social.jpg',
  'education': 'assets/images/education.jpg',
  'cleanup': 'assets/images/cleanup.jpg',
};

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.event, this.authService});

  final Map<String, String> event;
  final AuthService? authService;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late final _api = widget.authService ?? AuthService();
  late final _service = EventService(_api);

  EventRecord? _event;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.authService == null) {
      _api.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.detail(widget.event['id'] ?? '');

      if (mounted) {
        setState(() => _event = result);
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Мэдээлэл авахад алдаа гарлаа.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _participate() async {
    if (_busy || _event == null) return;

    final cancel = _api.currentSession != null && _event!.isJoined;

    if (_api.currentSession == null) {
      await Navigator.of(context).push<AuthSession>(
        MaterialPageRoute(builder: (_) => AuthPage(authService: _api)),
      );

      if (!mounted || _api.currentSession == null) return;
    }

    setState(() => _busy = true);

    try {
      final result = await _service.participate(_event!.id, cancel: cancel);

      if (!mounted) return;

      setState(() => _event = result);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            cancel
                ? 'Оролцох бүртгэлээ цуцаллаа.'
                : 'Оролцох бүртгэл амжилттай хадгалагдлаа.',
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));

      if (error.statusCode == 401) {
        await Navigator.of(context).push<AuthSession>(
          MaterialPageRoute(builder: (_) => AuthPage(authService: _api)),
        );

        if (!mounted) return;
      }

      await _load();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _editEvent() async {
    final event = _event;
    if (_busy || event == null) return;

    final updated = await Navigator.of(context).push<EventRecord>(
      MaterialPageRoute(
        builder: (_) => CreateEventPage(authService: _api, initialEvent: event),
      ),
    );

    if (mounted && updated != null) {
      setState(() => _event = updated);
    }
  }

  Future<void> _deleteEvent() async {
    final event = _event;
    if (_busy || event == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Үйл ажиллагаа устгах уу?'),
        content: Text(
          '“${event.title}”-ийг устгавал оролцогчдын бүртгэл мөн устна.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      await _service.delete(event.id);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openMap(EventRecord event) async {
    // Эдгээр нь жишээ координат.
    // Бодит координатыг backend-ээс авах шаардлагатай.
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => EventMapPage(
          location: event.location,
          latitude: 47.9184,
          longitude: 106.9177,
        ),
      ),
    );

    if (!mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Газрын зураг дээрх байршлыг сонголоо.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;

    final closed =
        event != null &&
        (event.status != 'open' || !event.endsAt.isAfter(DateTime.now()));

    final full = event != null && event.participantCount >= event.capacity;

    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        backgroundColor: backgroundBlue,
        foregroundColor: darkBlue,
        elevation: 0,
        title: const Text(
          'Үйл ажиллагааны дэлгэрэнгүй',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Мэдээлэл хуулах',
            onPressed: event == null
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${event.title}\n'
                            '${EventRecord.dateLabel(event.startsAt)}\n'
                            '${event.location}',
                      ),
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Мэдээллийг хууллаа.')),
                    );
                  },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                if (_loading) const LinearProgressIndicator(color: primaryBlue),

                if (_error != null) ...[
                  _card(
                    Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 42,
                        ),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Дахин оролдох'),
                        ),
                      ],
                    ),
                  ),
                ],

                if (event != null) ...[
                  _buildHeader(event),

                  const SizedBox(height: 18),

                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.info_outline,
                          title: 'Үйл ажиллагааны мэдээлэл',
                        ),
                        const SizedBox(height: 18),

                        _info(
                          Icons.calendar_month_outlined,
                          'Эхлэх огноо',
                          EventRecord.dateLabel(event.startsAt),
                        ),

                        _info(
                          Icons.event_available_outlined,
                          'Дуусах огноо',
                          EventRecord.dateLabel(event.endsAt),
                        ),

                        _info(
                          Icons.business_outlined,
                          'Зохион байгуулагч',
                          event.organization,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.description_outlined,
                          title: 'Үйл ажиллагааны тухай',
                        ),
                        const SizedBox(height: 14),
                        Text(
                          event.description.isEmpty
                              ? 'Тайлбар оруулаагүй байна.'
                              : event.description,
                          style: const TextStyle(
                            height: 1.7,
                            fontSize: 15,
                            color: Color(0xFF53647D),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.location_on_outlined,
                          title: 'Үйл ажиллагааны байршил',
                        ),
                        const SizedBox(height: 14),

                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openMap(event),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFD9E7FF),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: primaryBlue,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.location,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: darkBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      const Text(
                                        'Газрын зураг харах',
                                        style: TextStyle(
                                          color: primaryBlue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: primaryBlue,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(
                          icon: Icons.groups_outlined,
                          title: 'Оролцогчид',
                        ),
                        const SizedBox(height: 18),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${event.participantCount}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 5,
                                left: 5,
                              ),
                              child: Text(
                                '/ ${event.capacity} хүн',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              event.isJoined
                                  ? Icons.check_circle
                                  : Icons.people_alt_outlined,
                              color: event.isJoined
                                  ? Colors.green
                                  : primaryBlue,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: 9,
                            backgroundColor: const Color(0xFFE7EEFA),
                            color: primaryBlue,
                            value: event.capacity <= 0
                                ? 0
                                : (event.participantCount / event.capacity)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          event.isJoined
                              ? 'Та энэ үйл ажиллагаанд бүртгэлтэй.'
                              : full
                              ? 'Оролцогчдын тоо дүүрсэн байна.'
                              : 'Үлдсэн байр: '
                                    '${(event.capacity - event.participantCount).clamp(0, event.capacity)}',
                          style: const TextStyle(color: Color(0xFF53647D)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (event.isOwner) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _editEvent,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Засах'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: primaryBlue,
                              side: const BorderSide(color: primaryBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _deleteEvent,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Устгах'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed:
                          _busy ||
                              _loading ||
                              (!event.isJoined && (closed || full))
                          ? null
                          : _participate,
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryBlue,
                        disabledBackgroundColor: const Color(0xFFCFD8E8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              event.isJoined
                                  ? Icons.cancel_outlined
                                  : Icons.volunteer_activism,
                            ),
                      label: Text(
                        _busy
                            ? 'Түр хүлээнэ үү...'
                            : event.isJoined
                            ? 'Оролцохоо цуцлах'
                            : closed
                            ? 'Бүртгэл хаагдсан'
                            : full
                            ? 'Бүртгэл дүүрсэн'
                            : 'Оролцох',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ШИНЭ: дээд хэсгийн зураг (эвентийн зураг, байхгүй бол ангиллын зураг)
  Widget _headerImage(EventRecord event) {
    final fallback = Image.asset(
      _categoryAssets[event.category] ?? 'assets/images/vol.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8C70C8), Color(0xFF60429F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );

    final url = event.imageUrl;
    if (url == null) return fallback;

    return Image.network(
      url,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const ColoredBox(color: Color(0xFFE9E2F7)),
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  // ШИНЭ: зурагтай дээд хэсэг. Зургийн доод талд гарчиг, огноо, байршил.
  Widget _buildHeader(EventRecord event) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = (constraints.maxWidth * 0.62).clamp(280.0, 420.0);

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Positioned.fill(child: _headerImage(event)),
              // Текст уншигдахуйц болгох бараан нил ягаан уусгалт
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0x0039275F),
                        Color(0xE639275F),
                      ],
                      stops: [0.0, 0.3, 1.0],
                    ),
                  ),
                ),
              ),
              // Ангилал
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    eventCategories[event.category] ?? event.category,
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Гарчиг, огноо, байршил
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 70, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.25,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Color(0x66000000), blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            EventRecord.dateLabel(event.startsAt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAF0FA)),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: primaryBlue, size: 23),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
        ),
      ],
    );
  }
}

// Газрын зургийн хуудас

class EventMapPage extends StatefulWidget {
  const EventMapPage({
    super.key,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  final String location;
  final double latitude;
  final double longitude;

  @override
  State<EventMapPage> createState() => _EventMapPageState();
}

class _EventMapPageState extends State<EventMapPage> {
  late LatLng _selectedPoint;
  bool _confirmed = true;

  @override
  void initState() {
    super.initState();

    _selectedPoint = LatLng(widget.latitude, widget.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text('Үйл ажиллагааны байршил'),
        backgroundColor: backgroundBlue,
        foregroundColor: darkBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: 15,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedPoint = point;
                    _confirmed = false;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.donation_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 55,
                      height: 55,
                      child: const Icon(
                        Icons.location_pin,
                        size: 48,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Үйл ажиллагаа болох газар',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.location,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Өргөрөг: '
                    '${_selectedPoint.latitude.toStringAsFixed(6)}\n'
                    'Уртраг: '
                    '${_selectedPoint.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 13, height: 1.7),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: primaryBlue,
                    value: _confirmed,
                    title: const Text('Байршлыг баталгаажуулсан'),
                    onChanged: (value) {
                      setState(() {
                        _confirmed = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _confirmed
                          ? () => Navigator.pop(context, _selectedPoint)
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Байршлыг сонгох'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}