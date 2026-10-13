import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import '../models/booking_model.dart';
import 'api_service.dart';
import 'texts_service.dart';
import 'token_store.dart';

/// Kundens bookinger og ruterne. Alt kommer fra TideBook Core – appen har ingen indbyggede
/// ruter, afgange eller bookinger og starter tom.
class BookingService extends ChangeNotifier {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final List<RouteModel> _routes = [];
  final List<BookingModel> _bookings = [];
  final Map<String, String> _bookingTokens = {};
  BookingModel? _activeBooking;
  bool _isBackendConnected = false;
  bool _routesLoading = false;
  bool _routesFailed = false;

  /// Indtil init() er kaldt (fra main), gemmes nøglerne kun i hukommelsen – det gælder også tests
  BookingTokenStore _tokenStore = MemoryBookingTokenStore();

  List<RouteModel> get routes => List.unmodifiable(_routes);
  List<BookingModel> get bookings => List.unmodifiable(_bookings);
  BookingModel? get activeBooking => _activeBooking;
  bool get isBackendConnected => _isBackendConnected;
  bool get routesLoading => _routesLoading;

  /// Sand, når ruterne ikke kunne hentes fra Core (vis fejl + prøv igen)
  bool get routesFailed => _routesFailed;

  String? getBookingToken(String pnr) => _bookingTokens[pnr.trim().toUpperCase()];

  void setBookingToken(String pnr, String token) {
    _bookingTokens[pnr.trim().toUpperCase()] = token;
    _persistTokens();
  }

  /// Kaldes én gang ved app-start: indlæser de gemte booking-nøgler, henter bookingerne fra Core
  /// og ruterne.
  Future<void> init({BookingTokenStore? tokenStore}) async {
    if (tokenStore != null) _tokenStore = tokenStore;
    await Future.wait([loadStoredBookings(), syncBackend()]);
  }

  /// Til tests: nulstil alt (tom app) og brug en given nøglelagring.
  @visibleForTesting
  void resetForTest({BookingTokenStore? tokenStore}) {
    _routes.clear();
    _bookings.clear();
    _bookingTokens.clear();
    _activeBooking = null;
    _isBackendConnected = false;
    _routesLoading = false;
    _routesFailed = false;
    _tokenStore = tokenStore ?? MemoryBookingTokenStore();
  }

  Future<void> _persistTokens() => _tokenStore.writeAll(Map.of(_bookingTokens));

  /// Henter kundens bookinger fra Core med de gemte booking-nøgler. Afviser Core en nøgle
  /// (udløbet/ugyldig), glemmes den. Kan Core ikke nås, beholdes nøglerne til næste forsøg.
  Future<void> loadStoredBookings() async {
    final stored = await _tokenStore.readAll();
    if (stored.isEmpty) return;
    _bookingTokens.addAll(stored.map((k, v) => MapEntry(k.toUpperCase(), v)));
    var changed = false;
    for (final entry in stored.entries) {
      final (booking, status) = await ApiService().fetchBooking(entry.key, entry.value);
      if (booking != null && accessDenialFor(booking) == null) {
        _upsert(booking.copyWith(bookingToken: entry.value));
      } else if (status == 401 || status == 403 || status == 404 || booking != null) {
        _bookingTokens.remove(entry.key.toUpperCase());
        changed = true;
      }
    }
    if (changed) await _persistTokens();
    if (_activeBooking == null && _bookings.isNotEmpty) _activeBooking = _bookings.first;
    notifyListeners();
  }

  /// Henter ruterne fra Core.
  Future<void> syncBackend() async {
    _routesLoading = true;
    _routesFailed = false;
    notifyListeners();
    final health = await ApiService().checkHealth();
    _isBackendConnected = health != null && health['status'] == 'UP';
    final remoteRoutes = await ApiService().fetchRoutes();
    if (remoteRoutes != null) {
      _routes
        ..clear()
        ..addAll(remoteRoutes.where((r) => r.id.isNotEmpty));
    } else {
      _routesFailed = true;
    }
    _routesLoading = false;
    notifyListeners();
  }

  void setActiveBooking(BookingModel? b) {
    _activeBooking = b;
    notifyListeners();
  }

  void _upsert(BookingModel stored) {
    final cleanPnr = stored.pnr.trim().toUpperCase();
    final existingIdx = _bookings.indexWhere((b) => b.pnr.toUpperCase() == cleanPnr);
    if (existingIdx != -1) {
      _bookings[existingIdx] = stored;
    } else {
      _bookings.insert(0, stored);
    }
  }

