import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Appens tekster.
///
/// Den danske pakke ligger i appen (`assets/i18n/da.json`) sammen med den norske og engelske
/// (`no.json`, `en.json`), så appen virker uden net og på alle tre sprog. Den udgivne pakke `tidebookapp`
/// fra TideCMS lægges ovenpå – kun strenge, og kun hvor nøglen findes i forvejen – så rettelser i TideCMS
/// slår igennem uden ny app-version. Mangler en tekst på et sprog, leverer TideCMS den danske; den bruges
/// ikke oven på appens egen oversættelse (se [overlay]).
class TextsService {
  TextsService._();
  static final TextsService instance = TextsService._();

  /// Sprogene i appens sprogvælger (DK, NO, UK). Tekster på andre sprog i TideCMS bruges ikke.
  static const supported = ['da', 'no', 'en'];
  static const _namespace = 'tidebookapp';

  /// Ændres, når brugeren skifter sprog – appen genopbygges da forfra. Tekster, der kommer fra TideCMS
  /// efter start, bruges fra næste skærm (ingen genopbygning midt i fx en booking).
  final ValueNotifier<int> revision = ValueNotifier(0);

  Map<String, dynamic> _danish = const {};
  Map<String, dynamic> _bundled = const {};
  Map<String, dynamic> _texts = const {};
  String _language = 'da';

  String get language => _language;

  /// Sproget til Flutters egne tekster (datovælger m.m.). Norsk er bokmål.
  Locale get locale => Locale(_language == 'no' ? 'nb' : _language);

  /// Husker brugerens sprogvalg mellem app-starter. Kan udskiftes i tests.
  LanguageStore store = SecureLanguageStore();

  /// Standard: TideCMS online. `--dart-define=TIDECMS_URL=local` bruger TideCMS på udviklingsmaskinen.
  static const defaultUrl = 'https://tidebook.ceniconsulting.dk/cms';
  static const _envUrl = String.fromEnvironment('TIDECMS_URL', defaultValue: defaultUrl);
  static bool get _local => _envUrl.trim() == 'local';

  /// En release-build må ikke pege på udviklingsmaskinen (`local`).
  static bool isConfigured({bool releaseMode = kReleaseMode}) => !releaseMode || (_envUrl.isNotEmpty && !_local);

