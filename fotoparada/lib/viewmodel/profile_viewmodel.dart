import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isSigningOut = false;
  bool get isSigningOut => _isSigningOut;

  String get nombre {
    final nombre = _authService.displayName.trim();
    return nombre.isEmpty ? 'Usuario' : nombre;
  }

  String get email => _authService.currentUser?.email ?? '';

  Future<void> cerrarSesion() async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    notifyListeners();

    try {
      await _authService.signOut();
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }
}
