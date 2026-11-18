import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'store.dart';
import 'home.dart';

/// Show Flutter UI immediately rather than waiting on browser storage
/// and bundled catalog HTTP requests before the first rendered frame.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<AppState> _loading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _loading = AppState.load().timeout(const Duration(seconds: 25));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasData) return const MyApp();
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: auraduTheme(true),
          home: Scaffold(
            backgroundColor: const Color(0xFF061C32),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'رياض الأذكار',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: kArabicFont,
                          color: Color(0xFFFFE4A2),
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (snapshot.hasError) ...[
                        const Text(
                          'Unable to start the app. Check your connection and retry.',
                          style: TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Color(0xFFFFB9A6),
                              fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => setState(_load),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ] else ...[
                        const SizedBox(
                          width: 27,
                          height: 27,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Opening Riyadul Adkar...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          themeMode: app.dark ? ThemeMode.dark : ThemeMode.light,
          theme: auraduTheme(false),
          darkTheme: auraduTheme(true),
          home: const HomeScreen(),
        );
      },
    );
  }
}
