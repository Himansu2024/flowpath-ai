// lib/widgets/signal_countdown_widget.dart
// Prominent traffic signal HUD shown at the top of the navigation screen.
// Displays: traffic light, signal name, countdown timer, phase tag.

import 'package:flutter/material.dart';
import '../models/signal_model.dart';

class SignalCountdownWidget extends StatelessWidget {
  final SignalModel signal;
  final dynamic optimization; // Map from API or null

  const SignalCountdownWidget({
    super.key,
    required this.signal,
    this.optimization,
  });

  @override
  Widget build(BuildContext context) {
    final phase = signal.currentPhase;
    final color = _phaseColor(phase);
    final borderColor = color.withOpacity(0.45);
    final glowColor  = color.withOpacity(0.15);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: const Color(0xF00E1520),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(color: glowColor, blurRadius: 20, spreadRadius: 2),
            const BoxShadow(color: Colors.black54, blurRadius: 12),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [

          // ── Traffic Light Widget ────────────────────────────
          _TrafficLightWidget(phase: phase),
          const SizedBox(width: 14),

          // ── Signal Info ──────────────────────────────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NEXT SIGNAL',
                style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.5)),
              const SizedBox(height: 2),
              Text(signal.intersectionName,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                signal.distanceText.isNotEmpty ? '${signal.distanceText} ahead' : 'On your route',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              // Phase progress bar
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: signal.cycleTime > 0
                    ? signal.secondsRemaining / _getPhaseDuration(signal)
                    : 0.0,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 3,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),

          // ── Countdown ────────────────────────────────────────
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${signal.secondsRemaining}',
              style: TextStyle(
                color: color,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
                height: 1,
                shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 16)],
              ),
            ),
            const Text('SEC', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 2)),
            const SizedBox(height: 6),
            _PhaseTag(phase: phase),
          ]),
        ]),
      ),
    );
  }

  Color _phaseColor(String phase) {
    switch (phase) {
      case 'green':  return const Color(0xFF00E676);
      case 'yellow': return const Color(0xFFFFD600);
      default:       return const Color(0xFFFF1744);
    }
  }

  int _getPhaseDuration(SignalModel s) {
    switch (s.currentPhase) {
      case 'green':  return s.greenDuration;
      case 'yellow': return s.yellowDuration;
      default:       return s.redDuration;
    }
  }
}

// Compact traffic light with glowing bulbs
class _TrafficLightWidget extends StatelessWidget {
  final String phase;
  const _TrafficLightWidget({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: phase == 'red' ? const Color(0xFFFF1744).withOpacity(0.5)
               : phase == 'yellow' ? const Color(0xFFFFD600).withOpacity(0.5)
               : const Color(0xFF00E676).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _Bulb(active: phase == 'red',    color: const Color(0xFFFF1744)),
        const SizedBox(height: 4),
        _Bulb(active: phase == 'yellow', color: const Color(0xFFFFD600)),
        const SizedBox(height: 4),
        _Bulb(active: phase == 'green',  color: const Color(0xFF00E676)),
      ]),
    );
  }
}

class _Bulb extends StatelessWidget {
  final bool active;
  final Color color;
  const _Bulb({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 18, height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withOpacity(0.12),
        boxShadow: active ? [
          BoxShadow(color: color.withOpacity(0.7), blurRadius: 10, spreadRadius: 1),
        ] : null,
      ),
    );
  }
}

class _PhaseTag extends StatelessWidget {
  final String phase;
  const _PhaseTag({required this.phase});

  @override
  Widget build(BuildContext context) {
    final color = phase == 'green' ? const Color(0xFF00E676)
        : phase == 'yellow' ? const Color(0xFFFFD600)
        : const Color(0xFFFF1744);
    final label = phase == 'green' ? 'GO' : phase == 'yellow' ? 'SLOW' : 'STOP';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }
}
