import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/event_service.dart';

import 'event_detail_page.dart';

// ================= ӨНГӨ (нүүр хуудастай ижил нил ягаан загвар) =================
const Color _primary = Color(0xFF7353BA);
const Color _dark = Color(0xFF39275F);
const Color _muted = Color(0xFF756D83);
const Color _light = Color(0xFFF0EBFA);
const Color _background = Color(0xFFF8F6FF);
const Color _border = Color(0xFFE7E0F3);
const Color _gold = Color(0xFFFFD166);
const Color _green = Color(0xFF2E9E6A);
const Color _danger = Color(0xFFD64545);

const Map<String, String> _categoryAssets = {
  'environment': 'assets/images/environment.jpg',
  'social': 'assets/images/social.jpg',
  'education': 'assets/images/education.jpg',
  'cleanup': 'assets/images/cleanup.jpg',
};

String _initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();
}

// ================= НҮҮР ХУУДАСНЫ ПРОФАЙЛ ТОВЧ =================
/// Хэрэглэгчийн нэрийн эхний үсэгтэй жижиг дугуй аватар.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, this.authService, this.onClosed});
  final AuthService? authService;

  /// Профайл хуудас хаагдахад дуудагдана (жишээ нь гарсны дараа нүүр хуудсыг шинэчлэх)
  final VoidCallback? onClosed;

  Future<void> _open(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(authService: authService)),
    );
    onClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _initialOf(authService?.currentSession?.name ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Миний профайл',
        child: Material(
          color: _light,
          shape: CircleBorder(
            side: BorderSide(color: _primary.withValues(alpha: .25)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _open(context),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: initial.isEmpty
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: _primary,
                        size: 22,
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= ПРОФАЙЛ ХУУДАС =================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.authService});
  final AuthService? authService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final _api = widget.authService ?? AuthService();
  late final _service = EventService(_api);

  Map<String, dynamic> _user = {};
  List<EventRecord> _upcoming = [];
  List<EventRecord> _past = [];
  bool _loading = false;
  bool _showPast = false;
  bool _loggingOut = false;
  String? _error;

  // ШИНЭ: "Гарах уу?" гэж асуугаад, зөвшөөрвөл гарна
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _danger.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout_rounded, color: _danger),
        ),
        title: const Text(
          'Гарах уу?',
          style: TextStyle(
            color: _dark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Та бүртгэлээсээ гарахдаа итгэлтэй байна уу?',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _dark,
              side: const BorderSide(color: _border),
            ),
            child: const Text('Үгүй'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Тийм, гарах'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = _api.currentSession;
    if (session == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _loggingOut = true);
    try {
      await _api.logout(session.token);
      if (mounted) Navigator.pop(context);
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic me = await _api.request('/auth/me');
      final mine = await _service.mine();
      if (!mounted) return;
      final dynamic raw = me is Map && me['user'] is Map ? me['user'] : me;
      setState(() {
        _user = raw is Map ? Map<String, dynamic>.from(raw) : {};
        _upcoming = mine.upcoming;
        _past = mine.past;
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Мэдээллийг ачаалж чадсангүй. Дахин оролдоно уу.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Backend ямар нэртэй талбар буцаахаас үл хамааран олж авна
  String _pick(List<String> keys) {
    for (final key in keys) {
      final value = _user[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String get _email => _pick(['email', 'imeil', 'mail']);
  String get _phone => _pick(['phone', 'phone_number', 'utas']);

  String get _name {
    final direct = _pick(['full_name', 'name', 'ner', 'display_name']);
    if (direct.isNotEmpty) return direct;
    final joined = [_pick(['first_name', 'ovog']), _pick(['last_name'])]
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (joined.isNotEmpty) return joined;
    final username = _pick(['username']);
    if (username.isNotEmpty) return username;
    final session = _api.currentSession?.name ?? '';
    if (session.trim().isNotEmpty) return session.trim();
    if (_email.contains('@')) return _email.split('@').first;
    return 'Хэрэглэгч';
  }

  Future<void> _openEvent(EventRecord event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EventDetailPage(event: event.toDisplay(), authService: _api),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Буцах',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _dark),
        ),
        title: const Text(
          'Миний профайл',
          style: TextStyle(
            color: _dark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: _primary),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: _load,
              color: _primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(17, 6, 17, 30),
                children: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_loading && _user.isEmpty && _error == null) {
      return const [
        SizedBox(
          height: 320,
          child: Center(child: CircularProgressIndicator(color: _primary)),
        ),
      ];
    }

    if (_error != null && _user.isEmpty) {
      return [
        _MessageBox(
          icon: Icons.wifi_off_rounded,
          title: 'Профайл ачаалж чадсангүй',
          body: _error!,
          actionLabel: 'Дахин оролдох',
          onAction: _load,
        ),
        const SizedBox(height: 20),
        _LogoutButton(busy: _loggingOut, onPressed: _confirmLogout),
      ];
    }

    final events = _showPast ? _past : _upcoming;

    return [
      _buildHeader(),
      const SizedBox(height: 26),
      const Text(
        'Миний үйл ажиллагаа',
        style: TextStyle(
          color: _dark,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      _Segmented(
        showPast: _showPast,
        upcomingCount: _upcoming.length,
        pastCount: _past.length,
        onChanged: (past) => setState(() => _showPast = past),
      ),
      const SizedBox(height: 14),
      if (_loading)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(
            minHeight: 2,
            color: _primary,
            backgroundColor: _light,
          ),
        ),
      if (events.isEmpty)
        _MessageBox(
          icon: _showPast ? Icons.history_rounded : Icons.event_note_rounded,
          title: _showPast
              ? 'Одоогоор оролцсон үйл ажиллагаа алга'
              : 'Бүртгүүлсэн үйл ажиллагаа алга',
          body: _showPast
              ? 'Бүртгүүлсэн үйл ажиллагаа дууссаны дараа энд харагдана.'
              : 'Сонирхсон үйл ажиллагаандаа бүртгүүлэхэд энд харагдана.',
        )
      else
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EventTile(
              event: event,
              past: _showPast,
              onTap: () => _openEvent(event),
            ),
          ),
        ),
      const SizedBox(height: 20),
      _LogoutButton(busy: _loggingOut, onPressed: _confirmLogout),
    ];
  }

  // Нүүр хуудасны hero-той ижил нил ягаан карт
  Widget _buildHeader() {
    final name = _name;
    final initial = _initialOf(name);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: .17),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .35),
                    width: 4,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: initial.isEmpty
                    ? const Icon(Icons.person_rounded, color: _primary)
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_email.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _HeaderLine(icon: Icons.mail_outline_rounded, text: _email),
                    ],
                    if (_phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _HeaderLine(icon: Icons.phone_outlined, text: _phone),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  value: '${_upcoming.length}',
                  label: 'Бүртгүүлсэн',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  value: '${_past.length}',
                  label: 'Оролцсон',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================= ЖИЖИГ WIDGET-ҮҮД =================

// ШИНЭ: профайлын доод талын "Гарах" товч
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _danger,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 19),
        label: Text(busy ? 'Гарч байна...' : 'Гарах'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _danger,
          backgroundColor: Colors.white,
          side: BorderSide(color: _danger.withValues(alpha: .35)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _gold,
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// "Удахгүй болох" / "Оролцсон" сонгогч
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.showPast,
    required this.upcomingCount,
    required this.pastCount,
    required this.onChanged,
  });
  final bool showPast;
  final int upcomingCount, pastCount;
  final ValueChanged<bool> onChanged;

  Widget _segment(String label, int count, bool selected, bool past) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(past),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _primary.withValues(alpha: .12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? _dark : _muted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? _primary : _border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _light,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _segment('Удахгүй болох', upcomingCount, !showPast, false),
          _segment('Оролцсон', pastCount, showPast, true),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.past,
    required this.onTap,
  });
  final EventRecord event;
  final bool past;
  final VoidCallback onTap;

  Widget _categoryImage() => Image.asset(
    _categoryAssets[event.category] ?? 'assets/images/vol.jpg',
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => const ColoredBox(
      color: _light,
      child: Icon(Icons.volunteer_activism_rounded, color: _primary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl ?? '';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: url.isEmpty
                      ? _categoryImage()
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          errorBuilder: (context, error, stackTrace) =>
                              _categoryImage(),
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _smallRow(
                      Icons.calendar_today_rounded,
                      EventRecord.dateLabel(event.startsAt),
                    ),
                    const SizedBox(height: 3),
                    _smallRow(Icons.location_on_outlined, event.location),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: past ? _green.withValues(alpha: .1) : _light,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  past ? 'Оролцсон' : 'Бүртгүүлсэн',
                  style: TextStyle(
                    color: past ? _green : _primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: _muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title, body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _light,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: _primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _dark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}