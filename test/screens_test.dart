import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tidebook_app/models/booking_model.dart';
import 'package:tidebook_app/screens/boarding_pass_screen.dart';
import 'package:tidebook_app/screens/booking_detail_screen.dart';
import 'package:tidebook_app/screens/login_screen.dart';
import 'package:tidebook_app/screens/my_bookings_screen.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/auth_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/texts_service.dart';

/// Skærmene "Bookinger", bookingdetaljer, boardingkort og login mod en falsk Core.
void main() {
  late List<http.Request> requests;
  Map<String, dynamic> booking({String pnr = 'TB-300400', String status = 'CONFIRMED', String payment = 'PAID', bool vehicle = true}) => {
        'pnr': pnr,
        'routeId': 'ROUTE-CPH-OSL',
        'departureId': 'DEP-CPH-OSL-20261030-1630',
        'status': status,
        'paymentStatus': payment,
        'channel': 'B2C',
        'leadContact': {'fullName': 'Mette Hansen', 'email': 'mette@example.dk', 'phone': '+4512345678'},
        'passengers': [
          {'id': 'P1', 'firstName': 'Mette', 'lastName': 'Hansen', 'type': 'ADULT'},
          {'id': 'P2', 'firstName': 'Ole', 'lastName': 'Hansen', 'type': 'ADULT'},
        ],
        if (vehicle) 'vehicle': {'category': 'CAR_STANDARD', 'licensePlate': 'CD 98 765'},
        'selectedCabinIds': ['CAB-CROW-5709'],
        'fareBreakdown': {'totalAmountDkk': 4432},
      };
  final checkInOk = {
    'success': true,
    'checkInResult': {
      'passengerBoardingPasses': [
        {'passengerId': 'P1', 'passengerName': 'Mette Hansen', 'qrPayload': 'TB:TB-300400:P1:F15E1B7DFED3B7D3EAC5', 'seatOrCabin': '5709'},
        {'passengerId': 'P2', 'passengerName': 'Ole Hansen', 'qrPayload': 'TB:TB-300400:P2:0A1B2C3D4E5F60718293', 'seatOrCabin': '5709'},
      ]
    },
  };

  void core(Map<String, http.Response Function(http.Request)> routes) {
    requests = [];
    ApiService.client = MockClient((req) async {
      requests.add(req);
      final handler = routes['${req.method} ${req.url.path}'];
      if (handler == null) throw const SocketException('ikke i testen');
      return handler(req);
    });
  }

  http.Response json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TextsService.instance.load(jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>);
  });
  setUp(() {
    BookingService().resetForTest();
    AuthService().logout();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('Bookinger: find en booking', () {
    testWidgets('begge felter skal udfyldes – intet kald til Core', (tester) async {
      core({});
      await pump(tester, const MyBookingsScreen());
      await tester.tap(find.text(tr('myBookings.findButton')));
      await tester.pumpAndSettle();
      expect(find.text(tr('myBookings.missingFields')), findsOneWidget);
      expect(requests, isEmpty);
    });

    testWidgets('fundet: e-mail sendes med små bogstaver, bookingen vises og huskes med booking-nøglen', (tester) async {
      core({'POST /api/bookings/lookup': (_) => json({'success': true, 'booking': booking(), 'bookingToken': 'TOKEN-1'})});
      await pump(tester, const MyBookingsScreen());
      await tester.enterText(find.byType(TextField).at(0), 'tb-300400');
      await tester.enterText(find.byType(TextField).at(1), ' Mette@Example.DK ');
      await tester.tap(find.text(tr('myBookings.findButton')));
      await tester.pumpAndSettle();
      expect(jsonDecode(requests.single.body), {'pnr': 'TB-300400', 'email': 'mette@example.dk'});
      expect(find.text(tr('myBookings.found', {'pnr': 'TB-300400'})), findsOneWidget);
      expect(find.textContaining('TB-300400'), findsWidgets);
      expect(BookingService().getBookingToken('TB-300400'), 'TOKEN-1');
    });

    testWidgets('efternavn i stedet for e-mail sendes som lastName', (tester) async {
      core({'POST /api/bookings/lookup': (_) => json({'success': false, 'message': 'Ingen booking fundet'}, 404)});
      await pump(tester, const MyBookingsScreen());
      await tester.enterText(find.byType(TextField).at(0), 'TB-1');
      await tester.enterText(find.byType(TextField).at(1), 'Hansen');
      await tester.tap(find.text(tr('myBookings.findButton')));
      await tester.pumpAndSettle();
      expect(jsonDecode(requests.single.body), {'pnr': 'TB-1', 'lastName': 'hansen'});
      expect(find.text('Ingen booking fundet'), findsOneWidget);
    });

    testWidgets('uden forbindelse til Core: tydelig besked', (tester) async {
      core({});
      await pump(tester, const MyBookingsScreen());
      await tester.enterText(find.byType(TextField).at(0), 'TB-1');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.dk');
      await tester.tap(find.text(tr('myBookings.findButton')));
      await tester.pumpAndSettle();
      expect(find.text(tr('myBookings.lookupUnavailable')), findsOneWidget);
    });
  });

  group('Bookingdetaljer', () {
    testWidgets('viser rute, status, passagerer og bil på dansk – og betalt kun når Core siger det', (tester) async {
      core({});
      await pump(tester, BookingDetailScreen(booking: BookingModel.fromJson(booking())));
      expect(find.text(tr('bookingStatus.CONFIRMED')), findsOneWidget);
      expect(find.text('Mette Hansen, Ole Hansen'), findsOneWidget);
      expect(find.text('CD 98 765 (${tr('bookingWizard.vehicle.categories.CAR_STANDARD')})'), findsOneWidget);
      expect(find.text(tr('bookingDetail.totalPaid', {'amount': 4432})), findsOneWidget);
      expect(find.text('CONFIRMED'), findsNothing);
    });

    testWidgets('ubetalt booking (fx telefonbooking med betalingslink) står ikke som betalt', (tester) async {
      core({});
      await pump(tester, BookingDetailScreen(booking: BookingModel.fromJson(booking(status: 'PENDING', payment: 'PENDING', vehicle: false))));
      expect(find.text(tr('bookingDetail.totalUnpaid', {'amount': 4432})), findsOneWidget);
      expect(find.textContaining('(Betalt)'), findsNothing);
      expect(find.text(tr('bookingStatus.PENDING')), findsOneWidget);
    });

    testWidgets('check-in: booking-nøglen sendes med; knappen forsvinder, når Core har udstedt boardingkort', (tester) async {
      BookingService().setBookingToken('TB-300400', 'TOKEN-1');
      core({'POST /api/bookings/TB-300400/check-in': (_) => json({...checkInOk, 'booking': booking(status: 'CHECKED_IN')})});
      await pump(tester, BookingDetailScreen(booking: BookingModel.fromJson(booking())));
      await tester.tap(find.text(tr('bookingDetail.checkIn')));
      await tester.pumpAndSettle();
      expect(requests.single.headers['x-booking-token'], 'TOKEN-1');
      expect(jsonDecode(requests.single.body), {'legType': 'OUTBOUND'});
      expect(find.text(tr('bookingDetail.checkInDone')), findsOneWidget);
      expect(find.text(tr('bookingDetail.checkIn')), findsNothing);
    });

    testWidgets('Core afviser check-in: Core\'s begrundelse vises, og knappen bliver', (tester) async {
      core({'POST /api/bookings/TB-300400/check-in': (_) => json({'error': 'CHECKIN_CLOSED', 'message': 'Check-in lukker 15 minutter før afgang.'}, 409)});
      await pump(tester, BookingDetailScreen(booking: BookingModel.fromJson(booking())));
      await tester.tap(find.text(tr('bookingDetail.checkIn')));
      await tester.pumpAndSettle();
      expect(find.text('Check-in lukker 15 minutter før afgang.'), findsOneWidget);
      expect(find.text(tr('bookingDetail.checkIn')), findsOneWidget);
    });
  });

  group('Boardingkort', () {
    testWidgets('uden check-in: intet QR – kun opfordring til at tjekke ind', (tester) async {
      core({});
      await pump(tester, BoardingPassScreen(booking: BookingModel.fromJson(booking())));
      expect(find.text(tr('boardingPass.issuedAtCheckIn')), findsOneWidget);
      expect(find.text(tr('boardingPass.checkInNow')), findsOneWidget);
    });

    testWidgets('efter check-in: én fane pr. passager med Core\'s QR; bil og kahyt vises', (tester) async {
      core({'POST /api/bookings/TB-300400/check-in': (_) => json({...checkInOk, 'booking': booking(status: 'CHECKED_IN')})});
      await pump(tester, BoardingPassScreen(booking: BookingModel.fromJson(booking())));
      await tester.tap(find.text(tr('boardingPass.checkInNow')));
      await tester.pumpAndSettle();
      expect(find.text(tr('boardingPass.checkInDone')), findsOneWidget);
      expect(find.text(tr('boardingPass.statusCheckedIn')), findsOneWidget);
      expect(find.text('Mette'), findsOneWidget);
      expect(find.text('Ole'), findsOneWidget);
      expect(find.text('CD 98 765'), findsOneWidget);
      expect(find.text(tr('boardingPass.issuedAtCheckIn')), findsNothing);
    });
  });

  group('Login', () {
    Future<void> login(WidgetTester tester, String user, String pass) async {
      await tester.enterText(find.byType(TextField).at(0), user);
      await tester.enterText(find.byType(TextField).at(1), pass);
      await tester.tap(find.text(tr('login.submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('forkert kode giver en besked; ingen bruger gemmes', (tester) async {
      core({'POST /api/auth/portal-login': (_) => json({'IsLoggedIn': false})});
      await pump(tester, const LoginScreen());
      await login(tester, 'kunde', 'forkert');
      expect(find.text(tr('login.invalidCredentials')), findsOneWidget);
      expect(AuthService().currentUser, isNull);
    });

    testWidgets('uden forbindelse: login kræver Core (intet offline-login)', (tester) async {
      core({});
      await pump(tester, const LoginScreen());
      await login(tester, 'kunde', 'Kunde2026!');
      expect(find.text(tr('login.coreUnavailable')), findsOneWidget);
    });

    testWidgets('vellykket login viser profilen med Core\'s navn; log ud vender tilbage', (tester) async {
      core({'POST /api/auth/portal-login': (_) => json({
            'IsLoggedIn': true, 'token': 'T', 'expiresInSeconds': 3600,
            'user': {'id': 'U1', 'username': 'kunde', 'email': 'kunde@example.dk', 'fullName': 'Kunde Test', 'role': 'Person'},
          })});
      await pump(tester, const LoginScreen());
      await login(tester, 'kunde', 'hemmelig');
      expect(jsonDecode(requests.single.body)['isAgent'], false);
      expect(find.text(tr('login.profileTitle')), findsOneWidget);
      expect(find.textContaining('Kunde Test'), findsWidgets);
      await tester.tap(find.text(tr('login.logout')));
      await tester.pumpAndSettle();
      expect(AuthService().currentUser, isNull);
    });
  });
}
