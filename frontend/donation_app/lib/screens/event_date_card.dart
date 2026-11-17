import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Монгол гарагийн нэр (Даваа = 1).
const List<String> mnWeekdays = [
  'Даваа',
  'Мягмар',
  'Лхагва',
  'Пүрэв',
  'Баасан',
  'Бямба',
  'Ням',
];

String mnWeekday(DateTime date) => mnWeekdays[date.weekday - 1];

String mnMonth(DateTime date) => '${date.month}-р сар';

String _two(int value) => value.toString().padLeft(2, '0');

String clockLabel(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

/// "4 цаг 30 мин", "2 хоног" гэх мэт үргэлжлэх хугацаа.
String durationLabel(Duration duration) {
  if (duration.inMinutes < 1) return 'Хэдхэн минут';
  if (duration.inMinutes < 60) return '${duration.inMinutes} мин';
  if (duration.inHours < 24) {
    final minutes = duration.inMinutes % 60;
    return minutes == 0
        ? '${duration.inHours} цаг'
        : '${duration.inHours} цаг $minutes мин';
  }
  final hours = duration.inHours % 24;
  return hours == 0
      ? '${duration.inDays} хоног'
      : '${duration.inDays} хоног $hours цаг';
}

/// "3 хоногийн дараа", "Болж байна", "Дууссан".
({String text, Color color, IconData icon}) countdownLabel(
  DateTime start,
  DateTime end,
) {
  final now = DateTime.now();

  if (now.isAfter(end)) {
    return (text: 'Дууссан', color: brandInkSoft, icon: Icons.history_rounded);
  }
  if (!now.isBefore(start)) {
    return (
      text: 'Яг одоо болж байна',
      color: const Color(0xFF2BA86E),
      icon: Icons.play_circle_fill_rounded,
    );
  }

  final left = start.difference(now);
  final String text;
  if (left.inMinutes < 60) {
    text = '${left.inMinutes} минутын дараа';
  } else if (left.inHours < 24) {
    text = '${left.inHours} цагийн дараа';
  } else {
    text = '${left.inDays} хоногийн дараа';
  }

  return (
    text: text,
    color: left.inDays <= 1 ? brandYellowDeep : brandAquaDeep,
    icon: Icons.schedule_rounded,
  );
}

/// Эхлэх ба дуусах огноог календарь хэлбэрээр харуулах карт.
///
/// Зүүн талд эхлэх (усан цэнхэр), баруун талд дуусах (усан шар) хавтан,
/// дунд нь үргэлжлэх хугацаа, доод талд нь хэдийд болох нь гарна.
class EventDateCard extends StatelessWidget {
  const EventDateCard({
    super.key,
    required this.startsAt,
    required this.endsAt,
    this.compact = false,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final bool compact;

  bool get _sameDay =>
      startsAt.year == endsAt.year &&
      startsAt.month == endsAt.month &&
      startsAt.day == endsAt.day;

  @override
  Widget build(BuildContext context) {
    final countdown = countdownLabel(startsAt, endsAt);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: brandGradientSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandBorder),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _DayTile(
                  date: startsAt,
                  label: 'Эхлэх',
                  accent: brandAquaDeep,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6FE2F0), Color(0xFFBDF2F8)],
                  ),
                  icon: Icons.play_arrow_rounded,
                  compact: compact,
                ),
              ),
              _Connector(
                label: durationLabel(endsAt.difference(startsAt)),
                compact: compact,
              ),
              Expanded(
                child: _DayTile(
                  date: endsAt,
                  label: 'Дуусах',
                  accent: brandYellowDeep,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE49A), Color(0xFFFFF3CF)],
                  ),
                  icon: Icons.flag_rounded,
                  compact: compact,
                  showDate: !_sameDay,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 13),
          Row(
            children: [
              Expanded(
                child: _Pill(
                  icon: countdown.icon,
                  text: countdown.text,
                  color: countdown.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  icon: Icons.event_rounded,
                  text: _sameDay
                      ? mnWeekday(startsAt)
                      : '${mnWeekday(startsAt)} → ${mnWeekday(endsAt)}',
                  color: brandAccents[3],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Нэг өдрийн календарь хэлбэрийн хавтан.
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.date,
    required this.label,
    required this.accent,
    required this.gradient,
    required this.icon,
    required this.compact,
    this.showDate = true,
  });

  final DateTime date;
  final String label;
  final Color accent;
  final Gradient gradient;
  final IconData icon;
  final bool compact;

  /// Дуусах өдөр нь эхлэхтэй ижил бол зөвхөн цагийг онцолно.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 14,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: brandInk.withValues(alpha: 0.65)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: brandInk.withValues(alpha: 0.7),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 7),
          if (showDate) ...[
            Text(
              '${date.day}',
              style: TextStyle(
                color: brandInk,
                fontSize: compact ? 24 : 30,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mnMonth(date),
              style: const TextStyle(
                color: brandInk,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else
            Text(
              'Мөн өдөр',
              style: TextStyle(
                color: brandInk.withValues(alpha: 0.75),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          SizedBox(height: compact ? 5 : 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              clockLabel(date),
              style: const TextStyle(
                color: brandInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Хоёр хавтангийн дундах зураас ба үргэлжлэх хугацаа.
class _Connector extends StatelessWidget {
  const _Connector({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_forward_rounded,
            size: compact ? 16 : 19,
            color: brandAquaDeep,
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: brandBorder),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: brandAquaDeep,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Доод талын жижиг мэдээллийн таблет.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: brandAccentSurface(color),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
