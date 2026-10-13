import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tidebook_app/main.dart' show missingReleaseDefines;
import 'package:tidebook_app/models/addon_model.dart';
import 'package:tidebook_app/models/booking_model.dart';
import 'package:tidebook_app/models/cabin_model.dart';
import 'package:tidebook_app/models/departure_model.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/auth_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/texts_service.dart';
import 'package:tidebook_app/services/token_store.dart';

/// Appen må kun bruge TideBook Core (og TideRMS-priser via Core): ingen seed-data, ingen lokale
/// reserver og intet offline-login.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final offline = MockClient((_) async => throw const SocketException('Core kan ikke nås'));

  setUpAll(() {
    final json = jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>;
    TextsService.instance.load(json);
  });

  setUp(() {
    ApiService.client = offline;
    BookingService().resetForTest();
  });

  tearDown(() => AuthService().logout());

  Map<String, dynamic> coreBooking({String pnr = 'TB-100200', String? channel = 'B2C', bool group = false}) => {
        'pnr': pnr,
        'routeId': 'ROUTE-CPH-OSL',
        'departureId': 'DEP-1',
        'status': 'CONFIRMED',
        'paymentStatus': 'PAID',
        'leadContact': {'fullName': 'Anna Hansen', 'email': 'anna@example.dk', 'phone': '+4511223344'},
        'channel': ?channel,
        if (group) 'isGroupBooking': true,
      };

  group('Ingen seed-data', () {
    test('appen starter uden bookinger, aktiv booking og ruter', () {
      final service = BookingService();
      expect(service.bookings, isEmpty);
      expect(service.activeBooking, isNull);
      expect(service.routes, isEmpty);
      expect(service.getBookingToken('TIDE-9021'), isNull);
      expect(service.getBookingToken('TIDE-4412'), isNull);
    });

    test('init uden gemte nøgler og uden Core giver stadig en tom app og en rutefejl', () async {
      final service = BookingService();
      await service.init(tokenStore: MemoryBookingTokenStore());
      expect(service.bookings, isEmpty);
      expect(service.activeBooking, isNull);
      expect(service.routes, isEmpty);
      expect(service.routesFailed, isTrue);
    });

    test('gemte booking-nøgler bruges til at hente bookingerne fra Core', () async {
      ApiService.client = MockClient((req) async {
        if (req.url.path == '/api/bookings/TB-100200') {
          expect(req.headers['x-booking-token'], 'TOKEN-1');
          return http.Response(jsonEncode(coreBooking()), 200);
        }
        if (req.url.path == '/api/bookings/TB-EXPIRED') return http.Response('{"error":"UNAUTHORIZED"}', 401);
        throw const SocketException('ikke relevant');
      });
      final store = MemoryBookingTokenStore({'TB-100200': 'TOKEN-1', 'TB-EXPIRED': 'OLD'});
      final service = BookingService();
      await service.init(tokenStore: store);
      expect(service.bookings.map((b) => b.pnr), ['TB-100200']);
      expect(service.activeBooking?.pnr, 'TB-100200');
      // Den udløbne nøgle glemmes
      expect(store.tokens.keys, ['TB-100200']);
    });

    test('booking-nøgler gemmes i nøglelagringen', () async {
      final store = MemoryBookingTokenStore();
      final service = BookingService()..resetForTest(tokenStore: store);
      service.setBookingToken('tb-1', 'T1');
      await Future<void>.delayed(Duration.zero);
      expect(store.tokens, {'TB-1': 'T1'});
    });
  });

  group('Opslag uden lokal reserve', () {
    test('Core kan ikke nås → fejl, ingen opfundet booking', () async {
      final res = await BookingService().lookupBooking(pnr: 'TIDE-9021', emailOrLastName: 'mads.jensen@example.dk');
      expect(res.success, isFalse);
      expect(res.booking, isNull);
      expect(res.networkError, isTrue);
      expect(res.errorMessage, tr('myBookings.lookupUnavailable'));
      expect(BookingService().bookings, isEmpty);
      expect(BookingService().activeBooking, isNull);
    });

    test('Core svarer 404 → Core\'s fejltekst', () async {
      ApiService.client = MockClient((_) async => http.Response(
            jsonEncode({'error': 'BOOKING_NOT_FOUND', 'message': 'Ingen booking fundet med de angivne oplysninger.'}),
            404,
          ));
      final res = await BookingService().lookupBooking(pnr: 'TB-1', emailOrLastName: 'x@example.dk');
      expect(res.success, isFalse);
      expect(res.errorMessage, 'Ingen booking fundet med de angivne oplysninger.');
      expect(BookingService().bookings, isEmpty);
    });

    test('fundet i Core → huskes med booking-nøgle', () async {
      ApiService.client = MockClient((_) async => http.Response(
            jsonEncode({'success': true, 'booking': coreBooking(), 'bookingToken': 'TOKEN-2'}),
            200,
          ));
      final res = await BookingService().lookupBooking(pnr: 'tb-100200', emailOrLastName: 'Hansen');
      expect(res.success, isTrue);
      expect(BookingService().getBookingToken('TB-100200'), 'TOKEN-2');
      expect(BookingService().activeBooking?.pnr, 'TB-100200');
    });
  });

  group('Kanal fra Core afgør adgangen', () {
    BookingModel parse(Map<String, dynamic> json) => BookingModel.fromJson(json);

    test('AGENT/OTA afvises, B2C/CALL_CENTER tillades – også med et "GRP"-agtigt PNR', () {
      expect(BookingService.accessDenialFor(parse(coreBooking(channel: 'AGENT'))), contains('Online Agentur'));
      expect(BookingService.accessDenialFor(parse(coreBooking(channel: 'OTA'))), contains('Online Agentur'));
      expect(BookingService.accessDenialFor(parse(coreBooking(channel: 'B2C', pnr: 'OTA-12'))), isNull);
      expect(BookingService.accessDenialFor(parse(coreBooking(channel: 'CALL_CENTER'))), isNull);
    });

    test('gruppebooking afvises', () {
      expect(BookingService.accessDenialFor(parse(coreBooking(group: true))), contains('Gruppe-reservationer'));
    });

    test('uden kanal bruges PNR-reglerne som reserve', () {
      expect(BookingService.accessDenialFor(parse(coreBooking(channel: null, pnr: 'FG-DF-1'))), contains('Online Agentur'));
      expect(BookingService.accessDenialFor(parse(coreBooking(channel: null))), isNull);
    });

    test('agentbooking fra Core huskes ikke', () async {
      ApiService.client = MockClient((_) async => http.Response(
            jsonEncode({'success': true, 'booking': coreBooking(channel: 'AGENT'), 'bookingToken': 'T'}),
            200,
          ));
      final res = await BookingService().lookupBooking(pnr: 'TB-100200', emailOrLastName: 'Hansen');
      expect(res.success, isFalse);
      expect(BookingService().bookings, isEmpty);
      expect(BookingService().getBookingToken('TB-100200'), isNull);
    });
  });

  group('Intet offline-login', () {
    test('Core kan ikke nås → login afvises, også med kendt testkonto', () async {
      final auth = AuthService();
      final res = await auth.loginCustomer(usernameOrEmail: 'kunde', password: 'Kunde2026!');
      expect(res.success, isFalse);
      expect(res.errorMessage, tr('login.coreUnavailable'));
      expect(auth.currentUser, isNull);
      expect(auth.isLoggedIn, isFalse);

      final other = await auth.loginCustomer(usernameOrEmail: 'mads.jensen@example.dk', password: 'hvadsomhelst');
      expect(other.success, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('Core afviser → ugyldigt login', () async {
      ApiService.client = MockClient((_) async => http.Response('{"IsLoggedIn":false}', 200));
      final res = await AuthService().loginCustomer(usernameOrEmail: 'kunde', password: 'forkert');
      expect(res.success, isFalse);
      expect(res.errorMessage, tr('login.invalidCredentials'));
      expect(AuthService().currentUser, isNull);
    });

    test('Core uden navn → e-mailen bruges, ingen opfundet navn', () async {
      ApiService.client = MockClient((_) async => http.Response(
            jsonEncode({'IsLoggedIn': true, 'token': 'T', 'expiresInSeconds': 3600, 'user': {'id': 'U1', 'username': 'anna', 'email': 'anna@example.dk'}}),
            200,
          ));
      final res = await AuthService().loginCustomer(usernameOrEmail: 'anna', password: 'pw');
      expect(res.success, isTrue);
      expect(res.user?.fullName, 'anna@example.dk');
      expect(res.user?.fullName, isNot('Mads Jensen'));
    });

    test('fornyelse afvist af Core → kunden logges ud', () async {
      var calls = 0;
      ApiService.client = MockClient((req) async {
        calls++;
        if (req.url.path.endsWith('/portal-login')) {
          return http.Response(jsonEncode({'IsLoggedIn': true, 'token': 'T1', 'expiresInSeconds': 3600, 'user': {'id': 'U1', 'email': 'a@b.dk'}}), 200);
        }
        expect(req.url.path, '/api/auth/portal-renew');
        return http.Response('{"IsLoggedIn":false}', 200);
      });
      final auth = AuthService();
      await auth.loginCustomer(usernameOrEmail: 'a@b.dk', password: 'pw');
      expect(await auth.renewSession(), isFalse);
      expect(auth.currentUser, isNull);
      expect(calls, 2);
    });
  });

  group('Katalog, kahytter og afgange kun fra Core', () {
    test('tilvalg: kun aktive og gyldige på rejsedatoen', () async {
      ApiService.client = MockClient((req) async {
        expect(req.url.path, '/api/addons');
        return http.Response(
          jsonEncode([
            {'id': 'addon-priority-boarding', 'name': 'Prioriteret', 'basePriceDkk': 180, 'isActive': true, 'validFrom': '2026-01-01', 'validTo': '2026-12-31'},
            {'id': 'addon-ev-charging', 'name': 'Elbil', 'basePriceDkk': 220, 'isActive': false},
            {'id': 'addon-old', 'name': 'Udløbet', 'basePriceDkk': 10, 'isActive': true, 'validTo': '2025-12-31'},
          ]),
          200,
        );
      });
      final list = await ApiService().fetchAddOns(travelDate: DateTime(2026, 10, 14));
      expect(list!.map((a) => a.id), ['addon-priority-boarding']);
      expect(list.first.priceDkk, 180);
    });

    test('tilvalg: Core nede → null (fejltilstand), intet statisk katalog', () async {
      expect(await ApiService().fetchAddOns(), isNull);
      expect(AddOnModel.fromJson({'id': 'x'}).isActive, isFalse);
    });

    test('kahytter grupperes pr. Core-kategori, kun ledige, uden pris', () {
      final cats = CabinModel.fromCoreCabins([
        {'id': 'C1', 'category': 'X2', 'berths': 2, 'deck': 9, 'isBookedOnDeparture': false},
        {'id': 'C2', 'category': 'X2', 'berths': 2, 'deck': 10, 'isBookedOnDeparture': true},
        {'id': 'C3', 'category': 'B4', 'berths': 4, 'deck': 7},
      ]);
      expect(cats.map((c) => c.category), ['B4', 'X2']);
      final x2 = cats.firstWhere((c) => c.category == 'X2');
      expect(x2.freeCabinIds, ['C1']);
      expect(x2.cabinId, 'C1');
      expect(x2.decks, [9]);
    });

    test('kategorier udsolgt i TideRMS vises ikke', () {
      final cats = CabinModel.fromCoreCabins([
        {'id': 'C1', 'category': 'E4', 'berths': 4, 'deck': 6, 'isBookedOnDeparture': false, 'soldOutInRms': true},
        {'id': 'C2', 'category': 'B4', 'berths': 4, 'deck': 7, 'isBookedOnDeparture': false, 'soldOutInRms': false},
      ]);
      expect(cats.map((c) => c.category), ['B4']);
    });

    test('prisberegning: TideRMS ok=false eller Core nede → ingen pris', () async {
      expect(await ApiService().quoteTotal({'departureId': 'D'}), isNull);
      ApiService.client = MockClient((_) async => http.Response('{"ok":false,"totalAmountDkk":0}', 200));
      expect(await ApiService().quoteTotal({'departureId': 'D'}), isNull);
      ApiService.client = MockClient((_) async => http.Response('{"ok":true,"totalAmountDkk":1234.5}', 200));
      expect(await ApiService().quoteTotal({'departureId': 'D'}), 1234.5);
    });

    test('laveste priser fra Core; dage uden pris er null', () async {
      ApiService.client = MockClient((req) async {
        expect(req.url.path, '/api/pricing/lowest');
        expect(req.url.queryParameters['routeId'], 'ROUTE-CPH-OSL');
        return http.Response(jsonEncode({'days': [
          {'date': '2026-10-14', 'priceDkk': 799},
          {'date': '2026-10-15', 'available': false},
        ]}), 200);
      });
      final prices = await ApiService().fetchLowestPrices(routeId: 'ROUTE-CPH-OSL', from: '2026-10-14', to: '2026-10-15');
      expect(prices, {'2026-10-14': 799.0, '2026-10-15': null});
    });

    test('afgang uden id/tider eller aflyst opfindes ikke', () {
      expect(DepartureModel.tryFromJson({'routeId': 'R'}), isNull);
      expect(DepartureModel.tryFromJson({'id': 'D', 'routeId': 'R'}), isNull);
      expect(DepartureModel.tryFromJson({'id': 'D', 'routeId': 'R', 'scheduledDepartureTime': '2026-10-14T14:30:00Z', 'status': 'CANCELLED'}), isNull);
      expect(DepartureModel.tryFromJson({'id': 'D', 'routeId': 'R', 'scheduledDepartureTime': '2026-10-14T14:30:00Z'})?.id, 'D');
    });
  });

  group('Konfiguration', () {
    test('release-build uden --dart-define kræver Core- og TideCMS-adresse', () {
      // Testene bygges uden defines: i release-tilstand mangler begge
      expect(missingReleaseDefines(releaseMode: true), containsAll(['TIDEBOOK_API_URL', 'TIDECMS_URL']));
      expect(missingReleaseDefines(releaseMode: false), isEmpty);
    });
  });
}
