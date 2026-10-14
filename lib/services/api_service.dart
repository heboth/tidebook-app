import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/addon_model.dart';
import '../models/route_model.dart';
import '../models/departure_model.dart';
import '../models/booking_model.dart';

class BookingLookupResult {
  final bool success;
  final BookingModel? booking;
  final String? bookingToken;
  final String? errorMessage;

  /// Sand, når Core ikke kunne nås (ingen svar) – adskiller netværksfejl fra "ikke fundet"
  final bool networkError;

  const BookingLookupResult({
    required this.success,
    this.booking,
    this.bookingToken,
    this.errorMessage,
    this.networkError = false,
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

  /// HTTP-klienten mod Core. Kan udskiftes i tests (fx med `MockClient`).
  static http.Client _client = http.Client();
  @visibleForTesting
  static set client(http.Client c) => _client = c;
  static http.Client get client => _client;

  /// Configure API root address at runtime (e.g. from settings or environment)
  static void setBaseUrl(String url) {
    final clean = url.trim().replaceFirst(RegExp(r'/+$'), '');
    _customBaseUrl = clean.endsWith('/api') ? clean : '$clean/api';
  }

  static const _envUrl = String.fromEnvironment('TIDEBOOK_API_URL');

  /// Er Core-adressen sat? I release-builds skal den angives med
  /// `--dart-define=TIDEBOOK_API_URL=...` – localhost-standarden gælder kun under udvikling.
  static bool isConfigured({bool releaseMode = kReleaseMode}) =>
      !releaseMode || (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) || _envUrl.isNotEmpty;

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (_envUrl.isNotEmpty) {
      final clean = _envUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      return clean.endsWith('/api') ? clean : '$clean/api';
    }
    if (kReleaseMode) {
      // Ingen stille fallback til localhost i en udgivet app – main() viser en fejlskærm i stedet
      throw StateError('TIDEBOOK_API_URL er ikke angivet (--dart-define=TIDEBOOK_API_URL=https://...).');
    }
    // Kun under udvikling: Android-emulatoren når værtsmaskinen på 10.0.2.2
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
      final res = await _client.get(Uri.parse(healthUrl)).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Kundelogin mod Core's /api/auth/portal-login.
  /// Returnerer Core's svar ({IsLoggedIn, token, expiresInSeconds, user}) eller null, hvis Core ikke kan nås.
  Future<Map<String, dynamic>?> portalLogin(String username, String password) async {
    try {
      final res = await _client.post(
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

  /// Fornyer kundens token hos Core (/api/auth/portal-renew). null hvis Core ikke kan nås.
  Future<Map<String, dynamic>?> portalRenew(String token) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/auth/portal-renew'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPortalSession(String token) async {
    try {
      final res = await _client.get(
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

  /// Ruterne fra Core. null hvis Core ikke kan nås.
  Future<List<RouteModel>?> fetchRoutes() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/routes')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((item) => RouteModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
  }

  /// Afgange fra Core, evt. for én rute og/eller dato (YYYY-MM-DD). null hvis Core ikke kan nås.
  Future<List<DepartureModel>?> fetchDepartures({String? routeId, String? date}) async {
    try {
      final uri = Uri.parse('$baseUrl/departures').replace(queryParameters: {
        'routeId': ?routeId,
        'date': ?date,
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map(DepartureModel.tryFromJson)
            .whereType<DepartureModel>()
            .toList();
      }
    } catch (_) {}
    return null;
  }

  /// Tilvalg fra Core (/api/addons) – kun aktive og gyldige på rejsedatoen. null hvis Core ikke kan nås.
  /// Med [departureId] får hvert tilvalg sin pris på afgangen fra TideRMS (/departures/:id/availability), og tilvalg,
  /// TideRMS har udsolgt, udelades. Uden pris (TideRMS svarer ikke) er priceDkk null – aldrig katalogets pris.
  Future<List<AddOnModel>?> fetchAddOns({DateTime? travelDate, bool? hasVehicle, int? passengerCount, String? departureId}) async {
    try {
      final uri = Uri.parse('$baseUrl/addons').replace(queryParameters: {
        if (hasVehicle != null) 'hasVehicle': '$hasVehicle',
        if (passengerCount != null) 'passengerCount': '$passengerCount',
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .whereType<Map<String, dynamic>>()
            .map(AddOnModel.fromJson)
            .where((a) => a.isAvailableOn(travelDate ?? DateTime.now()))
            .toList();
        if (departureId == null) return list;
        final prices = await _addOnPrices(departureId);
        if (prices == null) return list;
        return list
            .where((a) => prices[a.id]?['soldOut'] != true)
            .map((a) => a.withPrice((prices[a.id]?['adultDkk'] as num?)?.toDouble()))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  /// Tilvalgenes pris på afgangen fra TideRMS (via Core). null hvis Core ikke kan nås.
  Future<Map<String, Map<String, dynamic>>?> _addOnPrices(String departureId) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/departures/${Uri.encodeComponent(departureId)}/availability')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final p = body['addOnPrices'] as Map<String, dynamic>? ?? const {};
        return p.map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>()));
      }
    } catch (_) {}
    return null;
  }

  /// Laveste pris pr. dag fra Core (/api/pricing/lowest – TideRMS-priser via Core).
  /// Nøgle = dato (YYYY-MM-DD), værdi = pris i DKK eller null (ingen pris den dag). null hvis Core ikke kan nås.
  Future<Map<String, double?>?> fetchLowestPrices({required String routeId, required String from, required String to}) async {
    try {
      final uri = Uri.parse('$baseUrl/pricing/lowest').replace(queryParameters: {'routeId': routeId, 'from': from, 'to': to});
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final days = body['days'] as List? ?? const [];
        return {
          for (final d in days.whereType<Map>())
            if (d['date'] is String) d['date'] as String: (d['priceDkk'] as num?)?.toDouble(),
        };
      }
    } catch (_) {}
    return null;
  }

  /// Henter en booking fra Core med kundens booking-nøgle (x-booking-token).
  /// Returnerer (booking, null) ved succes, (null, statuskode) når Core afviser, og (null, null) når Core ikke kan nås.
  Future<(BookingModel?, int?)> fetchBooking(String pnr, String bookingToken) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/bookings/${Uri.encodeComponent(pnr.toUpperCase())}'),
        headers: {'Content-Type': 'application/json', 'x-booking-token': bookingToken},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return (BookingModel.fromJson(json, bookingToken: bookingToken), null);
      }
      return (null, res.statusCode);
    } catch (_) {
      return (null, null);
    }
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

      final res = await _client.post(
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
        networkError: true,
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

      final res = await _client.post(
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

  /// Kahytter på en afgang fra Core (id, kategori som BookIT-kode, køjer, om den er optaget).
  /// null hvis Core ikke kan nås eller afviser.
  Future<List<Map<String, dynamic>>?> fetchDepartureCabins(String departureId) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/departures/${Uri.encodeComponent(departureId)}/cabins')).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body is Map ? body['cabins'] : body) as List? ?? const [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return null;
  }

  /// Partnerbilletter: ledige tidspunkter og priser for en dato (Core spørger partneren).
  Future<PartnerAvailability> partnerAvailability(String addOnId, String date) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/addons/${Uri.encodeComponent(addOnId)}/availability?date=$date'))
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body is! Map<String, dynamic>) throw PartnerException(body is Map ? '${body['message'] ?? body['error'] ?? res.statusCode}' : '${res.statusCode}');
    return PartnerAvailability.fromJson(body);
  }

  /// Partnerbilletter: tilbud fra Core (gælder i 15 minutter); bookingen henviser til det med quoteId.
  Future<PartnerQuote> partnerQuote(String addOnId, {required String date, String? time, required Map<String, int> tickets}) async {
    final res = await _client
        .post(Uri.parse('$baseUrl/addons/quote'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({
          'productId': addOnId,
          'visitDate': date,
          'visitTime': ?time,
          'tickets': tickets.entries.where((e) => e.value > 0).map((e) => {'type': e.key, 'quantity': e.value}).toList(),
        }))
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body is! Map<String, dynamic>) throw PartnerException(body is Map ? '${body['message'] ?? body['error'] ?? res.statusCode}' : '${res.statusCode}');
    return PartnerQuote.fromJson(body);
  }

  /// Serverens pris for en bookingkladde (samme beregning som ved betaling).
  /// null hvis Core ikke svarer, eller TideRMS ikke kan prissætte kladden (ok: false).
  Future<double?> quoteTotal(Map<String, dynamic> bookingDraft) async => (await quote(bookingDraft))?.total;

  /// Serverens pris og den afbestillingsforsikring, der kan vælges til (null hvis prisen ikke kan beregnes).
  Future<PriceQuote?> quote(Map<String, dynamic> bookingDraft) async {
    try {
      final res = await _client
          .post(Uri.parse('$baseUrl/pricing/calculate'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(bookingDraft))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['ok'] == false) return null;
        final total = body['totalAmountDkk'] ?? (body['fareBreakdown'] as Map?)?['totalAmountDkk'];
        if (total is! num) return null;
        final offer = body['insuranceOffer'];
        return PriceQuote(total: total.toDouble(), insuranceOffer: offer is Map<String, dynamic> ? InsuranceOffer.fromJson(offer) : null);
      }
    } catch (_) {}
    return null;
  }

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

      final res = await _client.post(
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
      final res = await _client.post(
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
      final res = await _client.post(
        Uri.parse('$baseUrl/integrations/payments/$paymentId/abandon'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Serverens pris for en bookingkladde.
class PriceQuote {
  final double total;
  /// Afbestillingsforsikringen, kunden kan vælge til (null = ingen til rejsen)
  final InsuranceOffer? insuranceOffer;
  const PriceQuote({required this.total, this.insuranceOffer});
}

/// Afbestillingsforsikring (opsat i TideRMS, fx Tryg): fast beløb eller procent af rejsens pris.
class InsuranceOffer {
  final String code;
  final String name;
  final String provider;
  final double priceDkk;
  final String priceType;
  final double? percent;
  final String? per;
  final bool premiumRefundable;
  final String? termsUrl;
  final String? description;

  const InsuranceOffer({required this.code, required this.name, required this.provider, required this.priceDkk, required this.priceType, this.percent, this.per, required this.premiumRefundable, this.termsUrl, this.description});

  factory InsuranceOffer.fromJson(Map<String, dynamic> j) => InsuranceOffer(
        code: '${j['code'] ?? ''}',
        name: '${j['name'] ?? ''}',
        provider: '${j['provider'] ?? ''}',
        priceDkk: (j['priceDkk'] as num?)?.toDouble() ?? 0,
        priceType: '${j['priceType'] ?? 'FIXED'}',
        percent: (j['percent'] as num?)?.toDouble(),
        per: j['per'] as String?,
        premiumRefundable: j['premiumRefundable'] == true,
        termsUrl: j['termsUrl'] as String?,
        description: j['description'] as String?,
      );
}

class PartnerException implements Exception {
  final String message;
  PartnerException(this.message);
  @override
  String toString() => message;
}

/// Ét tidspunkt hos partneren (time = null: hele dagen) med ledige pladser og pris pr. billettype.
class PartnerSlot {
  final String? time;
  final int remaining;
  final Map<String, double> prices;
  final Map<String, String> labels;
  const PartnerSlot({this.time, required this.remaining, required this.prices, required this.labels});
}

class PartnerAvailability {
  final bool requiresTime;
  final List<PartnerSlot> slots;
  final bool simulated;
  const PartnerAvailability({required this.requiresTime, required this.slots, this.simulated = false});

  factory PartnerAvailability.fromJson(Map<String, dynamic> j) => PartnerAvailability(
        requiresTime: j['requiresTime'] == true,
        simulated: j['simulated'] == true,
        slots: ((j['slots'] as List?) ?? const []).whereType<Map>().map((s) {
          final prices = <String, double>{};
          final labels = <String, String>{};
          for (final p in ((s['prices'] as List?) ?? const []).whereType<Map>()) {
            prices['${p['type']}'] = (p['amount'] as num?)?.toDouble() ?? 0;
            labels['${p['type']}'] = '${p['label'] ?? p['type']}';
          }
          return PartnerSlot(time: s['time'] as String?, remaining: (s['remaining'] as num?)?.toInt() ?? 0, prices: prices, labels: labels);
        }).toList(),
      );
}

class PartnerQuote {
  final String quoteId;
  final String visitDate;
  final String? visitTime;
  final double totalPriceDkk;
  final String? notes;
  /// Prisen kommer fra den simulerede test-partner (demo), ikke fra den rigtige partner
  final bool simulated;
  const PartnerQuote({required this.quoteId, required this.visitDate, this.visitTime, required this.totalPriceDkk, this.notes, this.simulated = false});

  factory PartnerQuote.fromJson(Map<String, dynamic> j) => PartnerQuote(
        quoteId: '${j['quoteId']}',
        visitDate: '${j['visitDate']}',
        visitTime: j['visitTime'] as String?,
        totalPriceDkk: (j['totalPriceDkk'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String?,
        simulated: j['simulated'] == true,
      );
}
