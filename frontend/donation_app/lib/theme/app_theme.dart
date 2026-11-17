import 'dart:ui';

import 'package:flutter/material.dart';

/// Аппын нэгдсэн өнгөний систем.
///
/// Санаа: УСАН ЦЭНХЭР → УСАН ШАР зөөлөн уусгалт.
/// Орчин үеийн pastel + glass (шилэн) загвар: цайвар уусгалт дээр
/// гүн номин өнгийн текст, зөөлөн өнгөт сүүдэр, том дугуйрсан булан.

// --- Усан цэнхэр ---
const Color brandAqua = Color(0xFF2DD4E8); // үндсэн усан цэнхэр
const Color brandAquaDeep = Color(0xFF0C92AC); // гүн усан цэнхэр (icon, товч)
const Color brandAquaLight = Color(0xFF7FE6F2); // цайвар усан цэнхэр
const Color brandAquaSoft = Color(0xFFD6F6FC); // маш цайвар талбай

// --- Усан шар ---
const Color brandYellow = Color(0xFFFFDE7A); // үндсэн усан шар
const Color brandYellowDeep = Color(0xFFD99A00); // тод шар (тодотгол)
const Color brandYellowSoft = Color(0xFFFFF5D6); // маш цайвар талбай

// --- Текст, гадаргуу ---
const Color brandInk = Color(0xFF0B4A57); // гол текст (гүн номин)
const Color brandInkSoft = Color(0xFF4F7F8B); // бүдэг текст
const Color brandBorder = Color(0xFFC3EBF3); // хүрээ
const Color brandSurface = Color(0xFFF3FCFE); // дэвсгэр
const Color brandDanger = Color(0xFFE2566A); // алдаа / устгах

// Хуучин нэрсийг эвдэхгүйн тулд үлдээв.
const Color brandBlue = brandAqua;
const Color brandSky = brandAquaLight;
const Color brandDeep = brandInk;
const Color brandMuted = brandInkSoft;
const Color brandAmber = brandYellowDeep;
const Color brandSoftBlue = brandAquaSoft;
const Color brandSoftYellow = brandYellowSoft;

// --- Уусгалтууд ---

/// Үндсэн уусгалт: усан цэнхэрээс усан шар руу.
/// Дээр нь цагаан биш, гүн номин ([brandInk]) текст тавина.
const LinearGradient brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3ADCEF), Color(0xFF7FE6F2), Color(0xFFFFE59B)],
  stops: [0.0, 0.52, 1.0],
);

/// Хэвтээ уусгалт: AppBar, туузан элемент.
const LinearGradient brandGradientHorizontal = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF4DDFF0), Color(0xFF8FEAF4), Color(0xFFFFE8A8)],
  stops: [0.0, 0.5, 1.0],
);

/// Hero / баннер: зүүн доороос усан цэнхэр, баруун дээш усан шар.
const LinearGradient brandHeroGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [
    Color(0xFF2ACFE4),
    Color(0xFF6FE2F0),
    Color(0xFFB6F0EC),
    Color(0xFFFFE49A),
  ],
  stops: [0.0, 0.34, 0.66, 1.0],
);

/// Дэлгэцийн дэвсгэр — маш зөөлөн.
const LinearGradient brandGradientSoft = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEBFBFE), Color(0xFFF6FDFF), Color(0xFFFFFAEC)],
  stops: [0.0, 0.52, 1.0],
);

/// Карт доторх арай мэдэгдэхүйц уусгалт.
const LinearGradient brandCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFFFFF), Color(0xFFF7FDFF), Color(0xFFFFFCF2)],
);

/// Зураг дээр тавих бараан уусгалт (цагаан текст уншигдахуйц болгоно).
const LinearGradient brandOverlayGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x33000000), Color(0x000B4A57), Color(0xE6083844)],
  stops: [0.0, 0.3, 1.0],
);

/// Зөөлөн, өнгөтэй сүүдэр.
List<BoxShadow> brandShadow({double opacity = 0.18, double blur = 22}) => [
  BoxShadow(
    color: brandAquaDeep.withValues(alpha: opacity),
    blurRadius: blur,
    offset: const Offset(0, 8),
  ),
];

// --- Icon-ы өнгөний багц ---

