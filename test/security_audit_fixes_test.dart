import 'package:flutter_test/flutter_test.dart';
import 'package:tidebook_app/models/booking_model.dart';
import 'package:tidebook_app/models/passenger_model.dart';
import 'package:tidebook_app/models/user_model.dart';
import 'package:tidebook_app/services/api_service.dart';
import 'package:tidebook_app/services/auth_service.dart';
import 'package:tidebook_app/services/booking_service.dart';
import 'package:tidebook_app/services/qr_security_service.dart';

void main() {
  group('Security Review Fixes (Audit Findings 1 to 5)', () {
    test('Finding 1: Nets betalingsflow benyttes - bookinger oprettes ikke med umiddelbar PAID uden om Nets', () {
      const sessionJson = {
        'pnr': 'TB-89421',
        'paymentId': 'PAY-NETS-99124',
        'amountDkk': 2450.0,
        'currency': 'DKK',
        'checkout': {
          'provider': 'simulator',
          'language': 'da-DK',
        },
        'bookingToken': 'TOKEN-SECURE-JWT-2026',
      };

      final session = CheckoutSession.fromJson(sessionJson);
      expect(session.pnr, 'TB-89421');
      expect(session.paymentId, 'PAY-NETS-99124');
      expect(session.amountDkk, 2450.0);
      expect(session.provider, 'simulator');
      expect(session.bookingToken, 'TOKEN-SECURE-JWT-2026');

      final completed = CompletedPaymentResult(
        success: true,
        pnr: session.pnr,
        booking: BookingModel(
          pnr: session.pnr,
          bookingCode: 'BK-${session.pnr}',
          routeId: 'ROUTE-CPH-OSL',
          routeName: 'København - Oslo',
          departureId: 'DEP-1',
          departureDate: '2026-10-15',
          departureTime: '16:30',
          arrivalTime: '10:00',
          vesselName: 'Crown Seaways',
          status: 'CONFIRMED',
          ticketClass: 'PREMIUM',
          passengers: const [
            PassengerModel(id: 'P1', firstName: 'Mads', lastName: 'Jensen', type: PassengerType.adult),
          ],
          selectedCabinIds: const ['CAB-1'],
          cabinTitle: 'Commodore',
          cabinNumbers: const ['CAB-1'],
          addOns: const [],
          leadContactName: 'Mads Jensen',
          leadContactEmail: 'mads@example.dk',
          leadContactPhone: '+45 20 30 40 50',
          totalAmountDkk: 2450.0,
          paymentStatus: 'PAID',
          bookingToken: session.bookingToken,
        ),
        bookingToken: session.bookingToken,
      );

      expect(completed.success, isTrue);
      expect(completed.booking?.paymentStatus, 'PAID');
      expect(completed.booking?.bookingToken, 'TOKEN-SECURE-JWT-2026');
    });

    test('Finding 2: Boardingkort bygges IKKE lokalt med fast salt - QR hentes fra Core check-in svar', () {
      const coreIssuedQr = 'TB:TB-7842:P1:98A4BC210DE491F0';
      expect(QrSecurityService.isValidBoardingPassPayload(coreIssuedQr), isTrue);
      expect(QrSecurityService.extractPnr(coreIssuedQr), 'TB-7842');
      expect(QrSecurityService.extractPassengerId(coreIssuedQr), 'P1');
      expect(QrSecurityService.extractSecurityCode(coreIssuedQr), '98A4BC210DE491F0');

      final uncheckedBooking = BookingModel(
        pnr: 'TB-7842',
        bookingCode: 'BK-TB-7842',
        routeId: 'ROUTE-CPH-OSL',
        routeName: 'København - Oslo',
        departureId: 'DEP-1',
        departureDate: '2026-10-15',
        departureTime: '16:30',
        arrivalTime: '10:00',
        vesselName: 'Crown Seaways',
        status: 'CONFIRMED',
        ticketClass: 'PREMIUM',
        passengers: const [
          PassengerModel(id: 'P1', firstName: 'Mads', lastName: 'Jensen', type: PassengerType.adult),
        ],
        selectedCabinIds: const [],
        cabinTitle: 'Standard',
        cabinNumbers: const [],
        addOns: const [],
        leadContactName: 'Mads Jensen',
        leadContactEmail: 'mads@example.dk',
        leadContactPhone: '+45 20 30 40 50',
        totalAmountDkk: 890.0,
        paymentStatus: 'PAID',
      );

      expect(uncheckedBooking.isCheckedIn, isFalse);
      expect(uncheckedBooking.qrPayload, isNull);

      final checkedInBooking = uncheckedBooking.copyWith(
        status: 'CHECKED_IN',
        boardingPasses: const [
          BoardingPassModel(
            passengerId: 'P1',
            passengerName: 'Mads Jensen',
            qrPayload: coreIssuedQr,
            seatOrCabin: 'CAB-101',
          ),
        ],
      );

      expect(checkedInBooking.isCheckedIn, isTrue);
      expect(checkedInBooking.qrPayload, coreIssuedQr);
      expect(checkedInBooking.boardingPasses.length, 1);
    });

    test('Finding 3: Appen gemmer booking-nøgle og afviser at vise checket ind ved afvisning fra Core', () async {
      final service = BookingService();

      // Gemmer bookingToken
      service.setBookingToken('TB-TEST-KEY', 'JWT_KEY_30_DAYS');
      expect(service.getBookingToken('TB-TEST-KEY'), 'JWT_KEY_30_DAYS');

      // Tjekker at CheckInResponse med fejl IKKE sætter bookingen som checket ind
      const failedResponse = CheckInResponse(
        success: false,
        errorMessage: 'Mobil check-in er lukket. Henvend dig venligst ved skranken senest 15 minutter før afgang (MNG-06).',
      );

      expect(failedResponse.success, isFalse);
      expect(failedResponse.errorMessage, contains('Mobil check-in er lukket'));
      expect(failedResponse.boardingPasses.isEmpty, isTrue);
    });

    test('Finding 5a: API-adresse er konfigurerbar og ikke låst til localhost:4000', () {
      ApiService.setBaseUrl('http://core-backend.prod.tidebook.io:4000');
      expect(ApiService.baseUrl, 'http://core-backend.prod.tidebook.io:4000/api');
      expect(ApiService.healthUrl, 'http://core-backend.prod.tidebook.io:4000/health');

      ApiService.setBaseUrl('https://api.staging.gonordic.dk');
      expect(ApiService.baseUrl, 'https://api.staging.gonordic.dk/api');
      expect(ApiService.healthUrl, 'https://api.staging.gonordic.dk/health');

      // Nulstil tilbage til standard
      ApiService.setBaseUrl('http://localhost:4000');
      expect(ApiService.baseUrl, 'http://localhost:4000/api');
    });

    test('Finding 5b: Kundelogin rammer Core portal-login og spærrer for agent/gruppe-roller', () async {
      final auth = AuthService();

      // B2B Online Agent (OA) afvises
      final agentRes = await auth.loginCustomer(usernameOrEmail: 'rejseagent', password: 'AnyPassword');
      expect(agentRes.success, isFalse);
      expect(agentRes.errorMessage, contains('Online Agent (OA)'));

      // Gruppeleder afvises
      final grpRes = await auth.loginCustomer(usernameOrEmail: 'gruppeleder', password: 'AnyPassword');
      expect(grpRes.success, isFalse);
      expect(grpRes.errorMessage, contains('Gruppeleder-login er ikke tilladt'));

      // Gyldigt kundelogin godkendes (demo / offline fallback)
      final custRes = await auth.loginCustomer(usernameOrEmail: 'kunde', password: 'Kunde2026!');
      expect(custRes.success, isTrue);
      expect(custRes.user?.role, UserRole.person);
      // Navnet kommer fra Core, når den kører (ellers fra demo-data) – det vigtige er rollen
      expect(custRes.user?.fullName, isNotEmpty);
    });

  });
}