  /// Remember booking and its customer booking key
  void rememberBooking(BookingModel booking, [String? token]) {
    final effectiveToken = token ?? booking.bookingToken;
    final cleanPnr = booking.pnr.trim().toUpperCase();
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      _bookingTokens[cleanPnr] = effectiveToken;
      _persistTokens();
    }
    final stored = booking.copyWith(bookingToken: effectiveToken);
    _upsert(stored);
    _activeBooking = stored;
    notifyListeners();
  }

  static const _groupDenied =
      'Adgang nægtet: Gruppe-reservationer (GRP) kan ikke åbnes i denne passager-app. Kontakt din gruppeleder.';
  static const _agentDenied =
      'Adgang nægtet: Denne booking er administreret af et Online Agentur (OA). Kontakt rejsebureauet for ændringer.';

  /// Må bookingen åbnes i passager-appen? Returnerer afvisningsteksten eller null.
  /// Core's `channel` (og `isGroupBooking`) afgør det; kun når Core ikke sender en kanal,
  /// bruges de gamle PNR-præfiksregler som reserve.
  static String? accessDenialFor(BookingModel booking) {
    if (booking.isGroupBooking) return _groupDenied;
    final channel = booking.channel?.toUpperCase();
    if (channel != null && channel.isNotEmpty) {
      if (channel == 'AGENT' || channel == 'OTA') return _agentDenied;
      return null;
    }
    if (!booking.isDirectCustomer) return _agentDenied;
    return pnrPrefixDenial(booking.pnr);
  }

  /// Reserveregel uden kanal fra Core: PNR-præfikser for gruppe- og bureaubookinger.
  static String? pnrPrefixDenial(String pnr) {
    final cleanPnr = pnr.trim().toUpperCase();
    if (cleanPnr.startsWith('TB-GRP') || cleanPnr.contains('GRP')) return _groupDenied;
    if (cleanPnr.startsWith('FG-DF') || cleanPnr.startsWith('OTA-')) return _agentDenied;
    return null;
  }

  /// Slår en booking op i Core med PNR og e-mail/efternavn. Der er ingen lokal reserve:
  /// kan Core ikke nås, vises en fejl.
  Future<BookingLookupResult> lookupBooking({
    required String pnr,
    required String emailOrLastName,
  }) async {
    final cleanPnr = pnr.trim().toUpperCase();
    final cleanIdentifier = emailOrLastName.trim();

    final res = await ApiService().lookupBooking(cleanPnr, cleanIdentifier);
    if (res.networkError) {
      return BookingLookupResult(
        success: false,
        networkError: true,
        errorMessage: tr('myBookings.lookupUnavailable'),
      );
    }
    if (!res.success || res.booking == null) {
      return BookingLookupResult(
        success: false,
        errorMessage: res.errorMessage ?? tr('myBookings.notFound'),
      );
    }

    final denial = accessDenialFor(res.booking!);
    if (denial != null) {
      return BookingLookupResult(success: false, errorMessage: denial);
    }

    rememberBooking(res.booking!, res.bookingToken);
    return res;
  }

  /// Perform Mobile Check-In with Core Backend verification and error handling
  Future<CheckInResponse> checkInBookingWithResult(
    String pnr, {
    String legType = 'OUTBOUND',
  }) async {
    final cleanPnr = pnr.trim().toUpperCase();
    final token = _bookingTokens[cleanPnr] ??
        (_bookings.any((b) => b.pnr.toUpperCase() == cleanPnr)
            ? _bookings.firstWhere((b) => b.pnr.toUpperCase() == cleanPnr).bookingToken
            : null);

    final res = await ApiService().checkIn(cleanPnr, bookingToken: token, legType: legType);

    if (res.success) {
      final index = _bookings.indexWhere((b) => b.pnr.toUpperCase() == cleanPnr);
      if (index != -1) {
        final current = _bookings[index];
        final updated = (res.booking ?? current).copyWith(
          status: 'CHECKED_IN',
          boardingPasses: res.boardingPasses.isNotEmpty ? res.boardingPasses : current.boardingPasses,
        );
        _bookings[index] = updated;
        if (_activeBooking?.pnr.toUpperCase() == cleanPnr) {
          _activeBooking = updated;
        }
        notifyListeners();
        return CheckInResponse(success: true, booking: updated, boardingPasses: updated.boardingPasses);
      }
      return res;
    } else {
      // Check-in was rejected by Core or network failed.
      // NEVER pretend success when Core says no!
      return res;
    }
  }

  /// Convenience boolean method for backward compatibility
  Future<bool> checkInBooking(String pnr) async {
    final res = await checkInBookingWithResult(pnr);
    return res.success;
  }

  /// Add newly completed booking and register token
  void addBooking(BookingModel newBooking, [String? token]) {
    rememberBooking(newBooking, token);
  }
}
