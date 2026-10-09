import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../models/departure_model.dart';
import '../models/booking_model.dart';

class BookingLookupResult {
  final bool success;
  final BookingModel? booking;
  final String? bookingToken;
  final String? errorMessage;

  const BookingLookupResult({
    required this.success,
    this.booking,
    this.bookingToken,
    this.errorMessage,
  });
}

class CheckInResponse {
  final bool success;
  final BookingModel? booking;
  final List<BoardingPassModel> boardingPasses;
  final String? errorMessage;

  const CheckInResponse({
    required this.success,
    this.booking,
    this.boardingPasses = const [],
    this.errorMessage,
  });
}

class CheckoutSession {
  final String pnr;
  final String paymentId;
  final double amountDkk;
  final String currency;
  final String provider;
  final String? checkoutKey;
  final String? scriptUrl;
  final String? bookingToken;
  /// Nets' betalingsside (eller Core's simulator-side i test) og adresserne Nets sender kunden tilbage til
  final String? paymentPageUrl;
  final String? returnUrl;
  final String? cancelUrl;

  const CheckoutSession({
    required this.pnr,
    required this.paymentId,
    required this.amountDkk,
    this.currency = 'DKK',
    required this.provider,
    this.checkoutKey,
    this.scriptUrl,
    this.bookingToken,
    this.paymentPageUrl,
    this.returnUrl,
    this.cancelUrl,
  });

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    final checkout = json['checkout'] is Map ? json['checkout'] as Map : {};
    return CheckoutSession(
      pnr: json['pnr'] ?? '',
      paymentId: json['paymentId'] ?? '',
      amountDkk: (json['amountDkk'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'DKK',
      provider: checkout['provider']?.toString() ?? 'simulator',
      checkoutKey: checkout['checkoutKey']?.toString(),
      scriptUrl: checkout['scriptUrl']?.toString(),
      bookingToken: json['bookingToken']?.toString(),
      paymentPageUrl: checkout['hostedPaymentPageUrl']?.toString(),
      returnUrl: checkout['returnUrl']?.toString(),
      cancelUrl: checkout['cancelUrl']?.toString(),
    );
  }
}

class CompletedPaymentResult {
  final bool success;
  final String? pnr;
  final BookingModel? booking;
  final String? bookingToken;
  final String? errorMessage;

  const CompletedPaymentResult({
    required this.success,
    this.pnr,
    this.booking,
    this.bookingToken,
    this.errorMessage,
  });
}


class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static String? _customBaseUrl;

