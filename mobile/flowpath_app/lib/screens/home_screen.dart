// lib/screens/home_screen.dart
// Home screen with search, recent trips, eco stats, and quick-start navigation.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import 'navigation_screen.dart';
import 'trip_analytics_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(children: [

          // ── Header ─────────────────────────────────────────
          _Header(userName: auth.userName ?? 'Driver'),

          // ── Tab content ────────────────────────────────────
          Expanded(
            child: IndexedStack(index: _tab, children: const [
              _HomeTab(),
              TripAnalyticsScreen(),
              SettingsScreen(),
            ]),
          ),

          // ── Bottom Navigation ───────────────────────────────
          _BottomNav(currentIndex: _tab, onTap: (i) => setState(() => _tab = i)),
        ]),
      ),

      // FAB: Quick Navigate
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen())),
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.navigation),
        label: const Text('Navigate', style: TextStyle(fontWeight: FontWeight.bold)),
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
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Good ${_greeting()},', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ])),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1520),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2A3A)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('🛣️', style: TextStyle(fontSize: 22)),
        ),
      ),
    ]),
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
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Search bar
        const _SearchBar(),
        const SizedBox(height: 24),

        // Quick stats cards
        const Text('Today\'s Eco Stats',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(label: 'Stops\nAvoided', value: '${nav.stopsAvoided}', icon: '🚦', color: const Color(0xFF00E676))),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'Fuel\nSaved', value: '${nav.fuelSavedL.toStringAsFixed(2)}L', icon: '⛽', color: const Color(0xFF00B0FF))),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'CO₂\nReduced', value: '${(nav.fuelSavedL * 2.31).toStringAsFixed(1)}kg', icon: '🌿', color: const Color(0xFF69F0AE))),
        ]),
        const SizedBox(height: 24),

        // GreenWave score
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E2A1A), Color(0xFF0E1520)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x4000E676)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🌊 GreenWave Score', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                '${nav.greenwaveScore.round()} / 100',
                style: const TextStyle(
                  color: Color(0xFF00E676), fontSize: 28, fontWeight: FontWeight.w900,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 4),
              Text(_scoreLabel(nav.greenwaveScore),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            const SizedBox(width: 16),
            SizedBox(
              width: 60, height: 60,
              child: CircularProgressIndicator(
                value: nav.greenwaveScore / 100,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                strokeWidth: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // Quick destinations
        const Text('Frequent Destinations',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _QuickDestination(icon: '🏠', label: 'Home', address: 'Koramangala, Bengaluru',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen()))),
        _QuickDestination(icon: '💼', label: 'Work', address: 'Whitefield, Bengaluru',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen()))),
        _QuickDestination(icon: '🛍️', label: 'Forum Mall', address: '21, Hosur Road, Bengaluru',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen()))),
      ]),
    );
  }

  String _scoreLabel(double score) =>
    score >= 85 ? 'Excellent — you\'re a GreenWave master!' :
    score >= 65 ? 'Good — catching most green lights' :
    score >= 40 ? 'Average — keep following FlowPath advice' :
    'Needs improvement — trust the speed recommendations';
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavigationScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1520),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2A3A)),
        ),
        child: const Row(children: [
          Icon(Icons.search, color: Colors.grey, size: 20),
          SizedBox(width: 10),
          Text('Where do you want to go?', style: TextStyle(color: Colors.grey, fontSize: 15)),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0E1520),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withAlpha((0.2 * 255).round())),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Orbitron')),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.3)),
    ]),
  );
}

class _QuickDestination extends StatelessWidget {
  final String icon, label, address;
  final VoidCallback onTap;
  const _QuickDestination({required this.icon, required this.label, required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1520), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      alignment: Alignment.center,
      child: Text(icon, style: const TextStyle(fontSize: 20)),
    ),
    title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    subtitle: Text(address, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
    onTap: onTap,
  );
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF0E1520),
      border: Border(top: BorderSide(color: Color(0xFF1E2A3A))),
    ),
    child: BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: const Color(0xFF00E676),
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontSize: 10),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Analytics'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
      ],
    ),
  );
}
