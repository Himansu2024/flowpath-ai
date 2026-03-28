// lib/screens/navigation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/signal_countdown_widget.dart';
import '../widgets/speed_advisor_widget.dart';
import '../widgets/greenwave_score_widget.dart';
import '../models/signal_model.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});
  @override State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapCtrl = MapController();
  Timer? _locationTimer;
  bool _showParking = false;
  List<Map<String,dynamic>> _parkingSpots = [];

  @override
  void initState() {
    super.initState();
    final nav = context.read<NavigationProvider>();
    nav.startTracking(_mapCtrl);
    _locationTimer = Timer.periodic(const Duration(seconds:2), (_) => nav.updateLocation());
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    context.read<NavigationProvider>().stopTracking();
    super.dispose();
  }

  Future<void> _loadParking() async {
    final nav = context.read<NavigationProvider>();
    final spots = await nav.findNearbyParking();
    setState(() { _parkingSpots = spots; _showParking = true; });
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(children: [

        // ── FULL SCREEN MAP ──────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: nav.userLocation ?? const LatLng(12.9716, 77.5946),
            initialZoom: 15,
            onTap: (_, latlng) {
              nav.setDestinationFromTap(latlng);
            },
          ),
          children: [
            // Dark map tiles (OpenStreetMap via CartoDB)
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a','b','c','d'],
              userAgentPackageName: 'com.flowpath.app',
            ),

            // Route polyline (glowing green)
            if (nav.routePoints.isNotEmpty) ...[
              PolylineLayer(polylines: [
                Polyline(points: nav.routePoints, strokeWidth: 14, color: const Color(0xFF00E676).withOpacity(0.12)),
                Polyline(points: nav.routePoints, strokeWidth: 5.5, color: const Color(0xFF00E676), strokeCap: StrokeCap.round),
              ]),
            ],

            // Markers layer
            MarkerLayer(markers: [
              // Signal markers at every junction
              ...nav.signals.where((s) => s.latitude != 0).map((s) => Marker(
                point: LatLng(s.latitude, s.longitude),
                width: 54, height: 82,
                child: _SignalMarkerWidget(signal: s),
              )),

              // User live location
              if (nav.userLocation != null) Marker(
                point: nav.userLocation!,
                width: 34, height: 34,
                child: _UserMarker(heading: nav.heading),
              ),

              // Destination pin
              if (nav.destination != null) Marker(
                point: nav.destination!,
                width: 32, height: 44,
                child: const _DestPin(),
              ),

              // Parking markers
              if (_showParking) ..._parkingSpots.take(8).map((p) => Marker(
                point: LatLng(p['lat'] as double, p['lon'] as double),
                width: 72, height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2979FF).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Color(0xFF2979FF), blurRadius: 8)],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal:8, vertical:4),
                  child: Text('P ${(p['dist'] as num?)?.round()}m',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              )),
            ]),
          ],
        ),

        // ── TOP: Search bar ──────────────────────────────────
        Positioned(
          top: safeTop + 12, left: 12, right: 12,
          child: _SearchBar(nav: nav),
        ),

        // ── SIGNAL HUD ───────────────────────────────────────
        if (nav.nextSignal != null)
          Positioned(
            top: safeTop + 78, left: 12, right: 12,
            child: SignalCountdownWidget(
              signal: nav.nextSignal!,
              optimization: nav.currentOptimization,
            ),
          ),

        // ── GREENWAVE SCORE (top right) ───────────────────────
        Positioned(
          top: safeTop + 80, right: 12,
          child: GreenWaveScoreWidget(score: nav.greenwaveScore),
        ),

        // ── SPEED HUD (bottom left) ───────────────────────────
        Positioned(
          bottom: safeBot + 160, left: 14,
          child: SpeedAdvisorWidget(
            recommendedSpeed: (nav.currentOptimization?['optimalSpeedKmh'] as num?)?.toDouble() ?? 40,
            actualSpeed: nav.currentSpeedKmh,
            action: nav.currentOptimization?['action'] as String? ?? 'maintain',
          ),
        ),

        // ── TRIP STATS (bottom right) ─────────────────────────
        Positioned(
          bottom: safeBot + 160, right: 14,
          child: _TripStatsCard(nav: nav),
        ),

        // ── JUNCTION STRIP ────────────────────────────────────
        Positioned(
          bottom: safeBot + 76, left: 0, right: 0,
          child: _JunctionStrip(signals: nav.signals),
        ),

        // ── BOTTOM CONTROL BAR ────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _BottomBar(
            nav: nav,
            onParking: _loadParking,
            onClose: () { nav.stopNavigation(); Navigator.pop(context); },
          ),
        ),

      ]),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  final NavigationProvider nav;
  const _SearchBar({required this.nav});
  @override State<_SearchBar> createState() => _SearchBarState();
}
class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xF00E1520),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFF1E2A3A)),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius:14)],
    ),
    child: Row(children: [
      const SizedBox(width:16),
      const Icon(Icons.search, color: Colors.grey, size:20),
      const SizedBox(width:8),
      Expanded(child: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          hintText: 'Search destination in India…',
          hintStyle: TextStyle(color: Colors.grey),
          border: InputBorder.none, contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(color: Colors.white, fontSize:15),
        onSubmitted: (q) { widget.nav.searchDestination(q); _ctrl.clear(); },
      )),
      IconButton(
        icon: const Icon(Icons.my_location, color: Color(0xFF00E676), size:20),
        onPressed: widget.nav.centerOnUser,
      ),
    ]),
  );
}

