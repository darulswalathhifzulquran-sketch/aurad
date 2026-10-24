import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_auradu/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all reading folders start empty without deleting source assets',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();

    expect(kStartWithEmptyLibrary, isTrue);
    expect(state.items, isEmpty);
    expect(mushafReady, isFalse);
    for (final category in [
      'quran', 'juz', 'mawlid', 'mala', 'swalath',
      'ratib', 'majlisunnoor', 'baith', 'dua', 'dikr',
    ]) {
      expect(state.itemsIn(category), isEmpty,
          reason: '$category should have zero visible books');
    }

    // Folder definitions and native counter still exist.
    expect(state.categories.map((c) => c.id), contains('quran'));
    expect(state.categories.map((c) => c.id), contains('mawlid'));
    expect(state.categories.map((c) => c.id), contains('counter'));
    expect(state.counter, 0);
    state.incCounter();
    expect(state.counter, 1);
  });
}
