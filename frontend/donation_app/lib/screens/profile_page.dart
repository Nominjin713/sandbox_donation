import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/event_service.dart';

import 'event_detail_page.dart';

// ================= ӨНГӨ (Үйл ажиллагаанууд хуудастай ижил шар загвар) =================
const Color _ink = Color(0xFF4A2F00);
const Color _inkMuted = Color(0xFF8C6A2F);
const Color _iconMuted = Color(0xFFC08A2E);
const Color _line = Color(0xFFFFE6A3);
const Color _cream = Color(0xFFFFF6DA);
const Color _green = Color(0xFF2E9E6A);

const LinearGradient _sunGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFFFE57F),
    Color(0xFFFFCA28),
    Color(0xFFFFB74D),
    Color(0xFFFFE0B2),
  ],
  stops: [0.0, 0.3, 0.65, 1.0],
);

const List<Color> _btnCream = [Colors.white, Color(0xFFFFF0BC)];
const Color _edgeCream = Color(0xFFEFC861);
const List<Color> _btnDeep = [Color(0xFFFFC107), Color(0xFFFF7A00)];
const Color _edgeDeep = Color(0xFFC75B00);

const List<Shadow> _textShadow = [
  Shadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1)),
];

const Map<String, String> _categoryAssets = {
  'environment': 'assets/images/environment.jpg',
  'social': 'assets/images/social.jpg',
  'education': 'assets/images/education.jpg',
  'cleanup': 'assets/images/cleanup.jpg',
};

// ================= НҮҮР ХУУДСАНД ТАВИХ ПРОФАЙЛ ТОВЧ =================
/// AppBar-ын actions дотор `const ProfileButton()` гэж тавина.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, this.authService});
  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Center(
        child: _Button3D(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(authService: authService),
            ),
          ),
          width: 44,
          height: 44,
          radius: 22,
          depth: 4,
          padding: EdgeInsets.zero,
          colors: _btnCream,
          edge: _edgeCream,
          child: const Icon(Icons.person_rounded, color: _ink),
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
        setState(() => _error = 'Мэдээллийг ачаалж чадсангүй. Дахин оролдоно уу.');
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
    final joined = [_pick(['first_name', 'ovog']), _pick(['last_name', 'ner'])]
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (joined.isNotEmpty) return joined;
    final username = _pick(['username']);
    if (username.isNotEmpty) return username;
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _sunGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 66,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Center(
              child: _Button3D(
                onTap: () => Navigator.pop(context),
                width: 44,
                height: 44,
                radius: 22,
                depth: 4,
                padding: EdgeInsets.zero,
                colors: _btnCream,
                edge: _edgeCream,
                child: const Icon(Icons.arrow_back_rounded, color: _ink),
              ),
            ),
          ),
          title: const Text(
            'Миний профайл',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: _Button3D(
                  onTap: _loading ? null : _load,
                  width: 44,
                  height: 44,
                  radius: 22,
                  depth: 4,
                  padding: EdgeInsets.zero,
                  colors: _btnCream,
                  edge: _edgeCream,
                  child: const Icon(Icons.refresh_rounded, color: _ink),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: RefreshIndicator(
                onRefresh: _load,
                color: const Color(0xFFFF8F00),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  children: _buildContent(),
                ),
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
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFFFF8F00)),
          ),
        ),
      ];
    }

    if (_error != null && _user.isEmpty) {
      return [
        _MessageBox(
          icon: Icons.wifi_off_rounded,
          title: 'Профайл ачаалж чадсангүй',
          body: _error!,
          actionLabel: 'Дахин ачаалах',
          onAction: _load,
        ),
      ];
    }

    final events = _showPast ? _past : _upcoming;

    return [
      _buildProfileCard(),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.event_available_rounded,
              value: '${_upcoming.length}',
              label: 'Бүртгүүлсэн',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: Icons.emoji_events_rounded,
              value: '${_past.length}',
              label: 'Оролцсон',
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      // Удахгүй / Оролцсон солих 3D товчнууд
      Row(
        children: [
          Expanded(child: _tabButton('Удахгүй болох', !_showPast, false)),
          const SizedBox(width: 12),
          Expanded(child: _tabButton('Оролцсон', _showPast, true)),
        ],
      ),
      const SizedBox(height: 16),
      if (_loading)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(
            minHeight: 2,
            color: Color(0xFFFF8F00),
            backgroundColor: Color(0x55FFFFFF),
          ),
        ),
      if (events.isEmpty)
        _MessageBox(
          icon: _showPast ? Icons.history_rounded : Icons.event_note_rounded,
          title: _showPast
              ? 'Одоогоор оролцсон үйл ажиллагаа алга'
              : 'Бүртгүүлсэн үйл ажиллагаа алга',
          body: _showPast
              ? 'Үйл ажиллагаанд бүртгүүлж оролцсоны дараа энд харагдана.'
              : 'Сонирхсон үйл ажиллагаандаа бүртгүүлэхэд энд харагдана.',
        )
      else
        ...events.map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _EventTile(
              event: event,
              past: _showPast,
              onTap: () => _openEvent(event),
            ),
          ),
        ),
    ];
  }

  Widget _tabButton(String label, bool selected, bool past) {
    return _Button3D(
      onTap: () => setState(() => _showPast = past),
      width: double.infinity,
      radius: 18,
      depth: 4,
      padding: const EdgeInsets.symmetric(vertical: 12),
      colors: selected ? _btnDeep : _btnCream,
      edge: selected ? _edgeDeep : _edgeCream,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _ink,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          shadows: selected ? _textShadow : null,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _name;
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return _RaisedCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _btnDeep,
              ),
              boxShadow: [
                BoxShadow(color: _edgeDeep, offset: Offset(0, 4)),
                BoxShadow(
                  color: Color(0x40C77700),
                  blurRadius: 16,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                shadows: _textShadow,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_email.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoLine(icon: Icons.mail_rounded, text: _email),
          ],
          if (_phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(icon: Icons.phone_rounded, text: _phone),
          ],
        ],
      ),
    );
  }
}

