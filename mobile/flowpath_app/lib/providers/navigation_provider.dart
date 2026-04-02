// lib/providers/navigation_provider.dart
// Complete navigation state management with GPS, rerouting, voice, and eco tracking

import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../models/signal_model.dart';
import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  final ApiService   apiService;
  final SocketService socketService;
  final FlutterTts   _tts = FlutterTts();

  // ── Location state ───────────────────────────────────────────
  LatLng? userLocation;
  LatLng? destination;
  double  heading       = 0;
  double  currentSpeedKmh = 0;

  // ── Route state ──────────────────────────────────────────────
  List<LatLng>   routePoints = [];
  List<SignalModel> signals  = [];
  SignalModel?   nextSignal;
  Map<String, dynamic>? currentOptimization;
  String? routeId;
  bool    isNavigating = false;

  // ── Trip metrics ─────────────────────────────────────────────
  double distanceKm    = 0;
  int    etaMinutes    = 0;
  int    timeSavedMinutes = 0;
  double greenwaveScore   = 0;

  // ── Eco metrics ──────────────────────────────────────────────
  double fuelSavedL   = 0;
  double co2SavedKg   = 0;
  int    stopsAvoided = 0;
  int    streakCount  = 0;

  // ── Internals ────────────────────────────────────────────────
  MapController?              _mapController;
  StreamSubscription<Position>? _positionStream;
  Timer?                      _locationTimer;
  String?                     _lastSpokenAdvice;

  // ── Simulation Internals ─────────────────────────────────────
  Timer? _simTimer;
  int _simIndex = 0;

  NavigationProvider({required this.apiService, required this.socketService}) {
    _initTts();
    _setupSocketListeners();
  }

  // ── TTS setup ────────────────────────────────────────────────
  Future<void> _initTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.95);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text, {bool priority = false}) async {
    if (priority) await _tts.stop();
    await _tts.speak(text);
  }

  // ── Socket listeners ─────────────────────────────────────────
  void _setupSocketListeners() {
    socketService.onSignalsUpdate((data) {
      final updated = (data['signals'] as List? ?? [])
          .map((s) => SignalModel.fromJson(Map<String, dynamic>.from(s)))
          .toList();

      // Merge with existing signals (preserve distance data)
      signals = updated.map((u) {
        final existing = signals.firstWhere((e) => e.id == u.id, orElse: () => u);
        return u.copyWith(distanceFromUser: existing.distanceFromUser);
      }).toList();

      _updateNextSignal();
      notifyListeners();
    });

    socketService.onCongestionAlert((data) {
      speak('Traffic alert: ${data['message'] ?? 'Congestion detected ahead'}');
    });

    socketService.onRerouting((_) {
      if (isNavigating && userLocation != null && destination != null) {
        speak('Off route. Recalculating.', priority: true);
        calcAndStartRoute();
      }
    });
  }

  // ── GPS Tracking ─────────────────────────────────────────────
  void startTracking(MapController controller) {
    _mapController = controller;
    _requestPermissionAndTrack();
  }

  Future<void> _requestPermissionAndTrack() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied');
      return;
    }
    _startPositionStream();
  }

  void _startPositionStream() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 3,
      ),
    ).listen((pos) {
      // If the simulator is running, IGNORE real GPS!
      if (_simTimer != null && _simTimer!.isActive) return;

      userLocation     = LatLng(pos.latitude, pos.longitude);
      heading          = pos.heading;
      currentSpeedKmh  = ((pos.speed * 3.6).clamp(0, 200)).toDouble();

      // Follow user while navigating
      final loc = userLocation;
      if (isNavigating && _mapController != null && loc != null) {
        final controller = _mapController!;
        controller.move(loc, controller.camera.zoom);
      }

      // Emit to Socket.IO for admin dashboard
      socketService.emitLocation(
        lat: pos.latitude,
        lon: pos.longitude,
        speedKmh: currentSpeedKmh,
        heading: heading,
        routeId: routeId,
      );

      notifyListeners();
    }, onError: (error) {
      debugPrint("GPS Stream Error: $error");
    });
  }

  // ── Location update (REST) ───────────────────────────────────
  Future<void> updateLocation() async {
    if (userLocation == null || !isNavigating) return;
    try {
      final resp = await apiService.updateLocation(
        lat:      userLocation!.latitude,
        lon:      userLocation!.longitude,
        speedKmh: currentSpeedKmh,
        heading:  heading,
        routeId:  routeId,
      );
      final advice = resp['data']?['speedAdvice'];
      if (advice != null) {
        currentOptimization = Map<String, dynamic>.from(advice);
        _speakAdviceIfNew(advice['adviceText'] as String? ?? '');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('updateLocation error: $e');
    }
  }

  void _speakAdviceIfNew(String text) {
    if (text.isNotEmpty && text != _lastSpokenAdvice) {
      _lastSpokenAdvice = text;
      speak(text);
    }
  }

  // ── Search ───────────────────────────────────────────────────
  Future<void> searchDestination(String query) async {
    if (query.isEmpty) return;
    try {
      final results = await apiService.geocodeSearch(query);
      if (results.isNotEmpty) {
        final place = results.first;
        destination = LatLng(
          double.parse(place['lat'].toString()),
          double.parse(place['lon'].toString()),
        );
        await calcAndStartRoute();
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void setDestinationFromTap(LatLng point) {
    destination = point;
    calcAndStartRoute();
  }

  // ── Route calculation ────────────────────────────────────────
  Future<void> calcAndStartRoute() async {
    if (destination == null) return;

    final startLoc = userLocation ?? const LatLng(12.9716, 77.5946);

    try {
      final resp = await apiService.startNavigation(
        startLat: startLoc.latitude,
        startLon: startLoc.longitude,
        endLat:   destination!.latitude,
        endLon:   destination!.longitude,
      );

      final data = resp['data'] as Map<String, dynamic>;
      routeId       = data['routeId'] as String?;
      etaMinutes    = (data['route']?['durationMinutes'] ?? 0) as int;
      distanceKm    = double.tryParse(data['route']?['distanceKm']?.toString() ?? '0') ?? 0;
      timeSavedMinutes = (etaMinutes * 0.3).round();
      greenwaveScore   = double.tryParse(data['greenwaveScore']?.toString() ?? '0') ?? 0;

      final coords = (data['route']?['geometry']?['coordinates'] as List? ?? []);
      routePoints  = coords.map((c) => LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      )).toList();

      // Fetch the LIVE signals computed by PostGIS on your backend
      final rawSignals = data['signals'] as List? ?? [];
      signals = rawSignals.map((s) => SignalModel.fromJson(Map<String, dynamic>.from(s))).toList();

      isNavigating = true;

      await WakelockPlus.enable();

      _locationTimer?.cancel();
      _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) => updateLocation());

      socketService.joinNavigation(routeId ?? '', userId: null);

      if (routePoints.isNotEmpty && _mapController != null) {
        final bounds = LatLngBounds.fromPoints(routePoints);
        _mapController!.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
      }

      _updateNextSignal();
      notifyListeners();

      speak(
        'Navigation started. ${distanceKm.toStringAsFixed(1)} kilometres. '
        'Estimated $etaMinutes minutes.',
        priority: true,
      );
    } catch (e) {
      debugPrint('Route calculation error: $e');
    }
  }

  // ── Signal helpers ───────────────────────────────────────────
  void _updateNextSignal() {
    if (signals.isEmpty) return;
    nextSignal = signals.first;

    if (nextSignal?.willCatchGreen == true) {
      stopsAvoided++;
      streakCount++;
      fuelSavedL   += 0.045;  
      co2SavedKg   += 0.105;  
    } else {
      streakCount = 0;
    }
  }

  // ── Map controls ─────────────────────────────────────────────
  void centerOnUser() {
    if (userLocation != null && _mapController != null) {
      _mapController!.move(userLocation!, 16);
    }
  }

  // ── Parking ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> findNearbyParking() async {
    final loc = destination ?? userLocation;
    if (loc == null) return [];
    try {
      final resp = await apiService.getParkingNearby(lat: loc.latitude, lon: loc.longitude);
      return List<Map<String, dynamic>>.from(resp['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  // ── Share route ──────────────────────────────────────────────
  void shareRoute() {
    if (userLocation == null || destination == null) return;
    final url =
        'https://maps.google.com/maps?saddr=${userLocation!.latitude},${userLocation!.longitude}'
        '&daddr=${destination!.latitude},${destination!.longitude}';
    Share.share(url, subject: 'FlowPath AI Navigation');
  }

  // ── SIMULATION MODE (For testing at desk) ────────────────────
  void startSimulation() {
    if (routePoints.isEmpty) return;
    _simIndex = 0;
    _simTimer?.cancel();
    
    speak('Simulation started. Enjoy the ride.', priority: true);

    _simTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (_simIndex >= routePoints.length - 1) {
        timer.cancel();
        speak('You have arrived at your destination.', priority: true);
        return;
      }

      final current = routePoints[_simIndex];
      final next = routePoints[_simIndex + 1];
      
      userLocation = current;
      currentSpeedKmh = 42.0; 
      
      heading = const Distance().bearing(current, next);

      if (_mapController != null) {
        _mapController!.move(current, 17.5);
      }
      
      notifyListeners();
      _simIndex += 2; 
    });
  }

  // ── Stop navigation ──────────────────────────────────────────
  Future<void> stopNavigation() async {
    isNavigating = false;
    routePoints  = [];
    signals      = [];
    nextSignal   = null;
    routeId      = null;
    
    _simTimer?.cancel(); // Stop the ghost car!
    _locationTimer?.cancel();
    
    await WakelockPlus.disable();
    await _tts.stop();
    notifyListeners();
  }

  // ── Cleanup ──────────────────────────────────────────────────
  void stopTracking() {
    _positionStream?.cancel();
    _locationTimer?.cancel();
    _simTimer?.cancel();
  }

  @override
  void dispose() {
    stopTracking();
    _tts.stop();
    super.dispose();
  }
}