import 'package:flutter/material.dart';
import '../models/user_dosen.dart';
import 'monitoring_screen.dart';
import 'presensi_screen.dart';
import 'iot_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserDosen dosen;
  const MainNavigationScreen({super.key, required this.dosen});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      MonitoringScreen(dosen: widget.dosen),
      const PresensiScreen(),
      const IoTScreen(),
      ProfileScreen(dosen: widget.dosen),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: const Color(0xFFE0E7FF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1E3A8A)),
            label: 'Monitoring',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check, color: Color(0xFF1E3A8A)),
            label: 'Presensi',
          ),
          NavigationDestination(
            icon: Icon(Icons.wind_power_outlined),
            selectedIcon: Icon(Icons.wind_power, color: Color(0xFF1E3A8A)),
            label: 'IoT Kipas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF1E3A8A)),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
