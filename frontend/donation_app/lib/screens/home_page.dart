import 'package:flutter/material.dart';

import 'auth_page.dart';
import 'event_list_page.dart';
import 'create_event_page.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../theme/app_theme.dart';
import 'event_detail_page.dart';

const Color primaryBlue = AppColors.primary;
const Color darkBlue = AppColors.ink;
const Color lightBlue = AppColors.softGreen;
const Color backgroundBlue = AppColors.background;
const Color softBorder = AppColors.border;

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
      final page = await _eventService.list(limit: 3, upcoming: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.forest, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.volunteer_activism_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Volunteer Hub',
                            style: TextStyle(
                              color: darkBlue,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Сайн үйлсэд нэгдье',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_session != null) ...[
                      Flexible(
                        child: Text(
                          'Тавтай морил! ${_session!.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _loggingOut ? null : _logout,
                        child: const Text('Гарах'),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () => _openAuth(),
                        child: const Text('Нэвтрэх'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _openAuth(register: true),
                        child: const Text('Бүртгүүлэх'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // HERO SECTION
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/vol.jpg'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Color(0xA8153D31),
                        BlendMode.darken,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'САЙН ҮЙЛСИЙН НЭГДЭЛ',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Сайн үйлсэд\nхамтдаа!',
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 13),
                      const Text(
                        'Бусдад тусалж, нийгэмдээ эерэг\nөөрчлөлтийг хамтдаа бүтээцгээе.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _openEvents,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.forest,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          'Үйл ажиллагаа үзэх',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // STATISTICS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  children: const [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite_rounded,
                        value: '120+',
                        label: 'Сайн дурынхан',
                        color: Color(0xFFFFE7ED),
                        iconColor: Color(0xFFFF7293),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.event_available_rounded,
                        value: '35+',
                        label: 'Үйл ажиллагаа',
                        color: AppColors.softGreen,
                        iconColor: primaryBlue,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.volunteer_activism_rounded,
                        value: '500+',
                        label: 'Сайн үйлс',
                        color: const Color(0xFFE7F2E6),
                        iconColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // CATEGORIES
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ангиллууд',
                        style: TextStyle(
                          color: darkBlue,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openEvents,
                      child: const Text('Бүгдийг үзэх →'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 125,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  children: const [
                    _CategoryCard(
                      title: 'Байгаль\nорчин',
                      icon: Icons.eco_rounded,
                      color: AppColors.softGreen,
                      iconColor: Color(0xFF35B779),
                    ),
                    _CategoryCard(
                      title: 'Хүүхэд,\nзалуус',
                      icon: Icons.child_care_rounded,
                      color: Color(0xFFFFF0DB),
                      iconColor: Color(0xFFFFAC42),
                    ),
                    _CategoryCard(
                      title: 'Боловсрол',
                      icon: Icons.menu_book_rounded,
                      color: Color(0xFFEDE7FF),
                      iconColor: Color(0xFF9275E8),
                    ),
                    _CategoryCard(
                      title: 'Нийгмийн\nхаламж',
                      icon: Icons.favorite_rounded,
                      color: Color(0xFFFFE6EA),
                      iconColor: Color(0xFFFF7293),
                    ),
                  ],
                ),
              ),
            ),

            if (_loadingEvents)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            if (_eventsError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(_eventsError!),
                      TextButton(
                        onPressed: _loadEvents,
                        child: const Text('Дахин оролдох'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_loadingEvents && _eventsError == null && _events.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Үйл ажиллагаа хараахан нийтлэгдээгүй байна.'),
                ),
              ),
            // UPCOMING EVENTS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Удахгүй болох үйл ажиллагаа',
                        style: TextStyle(
                          color: darkBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openEvents,
                      child: const Text('Бүгд →'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final event = _events[index];
                  return GestureDetector(
                    onTap: () async {
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
                    },
                    child: _EventCard(
                      event: {
                        ...event.toDisplay(),
                        'icon': Icons.volunteer_activism_rounded,
                        'color': lightBlue,
                        'people': '${event.participantCount}/${event.capacity}',
                      },
                    ),
                  );
                }, childCount: _events.length),
              ),
            ),

            // ABOUT
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(color: softBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.volunteer_activism_rounded,
                          color: primaryBlue,
                          size: 31,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Volunteer Hub гэж юу вэ?',
                              style: TextStyle(
                                color: darkBlue,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 9),
                            Text(
                              'Сайн дурын ажил зохион байгуулагчид болон '
                              'сайн дурын ажил хийх хүсэлтэй хүмүүсийг '
                              'нэг дор холбох платформ юм.',
                              style: TextStyle(
                                color: Color(0xFF687C9A),
                                fontSize: 13,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // CREATE EVENT CTA
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                child: Container(
                  padding: const EdgeInsets.all(23),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.forest, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forest.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Чи ч бас өөрчлөлт бүтээж чадна!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Өөрийн санаачилсан сайн дурын ажлаа '
                        'бусадтай хуваалцаарай.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 19),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openCreate,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.forest,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text(
                            'Үйл ажиллагаа нийтлэх',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: softBorder),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7183A0),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      margin: const EdgeInsets.only(right: 11, bottom: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: softBorder),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: iconColor, size: 25),
          ),
          const SizedBox(height: 9),
          Flexible(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: darkBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (event['image'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: softBorder),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 83,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: event['color'] as Color,
              borderRadius: BorderRadius.circular(19),
            ),
            child: imageUrl.isEmpty
                ? Icon(
                    event['icon'] as IconData,
                    color: primaryBlue,
                    size: 38,
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      event['icon'] as IconData,
                      color: primaryBlue,
                      size: 38,
                    ),
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event['category'] as String,
                    style: const TextStyle(
                      color: primaryBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event['title'] as String,
                  style: const TextStyle(
                    color: darkBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: Color(0xFF8091AC),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      event['date'] as String,
                      style: const TextStyle(
                        color: Color(0xFF7183A0),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Color(0xFF8091AC),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        event['location'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7183A0),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Column(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                color: primaryBlue,
                size: 19,
              ),
              const SizedBox(height: 5),
              Text(
                event['people'] as String,
                style: const TextStyle(
                  color: darkBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
