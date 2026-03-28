// lib/widgets/speed_advisor_widget.dart
// Displays recommended speed alongside actual GPS speed.

import 'package:flutter/material.dart';

class SpeedAdvisorWidget extends StatelessWidget {
  final double recommendedSpeed;
  final double actualSpeed;
  final String action; // maintain | slow_down | speed_up | stop

  const SpeedAdvisorWidget({
    super.key,
    required this.recommendedSpeed,
    required this.actualSpeed,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final recColor = _actionColor(action);
    final hudBorderColor = _actionBorderColor(action);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 140,
      decoration: BoxDecoration(
        color: const Color(0xF00E1520),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hudBorderColor, width: 1.5),
        boxShadow: [const BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Label
        const Text('RECOMMENDED', style: TextStyle(
          color: Colors.grey, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),

        // Recommended speed (large, glowing)
        Text(
          '${recommendedSpeed.round()}',
          style: TextStyle(
            color: recColor,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
            height: 1,
            shadows: [Shadow(color: recColor.withOpacity(0.5), blurRadius: 20)],
          ),
        ),
        const Text('KM/H', style: TextStyle(color: Colors.grey, fontSize: 9, letterSpacing: 2)),

        const Divider(color: Color(0xFF1E2A3A), height: 14),

        // Actual speed (from GPS)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Actual', style: TextStyle(color: Colors.grey, fontSize: 11)),
          Text(
            '${actualSpeed.round()} km/h',
            style: const TextStyle(
              color: Color(0xFF00B0FF), fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ]),
        const SizedBox(height: 8),

        // Action badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: recColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: recColor.withOpacity(0.25)),
          ),
          child: Text(
            _actionLabel(action),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: recColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ]),
    );
  }

  Color _actionColor(String a) {
    switch (a) {
      case 'slow_down': return const Color(0xFFFFD600);
      case 'stop':      return const Color(0xFFFF1744);
      case 'speed_up':  return const Color(0xFF00E676);
      default:          return const Color(0xFF00E676);
    }
  }

  Color _actionBorderColor(String a) => _actionColor(a).withOpacity(0.35);

  String _actionLabel(String a) {
    switch (a) {
      case 'slow_down': return '🟡 SLOW DOWN';
      case 'stop':      return '🔴 BRAKE';
      case 'speed_up':  return '🟢 SPEED UP';
      default:          return '🟢 OPTIMAL';
    }
  }
}
