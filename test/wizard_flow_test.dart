import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tidebook_app/screens/booking_wizard_screen.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/texts_service.dart';
import 'package:tidebook_app/widgets/cabin_card.dart';
import 'package:tidebook_app/widgets/partner_ticket_sheet.dart';

/// Booking-guiden efter kahytsvalget: tilkøb (pris fra Core) og partnerbilletter i trin 3, kontrollerne i trin 4 og
/// betalingsarket (Nets' side mangler → besked; afbryd → pladsen frigives hos Core). Core er en falsk server.
void main() {
  final out = DateTime.now().add(const Duration(days: 10));
  String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final outDate = iso(out);

  final routes = [
    {'id': 'R-CPH-OSL', 'name': 'Copenhagen - Oslo', 'originPort': {'code': 'DKCPH', 'name': 'Copenhagen'}, 'destinationPort': {'code': 'NOOSL', 'name': 'Oslo'}},
  ];
  final dep = {
    'id': 'DEP-OUT', 'routeId': 'R-CPH-OSL', 'vesselId': 'V1',
    'scheduledDepartureTime': '${outDate}T14:30:00.000Z', 'scheduledArrivalTime': '${outDate}T23:59:00.000Z',
  };
  final addons = [
    {'id': 'addon-breakfast', 'name': 'Morgenmadsbuffet', 'category': 'MEALS', 'isActive': true},
    {'id': 'addon-tivoli', 'name': 'Tivoli Entré & Turpas', 'category': 'EXPERIENCE', 'isActive': true, 'pricingModel': 'DYNAMIC_API', 'externalProviderConfig': {'partnerName': 'Tivoli Gardens A/S'}},
  ];

  late List<Map<String, dynamic>> quotes;
  late List<Map<String, dynamic>> checkouts;
  late List<String> abandoned;
  late List<Map<String, dynamic>> partnerQuotes;
  late int checkoutStatus;
  late List<Map<String, dynamic>> slots;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TextsService.instance.load(jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>);
  });

  setUp(() {
    quotes = [];
    checkouts = [];
    abandoned = [];
    partnerQuotes = [];
    checkoutStatus = 201;
    slots = [
      {'time': '11:00', 'remaining': 0, 'prices': [{'type': 'ADULT', 'amount': 195, 'label': 'Voksen'}]},
      {'time': '13:00', 'remaining': 40, 'prices': [{'type': 'ADULT', 'amount': 195, 'label': 'Voksen'}, {'type': 'CHILD', 'amount': 120, 'label': 'Barn'}]},
    ];
    ApiService.client = MockClient((req) async {
      final p = req.url.path;
      if (p == '/health') return http.Response('{"status":"UP"}', 200);
      if (p == '/api/routes') return http.Response(jsonEncode(routes), 200);
      if (p == '/api/departures') {
        return http.Response(req.url.queryParameters['date'] == outDate ? jsonEncode([dep]) : '[]', 200);
      }
      if (p == '/api/departures/DEP-OUT/cabins') {
        return http.Response(jsonEncode([{'id': 'C-A4', 'category': 'A4', 'berths': 4, 'deck': 8, 'isBookedOnDeparture': false}]), 200);
      }
      if (p == '/api/departures/DEP-OUT/availability') {
        return http.Response(jsonEncode({'addOnPrices': {'addon-breakfast': {'adultDkk': 145, 'childDkk': 75, 'soldOut': false}}}), 200);
      }
      if (p == '/api/addons') return http.Response(jsonEncode(addons), 200);
      if (p == '/api/addons/addon-tivoli/availability') return http.Response(jsonEncode({'requiresTime': true, 'slots': slots}), 200);
      if (p == '/api/addons/quote') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        partnerQuotes.add(body);
        final adults = ((body['tickets'] as List?) ?? []).whereType<Map>().fold<int>(0, (n, t) => n + ((t['quantity'] as num?)?.toInt() ?? 0));
        return http.Response(jsonEncode({'quoteId': 'Q-${partnerQuotes.length}', 'visitDate': body['visitDate'], 'visitTime': body['visitTime'], 'totalPriceDkk': 195 * adults}), 200);
      }
      if (p == '/api/pricing/calculate') {
        quotes.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('{"ok":true,"totalAmountDkk":2480}', 200);
      }
      if (p == '/api/integrations/payments/checkout') {
        checkouts.add(jsonDecode(req.body) as Map<String, dynamic>);
        if (checkoutStatus >= 300) return http.Response('{"error":"DOWN"}', checkoutStatus);
        // Uden Nets' hostede side (som i en test uden Nets-nøgle)
        return http.Response(jsonEncode({'pnr': 'TB-777001', 'paymentId': 'PAY-1', 'amountDkk': 2480, 'currency': 'DKK', 'checkout': {'provider': 'simulator'}}), 201);
      }
      if (p.startsWith('/api/integrations/payments/') && p.endsWith('/abandon')) {
        abandoned.add(p.split('/')[4]);
        return http.Response('{}', 200);
      }
      throw const SocketException('ikke relevant i testen');
    });
    BookingService().resetForTest();
  });

  Future<void> toStep(WidgetTester tester, int step) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => BookingService().syncBackend());
    await tester.pumpWidget(MaterialApp(
      home: BookingWizardScreen(initialRouteId: 'R-CPH-OSL', initialTripType: 'ONEWAY', initialDate: out, initialAdults: 2, initialChildren: 0, hasVehicle: false),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('bookingWizard.step1.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CabinCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('bookingWizard.step2.next')));
    await tester.pumpAndSettle();
    if (step == 4) {
      await tester.tap(find.text(tr('bookingWizard.step3.next')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> pick(WidgetTester tester, String key, String label) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> birthDate(WidgetTester tester, String prefix) async {
    await tester.ensureVisible(find.byKey(Key('$prefix-birthdate')));
    await tester.tap(find.byKey(Key('$prefix-birthdate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> contact(WidgetTester tester, {String name = 'Mette Guide', String email = 'mette@example.dk', String phone = '+4512345678'}) async {
    await tester.enterText(find.widgetWithText(TextField, tr('bookingWizard.step4.fullName')), name);
    await tester.enterText(find.widgetWithText(TextField, tr('bookingWizard.step4.email')), email);
    await tester.enterText(find.widgetWithText(TextField, tr('bookingWizard.step4.mobile')), phone);
  }

  Future<void> leadDetails(WidgetTester tester) async {
    await birthDate(tester, 'wizard');
    await pick(tester, 'wizard-gender', tr('bookingWizard.step4.genderFemale'));
    await pick(tester, 'wizard-nationality', tr('countries.DK'));
  }

  Future<void> fellow(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('wizard-p2-first')), 'Ole');
    await tester.enterText(find.byKey(const Key('wizard-p2-last')), 'Guide');
    await birthDate(tester, 'wizard-p2');
    await pick(tester, 'wizard-p2-gender', tr('bookingWizard.step4.genderMale'));
    await pick(tester, 'wizard-p2-nationality', tr('countries.NO'));
  }

  Future<void> acceptAndPay(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('wizard-terms')));
    await tester.tap(find.byKey(const Key('wizard-terms')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(tr('bookingWizard.step4.continueToPayment')));
    await tester.tap(find.text(tr('bookingWizard.step4.continueToPayment')));
    await tester.pumpAndSettle();
  }

  group('Trin 3: tilkøb', () {
    testWidgets('tilkøbets pris kommer fra Core, og et valgt tilkøb sendes med til prisberegningen', (tester) async {
      await toStep(tester, 3);
      expect(find.text(tr('bookingWizard.step3.price', {'amount': 145})), findsOneWidget);
      // Navnet vises på appens sprog; tilkøbet er det eneste afkrydsningsfelt (partnerbilletten er en knap)
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final addOns = (quotes.last['addOns'] as List).whereType<Map>().toList();
      expect(addOns.map((a) => a['id']), contains('addon-breakfast'));
    });

    testWidgets('partnerbillet: tidspunkt, antal og pris fra partneren; udsolgt tidspunkt kan ikke vælges', (tester) async {
      await toStep(tester, 3);
      expect(find.text(tr('bookingWizard.partner.partner', {'name': 'Tivoli Gardens A/S'})), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const Key('wizard-partner-addon-tivoli')), matching: find.text(tr('bookingWizard.partner.choose'))));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerTicketSheet), findsOneWidget);
      expect(find.text(tr('bookingWizard.partner.chooseTime')), findsOneWidget);
      // 11:00 er udsolgt
      await tester.tap(find.byKey(const Key('partner-time-11:00')));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('partner-add'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('partner-time-13:00')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('partner-plus-ADULT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('partner-plus-ADULT')));
      await tester.pumpAndSettle();
      expect(partnerQuotes.last['visitTime'], '13:00');
      final adults = (partnerQuotes.last['tickets'] as List).whereType<Map>().firstWhere((t) => t['type'] == 'ADULT')['quantity'] as int;
      expect(adults, greaterThanOrEqualTo(2));
      expect(find.text(tr('bookingWizard.partner.total', {'amount': 195 * adults})), findsOneWidget);
      await tester.tap(find.byKey(const Key('partner-add')));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerTicketSheet), findsNothing);
      expect(find.textContaining('13:00'), findsWidgets);
      expect(find.text(tr('bookingWizard.partner.change')), findsOneWidget);
    });

    testWidgets('partneren har lukket på datoen: beskeden vises, og intet kan lægges i kurven', (tester) async {
      slots = [];
      await toStep(tester, 3);
      await tester.tap(find.text(tr('bookingWizard.partner.choose')));
      await tester.pumpAndSettle();
      expect(find.text(tr('bookingWizard.partner.closed')), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('partner-add'))).onPressed, isNull);
    });
  });

  group('Trin 4: oplysninger og betaling', () {
    testWidgets('betalingsknappen er slået fra, indtil vilkårene er accepteret', (tester) async {
      await toStep(tester, 4);
      final btn = find.widgetWithText(ElevatedButton, tr('bookingWizard.step4.continueToPayment'));
      expect(tester.widget<ElevatedButton>(btn).onPressed, isNull);
    });

    testWidgets('mangler kontaktoplysninger: beskeden vises, og intet sendes til betaling', (tester) async {
      await toStep(tester, 4);
      await acceptAndPay(tester);
      expect(find.text(tr('bookingWizard.missingContact')), findsOneWidget);
      expect(checkouts, isEmpty);
    });

    testWidgets('kun ét navn: kunden skal selv skrive efternavnet (intet opdigtet)', (tester) async {
      await toStep(tester, 4);
      await contact(tester, name: 'Mette');
      await acceptAndPay(tester);
      expect(find.text(tr('bookingWizard.missingLastName')), findsOneWidget);
      expect(checkouts, isEmpty);
    });

    testWidgets('hovedrejsende uden fødselsdato, køn og nationalitet afvises', (tester) async {
      await toStep(tester, 4);
      await contact(tester);
      await acceptAndPay(tester);
      expect(find.text(tr('bookingWizard.missingPassengerDetails')), findsOneWidget);
      expect(checkouts, isEmpty);
    });

    testWidgets('medrejsende uden oplysninger: beskeden siger hvilken rejsende', (tester) async {
      await toStep(tester, 4);
      await contact(tester);
      await leadDetails(tester);
      await acceptAndPay(tester);
      expect(find.text(tr('bookingWizard.step4.missingFellowDetails', {'n': 2})), findsOneWidget);
      expect(checkouts, isEmpty);
    });

    testWidgets('alt udfyldt: Core får hele kladden, betalingsarket vises, og afbryd frigiver pladsen', (tester) async {
      await toStep(tester, 4);
      await contact(tester, name: 'Mette Marie Guide');
      await leadDetails(tester);
      await fellow(tester);
      await acceptAndPay(tester);
      expect(checkouts, hasLength(1));
      expect(checkouts.single['mode'], 'hosted');
      final b = checkouts.single['booking'] as Map<String, dynamic>;
      expect(b['departureId'], 'DEP-OUT');
      expect(b['cabinIds'] ?? b['selectedCabinIds'], ['C-A4']);
      final pax = (b['passengers'] as List).whereType<Map>().toList();
      expect(pax.map((p) => [p['firstName'], p['lastName']]), [['Mette', 'Marie Guide'], ['Ole', 'Guide']]);
      expect(pax.map((p) => p['nationality']), ['DK', 'NO']);
      expect(pax.map((p) => p['gender']), ['FEMALE', 'MALE']);
      expect((b['leadContact'] as Map)['email'], 'mette@example.dk');
      // Betalingsarket: uden Nets' betalingsside forklares det; afbryd frigiver hos Core
      expect(find.text(tr('bookingWizard.payment.title')), findsOneWidget);
      await tester.tap(find.text(tr('bookingWizard.payment.pay')));
      await tester.pumpAndSettle();
      expect(find.text(tr('bookingWizard.payment.pageUnavailable')), findsOneWidget);
      await tester.tap(find.text(tr('bookingWizard.payment.cancel')));
      await tester.pumpAndSettle();
      expect(abandoned, ['PAY-1']);
      expect(find.text(tr('bookingWizard.paymentCancelled')), findsOneWidget);
    });

    testWidgets('betalingsserveren svarer ikke: besked, og kunden bliver på siden', (tester) async {
      checkoutStatus = 503;
      await toStep(tester, 4);
      await contact(tester);
      await leadDetails(tester);
      await fellow(tester);
      await acceptAndPay(tester);
      expect(find.text(tr('bookingWizard.paymentServerUnreachable')), findsOneWidget);
      expect(find.text(tr('bookingWizard.payment.title')), findsNothing);
    });
  });
}
