import 'package:flutter/material.dart';
import 'package:muzhir/config/app_theme.dart';
import 'package:muzhir/screens/farmer/home_page.dart';
import 'package:muzhir/screens/farmer/diagnose_page.dart';
import 'package:muzhir/screens/farmer/map_page.dart';
import 'package:muzhir/screens/farmer/history_page.dart';

/// Root scaffold for the Farmer view.
/// Provides the BottomNavigationBar with four tabs:
///   0 – Home  |  1 – Diagnose  |  2 – Map  |  3 – History
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    FarmerHomePage(),
    DiagnosePage(),
    MapPage(),
    HistoryPage(),
  ];

  static const List<String> _titles = [
    'Muzhir',
    'Diagnose',
    'Disease Map',
    'Scan History',
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            Icons.eco_rounded,
            color: MuzhirColors.luminousLime,
            size: 28,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Notifications – future sprint
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () {
              // TODO: Profile / Settings – future sprint
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner_outlined),
            activeIcon: Icon(Icons.document_scanner_rounded),
            label: 'Diagnose',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
