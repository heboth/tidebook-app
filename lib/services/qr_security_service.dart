import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrSecurityService {
  static const String maritimeGateSalt = 'TIDEBOOK-GATE-AUTH-SEC-2026-NORDIC-PASS';

  /// Generates real cryptographic SHA-256 security checksum matching TideBook Gate Scanners
  static String generateSecurityCode({
    required String pnr,
    required String date,
    String? passengerId,
    String? cabin,
  }) {
    final raw = '$pnr|${passengerId ?? "P1"}|$date|${cabin ?? ""}|$maritimeGateSalt';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }

  /// Builds standardized maritime terminal scannable gate payload
  static String buildPayload({
    required String pnr,
    required String date,
    String? passengerId,
    String? cabin,
  }) {
    final secCode = generateSecurityCode(
      pnr: pnr,
      date: date,
      passengerId: passengerId,
      cabin: cabin,
    );
    final pid = passengerId ?? 'P1';
    return 'TB:$pnr:$pid:$date:$secCode';
  }
}
