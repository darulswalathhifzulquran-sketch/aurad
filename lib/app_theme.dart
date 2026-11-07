import 'package:flutter/material.dart';
import 'store.dart';

ColorScheme auraduColorScheme(bool isDark) {
  return ColorScheme.fromSeed(
    seedColor: const Color(0xFFEBCB84),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFFEBCB84),
    onPrimary: const Color(0xFF021228),
    secondary: const Color(0xFF087558),
    surface: isDark ? const Color(0xFF091D35) : const Color(0xFF103859),
    onSurface: const Color(0xFFFFF4DB),
    onSurfaceVariant: const Color(0xFFCDCBBD),
    primaryContainer: const Color(0xFF25466A),
    onPrimaryContainer: const Color(0xFFFFF4DB),
    outline: const Color(0xFF52648A),
    surfaceTint: const Color(0xFFEBCB84),
  );
}

ThemeData auraduTheme(bool isDark) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: auraduColorScheme(isDark),
    scaffoldBackgroundColor: isDark ? Colors.black : const Color(0xFF041C3A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF041C3A),
      foregroundColor: Color(0xFFFFF4DB),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF041C3A),
      elevation: 0,
      indicatorColor: Color(0xFF25466A),
      height: 72,
    ),
  );
}

Widget themeToggleAction() => IconButton(
      tooltip: app.dark ? 'Switch to light mode' : 'Switch to dark mode',
      icon:
          Icon(app.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: app.toggleDark,
    );
