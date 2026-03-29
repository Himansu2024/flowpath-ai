// lib/widgets/greenwave_score_widget.dart
import 'package:flutter/material.dart';

class GreenWaveScoreWidget extends StatelessWidget {
  final double score;
  const GreenWaveScoreWidget({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 75 ? const Color(0xFF00E676)
        : score >= 50 ? const Color(0xFFFFD600)
        : const Color(0xFFFF1744);

    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: const Color(0xF00E1520),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((0.25 * 255).round())),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌊', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          '${score.round()}',
          style: TextStyle(
            color: color, fontSize: 26, fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
            shadows: [Shadow(color: color.withAlpha((0.5 * 255).round()), blurRadius: 12)],
          ),
        ),
        const Text('/100', style: TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 4),
        const Text('WAVE\nSCORE', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 1, height: 1.3)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }
}
