import 'package:flutter/material.dart';

/// Navy and gold are the approved brand colors from the visual reference.
class AuradColors {
  static const navy = Color(0xFF041C3A);
  static const deepNavy = Color(0xFF021228);
  static const navyCard = Color(0xFF103859);
  static const gold = Color(0xFFEBCB84);
  static const ivory = Color(0xFFFFF4DB);
  static const mint = Color(0xFFEAF3ED); // Legacy reference for older screens.
  static const emerald = Color(0xFF087558);
  static const ink = Color(0xFF19342B);
  static const darkSurface = Color(0xFF091D35);

  static Color surface(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor == Colors.black
          ? darkSurface
          : navyCard;

  static Color secondaryText(BuildContext context) =>
      const Color(0xFFCDCBBD);
}

class AuradTheme {
  static ThemeData light() => _make(false);
  static ThemeData dark() => _make(true);

  static ThemeData _make(bool blackMode) {
    final background = blackMode ? Colors.black : AuradColors.navy;
    final surface =
        blackMode ? AuradColors.darkSurface : AuradColors.navyCard;
    const text = AuradColors.ivory;
    final scheme = ColorScheme.fromSeed(
      seedColor: AuradColors.gold,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AuradColors.gold,
      onPrimary: AuradColors.deepNavy,
      secondary: AuradColors.emerald,
      surface: surface,
      onSurface: text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AuradColors.navy,
        foregroundColor: AuradColors.ivory,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      dividerColor: const Color(0xFF365274),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AuradColors.ivory),
        bodyLarge: TextStyle(color: AuradColors.ivory),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF52648A)),
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AuradColors.gold, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        elevation: 0,
        indicatorColor: const Color(0xFF25466A),
        height: 72,
      ),
    );
  }
}

/// Raised, accessible soft-neumorphic surface. Safe for light and dark modes.
class AuradPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool inset;

  const AuradPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.onTap,
    this.inset = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).scaffoldBackgroundColor == Colors.black;
    final surface = AuradColors.surface(context);
    final shadows = dark
        ? <BoxShadow>[
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.045),
              offset: const Offset(-3, -3),
              blurRadius: 10,
            ),
            const BoxShadow(
              color: Colors.black,
              offset: Offset(5, 5),
              blurRadius: 13,
            ),
          ]
        : <BoxShadow>[
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-5, -5),
              blurRadius: 14,
            ),
            BoxShadow(
              color: const Color(0xFF00152E).withValues(alpha: 0.35),
              offset: const Offset(5, 6),
              blurRadius: 14,
            ),
          ];
    final border = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: border,
        border: Border.all(
          color: dark
              ? const Color(0xFF3C5263)
              : const Color(0xFFE0C17C),
        ),
        boxShadow: inset ? null : shadows,
      ),
      child: ClipRRect(
        borderRadius: border,
        child: Material(
          color: Colors.transparent,
          child: onTap == null
              ? Padding(padding: padding, child: child)
              : InkWell(
                  onTap: onTap,
                  child: Padding(padding: padding, child: child),
                ),
        ),
      ),
    );
  }
}
