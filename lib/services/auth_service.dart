import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/booking_model.dart';
import 'api_service.dart';
import 'texts_service.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final UserModel? user;

  const AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
  });
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  String? _activePnr;
  String? _portalToken;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null || _activePnr != null;
  String? get activePnr => _activePnr;
  String? get portalToken => _portalToken;

  Timer? _renewTimer;

  /// Logger kunden ind via Core's /api/auth/portal-login – den eneste måde at logge ind på.
  /// Der er intet offline-login og ingen indbyggede konti: kan Core ikke nås, afvises login.
  Future<AuthResult> loginCustomer({
    required String usernameOrEmail,
    required String password,
  }) async {
    final username = usernameOrEmail.trim();
    final key = username.toLowerCase();

    // Hurtig afvisning med en forklarende tekst – Core afviser i forvejen agent- og gruppekonti
    if (key.contains('agent') ||
        key.contains('direct-ferries') ||
        key.contains('ota') ||
        key.contains('bureau')) {
      return const AuthResult(
        success: false,
        errorMessage:
            'Adgang nægtet: Online Agent (OA) og B2B-konti kan ikke benytte denne app. Benyt venligst Tidebook Agent Portalen.',
      );
    }

    if (key.contains('gruppe') || key.contains('group')) {
      return const AuthResult(
        success: false,
        errorMessage:
            'Adgang nægtet: Gruppeleder-login er ikke tilladt i denne app. Benyt venligst Gruppeleder Portalen på tidebook.io.',
      );
    }

    if (username.isEmpty || password.isEmpty) {
      return AuthResult(success: false, errorMessage: tr('login.invalidCredentials'));
    }

    final res = await ApiService().portalLogin(username, password);
    if (res == null) {
      return AuthResult(success: false, errorMessage: tr('login.coreUnavailable'));
    }
    final token = res['token']?.toString();
    if (res['IsLoggedIn'] != true || token == null || token.isEmpty) {
      return AuthResult(success: false, errorMessage: tr('login.invalidCredentials'));
    }

    _portalToken = token;
    _currentUser = userFromCore(res['user'] is Map ? Map<String, dynamic>.from(res['user'] as Map) : null, username);
    _scheduleRenew(res['expiresInSeconds']);
    notifyListeners();
    return AuthResult(success: true, user: _currentUser);
  }

  /// Bygger kundeprofilen ud fra Core's svar. Mangler navnet, bruges e-mailen (eller brugernavnet) –
  /// der opfindes ingen navne eller stamdata.
  static UserModel userFromCore(Map<String, dynamic>? user, String loginName) {
    final email = user?['email']?.toString() ?? (loginName.contains('@') ? loginName : '');
    final fullName = (user?['fullName']?.toString() ?? '').trim();
    return UserModel(
      id: user?['id']?.toString() ?? '',
      username: user?['username']?.toString() ?? loginName,
      email: email,
      fullName: fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : loginName),
      role: UserRole.person,
    );
  }

  /// Fornyer tokenet hos Core (/api/auth/portal-renew) et minut før det udløber.
  void _scheduleRenew(Object? expiresInSeconds) {
    _renewTimer?.cancel();
    final seconds = expiresInSeconds is num ? expiresInSeconds.toInt() : 0;
    if (seconds <= 0) return;
    final delay = Duration(seconds: seconds > 120 ? seconds - 60 : seconds ~/ 2);
    _renewTimer = Timer(delay, () => renewSession());
  }

  /// Fornyer kundens session hos Core. Afviser Core fornyelsen, logges kunden ud.
  /// Kan Core ikke nås, beholdes sessionen og der prøves igen om lidt.
  Future<bool> renewSession() async {
    final token = _portalToken;
    if (token == null) return false;
    final res = await ApiService().portalRenew(token);
    if (res == null) {
      _renewTimer?.cancel();
      _renewTimer = Timer(const Duration(minutes: 1), () => renewSession());
      return false;
    }
    final newToken = res['token']?.toString();
    if (res['IsLoggedIn'] == true && newToken != null && newToken.isNotEmpty) {
      _portalToken = newToken;
      _scheduleRenew(res['expiresInSeconds']);
      return true;
    }
    logout();
    return false;
  }

  /// Direct session login via PNR booking reference
  void setBookingSession(BookingModel booking) {
    // Verify it is not a Group or Agent booking
    if (!booking.isDirectCustomer || booking.pnr.startsWith('TB-GRP')) {
      throw Exception(
        'Gruppe- og rejsebureaubookinger kan ikke administreres her.',
      );
    }
    _activePnr = booking.pnr;
    _currentUser = UserModel(
      id: 'USR-PNR-${booking.pnr}',
      username: booking.leadContactEmail,
      email: booking.leadContactEmail,
      fullName: booking.leadContactName,
      role: UserRole.person,
    );
    notifyListeners();
  }

  void updateProfile(UserModel updatedUser) {
    _currentUser = updatedUser;
    notifyListeners();
  }

  void logout() {
    _renewTimer?.cancel();
    _renewTimer = null;
    _currentUser = null;
    _activePnr = null;
    _portalToken = null;
    notifyListeners();
  }
}
