// lib/screens/navigation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../models/signal_model.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});
  @override 
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapCtrl = MapController();
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = context.read<NavigationProvider>();
      nav.startTracking(_mapCtrl);
      _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) => nav.updateLocation());
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    context.read<NavigationProvider>().stopTracking();
    super.dispose();
  }

  // ── 1. The Parking Panel ──
  Future<void> _loadParking() async {
    final nav = context.read<NavigationProvider>();
    final spots = await nav.findNearbyParking();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Transparent so our GlassContainer shows
      isScrollControlled: true,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        borderColor: const Color(0x33FFFFFF),
        padding: EdgeInsets.only(top: 10, left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slide Handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('🅿️ Parking Near Destination', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(color: Color(0x33FFFFFF), height: 30),
            
            if (spots.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Text('🅿️', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 12),
                      Text('Set a destination to find parking', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: spots.take(4).length, // Show top 4 spots
                itemBuilder: (context, i) {
                  final spot = spots[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF141A2A), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x33FFFFFF))),
                    child: Row(
                      children: [
                        const Text('🅿️', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(spot['name']?.toString() ?? 'Parking Area', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('${spot['distance'] ?? '500'}m away', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${spot['capacity'] ?? '24'}', style: GoogleFonts.orbitron(color: const Color(0xFF00E676), fontSize: 18, fontWeight: FontWeight.bold)),
                            const Text('SPACES', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1)),
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── 2. The Features Panel ──
  void _showFeaturesPanel() {
    final nav = context.read<NavigationProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 24,
        padding: EdgeInsets.only(top: 10, left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('⚡ FlowPath Exclusive Features', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(color: Color(0x33FFFFFF), height: 30),
            
            // Grid of Stats
            Row(
              children: [
                Expanded(child: _FeatureCard(title: '🌊 Wave Score', value: '${nav.greenwaveScore.round()}', color: const Color(0xFF00E676))),
                const SizedBox(width: 10),
                Expanded(child: _FeatureCard(title: '⚡ Streak', value: '${nav.stopsAvoided}', sub: 'greens in a row', color: const Color(0xFFFFD600))),
              ],
            ),
            const SizedBox(height: 10),
            
            // Eco Drive Wide Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF141A2A), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x3300E676))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🌿 Eco Drive', style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(color: const Color(0x1A00E676), borderRadius: BorderRadius.circular(8)), child: Text('A+', style: GoogleFonts.orbitron(color: const Color(0xFF00E676), fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('⛽ ${nav.fuelSavedL.toStringAsFixed(2)}L', style: const TextStyle(color: Colors.white)),
                      Text('🌱 -${nav.co2SavedKg.toStringAsFixed(1)}kg', style: const TextStyle(color: Colors.white)),
                      Text('💰 ₹${(nav.fuelSavedL * 102).round()}', style: const TextStyle(color: Colors.white)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // Deep space background
      body: Stack(
        children: [
          // ── 1. THE MAP (Dark Mode Tiles) ───────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: nav.userLocation ?? const LatLng(12.9716, 77.5946),
              initialZoom: 15.0,
              onTap: (_, latlng) => nav.setDestinationFromTap(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.himansu.flowpath',
              ),
              PolylineLayer(
                polylines: [
                  if (nav.routePoints.isNotEmpty) ...[
                    Polyline(points: nav.routePoints, color: const Color(0x3300E676), strokeWidth: 22), // HTML Glow
                    Polyline(points: nav.routePoints, color: const Color(0xFF00E676), strokeWidth: 6, strokeCap: StrokeCap.round), // Core
                  ]
                ],
              ),
              MarkerLayer(
                markers: nav.signals.map((s) => Marker(
                  point: LatLng(s.latitude, s.longitude), width: 52, height: 82,
                  child: _MapSignalPin(signal: s),
                )).toList(),
              ),
              if (nav.userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: nav.userLocation!, width: 40, height: 40,
                      child: _UserMarker(heading: nav.heading),
                    ),
                  ],
                ),
            ],
          ),

          // ── 2. THE GLASS HUD ───────────────────────────────────
          SafeArea(
            child: Stack(
              children: [
                // TOP BAR: Logo & Speed (Matches HTML top-row)
                Positioned(
                  top: 12, left: 12, right: 12,
                  child: Row(
                    children: [
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        borderRadius: 22,
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF00E676), blurRadius: 8)])),
                            const SizedBox(width: 8),
                            Text('FLOW', style: GoogleFonts.orbitron(color: const Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            Text('PATH', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          borderRadius: 20,
                          child: Row(
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('SPEED', style: TextStyle(color: Color(0xFF5A6A88), fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${nav.currentSpeedKmh.round()} km/h', style: GoogleFonts.orbitron(color: const Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // SEARCH BAR
                Positioned(
                  top: 64, left: 12, right: 12,
                  child: _SearchBar(nav: nav),
                ),

                // SIGNAL HUD
                if (nav.nextSignal != null)
                  Positioned(
                    top: 130, left: 12, right: 12,
                    child: _HtmlSignalHud(signal: nav.nextSignal!),
                  ),

                // SPEED HUD (Bottom Left)
                Positioned(
                  bottom: 110, left: 12,
                  child: _HtmlSpeedHud(nav: nav),
                ),

                // TRIP STATS (Bottom Right)
                Positioned(
                  bottom: 110, right: 12,
                  child: _TripStatsCard(nav: nav),
                ),

                // JUNCTION STRIP
                Positioned(
                  bottom: 56, left: 0, right: 0,
                  child: _JunctionStrip(signals: nav.signals),
                ),

                // BOTTOM BAR
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _BottomBar(
                    nav: nav, 
                    onParking: _loadParking, 
                    onFeatures: _showFeaturesPanel,
                    onClose: () { nav.stopNavigation(); Navigator.pop(context); }
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── HTML-Matched Search Bar ──
class _SearchBar extends StatelessWidget {
  final NavigationProvider nav;
  const _SearchBar({required this.nav});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: Color(0xFF5A6A88), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search anywhere in India...',
                hintStyle: TextStyle(color: Color(0xFF5A6A88), fontSize: 14),
                border: InputBorder.none,
              ),
              onSubmitted: (val) => nav.searchDestination(val),
            ),
          ),
          GestureDetector(
            onTap: () => nav.centerOnUser(),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF141A2A), shape: BoxShape.circle, border: Border.all(color: const Color(0x1AFFFFFF))),
              child: const Center(child: Text('📍', style: TextStyle(fontSize: 18))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HTML-Matched Signal HUD ──
class _HtmlSignalHud extends StatelessWidget {
  final SignalModel signal;
  const _HtmlSignalHud({required this.signal});

  @override
  Widget build(BuildContext context) {
    final isRed = signal.currentPhase == 'red';
    final isYellow = signal.currentPhase == 'yellow';
    final mainColor = isRed ? const Color(0xFFFF1744) : isYellow ? const Color(0xFFFFD600) : const Color(0xFF00E676);

    return GlassContainer(
      borderColor: mainColor.withAlpha((0.45 * 255).round()),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Traffic Light Column
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF070707),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: mainColor.withAlpha((0.55 * 255).round()), width: 2),
            ),
            child: Column(
              children: [
                _MiniBulb(isRed, const Color(0xFFFF1744), size: 18),
                const SizedBox(height: 5),
                _MiniBulb(isYellow, const Color(0xFFFFD600), size: 18),
                const SizedBox(height: 5),
                _MiniBulb(!isRed && !isYellow, const Color(0xFF00E676), size: 18),
              ],
            ),
          ),
          const SizedBox(width: 14),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEXT SIGNAL', style: TextStyle(color: Color(0xFF5A6A88), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(signal.intersectionName, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                const Text('~0.9 km ahead', style: TextStyle(color: Color(0xFF5A6A88), fontSize: 11)),
                const SizedBox(height: 8),
                Container(
                  height: 3, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.7, // Connect to live distance ratio later
                    child: Container(decoration: BoxDecoration(color: mainColor, borderRadius: BorderRadius.circular(2))),
                  ),
                )
              ],
            ),
          ),

          // Countdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${signal.secondsRemaining}', style: GoogleFonts.orbitron(color: mainColor, fontSize: 38, fontWeight: FontWeight.w900, shadows: [Shadow(color: mainColor, blurRadius: 28)])),
              const Text('SEC', style: TextStyle(color: Color(0xFF5A6A88), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: mainColor.withAlpha((0.12 * 255).round()), borderRadius: BorderRadius.circular(9), border: Border.all(color: mainColor.withAlpha((0.25 * 255).round()))),
                child: Text(isRed ? 'STOP' : isYellow ? 'SLOW' : 'GO', style: TextStyle(color: mainColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ── HTML-Matched Speed HUD ──
class _HtmlSpeedHud extends StatelessWidget {
  final NavigationProvider nav;
  const _HtmlSpeedHud({required this.nav});

  @override
  Widget build(BuildContext context) {
    final recSpeed = (nav.currentOptimization?['optimalSpeedKmh'] as num?)?.toDouble() ?? 40;
    final isGood = nav.currentSpeedKmh <= recSpeed + 5 && nav.currentSpeedKmh >= recSpeed - 5;
    final color = isGood ? const Color(0xFF00E676) : const Color(0xFFFFD600);

    return GlassContainer(
      borderColor: color.withAlpha((0.35 * 255).round()),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECOMMENDED', style: TextStyle(color: Color(0xFF5A6A88), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${recSpeed.round()}', style: GoogleFonts.orbitron(color: color, fontSize: 38, fontWeight: FontWeight.w900, shadows: [Shadow(color: color, blurRadius: 28)])),
              const Padding(padding: EdgeInsets.only(bottom: 6, left: 4), child: Text('KM/H', style: TextStyle(color: Color(0xFF5A6A88), fontSize: 10, letterSpacing: 2))),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x1AFFFFFF)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Actual', style: TextStyle(color: Color(0xFF5A6A88), fontSize: 11)),
                const SizedBox(width: 24),
                Text('${nav.currentSpeedKmh.round()} km/h', style: GoogleFonts.orbitron(color: const Color(0xFF00B0FF), fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared UI Elements ──
class _TripStatsCard extends StatelessWidget {
  final NavigationProvider nav;
  const _TripStatsCard({required this.nav});
  @override Widget build(BuildContext context) => GlassContainer(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatCol('ETA', '${nav.etaMinutes}m', const Color(0xFF00E676)),
        Container(width: 1, height: 24, color: const Color(0x1AFFFFFF), margin: const EdgeInsets.symmetric(horizontal: 14)),
        _StatCol('DIST', nav.distanceKm.toStringAsFixed(1), const Color(0xFF00B0FF)),
      ],
    ),
  );
}

class _StatCol extends StatelessWidget {
  final String l, v; final Color c;
  const _StatCol(this.l, this.v, this.c);
  @override Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(v, style: GoogleFonts.orbitron(color: c, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(l, style: const TextStyle(color: Color(0xFF5A6A88), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
    ],
  );
}

class _FeatureCard extends StatelessWidget {
  final String title, value; final String? sub; final Color color;
  const _FeatureCard({required this.title, required this.value, required this.color, this.sub});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF141A2A), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.orbitron(color: color, fontSize: 28, fontWeight: FontWeight.w900)),
        if (sub != null) Text(sub!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    ),
  );
}

class _MiniBulb extends StatelessWidget {
  final bool active; final Color color; final double size;
  const _MiniBulb(this.active, this.color, {this.size = 10});
  @override Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? color : color.withAlpha((0.15 * 255).round()),
      boxShadow: active ? [BoxShadow(color: color, blurRadius: 10, spreadRadius: 2)] : null,
    ),
  );
}

class _MapSignalPin extends StatelessWidget {
  final SignalModel signal;
  const _MapSignalPin({required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = signal.currentPhase == 'green' ? const Color(0xFF00E676)
        : signal.currentPhase == 'yellow' ? const Color(0xFFFFD600) : const Color(0xFFFF1744);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          padding: const EdgeInsets.all(5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniBulb(signal.currentPhase == 'red', const Color(0xFFFF1744)),
              _MiniBulb(signal.currentPhase == 'yellow', const Color(0xFFFFD600)),
              _MiniBulb(signal.currentPhase == 'green', const Color(0xFF00E676)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5)),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            '${signal.secondsRemaining}s',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _JunctionStrip extends StatelessWidget {
  final List<SignalModel> signals;
  const _JunctionStrip({required this.signals});

  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    color: const Color(0xF00D1117),
    child: signals.isEmpty
      ? const Center(child: Text('Set destination to see signals', style: TextStyle(color: Colors.grey, fontSize: 12)))
      : ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: signals.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = signals[i];
            final c = s.currentPhase == 'green' ? const Color(0xFF00E676)
                : s.currentPhase == 'yellow' ? const Color(0xFFFFD600) : const Color(0xFFFF1744);
            return Container(
              width: 66,
              decoration: BoxDecoration(
                color: const Color(0xFF0E1520),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.withAlpha((0.4 * 255).round())),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MiniBulb(s.currentPhase == 'red', const Color(0xFFFF1744), size: 8),
                      const SizedBox(width: 2),
                      _MiniBulb(s.currentPhase == 'yellow', const Color(0xFFFFD600), size: 8),
                      const SizedBox(width: 2),
                      _MiniBulb(s.currentPhase == 'green', const Color(0xFF00E676), size: 8),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${s.secondsRemaining}s', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(s.intersectionName.split(' ').first, style: const TextStyle(color: Colors.grey, fontSize: 9), overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          },
        ),
  );
}

class _BottomBar extends StatelessWidget {
  final NavigationProvider nav;
  final VoidCallback onParking;
  final VoidCallback onFeatures;
  final VoidCallback onClose;

  const _BottomBar({
    required this.nav,
    required this.onParking,
    required this.onFeatures,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: const Color(0xF00D1117),
      padding: EdgeInsets.only(left: 8, top: 8, right: 8, bottom: bottomInset + 4),
      child: Row(
        children: [
          // THE NEW SIMULATE DRIVE BUTTON!
          _BottomButton(Icons.play_arrow, 'Drive', () => nav.startSimulation(), color: const Color(0xFF00E676)),
          _BottomButton(Icons.local_parking, 'Parking', onParking),
          _BottomButton(Icons.electric_bolt, 'Features', onFeatures, color: const Color(0xFFFFD600)),
          _BottomButton(Icons.close, 'End', onClose, color: const Color(0xFFFF1744)),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _BottomButton(this.icon, this.label, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.grey, size: 20),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color ?? Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    ),
  );
}

class _UserMarker extends StatelessWidget {
  final double heading;
  const _UserMarker({required this.heading});

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(width: 34, height: 34, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x2E2979FF))),
      Container(width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2979FF), boxShadow: [BoxShadow(color: Color(0xFF2979FF), blurRadius: 14)])),
      Transform.rotate(angle: heading * 3.14159 / 180, child: const Icon(Icons.navigation, color: Colors.white, size: 14)),
    ],
  );
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 18,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xCC0E1520),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? const Color(0x1AFFFFFF)),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
    ),
    child: child,
  );
}

class GoogleFonts {
  static TextStyle orbitron({
    Color? color, double? fontSize, FontWeight? fontWeight, double? letterSpacing, List<Shadow>? shadows,
  }) => TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing, shadows: shadows);

  static TextStyle rajdhani({
    Color? color, double? fontSize, FontWeight? fontWeight,
  }) => TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight);
}
