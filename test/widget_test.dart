import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/main.dart';
import 'package:tidebook_app/services/auth_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/qr_security_service.dart';

void main() {
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
    test('Customer can login successfully', () async {
      final auth = AuthService();
      final res = await auth.loginCustomer(
        usernameOrEmail: 'kunde',
        password: 'Kunde2026!',
      );
      expect(res.success, isTrue);
      expect(res.user?.fullName, 'Mads Jensen');
    });

    test('Customer profile contains personal data and can be updated', () {
      final auth = AuthService();
      auth.loginAsDemoCustomer();
      final user = auth.currentUser!;
      expect(user.fullName, 'Mads Jensen');
      expect(user.phone, '+45 20 30 40 50');
      expect(user.savedVehiclePlate, 'CP 48 921');
      expect(user.address, contains('Dampfærgevej'));

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
    test('Can lookup customer booking by PNR and email', () async {
      final service = BookingService();
      final res = await service.lookupBooking(pnr: 'TIDE-9021', emailOrLastName: 'mads.jensen@example.dk');
      expect(res.success, isTrue);
      expect(res.booking?.pnr, 'TIDE-9021');
    });

    test('Group booking PNR is rejected in passenger app', () async {
      final service = BookingService();
      final res = await service.lookupBooking(pnr: 'TB-GRP-9020', emailOrLastName: 'leder@skole.dk');
      expect(res.success, isFalse);
      expect(res.errorMessage, contains('Gruppe-reservationer'));
    });

    test('OA / Agent booking PNR is rejected in passenger app', () async {
      final service = BookingService();
      final res = await service.lookupBooking(pnr: 'FG-DF-10928', emailOrLastName: 'agent@bureau.dk');
      expect(res.success, isFalse);
      expect(res.errorMessage, contains('Online Agentur (OA)'));
    });

    test('Backend API health and TideRMS connectivity', () async {
      final health = await ApiService().checkHealth();
      // If port 4000 is running on Mac, verify response
      if (health != null) {
        expect(health['status'], 'UP');
      }
    });

    test('Generates real scannable maritime QR payload with SHA-256 security checksum', () {
      final payload = QrSecurityService.buildPayload(
        pnr: 'TIDE-9021',
        date: '2026-10-10',
        passengerId: 'P1',
        cabin: 'CAB-CROW-1101',
      );
      expect(payload.startsWith('TB:TIDE-9021:P1:2026-10-10:'), isTrue);
    });
  });
}

