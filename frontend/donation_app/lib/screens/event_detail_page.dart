import 'package:flutter/material.dart';

const Color primaryBlue = Color(0xFF4389F5);
const Color darkBlue = Color(0xFF19345C);
const Color backgroundBlue = Color(0xFFF4F8FF);
const Color borderBlue = Color(0xFFE3EDFC);

class EventDetailPage extends StatefulWidget {
  final Map<String, String> event;

  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isFavorite = false;
  bool _hasRequested = false;

  Color get categoryColor {
    switch (widget.event['category']) {
      case 'Байгаль орчин':
        return const Color(0xFF35B779);
      case 'Нийгмийн халамж':
        return const Color(0xFFFF7596);
      case 'Боловсрол':
        return const Color(0xFF9676E8);
      default:
        return primaryBlue;
    }
  }

  Color get categoryBackground {
    switch (widget.event['category']) {
      case 'Байгаль орчин':
        return const Color(0xFFE2F8EA);
      case 'Нийгмийн халамж':
        return const Color(0xFFFFE9EF);
      case 'Боловсрол':
        return const Color(0xFFEFE9FF);
      default:
        return const Color(0xFFE5EEFF);
    }
  }

  IconData get categoryIcon {
    switch (widget.event['category']) {
      case 'Байгаль орчин':
        return Icons.park_rounded;
      case 'Нийгмийн халамж':
        return Icons.volunteer_activism_rounded;
      case 'Боловсрол':
        return Icons.menu_book_rounded;
      case 'Цэвэр орчин':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volunteer_activism_rounded,
              color: primaryBlue,
              size: 23,
            ),
            SizedBox(width: 8),
            Text(
              'Volunteer Hub',
              style: TextStyle(
                color: darkBlue,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Хуваалцах үйлдлийг дараа холбож болно.'),
                ),
              );
            },
            icon: const Icon(Icons.share_rounded, color: primaryBlue),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(event),
                  const SizedBox(height: 16),
                  _buildStatistics(event),
                  const SizedBox(height: 16),
                  _buildDescription(event),
                  const SizedBox(height: 16),
                  _buildOrganizer(),
                  const SizedBox(height: 16),
                  _buildParticipants(event),
                  const SizedBox(height: 22),
                  _buildJoinButton(),
                  const SizedBox(height: 15),
                  const Center(
                    child: Text(
                      '💙 Сайн үйлсийг хамтдаа бүтээцгээе',
                      style: TextStyle(color: Color(0xFF8295B2), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(Map<String, String> event) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  categoryBackground,
                  const Color(0xFFF3F7FF),
                  categoryBackground.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(27),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -24,
                  right: -15,
                  child: Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Center(
                  child: Icon(categoryIcon, size: 92, color: categoryColor),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(categoryIcon, color: categoryColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          event['category'] ?? 'Бусад',
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                      },
                      icon: Icon(
                        _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isFavorite
                            ? const Color(0xFFFF6387)
                            : primaryBlue,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: primaryBlue,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Сайн үйлсийн боломж',
                          style: TextStyle(
                            color: darkBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] ?? 'Үйл ажиллагаа',
                  style: const TextStyle(
                    color: darkBlue,
                    fontSize: 25,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  event['category'] == 'Байгаль орчин'
                      ? 'Байгальдаа ээлтэй, ногоон ирээдүйн төлөө хамтдаа!'
                      : 'Өөрийн хувь нэмрээ оруулж, эерэг өөрчлөлт бүтээгээрэй.',
                  style: const TextStyle(
                    color: Color(0xFF7285A3),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(Map<String, String> event) {
    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            icon: Icons.calendar_month_rounded,
            label: 'Огноо',
            value: event['date'] ?? 'Тодорхойгүй',
            color: const Color(0xFFE5EEFF),
            iconColor: primaryBlue,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _InfoCard(
            icon: Icons.location_on_rounded,
            label: 'Байршил',
            value: event['location'] ?? 'Тодорхойгүй',
            color: const Color(0xFFE2F8EA),
            iconColor: const Color(0xFF35B779),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _InfoCard(
            icon: Icons.groups_rounded,
            label: 'Оролцогч',
            value: '${event['slots'] ?? '0'} хүн',
            color: const Color(0xFFEFE9FF),
            iconColor: const Color(0xFF9676E8),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(Map<String, String> event) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(
                Icons.description_rounded,
                const Color(0xFFE5EEFF),
                primaryBlue,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Үйл ажиллагааны тухай',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            event['description'] ??
                'Энэ үйл ажиллагааны дэлгэрэнгүй мэдээлэл удахгүй нэмэгдэнэ.',
            style: const TextStyle(
              color: Color(0xFF627694),
              fontSize: 14,
              height: 1.85,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: primaryBlue,
                  size: 21,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Таны оролцоо нийгэмдээ бодит өөрчлөлт авчирч чадна.',
                    style: TextStyle(
                      color: darkBlue,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizer() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 59,
            height: 59,
            decoration: BoxDecoration(
              color: const Color(0xFFE5EEFF),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Icon(Icons.eco_rounded, color: primaryBlue, size: 32),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Зохион байгуулагч',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Сайн дурын баг',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Нийгэмдээ эерэг өөрчлөлт бүтээх хамт олон.',
                  style: TextStyle(
                    color: Color(0xFF7184A2),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: primaryBlue, size: 24),
        ],
      ),
    );
  }

  Widget _buildParticipants(Map<String, String> event) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Оролцогчдын мэдээлэл',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.groups_rounded, color: primaryBlue, size: 23),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            'Нийт ${event['slots'] ?? '0'} оролцогч авах боломжтой.',
            style: const TextStyle(
              color: Color(0xFF7184A2),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF76B5FF), primaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Оролцогчдын явцыг бүртгэлтэй болсны дараа харуулна.',
            style: TextStyle(color: Color(0xFF8A9BB6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 57,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF68A6FF),
                  Color(0xFF4389F5),
                  Color(0xFF326EF0),
                ],
              ),
              borderRadius: BorderRadius.circular(19),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: 0.23),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _hasRequested = !_hasRequested);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: darkBlue,
                    content: Text(
                      _hasRequested
                          ? 'Хүсэлтийг тэмдэглэлээ. Backend холбосны дараа хүсэлт хадгалагдана.'
                          : 'Хүсэлтийн төлөвийг буцаалаа.',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              icon: Icon(
                _hasRequested ? Icons.check_circle_rounded : Icons.send_rounded,
                size: 20,
              ),
              label: Text(
                _hasRequested
                    ? 'Хүсэлт илгээхээр сонголоо'
                    : 'Оролцох хүсэлт илгээх',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 56,
          height: 57,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: borderBlue),
          ),
          child: IconButton(
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
            },
            icon: Icon(
              _isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: borderBlue),
      boxShadow: [
        BoxShadow(
          color: darkBlue.withValues(alpha: 0.035),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _iconBox(IconData icon, Color background, Color foreground) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: foreground, size: 23),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 115),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: borderBlue),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7C8EAA), fontSize: 10),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
