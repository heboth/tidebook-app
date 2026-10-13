import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/services/texts_service.dart';
import 'package:tidebook_app/widgets/language_picker.dart';

class _MemoryStore implements LanguageStore {
  _MemoryStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String lang) async => value = lang;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final texts = TextsService.instance;

  test('kun DK, NO og UK kan vælges', () {
    expect(TextsService.supported, ['da', 'no', 'en']);
  });

  test('det gemte sprog bruges ved start', () async {
    texts.store = _MemoryStore('no');
    await texts.init(wait: Duration.zero);
    expect(texts.language, 'no');
  });

  test('et gemt sprog, der ikke længere kan vælges, giver ikke det sprog', () async {
    texts.store = _MemoryStore('de');
    await texts.init(wait: Duration.zero);
    expect(texts.language, isNot('de'));
    expect(TextsService.supported, contains(texts.language));
  });

  test('valget gemmes', () async {
    final store = _MemoryStore();
    texts.store = store;
    await texts.init(language: 'da', wait: Duration.zero);
    await texts.setLanguage('en');
    expect(store.value, 'en');
    await texts.setLanguage('sv'); // ikke i vælgeren: ignoreres
    expect(texts.language, 'en');
    expect(store.value, 'en');
  });

  testWidgets('dropdown viser flag og DK/NO/UK og skifter sprog', (tester) async {
    final store = _MemoryStore();
    texts.store = store;
    // init venter på en rigtig timer og et HTTP-kald – det skal køre uden for testens falske tid
    await tester.runAsync(() => texts.init(language: 'da', wait: Duration.zero));
    await tester.pumpWidget(MaterialApp(home: Scaffold(appBar: AppBar(actions: const [LanguagePicker()]))));

    expect(find.text('DK'), findsOneWidget);
    await tester.tap(find.byKey(const Key('languagePicker')));
    await tester.pumpAndSettle();
    expect(find.text('Dansk'), findsOneWidget);
    expect(find.text('Norsk'), findsOneWidget);
    expect(find.text('English (UK)'), findsOneWidget);

    await tester.tap(find.text('Norsk'));
    await tester.pumpAndSettle();
    expect(texts.language, 'no');
    expect(store.value, 'no');
  });
}
