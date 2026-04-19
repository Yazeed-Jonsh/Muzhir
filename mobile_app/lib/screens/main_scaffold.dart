import 'package:flutter/material.dart';
import 'package:muzhir/services/auth_service.dart';
import 'package:muzhir/screens/farmer/home_page.dart';
import 'package:muzhir/screens/farmer/diagnose_page.dart';
import 'package:muzhir/screens/farmer/map_page.dart';
import 'package:muzhir/screens/farmer/history_page.dart';
import 'package:muzhir/screens/farmer/profile_screen.dart';

/// Root scaffold for the Farmer view.
/// Floating Material 3 [NavigationBar] (rounded, inset from screen edges).
///   0 – Home  |  1 – Diagnose  |  2 – Map  |  3 – History
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static const double _floatingNavRadius = 30;

  int _currentIndex = 0;
  int _diagnoseRefreshSignal = 0;

  static const List<String> _titles = [
    'Muzhir',
    'Diagnose',
    'Disease Map',
    'Scan History',
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 1) {
        _diagnoseRefreshSignal++;
      }
    });
  }

  void _notifyDiagnoseRefresh() {
    setState(() {
      _diagnoseRefreshSignal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/logos/muzhir_logo.jpeg',
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
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
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const FarmerHomePage(),
          DiagnosePage(
            onViewAllRecent: () => setState(() => _currentIndex = 3),
            isTabVisible: _currentIndex == 1,
            refreshSignal: _diagnoseRefreshSignal,
          ),
          MapPage(isTabVisible: _currentIndex == 2),
          HistoryPage(onScanDeleted: _notifyDiagnoseRefresh),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ??
              Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(_floatingNavRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_floatingNavRadius),
          child: NavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.park_outlined),
                selectedIcon: Icon(Icons.park_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.biotech_outlined),
                selectedIcon: Icon(Icons.biotech_rounded),
                label: 'Diagnose',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