/// Icon, ангилал, статистикийг өөр өөр өнгөөр ялгахад ашиглана.
const List<Color> brandAccents = [
  Color(0xFF0C92AC), // усан цэнхэр
  Color(0xFFD99A00), // шар
  Color(0xFF2BA86E), // ногоон
  Color(0xFF7A5BD6), // ягаавтар
  Color(0xFFE2566A), // улаан
  Color(0xFFE2743B), // улбар шар
  Color(0xFF1F7AE0), // хөх
];

/// Нэр / түлхүүрээс тогтмол өнгө гаргана (нэг нэр үргэлж нэг өнгөтэй).
Color brandAccentFor(Object seed) =>
    brandAccents[seed.toString().hashCode.abs() % brandAccents.length];

/// Өнгийг нь зөөлрүүлсэн дэвсгэр.
Color brandAccentSurface(Color accent) => Color.alphaBlend(
  accent.withValues(alpha: 0.12),
  Colors.white,
);

/// Дарах бүрд өнгөө солидог icon.
///
/// [seed] өгвөл эхний өнгийг тогтооно. Дарахад [brandAccents] дотор
/// шилжиж, өнгө болон хэмжээ нь зөөлөн хөдөлгөөнтэйгээр солигдоно.
class BrandTapIcon extends StatefulWidget {
  const BrandTapIcon({
    super.key,
    required this.icon,
    this.seed,
    this.size = 22,
    this.boxSize = 42,
    this.radius = 14,
    this.tooltip = 'Өнгө солих',
    this.onTap,
  });

  final IconData icon;
  final Object? seed;
  final double size;
  final double boxSize;
  final double radius;
  final String tooltip;

  /// Өнгө солихоос гадна хийх үйлдэл (заавал биш).
  final VoidCallback? onTap;

  @override
  State<BrandTapIcon> createState() => _BrandTapIconState();
}

class _BrandTapIconState extends State<BrandTapIcon> {
  late int _index =
      widget.seed == null
      ? 0
      : widget.seed.toString().hashCode.abs() % brandAccents.length;

  void _next() {
    setState(() => _index = (_index + 1) % brandAccents.length);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final accent = brandAccents[_index];

    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: _next,
        borderRadius: BorderRadius.circular(widget.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          width: widget.boxSize,
          height: widget.boxSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: brandAccentSurface(accent),
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              widget.icon,
              key: ValueKey<int>(_index),
              size: widget.size,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Дэлгэцийн дэвсгэрийг уусгалттай болгох бүрхүүл.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: brandGradientSoft),
    child: child,
  );
}

/// Уусгалттай AppBar-ын дэвсгэр.
class BrandAppBarBackground extends StatelessWidget {
  const BrandAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(gradient: brandGradientHorizontal),
  );
}

/// Шилэн (glass) карт — орчин үеийн загварын үндсэн гадаргуу.
class BrandGlassCard extends StatelessWidget {
  const BrandGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.margin,
    this.opacity = 0.78,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: brandShadow(opacity: 0.10, blur: 26),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Уусгалттай үндсэн товч. Цайвар уусгалт дээр гүн номин текст.
class BrandGradientButton extends StatelessWidget {
  const BrandGradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.height = 54,
    this.radius = 18,
    this.busy = false,
    this.gradient = brandGradient,
    this.foreground = brandInk,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final double height;
  final double radius;
  final bool busy;
  final Gradient gradient;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final tint = enabled ? foreground : brandInkSoft;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : const Color(0xFFDCE9ED),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled ? brandShadow(opacity: 0.26, blur: 18) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tint,
                      ),
                    )
                  else if (icon != null)
                    IconTheme(
                      data: IconThemeData(color: tint, size: 21),
                      child: icon!,
                    ),
                  if (busy || icon != null) const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tint,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
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
}

/// Уусгалттай текст (гарчигт).
class BrandGradientText extends StatelessWidget {
  const BrandGradientText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.gradient = brandGradient,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (bounds) =>
        gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
    blendMode: BlendMode.srcIn,
    child: Text(
      text,
      textAlign: textAlign,
      style: (style ?? const TextStyle()).copyWith(color: Colors.white),
    ),
  );
}

/// Аппын нэгдсэн ThemeData.
ThemeData buildBrandTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: brandAquaDeep,
        primary: brandAquaDeep,
        secondary: brandYellowDeep,
      ).copyWith(
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: brandInk,
        error: brandDanger,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: brandInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: brandInk,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: brandInk),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: brandInkSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: brandBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: brandBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: brandAquaDeep, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandAquaDeep,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      side: const BorderSide(color: brandBorder),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: brandAquaDeep,
      linearTrackColor: brandAquaSoft,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brandInk,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