// ── Signal marker on map ──────────────────────────────────────
class _SignalMarkerWidget extends StatelessWidget {
  final SignalModel signal;
  const _SignalMarkerWidget({required this.signal});
  @override Widget build(BuildContext context) {
    final c = signal.currentPhase == 'green' ? const Color(0xFF00E676)
            : signal.currentPhase == 'yellow' ? const Color(0xFFFFD600)
            : const Color(0xFFFF1744);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c, width: 1.5),
          boxShadow: [BoxShadow(color: c.withOpacity(0.45), blurRadius:10)],
        ),
        padding: const EdgeInsets.all(5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Bulb(active: signal.currentPhase=='red',    color: const Color(0xFFFF1744)),
          _Bulb(active: signal.currentPhase=='yellow', color: const Color(0xFFFFD600)),
          _Bulb(active: signal.currentPhase=='green',  color: const Color(0xFF00E676)),
        ]),
      ),
      Container(
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(horizontal:5, vertical:2),
        child: Text('${signal.secondsRemaining}s',
          style: TextStyle(color:c, fontSize:10, fontWeight:FontWeight.bold, fontFamily:'Orbitron')),
      ),
    ]);
  }
}

class _Bulb extends StatelessWidget {
  final bool active; final Color color;
  const _Bulb({required this.active, required this.color});
  @override Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds:300),
    width:10, height:10, margin: const EdgeInsets.symmetric(vertical:1.5),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? color : color.withOpacity(0.12),
      boxShadow: active ? [BoxShadow(color:color.withOpacity(0.7), blurRadius:7)] : null,
    ),
  );
}

// ── User marker ───────────────────────────────────────────────
class _UserMarker extends StatelessWidget {
  final double heading;
  const _UserMarker({required this.heading});
  @override Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
    Container(width:34, height:34, decoration: BoxDecoration(
      shape: BoxShape.circle, color: const Color(0xFF2979FF).withOpacity(0.18))),
    Container(width:20, height:20, decoration: const BoxDecoration(
      shape: BoxShape.circle, color: Color(0xFF2979FF),
      boxShadow: [BoxShadow(color: Color(0xFF2979FF), blurRadius:14)])),
    Transform.rotate(angle: heading * 3.14159/180,
      child: const Icon(Icons.navigation, color: Colors.white, size:14)),
  ]);
}

// ── Destination pin ───────────────────────────────────────────
class _DestPin extends StatelessWidget {
  const _DestPin();
  @override Widget build(BuildContext context) => Column(mainAxisSize:MainAxisSize.min, children:[
    Container(width:22, height:22,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF1744),
        boxShadow: [BoxShadow(color: Color(0xFFFF1744), blurRadius:12)]),
      child: const Icon(Icons.flag, color: Colors.white, size:14)),
    Container(width:2, height:16, color: const Color(0xFFFF1744)),
  ]);
}

