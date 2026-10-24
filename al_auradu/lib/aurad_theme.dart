import 'package:flutter/material.dart';

/// A single visual language for AL AURADU.
/// Reader page artwork and religious content are intentionally unaffected.
class AuradColors {
  static const mint = Color(0xFFEAF3ED);
  static const ivory = Color(0xFFFAFAF4);
  static const emerald = Color(0xFF087558);
  static const gold = Color(0xFFC7A46A);
  static const ink = Color(0xFF19342B);
  static const darkSurface = Color(0xFF111715);

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : ivory;

  static Color secondaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFC0CCC5)
          : const Color(0xFF52635B);
}

class AuradTheme {
  static ThemeData light() => _make(false);
  static ThemeData dark() => _make(true);

  static ThemeData _make(bool dark) {
    final background = dark ? Colors.black : AuradColors.mint;
    final surface = dark ? AuradColors.darkSurface : AuradColors.ivory;
    final text = dark ? Colors.white : AuradColors.ink;
    final scheme = ColorScheme.fromSeed(
      seedColor: AuradColors.emerald,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: dark ? const Color(0xFF78CDB3) : AuradColors.emerald,
      secondary: AuradColors.gold,
      surface: surface,
      onSurface: text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      dividerColor: dark
          ? const Color(0xFF2C3833)
          : const Color(0xFFD5E2D8),
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
          borderSide: BorderSide(
            color: dark
                ? const Color(0xFF2E3833)
                : const Color(0xFFD3E0D6),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        elevation: 0,
        indicatorColor: dark
            ? const Color(0xFF194B3E)
            : const Color(0xFFCDEBDD),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
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
              color: const Color(0xFF9EB6A6).withValues(alpha: 0.35),
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
              ? const Color(0xFF293830)
              : const Color(0xFFF9FFFB),
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
