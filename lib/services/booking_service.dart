import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import '../models/departure_model.dart';
import '../models/booking_model.dart';
import 'api_service.dart';
import 'seed_data.dart';

class BookingService extends ChangeNotifier {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal() {
    _routes.addAll(SeedData.getRoutes());
    _departures.addAll(SeedData.getDepartures());
    _bookings.addAll(SeedData.getInitialBookings());
    if (_bookings.isNotEmpty) {
      _activeBooking = _bookings.first;
    }
    syncBackend();
  }

  final List<RouteModel> _routes = [];
  final List<DepartureModel> _departures = [];
  final List<BookingModel> _bookings = [];
  final Map<String, String> _bookingTokens = {};
  BookingModel? _activeBooking;
  bool _isBackendConnected = false;

  List<RouteModel> get routes => List.unmodifiable(_routes);
  List<DepartureModel> get departures => List.unmodifiable(_departures);
  List<BookingModel> get bookings => List.unmodifiable(_bookings);
  BookingModel? get activeBooking => _activeBooking;
  bool get isBackendConnected => _isBackendConnected;

  String? getBookingToken(String pnr) => _bookingTokens[pnr.trim().toUpperCase()];

  void setBookingToken(String pnr, String token) {
    _bookingTokens[pnr.trim().toUpperCase()] = token;
  }

  Future<void> syncBackend() async {
    try {
      final health = await ApiService().checkHealth();
      if (health != null && health['status'] == 'UP') {
        _isBackendConnected = true;
      }
      final remoteRoutes = await ApiService().fetchRoutes();
      if (remoteRoutes != null && remoteRoutes.isNotEmpty) {
        _routes.clear();
        _routes.addAll(remoteRoutes);
      }
      final remoteDepartures = await ApiService().fetchDepartures();
      if (remoteDepartures != null && remoteDepartures.isNotEmpty) {
        _departures.clear();
        _departures.addAll(remoteDepartures);
      }
      notifyListeners();
    } catch (_) {}
  }

  void setActiveBooking(BookingModel? b) {
    _activeBooking = b;
    notifyListeners();
  }

  /// Remember booking and its customer booking key
  void rememberBooking(BookingModel booking, [String? token]) {
    final effectiveToken = token ?? booking.bookingToken;
    final cleanPnr = booking.pnr.trim().toUpperCase();
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      _bookingTokens[cleanPnr] = effectiveToken;
    }
    final existingIdx = _bookings.indexWhere((b) => b.pnr.toUpperCase() == cleanPnr);
    final stored = booking.copyWith(bookingToken: effectiveToken);
    if (existingIdx != -1) {
      _bookings[existingIdx] = stored;
    } else {
      _bookings.insert(0, stored);
    }
    _activeBooking = stored;
    notifyListeners();
  }

  /// Lookup booking with PNR and Email / Last Name (checks live Core backend + local cache)
  Future<BookingLookupResult> lookupBooking({
    required String pnr,
    required String emailOrLastName,
  }) async {
    final cleanPnr = pnr.trim().toUpperCase();
    final cleanIdentifier = emailOrLastName.trim();

    // Rejection of Group leader reservation
    if (cleanPnr.startsWith('TB-GRP') || cleanPnr.contains('GRP')) {
      return const BookingLookupResult(
        success: false,
        errorMessage:
            'Adgang nægtet: Gruppe-reservationer (GRP) kan ikke åbnes i denne passager-app. Kontakt din gruppeleder.',
      );
    }

    // Rejection of Online Agent (OA) / B2B reservation
    if (cleanPnr.startsWith('FG-DF') || cleanPnr.startsWith('OTA-')) {
      return const BookingLookupResult(
        success: false,
        errorMessage:
            'Adgang nægtet: Denne booking er administreret af et Online Agentur (OA). Kontakt rejsebureauet for ændringer.',
      );
    }

    // 1. Check live Core Backend on port 4000
    try {
      final res = await ApiService().lookupBooking(cleanPnr, cleanIdentifier);
      if (res.success && res.booking != null) {
        if (res.bookingToken != null) {
          _bookingTokens[cleanPnr] = res.bookingToken!;
        }
        rememberBooking(res.booking!, res.bookingToken);
        return res;
      } else if (!res.success && res.errorMessage != null && !res.errorMessage!.contains('Kunne ikke forbinde')) {
        return res;
      }
    } catch (_) {}

    // 2. Fallback to local cached / seed list (offline / mock)
    try {
      final match = _bookings.firstWhere((b) {
        final matchesPnr = b.pnr.toUpperCase() == cleanPnr ||
            b.bookingCode.toUpperCase() == cleanPnr;
        if (!matchesPnr) return false;

        final matchesEmail =
            b.leadContactEmail.toLowerCase() == cleanIdentifier.toLowerCase();
        final lastName = b.leadContactName.split(' ').last.toLowerCase();
        final matchesLastName = lastName == cleanIdentifier.toLowerCase();

        return matchesEmail || matchesLastName;
      });

      _activeBooking = match;
      notifyListeners();
      return BookingLookupResult(success: true, booking: match);
    } catch (_) {
      return const BookingLookupResult(
        success: false,
        errorMessage:
            'Ingen booking fundet for de angivne oplysninger. Tjek venligst dit bookingnummer samt e-mail eller efternavn.',
      );
    }
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
