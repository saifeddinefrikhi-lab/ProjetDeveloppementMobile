import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:waste_classification/features/collection/collection_map_screen.dart';
import 'package:waste_classification/features/collection/my_requests_screen.dart';
import 'package:waste_classification/features/history/history_screen.dart';
import 'package:waste_classification/features/home/home_screen.dart';
import 'package:waste_classification/features/profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  LatLng? _mapFocusLocation;
  String? _mapFocusTitle;
  String? _mapFocusSubtitle;

  void _navigateToMap(LatLng location, String title, {String? subtitle}) {
    setState(() {
      _mapFocusLocation = location;
      _mapFocusTitle = title;
      _mapFocusSubtitle = subtitle;
      _selectedIndex = 1; // Switch to Map tab
    });
  }

  void _clearMapFocus() {
    setState(() {
      _mapFocusLocation = null;
      _mapFocusTitle = null;
      _mapFocusSubtitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using conditional switching instead of IndexedStack eliminates the
      // desktop MouseTracker / unlaid-out RenderBox assertion issue when
      // FlutterMap is offstage on initial startup.
      body: switch (_selectedIndex) {
        0 => const HomeScreen(),
        1 => CollectionMapScreen(
            focusLocation: _mapFocusLocation,
            focusTitle: _mapFocusTitle,
            focusSubtitle: _mapFocusSubtitle,
            onClearFocus: _clearMapFocus,
          ),
        2 => MyRequestsScreen(
            onNavigateToMap: _navigateToMap,
          ),
        3 => const HistoryScreen(),
        4 => const ProfileScreen(),
        _ => const HomeScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index != _selectedIndex) {
            setState(() {
              _selectedIndex = index;
              // If user manually switched away from map, clear focus
              if (index != 1) {
                _mapFocusLocation = null;
                _mapFocusTitle = null;
                _mapFocusSubtitle = null;
              }
            });
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: 'navigation.home'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded),
            label: 'navigation.map'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping_rounded),
            label: 'navigation.collection'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: 'navigation.history'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: 'navigation.profile'.tr(),
          ),
        ],
      ),
    );
  }
}
