import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_auradu/folder.dart';
import 'package:al_auradu/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Swalathu Sa\'adha is labelled Added and not hourglass',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    app = await AppState.load();
    final saadha = app.itemsIn('swalath').firstWhere(
          (item) => item.id == 'swalath-saadha',
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => itemTile(context, saadha),
        ),
      ),
    ));

    expect(find.text("Swalathu Sa'adha"), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    expect(find.text('صلاة السعادة'), findsOneWidget);
  });
}
