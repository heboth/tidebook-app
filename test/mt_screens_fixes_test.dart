import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/models/addon_model.dart';
import 'package:tidebook_app/models/booking_model.dart';
import 'package:tidebook_app/services/texts_service.dart';

/// Rettelser fundet ved skærmbillederne til MT: sprog, kahytstype før check-in og tilvalgenes navne.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> bundle(String lang) =>
      jsonDecode(File('assets/i18n/$lang.json').readAsStringSync()) as Map<String, dynamic>;

  Iterable<MapEntry<String, dynamic>> leaves(Map<String, dynamic> m, [String prefix = '']) sync* {
    for (final e in m.entries) {
      final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
      if (e.value is Map<String, dynamic>) {
        yield* leaves(e.value as Map<String, dynamic>, key);
      } else {
        yield MapEntry(key, e.value);
      }
    }
  }

  group('sprogpakkerne', () {
    final da = Map.fromEntries(leaves(bundle('da')));
    for (final lang in ['en', 'no']) {
      test('$lang.json har de samme nøgler og pladsholdere som da.json', () {
        final other = Map.fromEntries(leaves(bundle(lang)));
        expect(other.keys.toSet(), da.keys.toSet());
        final ph = RegExp(r'\{(\w+)\}');
        for (final e in da.entries) {
          Set<String> vars(Object? s) => ph.allMatches('$s').map((m) => m[1]!).toSet();
          expect(vars(other[e.key]), vars(e.value), reason: '${e.key} på $lang');
        }
      });
    }

    test('de tekster, der stod på dansk i den engelske udgave, er oversat', () {
      final en = Map.fromEntries(leaves(bundle('en')));
      for (final key in [
        'bookingWizard.step4.travellerTitle',
        'bookingWizard.step4.birthDate',
        'bookingWizard.step4.gender',
        'bookingWizard.step4.nationality',
        'bookingWizard.step3.loading',
        'explore.profileBar.loginLink',
        'bookingWizard.insurance.lead',
        'cabinCategories.A4',
        'addOns.addon-breakfast',
      ]) {
        expect(en[key], isNot(da[key]), reason: key);
      }
    });

    test('stavefejl og fanetekst', () {
      expect(da['boardingPass.issuedAtCheckInBody'], contains('kryptografisk'));
      expect(da['home.nav.bookings'], 'Bookinger');
    });
  });

  group('kahyt før check-in', () {
    setUp(() => TextsService.instance.load(bundle('da'), translation: bundle('en')));

    test('viser kahytstypen fra Core på appens sprog', () {
      final b = BookingModel.fromJson({'pnr': 'ABC123', 'selectedCabinIds': ['CAB-1'], 'cabinCategories': ['A4']});
      expect(b.cabinLabel, 'Outside cabin sea view 4P (bunks)');
    });

    test('uden kategori vises en oversat standardtekst', () {
      expect(BookingModel.fromJson({'pnr': 'ABC123', 'selectedCabinIds': ['CAB-1']}).cabinLabel, 'Cabin');
      expect(BookingModel.fromJson({'pnr': 'ABC123'}).cabinLabel, 'No cabin');
    });
  });

  test('tilvalgets navn kommer fra tekstpakken, ellers fra Core', () {
    TextsService.instance.load(bundle('da'), translation: bundle('en'));
    final known = AddOnModel.fromJson({'id': 'addon-breakfast', 'name': 'Morgenmadsbuffet', 'isActive': true});
    final unknown = AddOnModel.fromJson({'id': 'addon-new', 'name': 'Nyt tilvalg', 'isActive': true});
    expect(known.label, 'Breakfast buffet (Scandinavian table)');
    expect(unknown.label, 'Nyt tilvalg');
  });
}
