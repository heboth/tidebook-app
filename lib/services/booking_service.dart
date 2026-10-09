import 'package:flutter/foundation.dart';
import '../models/route_model.dart';
import '../models/departure_model.dart';
import '../models/booking_model.dart';
import 'api_service.dart';
import 'seed_data.dart';

class BookingLookupResult {
  final bool success;
  final String? errorMessage;
  final BookingModel? booking;

  const BookingLookupResult({
    required this.success,
    this.errorMessage,
    this.booking,
  });
}

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
  BookingModel? _activeBooking;
  bool _isBackendConnected = false;

  List<RouteModel> get routes => List.unmodifiable(_routes);
  List<DepartureModel> get departures => List.unmodifiable(_departures);
  List<BookingModel> get bookings => List.unmodifiable(_bookings);
  BookingModel? get activeBooking => _activeBooking;
  bool get isBackendConnected => _isBackendConnected;

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

  /// Lookup booking with PNR and Email / Last Name (checks live TideRMS backend + local cache)
  Future<BookingLookupResult> lookupBooking({
    required String pnr,
    required String emailOrLastName,
  }) async {
    final cleanPnr = pnr.trim().toUpperCase();
    final cleanIdentifier = emailOrLastName.trim().toLowerCase();

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

    // 1. Check live TideRMS / TideBook Backend on port 4000
    try {
      final remoteBooking = await ApiService().lookupBooking(cleanPnr, cleanIdentifier);
      if (remoteBooking != null) {
        final existingIdx = _bookings.indexWhere((b) => b.pnr == remoteBooking.pnr);
        if (existingIdx != -1) {
          _bookings[existingIdx] = remoteBooking;
        } else {
          _bookings.insert(0, remoteBooking);
        }
        _activeBooking = remoteBooking;
        notifyListeners();
        return BookingLookupResult(success: true, booking: remoteBooking);
      }
    } catch (_) {}

    // 2. Fallback to local cached / seed list
    try {
      final match = _bookings.firstWhere((b) {
        final matchesPnr = b.pnr.toUpperCase() == cleanPnr ||
            b.bookingCode.toUpperCase() == cleanPnr;
        if (!matchesPnr) return false;

        final matchesEmail =
            b.leadContactEmail.toLowerCase() == cleanIdentifier;
        final lastName = b.leadContactName.split(' ').last.toLowerCase();
        final matchesLastName = lastName == cleanIdentifier;

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

  /// Perform Mobile Check-In with Backend sync
  Future<bool> checkInBooking(String pnr) async {
    try {
      await ApiService().checkIn(pnr);
    } catch (_) {}

    final index = _bookings.indexWhere((b) => b.pnr == pnr);
    if (index != -1) {
      final updated = _bookings[index].copyWith(status: 'CHECKED_IN');
      _bookings[index] = updated;
      if (_activeBooking?.pnr == pnr) {
        _activeBooking = updated;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Add newly completed booking and register with TideRMS on port 4000
  Future<void> addBooking(BookingModel newBooking) async {
    _bookings.insert(0, newBooking);
    _activeBooking = newBooking;
    notifyListeners();

    try {
      await ApiService().createBooking(newBooking);
    } catch (_) {}
  }
}
