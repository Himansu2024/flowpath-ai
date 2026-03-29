// lib/providers/auth_provider.dart
// Authentication state management using ChangeNotifier + SharedPreferences.

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading  = false;
  bool _isLoggedIn = false;
  String? _error;
  Map<String, dynamic>? _user;

  bool get isLoading  => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get error   => _error;
  Map<String, dynamic>? get user => _user;
  String? get userId => _user?['user_id'] as String?;
  String? get userName => _user?['full_name'] as String? ?? _user?['email'] as String?;

  /// Try to restore session from stored JWT token.
  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    try {
      final hasToken = await _api.hasToken();
      if (hasToken) {
        final resp = await _api.getProfile();
        _user = resp['data'];
        _isLoggedIn = true;
      }
    } catch (_) {
      await _api.logout(); // Token invalid — clear it
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _api.login(email, password);
      _user = resp['user'];
      _isLoggedIn = true;
      _error = null;
      return true;
    } catch (e) {
      _error = _extractError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await _api.register(email, password, fullName);
      _user = resp['user'];
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _error = _extractError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('401')) return 'Invalid email or password';
      if (msg.contains('409')) return 'Email already registered';
      if (msg.contains('SocketException')) return 'No internet connection';
    }
    return 'Something went wrong. Please try again.';
  }
}
