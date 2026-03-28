// lib/models/signal_model.dart
// Data model for a traffic signal with current phase state

class SignalModel {
  final String id;
  final String intersectionName;
  final double latitude;
  final double longitude;
  final String currentPhase;      // 'red' | 'yellow' | 'green'
  final int secondsRemaining;
  final int nextGreenIn;
  final int greenDuration;
  final int yellowDuration;
  final int redDuration;
  final int cycleTime;
  final String? roadName;
  final String? city;
  final String? zone;
  final double? distanceFromUser;  // metres — set by app

  // Optional optimization advice from AI engine
  final double? optimalSpeedKmh;
  final String? action;
  final String? adviceText;
  final bool willCatchGreen;

  const SignalModel({
    required this.id,
    required this.intersectionName,
    required this.latitude,
    required this.longitude,
    required this.currentPhase,
    required this.secondsRemaining,
    required this.nextGreenIn,
    required this.greenDuration,
    required this.yellowDuration,
    required this.redDuration,
    required this.cycleTime,
    this.roadName,
    this.city,
    this.zone,
    this.distanceFromUser,
    this.optimalSpeedKmh,
    this.action,
    this.adviceText,
    this.willCatchGreen = false,
  });

  factory SignalModel.fromJson(Map<String, dynamic> json) {
    // Handle nested currentState object (from backend)
    final state = json['currentState'] as Map<String, dynamic>?;
    final opt   = json['optimization'] as Map<String, dynamic>?;

    return SignalModel(
      id:                json['id'] as String? ?? '',
      intersectionName:  json['intersectionName'] as String? ??
                         json['intersection_name'] as String? ?? 'Unknown Signal',
      latitude:          _toDouble(json['latitude'] ?? json['lat']) ?? 0.0,
      longitude:         _toDouble(json['longitude'] ?? json['lon']) ?? 0.0,
      currentPhase:      state?['phase'] as String? ?? json['phase'] as String? ?? 'red',
      secondsRemaining:  _toInt(state?['remaining'] ?? json['secondsRemaining']) ?? 0,
      nextGreenIn:       _toInt(state?['nextGreenIn'] ?? json['nextGreenIn']) ?? 0,
      greenDuration:     _toInt(json['greenDuration']  ?? json['green_duration'])  ?? 45,
      yellowDuration:    _toInt(json['yellowDuration'] ?? json['yellow_duration']) ?? 5,
      redDuration:       _toInt(json['redDuration']    ?? json['red_duration'])    ?? 60,
      cycleTime:         _toInt(json['cycleTime']      ?? json['cycle_time'])      ?? 110,
      roadName:          json['roadName']  as String? ?? json['road_name']  as String?,
      city:              json['city']      as String?,
      zone:              json['zone']      as String?,
      distanceFromUser:  _toDouble(json['distance_metres'] ?? json['distanceMetres']),
      optimalSpeedKmh:   _toDouble(opt?['optimalSpeedKmh']),
      action:            opt?['action'] as String?,
      adviceText:        opt?['adviceText'] as String?,
      willCatchGreen:    opt?['willCatchGreen'] as bool? ?? false,
    );
  }

  /// Returns display text for current phase
  String get phaseDisplay =>
    currentPhase == 'green' ? 'GO' :
    currentPhase == 'yellow' ? 'SLOW' : 'STOP';

  /// Returns colour hex string for current phase
  String get phaseColorHex =>
    currentPhase == 'green'  ? '#00E676' :
    currentPhase == 'yellow' ? '#FFD600' : '#FF1744';

  /// Returns formatted distance string
  String get distanceText {
    if (distanceFromUser == null) return '';
    if (distanceFromUser! < 1000) return '${distanceFromUser!.round()}m';
    return '${(distanceFromUser! / 1000).toStringAsFixed(1)}km';
  }

  SignalModel copyWith({
    String? currentPhase,
    int? secondsRemaining,
    int? nextGreenIn,
    double? distanceFromUser,
    double? optimalSpeedKmh,
    String? action,
    String? adviceText,
    bool? willCatchGreen,
  }) {
    return SignalModel(
      id: id,
      intersectionName: intersectionName,
      latitude: latitude,
      longitude: longitude,
      currentPhase: currentPhase ?? this.currentPhase,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      nextGreenIn: nextGreenIn ?? this.nextGreenIn,
      greenDuration: greenDuration,
      yellowDuration: yellowDuration,
      redDuration: redDuration,
      cycleTime: cycleTime,
      roadName: roadName,
      city: city,
      zone: zone,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      optimalSpeedKmh: optimalSpeedKmh ?? this.optimalSpeedKmh,
      action: action ?? this.action,
      adviceText: adviceText ?? this.adviceText,
      willCatchGreen: willCatchGreen ?? this.willCatchGreen,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
