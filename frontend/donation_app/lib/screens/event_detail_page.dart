import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/event_service.dart';
import 'auth_page.dart';
import 'create_event_page.dart';

const primaryBlue = Color(0xFF4389F5);
const darkBlue = Color(0xFF19345C);

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
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.authService == null) _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await _service.detail(widget.event['id'] ?? '');
      if (mounted) setState(() => _event = event);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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
      final event = await _service.participate(_event!.id, cancel: cancel);
      if (!mounted) return;
      setState(() => _event = event);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editEvent() async {
    final event = _event;
    if (_busy || event == null) return;
    final updated = await Navigator.of(context).push<EventRecord>(
      MaterialPageRoute(
        builder: (_) => CreateEventPage(
          authService: _api,
          initialEvent: event,
        ),
      ),
    );
    if (mounted && updated != null) setState(() => _event = updated);
  }

  Future<void> _deleteEvent() async {
    final event = _event;
    if (_busy || event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final closed =
        event != null &&
        (event.status != 'open' || !event.endsAt.isAfter(DateTime.now()));
    final full = event != null && event.participantCount >= event.capacity;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text('Үйл ажиллагааны дэлгэрэнгүй'),
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
                            '${event.title}\n${EventRecord.dateLabel(event.startsAt)}\n${event.location}',
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
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Дахин оролдох'),
                  ),
                ],
                if (event != null) ...[
                  const SizedBox(height: 16),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventCategories[event.category] ?? event.category,
                          style: const TextStyle(color: primaryBlue),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _info(
                          Icons.calendar_month,
                          'Эхлэх',
                          EventRecord.dateLabel(event.startsAt),
                        ),
                        _info(
                          Icons.event_available,
                          'Дуусах',
                          EventRecord.dateLabel(event.endsAt),
                        ),
                        _info(Icons.place_outlined, 'Байршил', event.location),
                        _info(
                          Icons.business_outlined,
                          'Зохион байгуулагч',
                          event.organization,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Үйл ажиллагааны тухай',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          event.description.isEmpty
                              ? 'Тайлбар оруулаагүй байна.'
                              : event.description,
                          style: const TextStyle(height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Оролцогч: ${event.participantCount}/${event.capacity}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: event.capacity == 0
                              ? 0
                              : (event.participantCount / event.capacity)
                                    .clamp(0, 1)
                                    .toDouble(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event.isJoined
                              ? 'Та энэ үйл ажиллагаанд бүртгэлтэй.'
                              : 'Үлдсэн байр: ${(event.capacity - event.participantCount).clamp(0, event.capacity)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (event.isOwner) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _editEvent,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Засах'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _deleteEvent,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Устгах'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  FilledButton.icon(
                    onPressed:
                        _busy ||
                            _loading ||
                            (!event.isJoined && (closed || full))
                        ? null
                        : _participate,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            event.isJoined
                                ? Icons.cancel_outlined
                                : Icons.person_add_alt,
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
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child) => Card(
    color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );

  Widget _info(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryBlue, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text('$label: $value')),
      ],
    ),
  );
}
