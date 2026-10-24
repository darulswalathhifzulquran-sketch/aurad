import 'package:flutter/material.dart';
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
        const seed = Color(0xFF1E3A8A);
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          themeMode: app.dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: seed, brightness: Brightness.dark),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
