
import 'package:flutter/material.dart';
import 'event_detail_page.dart';

const Color primaryBlue = Color(0xFF4389F5);
const Color darkBlue = Color(0xFF19345C);
const Color backgroundBlue = Color(0xFFF4F8FF);
const Color borderBlue = Color(0xFFE3EDFC);

class EventListPage extends StatefulWidget {
  const EventListPage({super.key});

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _selectedCategory = 'Бүгд';

  static const List<String> categories = [
    'Бүгд',
    'Байгаль орчин',
    'Нийгмийн халамж',
    'Цэвэр орчин',
    'Боловсрол',
    'Бусад',
  ];

  static const List<Map<String, String>> events = [
    {
      'title': 'Мод тарих өдөрлөг',
      'date': '2026.10.25',
      'location': 'Улаанбаатар хот',
      'category': 'Байгаль орчин',
      'description':
          'Ногоон орчноо нэмэгдүүлэх зорилгоор мод тарина. '
          'Та бүхнийг сайн дурын ажилд урьж байна.',
      'slots': '30',
      'color': 'green',
      'icon': 'tree',
    },
    {
      'title': 'Хүүхдүүдэд тусалъя',
      'date': '2026.10.28',
      'location': 'Сүхбаатар дүүрэг',
      'category': 'Нийгмийн халамж',
      'description':
          'Хүүхдүүдтэй цагийг өнгөрүүлж, тэдэнд туслах '
          'сайн дурын үйл ажиллагаа.',
      'slots': '15',
      'color': 'pink',
      'icon': 'heart',
    },
    {
      'title': 'Орчны цэвэрлэгээ',
      'date': '2026.11.01',
      'location': 'Үндэсний цэцэрлэгт хүрээлэн',
      'category': 'Цэвэр орчин',
      'description':
          'Нийтийн эзэмшлийн талбайг цэвэрлэж, '
          'байгаль орчноо хамгаалцгаая.',
      'slots': '40',
      'color': 'blue',
      'icon': 'clean',
    },
    {
      'title': 'Номын сан тохижуулах',
      'date': '2026.11.05',
      'location': 'Баянзүрх дүүрэг',
      'category': 'Боловсрол',
      'description':
          'Хүүхэд залуусын сурах орчныг сайжруулж, '
          'номын санг хамтдаа тохижуулна.',
      'slots': '20',
      'color': 'purple',
      'icon': 'book',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get filteredEvents {
    final query = _searchController.text.trim().toLowerCase();

    return events.where((event) {
      final matchesCategory = _selectedCategory == 'Бүгд' ||
          event['category'] == _selectedCategory;

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
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: darkBlue,
                    fontSize: 14,
                  ),
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
                              setState(() {});
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
                      borderSide: const BorderSide(
                        color: borderBlue,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: borderBlue,
                      ),
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
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = _selectedCategory == category;

                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
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
                        '${filtered.length} ажил',
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
            if (filtered.isEmpty)
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _EventCard(event: filtered[index]);
                    },
                    childCount: filtered.length,
                  ),
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
          colors: [
            Color(0xFFE0EDFF),
            Color(0xFFF0F6FF),
            Color(0xFFE6F5FF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
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

class _EventCard extends StatelessWidget {
  final Map<String, String> event;

  const _EventCard({required this.event});

  Color get _accentColor {
    switch (event['color']) {
      case 'green':
        return const Color(0xFF35B779);
      case 'pink':
        return const Color(0xFFFF7596);
      case 'purple':
        return const Color(0xFF9676E8);
      default:
        return primaryBlue;
    }
  }

  Color get _paleColor {
    switch (event['color']) {
      case 'green':
        return const Color(0xFFE1F7E9);
      case 'pink':
        return const Color(0xFFFFE8EE);
      case 'purple':
        return const Color(0xFFEDE7FF);
      default:
        return const Color(0xFFE5EEFF);
    }
  }

  IconData get _eventIcon {
    switch (event['icon']) {
      case 'tree':
        return Icons.park_rounded;
      case 'heart':
        return Icons.volunteer_activism_rounded;
      case 'clean':
        return Icons.cleaning_services_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDetailPage(event: event),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 83,
                      height: 91,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _paleColor,
                            _paleColor.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Icon(
                        _eventIcon,
                        color: _accentColor,
                        size: 42,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _paleColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              event['category'] ?? '',
                              style: TextStyle(
                                color: _accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            event['title'] ?? '',
                            style: const TextStyle(
                              color: darkBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 9),
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
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF9AACCA),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Divider(color: Color(0xFFEEF3FB), height: 1),
                const SizedBox(height: 13),
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
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailPage(event: event),
                        ),
                      );
                    },
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
        ),
      ),
    );
  }
}
