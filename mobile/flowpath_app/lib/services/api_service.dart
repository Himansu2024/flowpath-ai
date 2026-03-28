// lib/services/api_service.dart
// HTTP client for all FlowPath backend REST API calls.
// Uses Dio for automatic token injection, retry, and timeout handling.

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late final Dio _dio;

  // Base URL — change this to your deployed AWS CloudFront URL in production
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1', // Android emulator → localhost
  );

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    // Interceptor: auto-inject JWT Bearer token on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        // 401 = token expired — clear and redirect to login
        if (err.response?.statusCode == 401) {
          _clearToken();
        }
        handler.next(err);
      },
    ));
  }

  // ── Auth ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register(String email, String password, String fullName) async {
    final resp = await _dio.post('/auth/register', data: {
      'email': email, 'password': password, 'fullName': fullName,
    });
    if (resp.data['token'] != null) await _saveToken(resp.data['token']);
    return resp.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _dio.post('/auth/login', data: {
      'email': email, 'password': password,
    });
    if (resp.data['token'] != null) await _saveToken(resp.data['token']);
    return resp.data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final resp = await _dio.get('/auth/me');
    return resp.data;
  }

  Future<void> logout() async => _clearToken();

  // ── Navigation ───────────────────────────────────────────────

  /// Start a navigation session. Returns route + signals + GreenWave plan.
  Future<Map<String, dynamic>> startNavigation({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String vehicleType = 'car',
  }) async {
    final resp = await _dio.post('/navigation/start', data: {
      'startLat': startLat,
      'startLon': startLon,
      'endLat': endLat,
      'endLon': endLon,
      'vehicleType': vehicleType,
    });
    return resp.data;
  }

  /// Send live GPS position. Returns updated speed advice.
  Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lon,
    required double speedKmh,
    required double heading,
    String? routeId,
  }) async {
    final resp = await _dio.post('/vehicle/location', data: {
      'lat': lat, 'lon': lon,
      'speedKmh': speedKmh,
      'heading': heading,
      if (routeId != null) 'routeId': routeId,
    });
    return resp.data;
  }

  /// Get optimal speed for specific signal.
  Future<Map<String, dynamic>> getOptimalSpeed({
    required double lat,
    required double lon,
    required double speed,
    required String signalId,
  }) async {
    final resp = await _dio.get('/optimal-speed', queryParameters: {
      'lat': lat, 'lon': lon, 'speed': speed, 'signalId': signalId,
    });
    return resp.data;
  }

  // ── Signals ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAllSignals({String? city, String? zone, int page = 1}) async {
    final resp = await _dio.get('/signals', queryParameters: {
      if (city != null) 'city': city,
      if (zone != null) 'zone': zone,
      'page': page,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getSignalById(String id) async {
    final resp = await _dio.get('/signal/$id');
    return resp.data;
  }

  Future<Map<String, dynamic>> getNearbySignals({
    required double lat,
    required double lon,
    int radius = 1000,
  }) async {
    final resp = await _dio.get('/signals/nearby', queryParameters: {
      'lat': lat, 'lon': lon, 'radius': radius,
    });
    return resp.data;
  }

  // ── Trip / Eco ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getEcoStats() async {
    final resp = await _dio.get('/eco-stats');
    return resp.data;
  }

  Future<Map<String, dynamic>> getTripHistory({int page = 1, int limit = 20}) async {
    final resp = await _dio.get('/trip-history', queryParameters: {'page': page, 'limit': limit});
    return resp.data;
  }

  // ── Parking ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getParkingNearby({
    required double lat,
    required double lon,
    int radius = 500,
  }) async {
    final resp = await _dio.get('/parking-nearby', queryParameters: {
      'lat': lat, 'lon': lon, 'radius': radius,
    });
    return resp.data;
  }

  // ── Geocoding (Nominatim — free, full India) ─────────────────

  Future<List<Map<String, dynamic>>> geocodeSearch(String query) async {
    final dio2 = Dio();
    final resp = await dio2.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'format': 'json',
        'q': query,
        'limit': 7,
        'countrycodes': 'in',
        'addressdetails': 1,
      },
      options: Options(headers: {'Accept-Language': 'en-IN,en'}),
    );
    return List<Map<String, dynamic>>.from(resp.data);
  }

  Future<Map<String, dynamic>?> reverseGeocode(double lat, double lon) async {
    try {
      final dio2 = Dio();
      final resp = await dio2.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {'format': 'json', 'lat': lat, 'lon': lon},
        options: Options(headers: {'Accept-Language': 'en-IN,en'}),
      );
      return resp.data as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  // ── Token helpers ────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }
}
