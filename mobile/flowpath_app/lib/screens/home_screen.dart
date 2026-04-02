// lib/screens/home_screen.dart
// Home screen with search, recent trips, eco stats, and quick-start navigation.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/glass_container.dart';
import 'navigation_screen.dart';
import 'trip_analytics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Tell the provider to lock onto GPS as soon as the app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NavigationProvider>(context, listen: false).startTracking(_mapController);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // ── 1. BACKGROUND MAP (Idle Mode) ────────────────────
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(12.9716, 77.5946), // Bengaluru default
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.himansu.flowpath',
              ),
            ],
          ),

          // ── 2. GLASS UI OVERLAY ──────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                _Header(userName: auth.userName ?? 'Driver'),

                // ── Tab content ──
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: const [
                      _HomeTab(),
                      TripAnalyticsScreen(),
                      SettingsScreen(),
                    ],
                  ),
                ),

                // ── Bottom Navigation ──
                _BottomNav(currentIndex: _tab, onTap: (i) => setState(() => _tab = i)),
              ],
            ),
          ),
        ],
      ),

      // FAB: Quick Navigate
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen())),
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.navigation),
        label: Text('Navigate', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  const _Header({required this.userName});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderRadius: 22,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GOOD ${_greeting().toUpperCase()}', style: const TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text(userName, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF141A2A), shape: BoxShape.circle, border: Border.all(color: const Color(0x3300E676))),
            child: const Text('🛣️', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    ),
  );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          const _SearchBar(),
          const SizedBox(height: 24),

          // Quick stats cards
          Text('TODAY\'s ECO STATS', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Stops\nAvoided', value: '${nav.stopsAvoided}', icon: '🚦', color: const Color(0xFF00E676))),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Fuel\nSaved', value: '${nav.fuelSavedL.toStringAsFixed(2)}L', icon: '⛽', color: const Color(0xFF00B0FF))),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'CO₂\nReduced', value: '${(nav.fuelSavedL * 2.31).toStringAsFixed(1)}kg', icon: '🌿', color: const Color(0xFFFFD600))),
            ],
          ),
          const SizedBox(height: 24),

          // GreenWave score
          GlassContainer(
            padding: const EdgeInsets.all(18),
            borderColor: const Color(0xFF00E676).withValues(alpha: 0.4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🌊 WAVE SCORE', style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(
                        '${nav.greenwaveScore.round()}',
                        style: GoogleFonts.orbitron(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, shadows: [const Shadow(color: Color(0xFF00E676), blurRadius: 10)]),
                      ),
                      const SizedBox(height: 4),
                      Text(_scoreLabel(nav.greenwaveScore), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 60, height: 60,
                  child: CircularProgressIndicator(
                    value: nav.greenwaveScore / 100,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                    strokeWidth: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick destinations
          Text('FREQUENT DESTINATIONS', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          GlassContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _QuickDestination(icon: '🏠', label: 'Home', address: 'Koramangala, Bengaluru', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen()))),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                _QuickDestination(icon: '💼', label: 'Work', address: 'Whitefield, Bengaluru', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen()))),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                _QuickDestination(icon: '🛍️', label: 'Forum Mall', address: '21, Hosur Road, Bengaluru', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen()))),
              ],
            ),
          ),
          const SizedBox(height: 80), // Padding for FAB
        ],
      ),
    );
  }

  String _scoreLabel(double score) =>
    score >= 85 ? 'Excellent — Master of the GreenWave!' :
    score >= 65 ? 'Good — Catching most green lights' :
    score >= 40 ? 'Average — Follow speed advice' :
    'Needs improvement — Trust the AI';
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen())),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 24,
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF00E676), size: 22),
            const SizedBox(width: 12),
            Text('Where do you want to go?', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
            )
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => GlassContainer(
    padding: const EdgeInsets.all(14),
    borderColor: color.withAlpha((0.3 * 255).round()),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.orbitron(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, height: 1.3, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _QuickDestination extends StatelessWidget {
  final String icon, label, address;
  final VoidCallback onTap;
  const _QuickDestination({required this.icon, required this.label, required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: const Color(0xFF141A2A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33FFFFFF))),
      alignment: Alignment.center,
      child: Text(icon, style: const TextStyle(fontSize: 18)),
    ),
    title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    subtitle: Text(address, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
    onTap: onTap,
  );
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => GlassContainer(
    borderRadius: 0,
    padding: const EdgeInsets.only(top: 4),
    child: BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: const Color(0xFF00E676),
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
      ],
    ),
  );
}