// ================= ЖИЖИГ WIDGET-ҮҮД =================

// Товойсон цагаан карт
class _RaisedCard extends StatelessWidget {
  const _RaisedCard({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0xFFF0C760), offset: Offset(0, 6)),
          BoxShadow(
            color: Color(0x40C77700),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _iconMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _inkMuted, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return _RaisedCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFFF8F00), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: _inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
      color: _cream,
      child: Icon(Icons.volunteer_activism_rounded, color: Color(0xFFFF8F00)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl ?? '';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0xFFF0C760), offset: Offset(0, 5)),
          BoxShadow(
            color: Color(0x33C77700),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0x22FFB300),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 86,
                    height: 86,
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _smallRow(
                        Icons.schedule_rounded,
                        EventRecord.dateLabel(event.startsAt),
                      ),
                      const SizedBox(height: 3),
                      _smallRow(Icons.location_on_rounded, event.location),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: past
                              ? _green.withValues(alpha: 0.12)
                              : const Color(0xFFFFF0C2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          past ? 'Оролцсон' : 'Бүртгүүлсэн',
                          style: TextStyle(
                            color: past ? _green : const Color(0xFFC75B00),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _iconMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _iconMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _inkMuted, fontSize: 12),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _btnCream,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: _edgeCream, offset: Offset(0, 5)),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFFF8F00), size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _inkMuted, fontSize: 13, height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            _Button3D(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  shadows: _textShadow,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================= 3D ТОВОЙСОН ТОВЧ =================
class _Button3D extends StatefulWidget {
  const _Button3D({
    required this.child,
    required this.onTap,
    this.colors = _btnDeep,
    this.edge = _edgeDeep,
    this.radius = 18,
    this.depth = 5,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
    this.width,
    this.height,
  });

  final Widget child;
  final VoidCallback? onTap;
  final List<Color> colors;
  final Color edge;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  @override
  State<_Button3D> createState() => _Button3DState();
}

class _Button3DState extends State<_Button3D> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final lift = _pressed ? 1.0 : widget.depth;
    final radius = BorderRadius.circular(widget.radius);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled
            ? (_) {
                _setPressed(false);
                widget.onTap!();
              }
            : null,
        onTapCancel: () => _setPressed(false),
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.depth),
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              alignment: (widget.width != null || widget.height != null)
                  ? Alignment.center
                  : null,
              transform: Matrix4.translationValues(0, widget.depth - lift, 0),
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.colors,
                ),
                boxShadow: [
                  BoxShadow(color: widget.edge, offset: Offset(0, lift)),
                  BoxShadow(
                    color: widget.edge.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: Offset(0, lift + 5),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.5],
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}