// ── Trip stats card ───────────────────────────────────────────
class _TripStatsCard extends StatelessWidget {
  final NavigationProvider nav;
  const _TripStatsCard({required this.nav});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xF00E1520), borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF1E2A3A)),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius:12)],
    ),
    padding: const EdgeInsets.symmetric(horizontal:14, vertical:10),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _SRow('ETA',  '${nav.etaMinutes}m',        const Color(0xFF00E676)),
      _SRow('Dist', '${nav.distanceKm.toStringAsFixed(1)}km', const Color(0xFF00B0FF)),
      _SRow('Save', '${nav.timeSavedMinutes}m',   const Color(0xFFFFD600)),
    ]),
  );
}
class _SRow extends StatelessWidget {
  final String l, v; final Color c;
  const _SRow(this.l, this.v, this.c);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical:2),
    child: Row(mainAxisSize: MainAxisSize.min, children:[
      Text('$l ', style: const TextStyle(color: Colors.grey, fontSize:11)),
      Text(v, style: TextStyle(color:c, fontSize:11, fontWeight: FontWeight.bold, fontFamily:'Orbitron')),
    ]));
}

// ── Junction strip ────────────────────────────────────────────
class _JunctionStrip extends StatelessWidget {
  final List<SignalModel> signals;
  const _JunctionStrip({required this.signals});
  @override Widget build(BuildContext context) => Container(
    height: 76,
    color: const Color(0xF00D1117),
    child: signals.isEmpty
      ? const Center(child: Text('Set destination to see signals', style: TextStyle(color: Colors.grey, fontSize:12)))
      : ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal:12, vertical:8),
          itemCount: signals.length,
          separatorBuilder: (_, __) => const SizedBox(width:8),
          itemBuilder: (_, i) {
            final s = signals[i];
            final c = s.currentPhase=='green' ? const Color(0xFF00E676)
                    : s.currentPhase=='yellow' ? const Color(0xFFFFD600) : const Color(0xFFFF1744);
            return Container(
              width: 66,
              decoration: BoxDecoration(
                color: const Color(0xFF0E1520), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.withOpacity(0.4)),
              ),
              padding: const EdgeInsets.all(6),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
                Row(mainAxisAlignment: MainAxisAlignment.center, children:[
                  _MiniBulb(s.currentPhase=='red',    const Color(0xFFFF1744)),
                  const SizedBox(width:2),
                  _MiniBulb(s.currentPhase=='yellow', const Color(0xFFFFD600)),
                  const SizedBox(width:2),
                  _MiniBulb(s.currentPhase=='green',  const Color(0xFF00E676)),
                ]),
                const SizedBox(height:4),
                Text('${s.secondsRemaining}s',
                  style: TextStyle(color:c, fontSize:12, fontWeight:FontWeight.bold, fontFamily:'Orbitron')),
                Text(s.intersectionName.split(' ').first,
                  style: const TextStyle(color:Colors.grey, fontSize:9),
                  overflow: TextOverflow.ellipsis),
              ]),
            );
          },
        ),
  );
}
class _MiniBulb extends StatelessWidget {
  final bool active; final Color color;
  const _MiniBulb(this.active, this.color);
  @override Widget build(BuildContext context) => Container(
    width:8, height:8, decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? color : color.withOpacity(0.15),
      boxShadow: active ? [BoxShadow(color:color.withOpacity(0.6), blurRadius:4)] : null,
    ));
}

// ── Bottom bar ────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final NavigationProvider nav;
  final VoidCallback onParking, onClose;
  const _BottomBar({required this.nav, required this.onParking, required this.onClose});
  @override Widget build(BuildContext context) {
    final sab = MediaQuery.of(context).padding.bottom;
    return Container(
      color: const Color(0xF00D1117),
      padding: EdgeInsets.only(bottom: sab + 4, top:8, left:8, right:8),
      child: Row(children:[
        _Btn(Icons.my_location,    'Center',    nav.centerOnUser),
        _Btn(Icons.local_parking,  'Parking',   onParking),
        _Btn(Icons.share,          'Share',     nav.shareRoute),
        _Btn(Icons.nightlight_round,'Night',    (){}),
        _Btn(Icons.close, 'End', onClose, color: const Color(0xFFFF1744)),
      ]),
    );
  }
}
class _Btn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final Color? color;
  const _Btn(this.icon, this.label, this.onTap, {this.color});
  @override Widget build(BuildContext context) => Expanded(child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical:8),
      child: Column(mainAxisSize: MainAxisSize.min, children:[
        Icon(icon, color: color ?? Colors.grey, size:20),
        const SizedBox(height:2),
        Text(label, style: TextStyle(color: color ?? Colors.grey, fontSize:10)),
      ]),
    ),
  ));
}