  /// Configure API root address at runtime (e.g. from settings or environment)
  static void setBaseUrl(String url) {
    final clean = url.trim().replaceFirst(RegExp(r'/+$'), '');
    _customBaseUrl = clean.endsWith('/api') ? clean : '$clean/api';
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    const envUrl = String.fromEnvironment('TIDEBOOK_API_URL');
    if (envUrl.isNotEmpty) {
      final clean = envUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      return clean.endsWith('/api') ? clean : '$clean/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:4000/api';
      }
    } catch (_) {}
    return 'http://localhost:4000/api';
  }

  static String get serverRoot {
    final b = baseUrl;
    if (b.endsWith('/api')) {
      return b.substring(0, b.length - 4);
    }
    return b;
  }

  static String get healthUrl => '$serverRoot/health';

  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final res = await http.get(Uri.parse(healthUrl)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Authenticate customer against Core's /api/auth/portal-login
  Future<Map<String, dynamic>?> portalLogin(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/portal-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'isAgent': false,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPortalSession(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/portal-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<RouteModel>?> fetchRoutes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/routes')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((item) => RouteModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<DepartureModel>?> fetchDepartures() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/departures')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((item) => DepartureModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  /// Lookup booking with PNR and Email / Last Name (returns booking + bookingToken)
  Future<BookingLookupResult> lookupBooking(String pnr, String emailOrLastName) async {
    try {
      final cleanPnr = pnr.trim().toUpperCase();
      final identifier = emailOrLastName.trim();
      final body = <String, dynamic>{
        'pnr': cleanPnr,
      };
      if (identifier.contains('@')) {
        body['email'] = identifier.toLowerCase();
      } else {
        body['lastName'] = identifier.toLowerCase();
      }

      final res = await http.post(
        Uri.parse('$baseUrl/bookings/lookup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true && data['booking'] != null) {
        final token = data['bookingToken']?.toString();
        final booking = BookingModel.fromJson(
          data['booking'] as Map<String, dynamic>,
          bookingToken: token,
        );
        return BookingLookupResult(
          success: true,
          booking: booking,
          bookingToken: token,
        );
      } else {
        return BookingLookupResult(
          success: false,
          errorMessage: data['message'] ?? data['error'] ?? 'Booking ikke fundet.',
        );
      }
    } catch (_) {
      return const BookingLookupResult(
        success: false,
        errorMessage: 'Kunne ikke forbinde til booking-serveren.',
      );
    }
  }

  /// Mobile check-in requiring x-booking-token after PR 4
  Future<CheckInResponse> checkIn(
    String pnr, {
    String? bookingToken,
    String legType = 'OUTBOUND',
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (bookingToken != null && bookingToken.isNotEmpty) {
        headers['x-booking-token'] = bookingToken;
      }

      final res = await http.post(
        Uri.parse('$baseUrl/bookings/${pnr.toUpperCase()}/check-in'),
        headers: headers,
        body: jsonEncode({'legType': legType}),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final bookingJson = data['booking'] as Map<String, dynamic>?;
        final checkInResult = data['checkInResult'] as Map<String, dynamic>?;
        final rawPasses = checkInResult?['passengerBoardingPasses'] as List?;
        final passes = rawPasses != null
            ? rawPasses
                .map((p) => BoardingPassModel.fromJson(Map<String, dynamic>.from(p as Map)))
                .toList()
            : <BoardingPassModel>[];

        BookingModel? updatedBooking;
        if (bookingJson != null) {
          updatedBooking = BookingModel.fromJson(bookingJson, bookingToken: bookingToken);
          if (passes.isNotEmpty && updatedBooking.boardingPasses.isEmpty) {
            updatedBooking = updatedBooking.copyWith(boardingPasses: passes, status: 'CHECKED_IN');
          }
        }

        return CheckInResponse(
          success: true,
          booking: updatedBooking,
          boardingPasses: passes,
        );
      } else {
        return CheckInResponse(
          success: false,
          errorMessage: data['message'] ?? data['error'] ?? 'Check-in afvist af serveren.',
        );
      }
    } catch (_) {
      return const CheckInResponse(
        success: false,
        errorMessage: 'Forbindelsesfejl under check-in. Prøv igen om et øjeblik.',
      );
    }
  }

  // ==========================================
  // Nets Betalingsmotor Integration Flow
  // ==========================================

  /// Start checkout session: Core registers draft as PENDING and creates Nets session
  Future<CheckoutSession?> startCheckout(
    Map<String, dynamic> bookingDraft, {
    String? checkoutUrl,
  }) async {
    try {
      // Appen bruger Nets' betalingsside (hosted) – Core giver adressen og retur-/afbrudt-adresserne
      final payload = {
        'booking': bookingDraft,
        'mode': 'hosted',
      };

      final res = await http.post(
        Uri.parse('$baseUrl/integrations/payments/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'x-tidebook-client': 'tidebook-app',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return CheckoutSession.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Complete payment with Nets verification: Core marks booking CONFIRMED / PAID and returns booking + token
  Future<CompletedPaymentResult> completePayment(String paymentId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/integrations/payments/$paymentId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'x-tidebook-client': 'tidebook-app',
        },
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && (data['status'] == 'COMPLETED' || data['booking'] != null)) {
        final token = data['bookingToken']?.toString();
        final bookingJson = data['booking'] as Map<String, dynamic>;
        final booking = BookingModel.fromJson(bookingJson, bookingToken: token);
        return CompletedPaymentResult(
          success: true,
          pnr: data['pnr'] ?? booking.pnr,
          booking: booking,
          bookingToken: token,
        );
      } else {
        return CompletedPaymentResult(
          success: false,
          errorMessage: data['message'] ?? data['error'] ?? 'Betalingen kunne ikke afsluttes.',
        );
      }
    } catch (_) {
      return const CompletedPaymentResult(
        success: false,
        errorMessage: 'Forbindelsesfejl ved betalingsafslutning. Prøv igen.',
      );
    }
  }

  /// Abandon / cancel payment: Releases reserved capacity back to Core / TideRMS
  Future<bool> abandonPayment(String paymentId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/integrations/payments/$paymentId/abandon'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
