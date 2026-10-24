import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_auradu/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('existing folder names remain but all old reading pages are absent',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();

    expect(kStartWithEmptyLibrary, isTrue);
    expect(mushafReady, isFalse);

    // Keep the full familiar Quran navigation, even before importing its PDF.
    expect(state.itemsIn('quran'), hasLength(114));
    expect(state.itemsIn('juz'), hasLength(30));
    expect(state.itemsIn('quran').first.title, '1. Al-Fatiha');
    expect(state.itemsIn('quran').last.title, '114. An-Nas');

    // Existing curated folder item names must not be deleted.
    expect(state.itemsIn('baith'), isNotEmpty);
    expect(state.itemsIn('mawlid'), isNotEmpty);
    expect(state.itemsIn('mala'), hasLength(3));
    expect(state.itemsIn('swalath'), isNotEmpty);
    expect(state.itemsIn('dua'), isNotEmpty);
    expect(state.itemsIn('ratib').map((it) => it.title),
        contains('Haddad Ratib'));
    expect(state.itemsIn('majlisunnoor').map((it) => it.title),
        contains('Majlisunnoor'));

    // Every list entry opens an existing ReaderScreen empty-page placeholder.
    for (final item in state.items) {
      expect(item.pages, isEmpty, reason: item.title);
    }

    // Folder definitions, interactions and counter are retained.
    expect(state.categories.map((c) => c.id), contains('quran'));
    expect(state.categories.map((c) => c.id), contains('counter'));
    expect(state.counter, 0);
    state.incCounter();
    expect(state.counter, 1);
  });
}
