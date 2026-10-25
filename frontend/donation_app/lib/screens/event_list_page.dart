import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:ui' show ImageFilter;

import '../services/auth_service.dart';
import '../services/event_service.dart';

import 'event_detail_page.dart';

const Color primaryBlue = Color(0xFF4389F5);
const Color darkBlue = Color(0xFF19345C);
const Color backgroundBlue = Color(0xFFF4F8FF);
const Color borderBlue = Color(0xFFE3EDFC);
const Color mutedText = Color(0xFF6C7F9D);
const Color joinedGreen = Color(0xFF2E9E6A);

// ШИНЭ: хуудасны цэнхэр уусгалттай дэвсгэр (дээрээс доош цайрна)
const LinearGradient pageGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF1E6FE8), // цэнхэр
    Color(0xFF2FB4FF), // тод цэнхэр
    Color(0xFF6FA4FF), // зөөлөн цэнхэр
    Color(0xFF8E8CFF), // хөх (индиго)
  ],
  stops: [0.0, 0.35, 0.7, 1.0],
);

// Ангилал бүрийн зураг, icon, өнгө
class _CategoryStyle {
  const _CategoryStyle(this.asset, this.icon, this.accent, this.pale);
  final String asset;
  final IconData icon;
  final Color accent;
  final Color pale;

  static const _styles = <String, _CategoryStyle>{
    'Байгаль орчин': _CategoryStyle(
      'assets/images/environment.jpg',
      Icons.park_rounded,
      Color(0xFF35B779),
      Color(0xFFE1F7E9),
    ),
    'Нийгмийн халамж': _CategoryStyle(
      'assets/images/social.jpg',
      Icons.volunteer_activism_rounded,
      Color(0xFFFF7596),
      Color(0xFFFFE8EE),
    ),
    'Цэвэр орчин': _CategoryStyle(
      'assets/images/cleanup.jpg',
      Icons.cleaning_services_rounded,
      primaryBlue,
      Color(0xFFE5EEFF),
    ),
    'Боловсрол': _CategoryStyle(
      'assets/images/education.jpg',
      Icons.menu_book_rounded,
      Color(0xFF9676E8),
      Color(0xFFEDE7FF),
    ),
  };

  static const _other = _CategoryStyle(
    'assets/images/other.jpg',
    Icons.favorite_rounded,
    primaryBlue,
    Color(0xFFE5EEFF),
  );

  static _CategoryStyle of(String? category) => _styles[category] ?? _other;
}

// "2026.10.22 03:21" -> өдөр, сар, цаг
({String day, String month, String time}) _dateParts(String? raw) {
  final parts = (raw ?? '').trim().split(' ');
  final ymd = parts.first.split('.');
  if (ymd.length != 3) return (day: '', month: '', time: '');
  final day = int.tryParse(ymd[2]);
  final month = int.tryParse(ymd[1]);
  return (
    day: day == null ? ymd[2] : '$day',
    month: month == null ? '' : '$month-р сар',
    time: parts.length > 1 ? parts[1] : '',
  );
}

