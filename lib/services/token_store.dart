import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gemmer kundens booking-nøgler (PNR → bookingToken) mellem app-starter.
abstract class BookingTokenStore {
  Future<Map<String, String>> readAll();
  Future<void> writeAll(Map<String, String> tokens);
}

/// Booking-nøglerne giver adgang til bookingen i Core og ligger derfor i iOS Keychain /
/// Android Keystore via flutter_secure_storage – ikke i almindelige præferencer.
class SecureBookingTokenStore implements BookingTokenStore {
  SecureBookingTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'tidebook.bookingTokens';
  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is String && (e.value as String).isNotEmpty) e.key.toString(): e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> writeAll(Map<String, String> tokens) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(tokens));
    } catch (_) {
      // Kan nøglerne ikke gemmes, virker appen stadig i denne session
    }
  }
}

/// Til tests og platforme uden sikker lagring: kun i hukommelsen.
class MemoryBookingTokenStore implements BookingTokenStore {
  MemoryBookingTokenStore([Map<String, String>? initial]) : tokens = {...?initial};
  final Map<String, String> tokens;

  @override
  Future<Map<String, String>> readAll() async => {...tokens};

  @override
  Future<void> writeAll(Map<String, String> t) async {
    tokens
      ..clear()
      ..addAll(t);
  }
}
