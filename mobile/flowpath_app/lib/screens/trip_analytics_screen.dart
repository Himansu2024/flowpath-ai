// lib/screens/trip_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';

class TripAnalyticsScreen extends StatefulWidget {
  const TripAnalyticsScreen({super.key});
  @override
  State<TripAnalyticsScreen> createState() => _TripAnalyticsScreenState();
}

class _TripAnalyticsScreenState extends State<TripAnalyticsScreen> {
  bool _loading = false;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final nav = context.read<NavigationProvider>();
      final resp = await nav.apiService.getEcoStats();
      setState(() { _stats = resp['data']; });
    } catch (e) {
      debugPrint('Stats load error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF00E676),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          const Text('Trip Analytics', style: TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Your eco-driving performance', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),

          if (_stats != null) ...[
            // Summary grid
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
              children: [
                _AnalyticsCard('Total Trips',    '${_stats!['totalTrips']}',     '🚗', const Color(0xFF2979FF)),
                _AnalyticsCard('Distance',        '${_stats!['totalDistanceKm']} km', '📍', const Color(0xFF00B0FF)),
                _AnalyticsCard('Stops Avoided',   '${_stats!['totalStopsAvoided']}',  '🚦', const Color(0xFF00E676)),
                _AnalyticsCard('Fuel Saved',      '${(_stats!['totalFuelSavedMl'] as int) ~/ 1000}.${(_stats!['totalFuelSavedMl'] as int) % 1000 ~/ 100}L', '⛽', const Color(0xFFFFD600)),
                _AnalyticsCard('CO₂ Reduced',     '${(_stats!['totalCO2SavedG'] as int) ~/ 1000}.${(_stats!['totalCO2SavedG'] as int) % 1000 ~/ 100}kg', '🌿', const Color(0xFF69F0AE)),
                _AnalyticsCard('₹ Saved',         '₹${_stats!['moneySavedINR']}',     '💰', const Color(0xFFFF9800)),
              ],
            ),
            const SizedBox(height: 24),

            // GreenWave score
            Container(
              width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1520), borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x3300E676)),
              ),
              child: Column(children: [
                const Text('Average GreenWave Score', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 10),
                Text(
                  '${_stats!['avgGreenwaveScore']} / 100',
                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 36,
                    fontWeight: FontWeight.w900, fontFamily: 'Orbitron'),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: double.tryParse(_stats!['avgGreenwaveScore'].toString())! / 100,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                    minHeight: 8,
                  ),
                ),
              ]),
            ),
          ],

          if (_stats == null)
            const Center(child: Text('No trip data yet.\nStart your first navigation!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6))),
        ]),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _AnalyticsCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0E1520), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withAlpha((0.2 * 255).round())),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const Spacer(),
      Text(value, style: TextStyle(color: color, fontSize: 20,
        fontWeight: FontWeight.w800, fontFamily: 'Orbitron')),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ]),
  );
}