class EventListPage extends StatefulWidget {
  const EventListPage({super.key, this.authService});
  final AuthService? authService;

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final TextEditingController _searchController = TextEditingController();
  late final _api = widget.authService ?? AuthService();
  late final _service = EventService(_api);
  List<Map<String, String>> _events = [];
  bool _loading = false;
  String? _error;
  int? _nextOffset;
  int _total = 0, _version = 0;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!mounted) return;
    if (more && (_loading || _nextOffset == null)) return;
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _events = [];
        _nextOffset = null;
        _total = 0;
      }
    });
    try {
      final page = await _service.list(
        query: _searchController.text.trim(),
        category: _selectedCategory == 'Бүгд'
            ? ''
            : categoryCode(_selectedCategory),
        offset: more ? _nextOffset! : 0,
      );
      if (mounted && version == _version) {
        setState(() {
          _events = [
            ...(more ? _events : <Map<String, String>>[]),
            ...page.events.map((event) => event.toDisplay()),
          ];
          _nextOffset = page.nextOffset;
          _total = page.count;
        });
      }
    } on AuthException catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  void _search() {
    ++_version;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () => _load());
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() => _selectedCategory = 'Бүгд');
    _searchTimer?.cancel();
    _load();
  }

  String _selectedCategory = 'Бүгд';

  static const List<String> categories = [
    'Бүгд',
    'Байгаль орчин',
    'Нийгмийн халамж',
    'Цэвэр орчин',
    'Боловсрол',
    'Бусад',
  ];

  @override
  void dispose() {
    _searchTimer?.cancel();
    if (widget.authService == null) _api.close();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get filteredEvents {
    final query = _searchController.text.trim().toLowerCase();

    return _events.where((event) {
      final matchesCategory =
          _selectedCategory == 'Бүгд' || event['category'] == _selectedCategory;

      final matchesSearch =
          (event['title'] ?? '').toLowerCase().contains(query) ||
          (event['location'] ?? '').toLowerCase().contains(query) ||
          (event['category'] ?? '').toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredEvents;

    // ШИНЭ: бүх хуудасны ард цэнхэр уусгалт
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: pageGradient),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryBlue,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        title: const Text(
          'Үйл ажиллагаанууд',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(),
          color: primaryBlue,
          child: CustomScrollView(
            slivers: [
              // HERO
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: _buildHero(),
                ),
              ),

              // ХАЙЛТ + АНГИЛАЛ (гүйлгэхэд дээр наалдаж үлдэнэ)
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedBar(height: 128, child: _buildFilterBar()),
              ),

              // ҮР ДҮНГИЙН ГАРЧИГ
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Танд зориулсан боломжууд',
                          style: TextStyle(
                            color: darkBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '$_total үйл ажиллагаа',
                        style: const TextStyle(
                          color: darkBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // АЧААЛЖ БАЙХ ҮЕД
              if (_loading && filtered.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: _SkeletonCard(),
                      ),
                      childCount: 2,
                    ),
                  ),
                )
              else if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ),

              // АЛДАА
              if (_error != null)
                SliverToBoxAdapter(child: _buildMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Мэдээлэл ачаалж чадсангүй',
                  body: _error!,
                  actionLabel: 'Дахин ачаалах',
                  onAction: () => _load(more: _events.isNotEmpty),
                )),

              // ХООСОН
              if (filtered.isEmpty && !_loading && _error == null)
                SliverToBoxAdapter(child: _buildMessage(
                  icon: Icons.search_off_rounded,
                  title: 'Үйл ажиллагаа олдсонгүй',
                  body: 'Өөр үгээр хайх эсвэл бүх ангиллыг харах боломжтой.',
                  actionLabel: 'Бүгдийг харах',
                  onAction: _resetFilters,
                ))
              else if (filtered.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  sliver: _buildEventGrid(filtered),
                ),

              if (_nextOffset != null && !_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    child: OutlinedButton(
                      onPressed: () => _load(more: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryBlue,
                        side: const BorderSide(color: borderBlue),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Цааш үзэх',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // Дэлгэцийн өргөнөөс хамаарч 1, 2, 3 багана
  Widget _buildEventGrid(List<Map<String, String>> filtered) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = width >= 1000 ? 3 : (width >= 600 ? 2 : 1);

        if (columns == 1) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _EventCard(
                  event: filtered[index],
                  api: _api,
                  onChanged: () => _load(),
                ),
              ),
              childCount: filtered.length,
            ),
          );
        }

        const spacing = 16.0;
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            // зураг (16:10) + доорх мэдээлэл
            mainAxisExtent: tileWidth * 10 / 16 + 200,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _EventCard(
              event: filtered[index],
              api: _api,
              onChanged: () => _load(),
              expand: true,
            ),
            childCount: filtered.length,
          ),
        );
      },
    );
  }

  // Дээд хэсэг: бодит зураг дээр гарчиг
  // Дээд хэсгийн зураг: босоо дэлгэц дээрх шиг бүтэн өргөнөөр,
  // гэхдээ том дэлгэц дээр хэт өндөр болохгүй
  Widget _buildHero() {
    return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // жижиг дэлгэц дээрхтэй ижил харьцаа, гэхдээ хэт өндөр болохгүй
            // 360 = хамгийн их өндөр. Багасгавал намхан, ихэсгэвэл өндөр болно.
            final height = (width / 2.6).clamp(190.0, 360.0);

            return ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/vol.jpg',
                      fit: BoxFit.cover,
                      // өргөн дэлгэц дээр хүмүүсийн нүүр харагдахаар дээш нь тааруулсан
                      alignment: const Alignment(0, -0.6),
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(color: darkBlue),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            darkBlue.withValues(alpha: 0.88),
                            darkBlue.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'Сайн үйлсэд хамтдаа',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Сонирхолдоо тохирох сайн дурын ажлаа олоод нэгдээрэй.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          if (_total > 0) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_total үйл ажиллагаа нээлттэй',
                                style: const TextStyle(
                                  color: darkBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _buildFilterBar() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SizedBox(
            height: 52,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _search(),
              style: const TextStyle(color: darkBlue, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Нэр, байршлаар хайх',
                hintStyle: const TextStyle(
                  color: Color(0xFF8A9BB6),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: primaryBlue,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Цэвэрлэх',
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF8A9BB6),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: borderBlue),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: borderBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              final selected = _selectedCategory == category;
              final style = _CategoryStyle.of(category);

              return ChoiceChip(
                avatar: category == 'Бүгд'
                    ? null
                    : Icon(
                        style.icon,
                        size: 15,
                        color: selected ? Colors.white : style.accent,
                      ),
                label: Text(category),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                  _searchTimer?.cancel();
                  _load();
                },
                labelStyle: TextStyle(
                  color: selected ? Colors.white : darkBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: Colors.white,
                selectedColor: darkBlue,
                side: BorderSide(color: selected ? darkBlue : borderBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 20),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F0FF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, color: primaryBlue, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedText, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

// Хайлт, ангиллыг дээр наалдуулж үлдээх
class _PinnedBar extends SliverPersistentHeaderDelegate {
  _PinnedBar({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // ШИНЭ: уусгалттай дэвсгэр дээр бүдэгрүүлсэн шилэн эффект
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.28),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedBar oldDelegate) => true;
}

class _EventCard extends StatelessWidget {
  final Map<String, String> event;
  final AuthService api;
  final VoidCallback onChanged;
  final bool expand; // grid дотор байгаа эсэх

  const _EventCard({
    required this.event,
    required this.api,
    required this.onChanged,
    this.expand = false,
  });

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailPage(event: event, authService: api),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final style = _CategoryStyle.of(event['category']);
    final date = _dateParts(event['date']);
    final slots = int.tryParse(event['slots'] ?? '') ?? 0;
    final joined = int.tryParse(event['participants'] ?? '') ?? 0;
    final isJoined = event['isJoined'] == 'true';
    final isFull = slots > 0 && joined >= slots;
    final progress = slots == 0 ? 0.0 : (joined / slots).clamp(0.0, 1.0);

    final image = _CardImage(
      imageUrl: event['image'] ?? '', // ШИНЭ: эвентийн өөрийн зураг
      style: style,
      category: event['category'] ?? '',
      day: date.day,
      month: date.month,
      isJoined: isJoined,
    );

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: borderBlue),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expand)
              Expanded(child: image)
            else
              AspectRatio(aspectRatio: 16 / 10, child: image),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: darkBlue,
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    text: date.time.isEmpty
                        ? (event['date'] ?? '')
                        : '${date.month} ${date.day}, ${date.time}',
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    text: event['location'] ?? '',
                  ),
                  const SizedBox(height: 14),
                  // Хэдэн хүн бүртгүүлснийг харуулах
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEEF3FB),
                      color: isFull ? const Color(0xFFE5A23B) : style.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$joined / $slots хүн',
                        style: const TextStyle(
                          color: darkBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isFull ? 'Дүүрсэн' : '${slots - joined} сул орон',
                        style: TextStyle(
                          color: isFull ? const Color(0xFFC77F12) : mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8295B2)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: mutedText, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// Картын зураг: ангилал, огноо, бүртгүүлсэн тэмдэг
class _CardImage extends StatelessWidget {
  const _CardImage({
    this.imageUrl = '',
    required this.style,
    required this.category,
    required this.day,
    required this.month,
    required this.isJoined,
  });
  final String imageUrl;
  final _CategoryStyle style;
  final String category, day, month;
  final bool isJoined;

  // Ангиллын зураг (эвент зураггүй үед)
  Widget _categoryImage() => Image.asset(
    style.asset,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => _fallback(),
  );

  Widget _fallback() {
    return ColoredBox(
      color: style.pale,
      child: Icon(style.icon, color: style.accent, size: 56),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ШИНЭ: эвент өөрийн зурагтай бол түүнийг, үгүй бол ангиллын зургийг
        // BoxFit.cover: босоо ч, хэвтээ ч зураг сунахгүйгээр тайрагдана
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            // Web дээр CORS-оос болж ачаалагдахгүй бол энгийн <img>-ээр харуулна
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : ColoredBox(color: style.pale),
            errorBuilder: (context, error, stackTrace) => _categoryImage(),
          )
        else
          _categoryImage(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Colors.transparent, Color(0x33000000)],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
        ),
        // Ангилал
        if (category.isNotEmpty)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(style.icon, color: style.accent, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    category,
                    style: TextStyle(
                      color: style.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Огноо: календарийн хуудас шиг
        if (day.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      color: darkBlue,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    month,
                    style: const TextStyle(
                      color: mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Бүртгүүлсэн бол
        if (isJoined)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: joinedGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'Бүртгүүлсэн',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Ачаалж байх үеийн саарал карт
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  Widget _bar(double? width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFEEF3FB),
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 10,
            child: ColoredBox(color: Color(0xFFE9EFF8)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(180, 18),
                const SizedBox(height: 12),
                _bar(140, 12),
                const SizedBox(height: 8),
                _bar(110, 12),
                const SizedBox(height: 16),
                _bar(double.infinity, 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}