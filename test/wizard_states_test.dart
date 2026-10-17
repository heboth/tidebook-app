import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tidebook_app/models/user_model.dart';
import 'package:tidebook_app/screens/booking_wizard_screen.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/auth_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/texts_service.dart';
import 'package:tidebook_app/widgets/cabin_card.dart';

/// Booking-guidens tilstande, når Core svarer anderledes end forventet: ingen afgange, ingen hjemrejse, kahytter
/// og tilkøb der ikke kan hentes (med "Prøv igen"), skib uden ledige kahytter til alle; den indloggede kunde, der
/// udfylder kontakten fra profilen, og afbestillingsforsikringen fra TideRMS. Core er en falsk server.
void main() {
  String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final out = DateTime.now().add(const Duration(days: 10));
  final outDate = iso(out);

  final routes = [
    {'id': 'R-CPH-OSL', 'name': 'Copenhagen - Oslo', 'originPort': {'code': 'DKCPH', 'name': 'Copenhagen'}, 'destinationPort': {'code': 'NOOSL', 'name': 'Oslo'}},
    {'id': 'R-OSL-CPH', 'name': 'Oslo - Copenhagen', 'originPort': {'code': 'NOOSL', 'name': 'Oslo'}, 'destinationPort': {'code': 'DKCPH', 'name': 'Copenhagen'}},
  ];
  final dep = {
    'id': 'DEP-OUT', 'routeId': 'R-CPH-OSL', 'vesselId': 'V1',
    'scheduledDepartureTime': '${outDate}T14:30:00.000Z', 'scheduledArrivalTime': '${outDate}T23:59:00.000Z',
  };

  late int departuresStatus;
  late bool noDepartures;
  late int cabinsStatus;
  late List<Map<String, dynamic>> cabins;
  late int addonsStatus;
  late Map<String, dynamic>? insurance;
  late List<Map<String, dynamic>> quotes;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TextsService.instance.load(jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>);
  });

  setUp(() {
    departuresStatus = 200;
    noDepartures = false;
    cabinsStatus = 200;
    cabins = [{'id': 'C-A4', 'category': 'A4', 'berths': 4, 'deck': 8, 'isBookedOnDeparture': false}];
    addonsStatus = 200;
    insurance = null;
    quotes = [];
    ApiService.client = MockClient((req) async {
      final p = req.url.path;
      if (p == '/health') return http.Response('{"status":"UP"}', 200);
      if (p == '/api/routes') return http.Response(jsonEncode(routes), 200);
      if (p == '/api/departures') {
        if (departuresStatus != 200) return http.Response('fejl', departuresStatus);
        final r = req.url.queryParameters['routeId'];
        return http.Response(!noDepartures && r == 'R-CPH-OSL' && req.url.queryParameters['date'] == outDate ? jsonEncode([dep]) : '[]', 200);
      }
      if (p == '/api/departures/DEP-OUT/cabins') {
        return cabinsStatus == 200 ? http.Response(jsonEncode(cabins), 200) : http.Response('fejl', cabinsStatus);
      }
      if (p == '/api/departures/DEP-OUT/availability') return http.Response('{"addOnPrices":{}}', 200);
      if (p == '/api/addons') return addonsStatus == 200 ? http.Response('[]', 200) : http.Response('fejl', addonsStatus);
      if (p == '/api/pricing/calculate') {
        quotes.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'ok': true, 'totalAmountDkk': 2480, 'insuranceOffer': ?insurance}), 200);
      }
      throw const SocketException('ikke relevant i testen');
    });
    BookingService().resetForTest();
    AuthService().logout();
  });

  tearDown(() => AuthService().logout());

  Future<void> pumpWizard(WidgetTester tester, {String tripType = 'ONEWAY', int adults = 2}) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => BookingService().syncBackend());
    await tester.pumpWidget(MaterialApp(
      home: BookingWizardScreen(initialRouteId: 'R-CPH-OSL', initialTripType: tripType, initialDate: out, initialAdults: adults, initialChildren: 0, hasVehicle: false),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.text(tr(key)));
    await tester.tap(find.text(tr(key)));
    await tester.pumpAndSettle();
  }

  group('Trin 1: afgange', () {
    testWidgets('afgangene kan ikke hentes: besked i stedet for en opdigtet afgang', (tester) async {
      departuresStatus = 503;
      await pumpWizard(tester);
      expect(find.text(tr('bookingWizard.step1.departuresUnavailable')), findsOneWidget);
    });

    testWidgets('ingen afgange på datoen: besked', (tester) async {
      noDepartures = true;
      await pumpWizard(tester);
      expect(find.text(tr('bookingWizard.step1.noDepartures')), findsOneWidget);
    });

    testWidgets('MiniCruise uden hjemrejse dagen efter: besked om, at der ingen hjemrejse er', (tester) async {
      await pumpWizard(tester, tripType: 'CRUISE');
      expect(find.text(tr('bookingWizard.step1.noReturn')), findsOneWidget);
    });

    testWidgets('en anden rute kan vælges; den henter sine egne afgange', (tester) async {
      await pumpWizard(tester);
      await tester.tap(find.text('Oslo - Copenhagen'));
      await tester.pumpAndSettle();
      expect(find.text(tr('bookingWizard.step1.noDepartures')), findsOneWidget);
      await tester.tap(find.text('Copenhagen - Oslo'));
      await tester.pumpAndSettle();
      expect(find.text(tr('bookingWizard.step1.noDepartures')), findsNothing);
    });
  });

  group('Trin 2 og 3: kahytter og tilkøb', () {
    testWidgets('kahytterne kan ikke hentes: besked og "Prøv igen" henter dem', (tester) async {
      cabinsStatus = 503;
      await pumpWizard(tester);
      await next(tester, 'bookingWizard.step1.next');
      expect(find.text(tr('bookingWizard.step2.unavailable')), findsOneWidget);
      cabinsStatus = 200;
      await tester.tap(find.text(tr('bookingWizard.retry')));
      await tester.pumpAndSettle();
      expect(find.byType(CabinCard), findsOneWidget);
    });

    testWidgets('kahytter for små til hele selskabet skjules med en note; ingen tilbage giver en besked', (tester) async {
      cabins = [
        {'id': 'C-B2', 'category': 'B2', 'berths': 2, 'deck': 8, 'isBookedOnDeparture': false},
        {'id': 'C-A4', 'category': 'A4', 'berths': 4, 'deck': 8, 'isBookedOnDeparture': false},
      ];
      await pumpWizard(tester, adults: 3);
      await next(tester, 'bookingWizard.step1.next');
      expect(find.byType(CabinCard), findsOneWidget);
      expect(find.text(tr('bookingWizard.step2.capacityNote', {'count': 3})), findsOneWidget);
    });

    testWidgets('ingen kahyt valgt: "Næste" beder om at vælge en kahyt', (tester) async {
      await pumpWizard(tester);
      await next(tester, 'bookingWizard.step1.next');
      await tester.tap(find.text(tr('bookingWizard.step2.next')));
      await tester.pump();
      expect(find.text(tr('bookingWizard.step2.selectCabin')), findsOneWidget);
    });

    testWidgets('ingen tilkøb fra Core: besked i trin 3', (tester) async {
      await pumpWizard(tester);
      await next(tester, 'bookingWizard.step1.next');
      await tester.tap(find.byType(CabinCard));
      await tester.pumpAndSettle();
      await next(tester, 'bookingWizard.step2.next');
      expect(find.text(tr('bookingWizard.step3.none')), findsOneWidget);
    });
  });

  group('Trin 4: profil og forsikring', () {
    Future<void> toStep4(WidgetTester tester) async {
      await pumpWizard(tester);
      await next(tester, 'bookingWizard.step1.next');
      await tester.tap(find.byType(CabinCard));
      await tester.pumpAndSettle();
      await next(tester, 'bookingWizard.step2.next');
      await next(tester, 'bookingWizard.step3.next');
    }

    testWidgets('uden login: opfordring til at logge ind for hurtig udfyldning', (tester) async {
      await toStep4(tester);
      expect(find.text(tr('bookingWizard.step4.loginForQuickFill')), findsOneWidget);
    });

    testWidgets('indlogget kunde: kontakt, nationalitet og fødselsdato udfyldes fra profilen', (tester) async {
      AuthService().updateProfile(const UserModel(
        id: 'U1', username: 'mette@example.dk', email: 'mette@example.dk', fullName: 'Mette Profil', phone: '+4512345678',
        nationality: 'NO', birthDate: '1985-04-12', clubTier: 'Gold', role: UserRole.person,
      ));
      await toStep4(tester);
      expect(find.text(tr('bookingWizard.step4.loggedInAs', {'name': 'Mette Profil', 'tier': 'Gold'})), findsOneWidget);
      await tester.ensureVisible(find.text(tr('bookingWizard.step4.useProfile')));
      await tester.tap(find.text(tr('bookingWizard.step4.useProfile')));
      await tester.pump();
      expect(find.text(tr('bookingWizard.profileFilled', {'name': 'Mette Profil'})), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mette Profil'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'mette@example.dk'), findsOneWidget);
      expect(find.widgetWithText(TextField, '+4512345678'), findsOneWidget);
    });

    testWidgets('indlogget uden kundeklub: hilsen uden niveau', (tester) async {
      AuthService().updateProfile(const UserModel(id: 'U2', username: 'ole@example.dk', email: 'ole@example.dk', fullName: 'Ole Uden', role: UserRole.person));
      await toStep4(tester);
      expect(find.text(tr('bookingWizard.step4.loggedInAsNoTier', {'name': 'Ole Uden'})), findsOneWidget);
    });

    testWidgets('afbestillingsforsikring fra TideRMS: pris, vilkår og valget sendes med til prisberegningen', (tester) async {
      insurance = {'code': 'TRYG-AFB', 'name': 'Afbestillingsforsikring', 'provider': 'Tryg', 'priceDkk': 59.5, 'priceType': 'PERCENT', 'percent': 6, 'premiumRefundable': false, 'termsUrl': 'https://example.dk/vilkaar'};
      await toStep4(tester);
      expect(find.byKey(const Key('wizard-insurance')), findsOneWidget);
      expect(find.text(tr('bookingWizard.insurance.title', {'provider': 'Tryg'})), findsOneWidget);
      expect(find.text(tr('bookingWizard.insurance.price', {'amount': '59,50'})), findsOneWidget);
      expect(find.textContaining(tr('bookingWizard.insurance.notRefundable')), findsOneWidget);
      expect(find.textContaining('https://example.dk/vilkaar'), findsOneWidget);
      expect(quotes.last['withCancellationInsurance'], isNot(true));
      await tester.ensureVisible(find.byKey(const Key('wizard-insurance')));
      await tester.tap(find.byKey(const Key('wizard-insurance')));
      await tester.pumpAndSettle();
      expect(quotes.last['withCancellationInsurance'], true);
    });

    testWidgets('forsikring pr. person med fast pris viser det', (tester) async {
      insurance = {'code': 'TRYG-FAST', 'name': 'Afbestillingsforsikring', 'provider': 'Tryg', 'priceDkk': 99, 'priceType': 'FIXED', 'per': 'PERSON', 'premiumRefundable': true};
      await toStep4(tester);
      expect(find.text(tr('bookingWizard.insurance.price', {'amount': '99'})), findsOneWidget);
      expect(find.textContaining(tr('bookingWizard.insurance.perPerson')), findsOneWidget);
      expect(find.textContaining(tr('bookingWizard.insurance.notRefundable')), findsNothing);
    });
  });
}
