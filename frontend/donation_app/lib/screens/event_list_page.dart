import 'package:flutter/material.dart';

import 'dart:async';

import '../services/auth_service.dart';
import '../services/event_service.dart';

import 'event_detail_page.dart';

const Color primaryBlue = Color(0xFF4389F5);
const Color darkBlue = Color(0xFF19345C);
const Color backgroundBlue = Color(0xFFF4F8FF);
const Color borderBlue = Color(0xFFE3EDFC);

// ШИНЭ: ангилал бүрийн зураг, icon, өнгө
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

    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        backgroundColor: backgroundBlue,
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
            color: darkBlue,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: _buildHeader(),
              ),
            ),

            // SEARCH
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 15),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _search(),
                  style: const TextStyle(color: darkBlue, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Үйл ажиллагаа хайх...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8A9BB6),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: primaryBlue,
                      size: 24,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
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
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 17,
                      horizontal: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: borderBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: borderBlue),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: primaryBlue,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // CATEGORY FILTERS
            SliverToBoxAdapter(
              child: SizedBox(
                height: 47,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = _selectedCategory == category;

                    return ChoiceChip(
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
                      selectedColor: primaryBlue,
                      side: BorderSide(
                        color: selected ? primaryBlue : borderBlue,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                    );
                  },
                ),
              ),
            ),

            // RESULTS HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 13),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F0FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_total ажил',
                        style: const TextStyle(
                          color: primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // EVENT CARDS
            if (_loading)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: () => _load(more: _events.isNotEmpty),
                        child: const Text('Дахин оролдох'),
                      ),
                    ],
                  ),
                ),
              ),
            if (filtered.isEmpty && !_loading && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(35),
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F0FF),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.search_off_rounded,
                          color: primaryBlue,
                          size: 45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Үйл ажиллагаа олдсонгүй',
                        style: TextStyle(
                          color: darkBlue,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Өөр үг эсвэл ангиллаар хайж үзээрэй.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF7C8EAA),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // ШИНЭ: дэлгэцийн өргөнөөс хамаарч 1, 2, 3 багана
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 1000 ? 3 : (width >= 600 ? 2 : 1);

                    if (columns == 1) {
                      // Босоо утас: нэг багана, жагсаалт
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

                    // Хэвтээ утас / tablet / компьютер: grid
                    const spacing = 16.0;
                    final tileWidth =
                        (width - spacing * (columns - 1)) / columns;
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        // зураг 16:9 + доорх мэдээллийн хэсэг
                        mainAxisExtent: tileWidth * 9 / 16 + 250,
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
                ),
              ),
            if (_nextOffset != null && !_loading)
              SliverToBoxAdapter(
                child: TextButton(
                  onPressed: () => _load(more: true),
                  child: const Text('Цааш үзэх'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0EDFF), Color(0xFFF0F6FF), Color(0xFFE6F5FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Text(
              '💙 Сайн үйлсийн нэгдэл',
              style: TextStyle(
                color: primaryBlue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Сайн үйлсэд\nхамтдаа!',
            style: TextStyle(
              color: darkBlue,
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Өөрийн сонирхолд тохирох сайн дурын ажлыг '
            'олоод, эерэг өөрчлөлт бүтээгээрэй.',
            style: TextStyle(
              color: Color(0xFF627A9C),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              _miniInfo(Icons.favorite_rounded, 'Сайн үйлс'),
              const SizedBox(width: 10),
              _miniInfo(Icons.groups_rounded, 'Нэгдэл'),
              const Spacer(),
              const Icon(
                Icons.volunteer_activism_rounded,
                color: primaryBlue,
                size: 39,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryBlue, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ШИНЭ: картын дээд хэсгийн зураг
class _EventImage extends StatelessWidget {
  const _EventImage({required this.style, required this.category});
  final _CategoryStyle style;
  final String category;

  Widget _fallback() {
    // Зураг олдохгүй бол өмнөх шиг өнгөт дэвсгэр + icon
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [style.pale, style.pale.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(style.icon, color: style.accent, size: 56),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // BoxFit.cover: босоо ч, хэвтээ ч зураг сунахгүйгээр тайрагдана
        Image.asset(
          style.asset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
        // Доод талд бага зэрэг сүүдэр
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x40000000)],
              stops: [0.6, 1.0],
            ),
          ),
        ),
        // Ангиллын тэмдэг зураг дээр
        if (category.isNotEmpty)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
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
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, String> event;
  final AuthService api;
  final VoidCallback onChanged;
  final bool expand; // ШИНЭ: grid дотор байгаа эсэх

  const _EventCard({
    required this.event,
    required this.api,
    required this.onChanged,
    this.expand = false,
  });

  // ШИНЭ: карт болон товч хоёулаа ижил байдлаар нээгдэнэ
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
    final image = _EventImage(style: style, category: event['category'] ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderBlue),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetail(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Жагсаалтад 16:9, grid дотор үлдсэн зайг бүтэн эзэлнэ
              if (expand)
                Expanded(child: image)
              else
                AspectRatio(aspectRatio: 16 / 9, child: image),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: darkBlue,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF9AACCA),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 15,
                          color: Color(0xFF8295B2),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event['date'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFF7184A2),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFEEF3FB), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: primaryBlue,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event['location'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6C7F9D),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.people_alt_rounded,
                          color: primaryBlue,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${event['slots']} хүн',
                          style: const TextStyle(
                            color: darkBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _openDetail(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryBlue,
                          side: const BorderSide(color: borderBlue),
                          backgroundColor: const Color(0xFFF8FBFF),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Дэлгэрэнгүй үзэх',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 7),
                            Icon(Icons.arrow_forward_rounded, size: 17),
                          ],
                        ),
                      ),
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
}