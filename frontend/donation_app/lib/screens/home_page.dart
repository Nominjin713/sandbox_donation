import 'package:flutter/material.dart';

import 'auth_page.dart';
import 'event_list_page.dart';
import 'create_event_page.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import 'event_detail_page.dart';
import 'profile_page.dart';

const Color primaryBlue = Color(0xFF7353BA);
const Color darkBlue = Color(0xFF39275F);
const Color mutedText = Color(0xFF756D83);
const Color lightBlue = Color(0xFFF0EBFA);
const Color backgroundBlue = Color(0xFFF8F6FF);
const Color softBorder = Color(0xFFE7E0F3);

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.authService});
  final AuthService? authService;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AuthService _authService = widget.authService ?? AuthService();
  AuthSession? get _session => _authService.currentSession;
  late final _eventService = EventService(_authService);
  List<EventRecord> _events = [];
  bool _loadingEvents = true;
  String? _eventsError;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    final version = ++_loadVersion;
    setState(() {
      _loadingEvents = true;
      _eventsError = null;
    });
    try {
      final page = await _eventService.list(limit: 6, upcoming: true);
      if (mounted && version == _loadVersion) {
        setState(() => _events = page.events);
      }
    } on AuthException catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() => _eventsError = error.message);
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loadingEvents = false);
      }
    }
  }

  Future<void> _openEvents() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventListPage(authService: _authService),
      ),
    );
    if (mounted) {
      setState(() {});
      _loadEvents();
    }
  }

  Future<void> _openCreate() async {
    if (_session == null) await _openAuth();
    if (!mounted || _session == null) return;
    final event = await Navigator.of(context).push<EventRecord>(
      MaterialPageRoute(
        builder: (_) => CreateEventPage(authService: _authService),
      ),
    );
    if (!mounted) return;
    setState(() {});
    if (event != null) {
      _loadEvents();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Үйл ажиллагаа амжилттай нийтлэгдлээ.')),
      );
    }
  }

  bool _loggingOut = false;

  @override
  void dispose() {
    if (widget.authService == null) _authService.close();
    super.dispose();
  }

  Future<void> _openAuth({bool register = false}) async {
    final session = await Navigator.of(context).push<AuthSession>(
      MaterialPageRoute(
        builder: (_) => AuthPage(authService: _authService, register: register),
      ),
    );
    if (mounted && session != null) setState(() {});
  }

  Future<void> _logout() async {
    if (_loggingOut || _session == null) return;
    setState(() => _loggingOut = true);
    try {
      await _authService.logout(_session!.token);
      if (mounted) {
        setState(() {});
        _loadEvents();
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _openEvent(EventRecord event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event.toDisplay(),
          authService: _authService,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1120;
            final content = _DashboardMain(
              authService: _authService, // ШИНЭ: профайл товчинд хэрэгтэй
              events: _events,
              loading: _loadingEvents,
              error: _eventsError,
              signedIn: _session != null,
              userName: _session?.name ?? '',
              onEvents: _openEvents,
              onLogin: () => _openAuth(),
              onRegister: () => _openAuth(register: true),
              onLogout: _logout,
              onCreate: _openCreate,
              onRetry: _loadEvents,
              onOpenEvent: _openEvent,
              loggingOut: _loggingOut,
            );

            if (!desktop) return content;
            return Row(
              children: [
                _DesktopSidebar(
                  onEvents: _openEvents,
                  onCreate: _openCreate,
                  isSignedIn: _session != null,
                ),
                Expanded(child: content),
                const _DashboardAside(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.onEvents,
    required this.onCreate,
    required this.isSignedIn,
  });

  final VoidCallback onEvents;
  final VoidCallback onCreate;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    height: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: softBorder)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.volunteer_activism_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Сайн үйл',
                style: TextStyle(
                  color: darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text(
          'ҮНДСЭН ЦЭС',
          style: TextStyle(
            color: mutedText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _SidebarItem(
          icon: Icons.grid_view_rounded,
          label: 'Нүүр хуудас',
          selected: true,
          onTap: () {},
        ),
        _SidebarItem(
          icon: Icons.event_available_rounded,
          label: 'Арга хэмжээнүүд',
          onTap: onEvents,
        ),
        const _SidebarItem(
          icon: Icons.favorite_border_rounded,
          label: 'Хадгалсан',
        ),
        const _SidebarItem(
          icon: Icons.people_alt_outlined,
          label: 'Сайн дурынхан',
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: primaryBlue),
              const SizedBox(height: 8),
              const Text(
                'Санаагаа хуваалцаарай',
                style: TextStyle(color: darkBlue, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              const Text(
                'Шинэ арга хэмжээ нээгээд бусдыг уриарай.',
                style: TextStyle(color: mutedText, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Арга хэмжээ нэмэх'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isSignedIn ? 'Таны бүртгэл нэвтэрсэн' : 'Сайн дурын ажилд нэгдээрэй',
          style: const TextStyle(color: mutedText, fontSize: 10),
        ),
      ],
    ),
  );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Material(
      color: selected ? lightBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? primaryBlue : mutedText),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? darkBlue : mutedText,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashboardAside extends StatelessWidget {
  const _DashboardAside();

  @override
  Widget build(BuildContext context) => Container(
    width: 270,
    height: double.infinity,
    padding: const EdgeInsets.fromLTRB(0, 20, 18, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: softBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Сайн үйлсийн нөлөө',
                style: TextStyle(color: darkBlue, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(
                    child: _AsideMetric(value: '32', label: 'Арга хэмжээ'),
                  ),
                  Expanded(
                    child: _AsideMetric(value: '120+', label: 'Сайн дурынхан'),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: const LinearProgressIndicator(
                  value: .68,
                  minHeight: 7,
                  color: primaryBlue,
                  backgroundColor: lightBlue,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Энэ сарын зорилгын 68%',
                style: TextStyle(color: mutedText, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: softBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Тун удахгүй',
                style: TextStyle(color: darkBlue, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 14),
              _AsideEvent(
                day: '31',
                month: '10-р сар',
                title: 'Хамтдаа мод тарья',
              ),
              Divider(height: 20, color: softBorder),
              _AsideEvent(
                day: '07',
                month: '11-р сар',
                title: 'Хүүхдүүдэд тусалъя',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Таны нэг цаг хэн нэгний амьдралд том өөрчлөлт авчирч чадна.',
            style: TextStyle(
              color: darkBlue,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AsideMetric extends StatelessWidget {
  const _AsideMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: primaryBlue,
          fontSize: 23,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(label, style: const TextStyle(color: mutedText, fontSize: 10)),
    ],
  );
}

class _AsideEvent extends StatelessWidget {
  const _AsideEvent({
    required this.day,
    required this.month,
    required this.title,
  });
  final String day;
  final String month;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              day,
              style: const TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(month, style: const TextStyle(color: mutedText, fontSize: 8)),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: darkBlue,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _DashboardMain extends StatelessWidget {
  const _DashboardMain({
    required this.authService, // ШИНЭ
    required this.events,
    required this.loading,
    required this.error,
    required this.signedIn,
    required this.userName,
    required this.onEvents,
    required this.onLogin,
    required this.onRegister,
    required this.onLogout,
    required this.onCreate,
    required this.onRetry,
    required this.onOpenEvent,
    required this.loggingOut,
  });

  final AuthService authService; // ШИНЭ
  final List<EventRecord> events;
  final bool loading;
  final String? error;
  final bool signedIn;
  final String userName;
  final VoidCallback onEvents, onLogin, onRegister, onLogout, onCreate, onRetry;
  final ValueChanged<EventRecord> onOpenEvent;
  final bool loggingOut;

  static const categories = [
    'Бүгд',
    'Байгаль орчин',
    'Нийгмийн халамж',
    'Боловсрол',
    'Цэвэр орчин',
  ];
  static const categoryIcons = [
    Icons.grid_view_rounded,
    Icons.eco_rounded,
    Icons.favorite_border_rounded,
    Icons.menu_book_rounded,
    Icons.cleaning_services_rounded,
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final inset = wide ? 30.0 : 17.0;
      final cardWidth = wide
          ? (constraints.maxWidth - inset * 2 - 18) / 2
          : constraints.maxWidth - inset * 2;

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(inset, 18, inset, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!wide) ...[
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wide ? 'Нүүр хуудас  /  Сайн дурын ажил' : 'Сайн үйл',
                        style: const TextStyle(color: mutedText, fontSize: 11),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        wide ? 'Сайн дурын ажлууд' : 'Volunteer Hub',
                        style: const TextStyle(
                          color: darkBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                if (signedIn) ...[
                  if (wide)
                    Flexible(
                      child: Text(
                        'Сайн байна уу, ' + userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: darkBlue, fontSize: 12),
                      ),
                    ),
                  // ШИНЭ: профайл хуудас нээх товч
                  ProfileButton(authService: authService),
                  IconButton(
                    tooltip: 'Гарах',
                    onPressed: loggingOut ? null : onLogout,
                    icon: const Icon(Icons.logout_rounded, color: primaryBlue),
                  ),
                ] else ...[
                  TextButton(onPressed: onLogin, child: const Text('Нэвтрэх')),
                  const SizedBox(width: 3),
                  FilledButton(
                    onPressed: onRegister,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Бүртгүүлэх'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            _DashboardHero(onExplore: onEvents, onCreate: onCreate, wide: wide),
            const SizedBox(height: 19),
            InkWell(
              onTap: onEvents,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: softBorder),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: mutedText, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Арга хэмжээ, сайн дурын ажил хайх...',
                        style: TextStyle(color: mutedText, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.tune_rounded, color: primaryBlue, size: 19),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 7,
              children: List.generate(
                categories.length,
                (index) => ActionChip(
                  avatar: Icon(
                    categoryIcons[index],
                    size: 15,
                    color: primaryBlue,
                  ),
                  label: Text(categories[index]),
                  onPressed: onEvents,
                  backgroundColor: index == 0 ? lightBlue : Colors.white,
                  side: BorderSide(
                    color: index == 0
                        ? primaryBlue.withValues(alpha: .25)
                        : softBorder,
                  ),
                  labelStyle: const TextStyle(
                    color: darkBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Тун удахгүй болох арга хэмжээнүүд',
                    style: TextStyle(
                      color: darkBlue,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onEvents,
                  child: const Text('Бүгдийг үзэх  →'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 35),
                child: Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                ),
              )
            else if (error != null)
              _DashboardMessage(
                text: error!,
                action: 'Дахин оролдох',
                onAction: onRetry,
              )
            else if (events.isEmpty)
              _DashboardMessage(
                text: 'Одоогоор нийтлэгдсэн арга хэмжээ алга.',
                action: 'Арга хэмжээ харах',
                onAction: onEvents,
              )
            else
              Wrap(
                spacing: 18,
                runSpacing: 15,
                children: events
                    .map(
                      (event) => SizedBox(
                        width: cardWidth,
                        child: _DashboardEventCard(
                          event: event,
                          onTap: () => onOpenEvent(event),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.volunteer_activism_rounded,
                    color: primaryBlue,
                    size: 25,
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Сайн үйлс өөрөөс чинь эхэлнэ. Өөрийн арга хэмжээг нээгээрэй.',
                      style: TextStyle(
                        color: darkBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(onPressed: onCreate, child: const Text('Нээх')),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.onExplore,
    required this.onCreate,
    required this.wide,
  });
  final VoidCallback onExplore, onCreate;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'ХАМТДАА САЙН ҮЙЛС БҮТЭЭЕ',
            style: TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Жижиг үйлдэл.\nТом өөрчлөлт.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            height: 1.12,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Өөрийн цаг, сэтгэлээ зориулж нийгэмдээ эерэг өөрчлөлт авчраарай.',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD166),
                foregroundColor: darkBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
              child: const Text(
                'Ажлууд үзэх  →',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton(
              onPressed: onCreate,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
              ),
              child: const Text(
                'Арга хэмжээ нэмэх',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: wide ? 235 : double.infinity,
        height: wide ? 190 : 150,
        child: Image.asset('assets/images/vol.jpg', fit: BoxFit.cover),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: .17),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 18),
                photo,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 16), photo],
            ),
    );
  }
}

class _DashboardEventCard extends StatelessWidget {
  const _DashboardEventCard({required this.event, required this.onTap});
  final EventRecord event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = event.startsAt;
    final dateLabel =
        date.month.toString().padLeft(2, '0') +
        '.' +
        date.day.toString().padLeft(2, '0') +
        ' · ' +
        date.hour.toString().padLeft(2, '0') +
        ':' +
        date.minute.toString().padLeft(2, '0');
    final image = event.imageUrl;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: softBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 145,
                    child: image != null
                        ? Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _fallback(),
                          )
                        : _fallback(),
                  ),
                  Positioned(
                    left: 11,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.category,
                        style: const TextStyle(
                          color: primaryBlue,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 11,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_border_rounded,
                        size: 16,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: mutedText,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: mutedText,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: mutedText,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: mutedText,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.participantCount.toString() +
                                ' / ' +
                                event.capacity.toString() +
                                ' оролцогч',
                            style: const TextStyle(
                              color: mutedText,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Дэлгэрэнгүй',
                            style: TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Image.asset(
    'assets/images/vol.jpg',
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Container(
      color: lightBlue,
      child: const Center(
        child: Icon(
          Icons.volunteer_activism_rounded,
          color: primaryBlue,
          size: 42,
        ),
      ),
    ),
  );
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.text,
    required this.action,
    required this.onAction,
  });
  final String text, action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: softBorder),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: mutedText),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}