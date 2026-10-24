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
    // Clear imported content ONLY; all original folder definitions and
    // their labels, ordering, and the Counter entry must remain intact.
    final ids = state.categories.map((c) => c.id).toList();
    expect(ids, [
      'quran', 'baith', 'mawlid', 'mala', 'swalath',
      'dua', 'ratib', 'majlisunnoor', 'counter',
    ]);
    expect(state.categories.first.name, 'ഖുർആൻ');
    expect(state.categories.first.ar, 'القرآن الكريم');
    expect(state.categories.last.en, 'Counter');
    expect(state.counter, 0);
    state.incCounter();
    expect(state.counter, 1);
  });
}
