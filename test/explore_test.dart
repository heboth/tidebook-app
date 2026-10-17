import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tidebook_app/screens/booking_wizard_screen.dart';
import 'package:tidebook_app/screens/destination_guide_screen.dart';
import 'package:tidebook_app/screens/explore_screen.dart';
import 'package:tidebook_app/screens/login_screen.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/texts_service.dart';

/// "Søg og opdag": ruterne og lavpriskalenderen fra Core, ruteskift, fejl med "Prøv igen", rejsende og bil,
/// MiniCruise/færge og "Find afgange", der åbner booking-guiden med valgene. Core er en falsk server.
void main() {
  String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final day3 = DateTime.now().add(const Duration(days: 3));

  final routes = [
    {'id': 'R-CPH-OSL', 'name': 'København - Oslo', 'originPort': {'code': 'DKCPH', 'name': 'København'}, 'destinationPort': {'code': 'NOOSL', 'name': 'Oslo'}},
    {'id': 'R-OSL-CPH', 'name': 'Oslo - København', 'originPort': {'code': 'NOOSL', 'name': 'Oslo'}, 'destinationPort': {'code': 'DKCPH', 'name': 'København'}},
  ];

  late List<Map<String, String>> priceCalls;
  late bool pricesFail;
  late bool routesFail;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TextsService.instance.load(jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>);
  });

  setUp(() {
    priceCalls = [];
    pricesFail = false;
    routesFail = false;
    ApiService.client = MockClient((req) async {
      final p = req.url.path;
      if (p == '/health') return http.Response('{"status":"UP"}', 200);
      if (p == '/api/routes') return routesFail ? http.Response('fejl', 500) : http.Response(jsonEncode(routes), 200);
      if (p == '/api/pricing/lowest') {
        priceCalls.add(req.url.queryParameters);
        if (pricesFail) return http.Response('fejl', 503);
        final r = req.url.queryParameters['routeId'];
        return http.Response(jsonEncode({
          'days': [
            {'date': iso(tomorrow), 'priceDkk': r == 'R-CPH-OSL' ? 499.4 : 799},
            {'date': iso(day3), 'priceDkk': null},
          ]
        }), 200);
      }
      if (p == '/api/departures') return http.Response('[]', 200);
      throw const SocketException('ikke relevant i testen');
    });
    BookingService().resetForTest();
  });

  Future<void> pumpExplore(WidgetTester tester, {bool loadRoutes = true}) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (loadRoutes) await tester.runAsync(() => BookingService().syncBackend());
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('første rute fra Core og 14 dages laveste priser; dage uden pris får en streg', (tester) async {
    await pumpExplore(tester);
    expect(find.text('København - Oslo'), findsOneWidget);
    expect(priceCalls.single['routeId'], 'R-CPH-OSL');
    expect(priceCalls.single['from'], iso(tomorrow));
    expect(priceCalls.single['to'], iso(DateTime.now().add(const Duration(days: 14))));
    expect(find.text(tr('explore.priceCalendar')), findsOneWidget);
    expect(find.text('499,-'), findsOneWidget);
    expect(find.text(tr('explore.noPrice')), findsWidgets);
  });

  testWidgets('et tryk på ruten skifter til næste rute fra Core og henter dens priser', (tester) async {
    await pumpExplore(tester);
    await tester.tap(find.text('København - Oslo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Oslo - København'), findsOneWidget);
    expect(priceCalls.last['routeId'], 'R-OSL-CPH');
    expect(find.text('799,-'), findsOneWidget);
    // … og rundt igen
    await tester.tap(find.text('Oslo - København'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('København - Oslo'), findsOneWidget);
  });

  testWidgets('priserne kan ikke hentes: besked og "Prøv igen" henter dem igen', (tester) async {
    pricesFail = true;
    await pumpExplore(tester);
    expect(find.text(tr('explore.priceUnavailable')), findsOneWidget);
    pricesFail = false;
    await tester.tap(find.widgetWithText(TextButton, tr('explore.retry')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(priceCalls, hasLength(2));
    expect(find.text(tr('explore.priceUnavailable')), findsNothing);
    expect(find.text('499,-'), findsOneWidget);
  });

  testWidgets('ruterne kan ikke hentes: besked, ingen lavpriskalender, og "Prøv igen" henter dem', (tester) async {
    routesFail = true;
    await pumpExplore(tester);
    expect(find.text(tr('explore.routesUnavailable')), findsOneWidget);
    expect(find.text(tr('explore.priceCalendar')), findsNothing);
    expect(priceCalls, isEmpty);
    routesFail = false;
    await tester.tap(find.widgetWithText(TextButton, tr('explore.retry')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('København - Oslo'), findsOneWidget);
    expect(priceCalls, hasLength(1));
  });

  testWidgets('rejsende og bil: plus og minus inden for grænserne, bil til og fra – opsummeringen følger med', (tester) async {
    await pumpExplore(tester);
    final summary = '${tr('explore.search.adults', {'count': 2})} • ${tr('explore.search.vehicle')}';
    expect(find.textContaining(tr('explore.search.adults', {'count': 2})), findsOneWidget);
    await tester.tap(find.textContaining(tr('explore.search.adults', {'count': 2})));
    await tester.pumpAndSettle();
    expect(find.text(tr('explore.passengerModal.title')), findsOneWidget);
    final plus = find.byIcon(Icons.add_circle_outline);
    final minus = find.byIcon(Icons.remove_circle_outline);
    for (final t in [plus.first, plus.last, plus.last, minus.last]) { // 3 voksne, 1 barn, 2 børn, 1 barn
      await tester.tap(t);
      await tester.pump();
    }
    await tester.tap(find.byType(Switch)); // uden bil
    await tester.pump();
    await tester.tap(find.text(tr('explore.passengerModal.confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining(tr('explore.search.adults', {'count': 3})), findsOneWidget);
    expect(find.textContaining(tr('explore.search.children', {'count': 1})), findsOneWidget);
    expect(find.textContaining(tr('explore.search.vehicle')), findsNothing, reason: summary);
  });

  testWidgets('"Find afgange" åbner booking-guiden med rute, rejsetype, dato, rejsende og bil', (tester) async {
    await pumpExplore(tester);
    await tester.tap(find.text(tr('explore.search.ferryTab')));
    await tester.pump();
    await tester.tap(find.text('499,-'));
    await tester.pump();
    await tester.tap(find.text(tr('explore.search.findDepartures')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final wizard = tester.widget<BookingWizardScreen>(find.byType(BookingWizardScreen));
    expect(wizard.initialRouteId, 'R-CPH-OSL');
    expect(wizard.initialTripType, 'ONEWAY');
    expect(iso(wizard.initialDate!), iso(tomorrow));
    expect([wizard.initialAdults, wizard.initialChildren, wizard.hasVehicle], [2, 0, true]);
  });

  testWidgets('uden login: bjælken åbner login; oplevelserne åbner guiden', (tester) async {
    await pumpExplore(tester);
    await tester.tap(find.text(tr('explore.highlights.seeAll')));
    await tester.pumpAndSettle();
    expect(find.byType(DestinationGuideScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(DestinationGuideScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text(tr('explore.profileBar.loginTitle')), findsOneWidget);
    await tester.tap(find.text(tr('explore.profileBar.loginTitle')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
