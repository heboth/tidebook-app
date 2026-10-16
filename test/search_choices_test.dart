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

/// Søgningens valg (MiniCruise/færge, rejsende, bil) skal med i bookingen – ikke kun rute og dato.
void main() {
  final out = DateTime.now().add(const Duration(days: 10));
  String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final outDate = iso(out);
  final backDate = iso(DateTime.utc(out.year, out.month, out.day + 1));

  final routes = [
    {'id': 'R-CPH-OSL', 'name': 'Copenhagen - Oslo', 'originPort': {'code': 'DKCPH', 'name': 'Copenhagen'}, 'destinationPort': {'code': 'NOOSL', 'name': 'Oslo'}},
    {'id': 'R-OSL-CPH', 'name': 'Oslo - Copenhagen', 'originPort': {'code': 'NOOSL', 'name': 'Oslo'}, 'destinationPort': {'code': 'DKCPH', 'name': 'Copenhagen'}},
  ];
  Map<String, dynamic> dep(String id, String routeId, String date) => {
    'id': id, 'routeId': routeId, 'vesselId': 'V1',
    'scheduledDepartureTime': '${date}T14:30:00.000Z', 'scheduledArrivalTime': '${date}T23:59:00.000Z',
  };
  Map<String, dynamic> cabin(String id, String category, int berths, {bool booked = false}) =>
      {'id': id, 'category': category, 'berths': berths, 'deck': 8, 'isBookedOnDeparture': booked};

  late List<Map<String, dynamic>> quotes;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TextsService.instance.load(jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>);
  });

  setUp(() {
    quotes = [];
    ApiService.client = MockClient((req) async {
      final p = req.url.path;
      if (p == '/health') return http.Response('{"status":"UP"}', 200);
      if (p == '/api/routes') return http.Response(jsonEncode(routes), 200);
      if (p == '/api/departures') {
        final r = req.url.queryParameters['routeId'];
        final d = req.url.queryParameters['date'];
        if (r == 'R-CPH-OSL' && d == outDate) return http.Response(jsonEncode([dep('DEP-OUT', r!, outDate)]), 200);
        if (r == 'R-OSL-CPH' && d == backDate) return http.Response(jsonEncode([dep('DEP-BACK', r!, backDate)]), 200);
        return http.Response('[]', 200);
      }
      // Udrejsen: B2 (2 køjer) og to A4; hjemrejsen: den ene A4 er optaget
      if (p == '/api/departures/DEP-OUT/cabins') {
        return http.Response(jsonEncode([cabin('C-B2', 'B2', 2), cabin('C-A4-1', 'A4', 4), cabin('C-A4-2', 'A4', 4)]), 200);
      }
      if (p == '/api/departures/DEP-BACK/cabins') {
        return http.Response(jsonEncode([cabin('C-B2', 'B2', 2), cabin('C-A4-1', 'A4', 4, booked: true), cabin('C-A4-2', 'A4', 4)]), 200);
      }
      if (p == '/api/pricing/calculate') {
        quotes.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('{"ok":true,"totalAmountDkk":4321}', 200);
      }
      throw const SocketException('ikke relevant i testen');
    });
    BookingService().resetForTest();
  });

  Future<void> pumpWizard(WidgetTester tester, {required String tripType}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Ruterne hentes med rigtige timere (ikke testens falske tid)
    await tester.runAsync(() => BookingService().syncBackend());
    await tester.pumpWidget(MaterialApp(
      home: BookingWizardScreen(
        initialRouteId: 'R-CPH-OSL',
        initialTripType: tripType,
        initialDate: out,
        initialAdults: 2,
        initialChildren: 1,
        hasVehicle: true,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('MiniCruise: hjemrejse, alle rejsende og bilen sendes til prisberegningen', (tester) async {
    await pumpWizard(tester, tripType: 'CRUISE');

    expect(find.textContaining('Hjemrejse:'), findsOneWidget);
    expect(find.byKey(const Key('wizard-adults-count')).evaluate().single.widget, isA<Text>().having((t) => t.data, 'data', '2'));

    await tester.tap(find.text(tr('bookingWizard.step1.next')));
    await tester.pumpAndSettle();

    // Kun kahytter med plads til 3 og ledige både ud og hjem
    expect(find.byType(CabinCard), findsOneWidget);
    expect(find.text(tr('bookingWizard.step2.capacityNote', {'count': 3})), findsOneWidget);
    await tester.tap(find.byType(CabinCard));
    await tester.pumpAndSettle();

    final q = quotes.last;
    expect(q['departureId'], 'DEP-OUT');
    expect(q['returnDepartureId'], 'DEP-BACK');
    expect((q['legs'] as List).map((l) => l['departureId']), ['DEP-OUT', 'DEP-BACK']);
    expect(q['cabinIds'], ['C-A4-2']);
    expect((q['passengers'] as List).map((p) => p['type']), ['ADULT', 'ADULT', 'CHILD']);
    expect(q['vehicle']['category'], 'CAR_STANDARD');
  });

  testWidgets('Færgeoverfart: kun udrejsen, og valgene kan rettes i trin 1', (tester) async {
    await pumpWizard(tester, tripType: 'ONEWAY');
    expect(find.textContaining('Hjemrejse:'), findsNothing);

    // Én voksen færre og ingen bil
    await tester.tap(find.byKey(const Key('wizard-adults-minus')));
    await tester.tap(find.byKey(const Key('wizard-vehicle')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr('bookingWizard.step1.next')));
    await tester.pumpAndSettle();
    // To rejsende: B2 og A4 passer begge
    expect(find.byType(CabinCard), findsNWidgets(2));
    await tester.tap(find.byType(CabinCard).first);
    await tester.pumpAndSettle();

    final q = quotes.last;
    expect(q.containsKey('returnDepartureId'), isFalse);
    expect((q['legs'] as List), hasLength(1));
    expect((q['passengers'] as List).map((p) => p['type']), ['ADULT', 'CHILD']);
    expect(q.containsKey('vehicle'), isFalse);
  });
}
