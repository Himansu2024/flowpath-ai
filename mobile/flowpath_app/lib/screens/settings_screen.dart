// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _voiceNav   = true;
  bool _ecoMode    = true;
  bool _notifications = true;
  String _vehicleType = 'car';
  String _mapStyle = 'dark';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // Profile card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1520), borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E2A3A)),
          ),
          child: Row(children: [
            CircleAvatar(backgroundColor: const Color(0x2600E676),
              child: Text(
                (auth.userName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
              )),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(auth.userName ?? 'Driver',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(auth.user?['email'] ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.grey), onPressed: () {}),
          ]),
        ),
        const SizedBox(height: 24),

        const _SectionLabel('Navigation'),
        _SettingToggle('Voice Navigation', 'Speak turn-by-turn instructions', '🔊', _voiceNav,
          (v) => setState(() => _voiceNav = v)),
        _SettingToggle('Eco Mode', 'Prioritise fuel-saving speed recommendations', '🌿', _ecoMode,
          (v) => setState(() => _ecoMode = v)),
        _SettingToggle('Push Notifications', 'Congestion alerts, signal warnings', '🔔', _notifications,
          (v) => setState(() => _notifications = v)),
        const SizedBox(height: 20),

        const _SectionLabel('Vehicle Type'),
        Wrap(spacing: 10, children: ['car', 'bike', 'truck', 'bus'].map((t) =>
          ChoiceChip(
            label: Text('${_vehicleEmoji(t)} ${t[0].toUpperCase()}${t.substring(1)}'),
            selected: _vehicleType == t,
            selectedColor: const Color(0x3300E676),
            labelStyle: TextStyle(
              color: _vehicleType == t ? const Color(0xFF00E676) : Colors.grey),
            backgroundColor: const Color(0xFF0E1520),
            side: BorderSide(color: _vehicleType == t
              ? const Color(0x6600E676)
              : const Color(0xFF1E2A3A)),
            onSelected: (s) { if (s) setState(() => _vehicleType = t); },
          ),
        ).toList()),
        const SizedBox(height: 20),

        const _SectionLabel('Map Style'),
        Wrap(spacing: 10, children: [
          _MapStyleChip('Dark', 'dark', _mapStyle, (v) => setState(() => _mapStyle = v)),
          _MapStyleChip('Satellite', 'satellite', _mapStyle, (v) => setState(() => _mapStyle = v)),
          _MapStyleChip('Night', 'night', _mapStyle, (v) => setState(() => _mapStyle = v)),
        ]),
        const SizedBox(height: 28),

        // About
        const _SectionLabel('About'),
        const _InfoRow('App Version', '1.0.0'),
        const _InfoRow('AI Engine', 'GreenWave v1.0'),
        const _InfoRow('Map Data', 'OpenStreetMap India'),
        const SizedBox(height: 28),

        // Logout
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1010),
              foregroundColor: const Color(0xFFFF1744),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFF1744), width: 1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  String _vehicleEmoji(String t) {
    switch (t) { case 'bike': return '🏍️'; case 'truck': return '🚛'; case 'bus': return '🚌'; default: return '🚗'; }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label.toUpperCase(), style: const TextStyle(
      color: Colors.grey, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
  );
}

class _SettingToggle extends StatelessWidget {
  final String title, subtitle, icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingToggle(this.title, this.subtitle, this.icon, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0E1520), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF1E2A3A)),
    ),
    child: SwitchListTile(
      title: Text('$icon  $title', style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF00E676),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

class _MapStyleChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onSelected;
  const _MapStyleChip(this.label, this.value, this.current, this.onSelected);

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: current == value,
    selectedColor: const Color(0x3300E676),
    labelStyle: TextStyle(color: current == value ? const Color(0xFF00E676) : Colors.grey),
    backgroundColor: const Color(0xFF0E1520),
    side: BorderSide(color: current == value ? const Color(0x6600E676) : const Color(0xFF1E2A3A)),
    onSelected: (s) { if (s) onSelected(value); },
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}
