import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'store.dart';
import 'home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  app = await AppState.load();
  runApp(const MyApp());
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
