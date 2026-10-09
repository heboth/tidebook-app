import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import '../models/route_model.dart';
import '../models/departure_model.dart';
import '../models/booking_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static String get baseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:4000/api';
      }
    } catch (_) {}
    return 'http://localhost:4000/api';
  }

  static String get healthUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:4000/health';
      }
    } catch (_) {}
    return 'http://localhost:4000/health';
  }

  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final res = await http.get(Uri.parse(healthUrl)).timeout(const Duration(seconds: 3));
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

  Future<BookingModel?> lookupBooking(String pnr, String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/bookings/lookup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pnr': pnr, 'email': email}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['booking'] != null) {
          return BookingModel.fromJson(data['booking'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<BookingModel?> checkIn(String pnr) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/bookings/$pnr/check-in'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'legType': 'OUTBOUND'}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return null; // Signals successful backend check-in
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> createBooking(BookingModel booking) async {
    try {
      final payload = {
        'termsAccepted': true,
        'routeId': booking.routeId,
        'departureId': booking.departureId,
        'outboundDate': booking.departureDate,
        'ticketClass': booking.ticketClass,
        'passengers': booking.passengers.map((p) => {
          'id': p.id,
          'firstName': p.firstName,
          'lastName': p.lastName,
          'type': p.type.name.toUpperCase(),
          'nationality': p.nationality,
          'dateOfBirth': '1988-01-01',
        }).toList(),
        'leadContact': {
          'fullName': booking.leadContactName,
          'email': booking.leadContactEmail,
          'phone': booking.leadContactPhone,
        },
        'selectedCabinIds': booking.selectedCabinIds,
        'addOns': booking.addOns,
        'paymentStatus': 'PAID',
      };

      final res = await http.post(
        Uri.parse('$baseUrl/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
