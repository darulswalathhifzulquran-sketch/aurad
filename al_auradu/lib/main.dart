import 'package:flutter/material.dart';

import 'aurad_theme.dart';
import 'home.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuradBootstrap());
}

/// Start Flutter immediately so bundled content can load behind a real,
/// branded loading screen instead of a blank window.
class AuradBootstrap extends StatefulWidget {
  const AuradBootstrap({super.key});

  @override
  State<AuradBootstrap> createState() => _AuradBootstrapState();
}

class _AuradBootstrapState extends State<AuradBootstrap> {
  late Future<AppState> _loading;

  @override
  void initState() {
    super.initState();
    _loading = AppState.load();
  }

  void _retry() {
    setState(() {
      _loading = AppState.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          app = snapshot.data!;
          return const MyApp();
        }
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: AuradTheme.light(),
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: AuradPanel(
                      padding: const EdgeInsets.symmetric(
                          vertical: 36, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 46,
                            color: AuradColors.emerald,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            kAppName,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: kArabicFont,
                              fontFamilyFallback: kFontFallback,
                              fontSize: 34,
                              color: AuradColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'AL AURADU',
                            style: TextStyle(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              color: AuradColors.emerald,
                            ),
                          ),
                          const SizedBox(height: 26),
                          if (snapshot.hasError) ...[
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFB34832)),
                            const SizedBox(height: 10),
                            const Text(
                              'The library could not be loaded. '
                              'Please check the bundled content files.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _retry,
                              child: const Text('Retry'),
                            ),
                          ] else ...[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 14),
                            const Text('Opening your library...'),
                          ],
                        ],
                      ),
                    ),
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
      builder: (context, _) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        themeMode: app.dark ? ThemeMode.dark : ThemeMode.light,
        theme: AuradTheme.light(),
        darkTheme: AuradTheme.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
