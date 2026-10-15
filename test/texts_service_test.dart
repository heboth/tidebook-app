import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/services/texts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bundled = <String, dynamic>{
    'home': {
      'title': 'Forside',
      'nav': {'explore': 'Udforsk'},
    },
    'myBookings': {'count': '{count} bookinger'},
  };

  setUp(() => TextsService.instance.load(bundled));

  group('tr()', () {
    test('finder en indlejret nøgle', () {
      expect(tr('home.title'), 'Forside');
      expect(tr('home.nav.explore'), 'Udforsk');
    });

    test('udfylder pladsholdere', () {
      expect(tr('myBookings.count', {'count': 3}), '3 bookinger');
    });

    test('lader ukendte pladsholdere stå', () {
      expect(tr('myBookings.count'), '{count} bookinger');
    });

    test('returnerer nøglen, når teksten mangler', () {
      expect(tr('home.missing'), 'home.missing');
      expect(tr('nothing.here.at.all'), 'nothing.here.at.all');
      // En gren (ikke en streng) er heller ikke en tekst
      expect(tr('home.nav'), 'home.nav');
    });
  });

  group('TextsService.overlay', () {
    test('erstatter kun eksisterende strengnøgler', () {
      final remote = {
        'home': {
          'title': 'Home',
          'extra': 'Ignoreres',
          'nav': {'explore': 'Explore', 'more': 'Ignoreres'},
        },
        'newGroup': {'x': 'Ignoreres'},
      };
      final result = TextsService.overlay(bundled, remote) as Map<String, dynamic>;
      expect(result['home']['title'], 'Home');
      expect(result['home']['nav']['explore'], 'Explore');
      expect((result['home'] as Map).containsKey('extra'), isFalse);
      expect((result['home']['nav'] as Map).containsKey('more'), isFalse);
      expect(result.containsKey('newGroup'), isFalse);
      expect(result['myBookings']['count'], '{count} bookinger');
    });

    test('ignorerer ikke-strenge og tomme strenge', () {
      final remote = {
        'home': {
          'title': 42,
          'nav': {'explore': '   '},
        },
        'myBookings': {'count': ''},
      };
      final result = TextsService.overlay(bundled, remote) as Map<String, dynamic>;
      expect(result['home']['title'], 'Forside');
      expect(result['home']['nav']['explore'], 'Udforsk');
      expect(result['myBookings']['count'], '{count} bookinger');
    });

    test('en gren erstattes ikke af en streng', () {
      final result = TextsService.overlay(bundled, {'home': 'Flad tekst'}) as Map<String, dynamic>;
      expect(result['home']['title'], 'Forside');
    });

    test("TideCMS' danske stedfortræder erstatter ikke appens egen oversættelse", () {
      TextsService.instance.load(bundled,
          translation: {
            'home': {'title': 'Home', 'nav': {'explore': 'Explore'}},
          },
          // TideCMS' engelske pakke: titlen er oversat på ny, "explore" mangler (TideCMS sender dansk)
          remote: {
            'home': {'title': 'Front page', 'nav': {'explore': 'Udforsk'}},
          },
          remoteDanish: {
            'home': {'title': 'Forside', 'nav': {'explore': 'Udforsk'}},
          });
      expect(tr('home.title'), 'Front page');
      expect(tr('home.nav.explore'), 'Explore');
      // Uden appens oversættelse bruges den danske
      expect(tr('myBookings.count', {'count': 2}), '2 bookinger');
    });

    test('load med remote bruger overlay', () {
      TextsService.instance.load(bundled, remote: {
        'home': {'title': 'Startseite', 'extra': 'x'},
      });
      expect(tr('home.title'), 'Startseite');
      expect(tr('home.extra'), 'home.extra');
    });
  });
}
