/// TideBook Maritime QR Helper Service
///
/// Boarding pass QR codes are generated and cryptographically signed exclusively
/// by TideBook Core during mobile check-in (POST /api/bookings/:pnr/check-in).
/// The client application NEVER stores gate secrets or manufactures boarding passes locally.
class QrSecurityService {
  /// Extracts the gate security code (HMAC / checksum) from Core's official QR payload.
  /// Core payload format: `TB:<pnr>:<passengerId>:<hmac>`
  static String? extractSecurityCode(String? qrPayload) {
    if (qrPayload == null || qrPayload.isEmpty) return null;
    final clean = qrPayload.trim();
    if (clean.toUpperCase().startsWith('TB:')) {
      final parts = clean.split(':');
      if (parts.length >= 4) {
        return parts.sublist(3).join(':').toUpperCase();
      }
    }
    return null;
  }

  /// Extracts passenger ID from Core's official QR payload.
  static String? extractPassengerId(String? qrPayload) {
    if (qrPayload == null || qrPayload.isEmpty) return null;
    final clean = qrPayload.trim();
    if (clean.toUpperCase().startsWith('TB:')) {
      final parts = clean.split(':');
      if (parts.length >= 3) {
        return parts[2];
      }
    }
    return null;
  }

  /// Extracts PNR from Core's official QR payload.
  static String? extractPnr(String? qrPayload) {
    if (qrPayload == null || qrPayload.isEmpty) return null;
    final clean = qrPayload.trim();
    if (clean.toUpperCase().startsWith('TB:')) {
      final parts = clean.split(':');
      if (parts.length >= 2) {
        return parts[1].toUpperCase();
      }
    }
    return null;
  }

  /// Checks whether a QR payload matches Core's signed maritime boarding pass format.
  static bool isValidBoardingPassPayload(String? qrPayload) {
    if (qrPayload == null || qrPayload.isEmpty) return false;
    final clean = qrPayload.trim();
    if (!clean.toUpperCase().startsWith('TB:')) return false;
    final parts = clean.split(':');
    return parts.length >= 4 && parts[1].isNotEmpty && parts[2].isNotEmpty && parts[3].isNotEmpty;
  }
}

