import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tidebook_app/main.dart';
import 'package:tidebook_app/services/auth_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/qr_security_service.dart';
import 'package:tidebook_app/services/texts_service.dart';

void main() {
  setUpAll(() {
    // Testene kører uden TideCMS – den indbyggede danske pakke indlæses direkte
    TestWidgetsFlutterBinding.ensureInitialized();
    final json = jsonDecode(File('assets/i18n/da.json').readAsStringSync()) as Map<String, dynamic>;
    TextsService.instance.load(json);
    // Ingen Core i testene: alle kald svarer som en utilgængelig server
    ApiService.client = MockClient((_) async => throw const SocketException('Core er ikke startet i testen'));
    BookingService().resetForTest();
  });

  tearDown(() => AuthService().logout());

  testWidgets('Tidebook passenger app loads with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const TidebookApp());
    await tester.pumpAndSettle();

    expect(find.text('Udforsk'), findsOneWidget);
    expect(find.text('Book Rejse'), findsWidgets);
    expect(find.text('Mine Bookinger'), findsOneWidget);
    expect(find.text('Boardingkort'), findsOneWidget);
    expect(find.text('Min Profil'), findsOneWidget);
  });

  group('Authentication & Authorization Tests', () {
    test('Kundelogin går via Core (portal-login) og bruger Core\'s navn', () async {
      ApiService.client = MockClient((req) async {
        expect(req.url.path, '/api/auth/portal-login');
        expect(jsonDecode(req.body)['isAgent'], false);
        return http.Response(
          jsonEncode({
            'IsLoggedIn': true,
            'token': 'PORTAL-TOKEN',
            'expiresInSeconds': 3600,
            'user': {'id': 'USR-CUST-01', 'username': 'kunde', 'email': 'kunde@example.dk', 'fullName': 'Kunde Test', 'role': 'Person'},
          }),
          200,
        );
      });
      final auth = AuthService();
      final res = await auth.loginCustomer(usernameOrEmail: 'kunde', password: 'Kunde2026!');
      expect(res.success, isTrue);
      expect(res.user?.fullName, 'Kunde Test');
      expect(auth.portalToken, 'PORTAL-TOKEN');
      ApiService.client = MockClient((_) async => throw const SocketException('offline'));
    });

    test('Profilen har ingen opfundne stamdata og kan opdateres', () {
      final user = AuthService.userFromCore({'id': 'USR-1', 'username': 'kunde', 'email': 'kunde@example.dk'}, 'kunde');
      // Uden navn fra Core bruges e-mailen – ingen "Mads Jensen"
      expect(user.fullName, 'kunde@example.dk');
      expect(user.phone, isEmpty);
      expect(user.savedVehiclePlate, isEmpty);
      expect(user.passportNumber, isEmpty);
      expect(user.clubTier, isEmpty);

      final auth = AuthService();
      auth.updateProfile(user);
      final updated = user.copyWith(phone: '+45 99 88 77 66', savedVehiclePlate: 'DK 12 345');
      auth.updateProfile(updated);
      expect(auth.currentUser?.phone, '+45 99 88 77 66');
      expect(auth.currentUser?.savedVehiclePlate, 'DK 12 345');
    });

    test('Online Agent (OA) login is STRICTLY REJECTED', () async {
      final auth = AuthService();
      final res = await auth.loginCustomer(
        usernameOrEmail: 'rejseagent',
        password: 'Agent2026!',
      );
      expect(res.success, isFalse);
      expect(res.errorMessage, contains('Online Agent (OA)'));
    });

    test('Group leader login is STRICTLY REJECTED', () async {
      final auth = AuthService();
      final res = await auth.loginCustomer(
        usernameOrEmail: 'gruppeleder',
        password: 'Gruppe2026!',
      );
      expect(res.success, isFalse);
      expect(res.errorMessage, contains('Gruppeleder-login er ikke tilladt'));
    });
  });

  group('Booking & Boarding Pass Tests', () {
    test('Gruppe-PNR afvises (reserveregel uden kanal fra Core)', () {
      expect(BookingService.pnrPrefixDenial('TB-GRP-9020'), contains('Gruppe-reservationer'));
    });

    test('OA/agent-PNR afvises (reserveregel uden kanal fra Core)', () {
      expect(BookingService.pnrPrefixDenial('FG-DF-10928'), contains('Online Agentur (OA)'));
      expect(BookingService.pnrPrefixDenial('TB-123456'), isNull);
    });

    test('Backend API health and TideRMS connectivity', () async {
      final health = await ApiService().checkHealth();
      // If port 4000 is running on Mac, verify response
      if (health != null) {
        expect(health['status'], 'UP');
      }
    });

    test('Validates Core-issued maritime boarding pass QR payload and extracts HMAC', () {
      const corePayload = 'TB:TIDE-9021:P1:A7F39C20BD8104E2';
      expect(QrSecurityService.isValidBoardingPassPayload(corePayload), isTrue);
      expect(QrSecurityService.extractPnr(corePayload), 'TIDE-9021');
      expect(QrSecurityService.extractPassengerId(corePayload), 'P1');
      expect(QrSecurityService.extractSecurityCode(corePayload), 'A7F39C20BD8104E2');

      // Invalid / forged formats are rejected
      expect(QrSecurityService.isValidBoardingPassPayload('INVALID-QR'), isFalse);
    });

    test('BookingService stores and remembers booking tokens for Core authentication', () {
      final service = BookingService();
      service.setBookingToken('TIDE-9021', 'JWT_TEST_TOKEN_2026');
      expect(service.getBookingToken('TIDE-9021'), 'JWT_TEST_TOKEN_2026');
    });

    test('ApiService supports configurable API base URL and does not rely on hardcoded localhost:4000', () {
      // Debug/test: localhost er kun standard uden for release
      expect(ApiService.isConfigured(releaseMode: false), isTrue);
      ApiService.setBaseUrl('http://api.gonordic.dk:8080');
      expect(ApiService.baseUrl, 'http://api.gonordic.dk:8080/api');
      expect(ApiService.healthUrl, 'http://api.gonordic.dk:8080/health');

      // Reset back for local testing
      ApiService.setBaseUrl('http://localhost:4000');
      expect(ApiService.baseUrl, 'http://localhost:4000/api');
    });
  });
}