  /// TideCMS' adresse – null i en release-build med `local` (så bruges kun de indbyggede tekster).
  /// localhost/10.0.2.2 bruges kun under udvikling.
  static String? get tideCmsUrl {
    if (_envUrl.isNotEmpty && !_local) return _envUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (kReleaseMode) return null;
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:4300';
    } catch (_) {}
    return 'http://localhost:4300';
  }

  /// Indlæser den indbyggede pakke og venter kort på TideCMS (højst `wait`), så første skærm har de
  /// udgivne tekster. Svarer TideCMS senere, bruges teksterne fra næste skærm.
  Future<void> init({String? language, Duration wait = const Duration(milliseconds: 1500)}) async {
    _danish = await _loadAsset('da') ?? const {};
    // Rækkefølge: angivet sprog → brugerens gemte valg → enhedens sprog → dansk
    final saved = await store.read();
    final device = PlatformDispatcher.instance.locale.languageCode;
    _language = language ?? (supported.contains(saved) ? saved! : supported.contains(device) ? device : 'da');
    await _loadBundled();
    final fetch = refresh();
    await Future.any([fetch, Future.delayed(wait)]);
  }

  /// Til tests: sæt pakken direkte. `translation` er appens egen oversættelse (som `en.json`),
  /// `remoteDanish` TideCMS' danske pakke (dens tekster tæller ikke som oversættelser).
  @visibleForTesting
  void load(Map<String, dynamic> bundled,
      {Map<String, dynamic>? remote, Map<String, dynamic>? translation, Map<String, dynamic>? remoteDanish}) {
    _danish = bundled;
    _bundled = translation == null ? bundled : overlay(bundled, translation) as Map<String, dynamic>;
    _texts = remote == null ? _bundled : overlay(_bundled, remote, remoteDanish) as Map<String, dynamic>;
    revision.value++;
  }

  static Future<Map<String, dynamic>?> _loadAsset(String lang) async {
    try {
      return jsonDecode(await rootBundle.loadString('assets/i18n/$lang.json')) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Appens egen pakke på det valgte sprog – manglende tekster er de danske.
  Future<void> _loadBundled() async {
    final own = _language == 'da' ? null : await _loadAsset(_language);
    _bundled = own == null ? _danish : overlay(_danish, own) as Map<String, dynamic>;
    _texts = _bundled;
  }

  Future<void> setLanguage(String lang) async {
    if (!supported.contains(lang)) return;
    _language = lang;
    await store.write(lang);
    await _loadBundled();
    await refresh();
    revision.value++;
  }

  Future<void> refresh() async {
    final base = tideCmsUrl;
    if (base == null) return;
    Future<dynamic> fetch(String lang) async {
      final res = await http.get(Uri.parse('$base/api/v1/bundles/$_namespace/$lang')).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) throw http.ClientException('${res.statusCode}');
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    try {
      // På andre sprog end dansk hentes også den danske pakke: TideCMS udfylder manglende oversættelser med
      // dansk, og de tekster må ikke erstatte appens egen oversættelse
      final lang = _language;
      final results = await Future.wait([fetch(lang), if (lang != 'da') fetch('da')]);
      if (lang != _language) return; // sproget er skiftet imens
      _texts = overlay(_bundled, results[0], lang == 'da' ? null : results[1]) as Map<String, dynamic>;
    } catch (_) {
      // TideCMS kan ikke nås – de indbyggede tekster bruges
    }
  }

  /// Teksten på `key` ("home.title"). Pladsholdere som {count} udfyldes fra `vars`.
  /// Findes nøglen ikke, returneres nøglen selv (så en manglende tekst ses, men appen ikke fejler).
  String tr(String key, [Map<String, Object?> vars = const {}]) {
    dynamic node = _texts;
    for (final part in key.split('.')) {
      if (node is Map<String, dynamic> && node.containsKey(part)) {
        node = node[part];
      } else {
        return key;
      }
    }
    if (node is! String) return key;
    return node.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars.containsKey(m[1]) ? '${vars[m[1]]}' : m[0]!);
  }

  /// Lægger kun strenge fra `remote` oven på `base`, og kun hvor nøglen findes i `base`.
  /// `danish` (TideCMS' danske pakke): en tekst i `remote`, der er den samme som den danske, er TideCMS'
  /// stedfortræder for en manglende oversættelse og erstatter ikke `base`.
  static dynamic overlay(dynamic base, dynamic remote, [dynamic danish]) {
    if (base is String) {
      if (remote is! String || remote.trim().isEmpty) return base;
      return danish is String && remote == danish ? base : remote;
    }
    if (base is List) {
      return [
        for (var i = 0; i < base.length; i++)
          overlay(base[i], remote is List && i < remote.length ? remote[i] : null, danish is List && i < danish.length ? danish[i] : null)
      ];
    }
    if (base is Map<String, dynamic>) {
      final r = remote is Map ? remote : const {};
      final d = danish is Map ? danish : const {};
      return {for (final e in base.entries) e.key: overlay(e.value, r[e.key], d[e.key])};
    }
    return base;
  }
}

/// Gemmer det valgte sprog.
abstract class LanguageStore {
  Future<String?> read();
  Future<void> write(String lang);
}

class SecureLanguageStore implements LanguageStore {
  SecureLanguageStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'tidebook.language';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null; // ingen lager (fx i tests): enhedens sprog bruges
    }
  }

  @override
  Future<void> write(String lang) async {
    try {
      await _storage.write(key: _key, value: lang);
    } catch (_) {
      // Kan valget ikke gemmes, gælder det stadig i denne session
    }
  }
}

/// Kort form: `tr('home.title')`.
String tr(String key, [Map<String, Object?> vars = const {}]) => TextsService.instance.tr(key, vars);
