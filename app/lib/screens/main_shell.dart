import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../models/trends.dart';
import '../sheets/add_entry_sheet.dart';
import '../theme.dart';
import 'profile_screen.dart';
import 'today_screen.dart';
import 'trends_screen.dart';

/// Today, Trends and Profile, with "Add an entry" on Today.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final FeedingStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  /// The day shown on Today. Trends sets it when a day is tapped.
  late final _day = ValueNotifier<DateTime>(dateOnly(widget.store.now()));

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }

  void _openDay(DateTime day) {
    _day.value = day;
    setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) =>
                  widget.store.storageReady ? const SizedBox.shrink() : LinearProgressIndicator(minHeight: 3, color: c.primary),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  TodayScreen(store: widget.store, day: _day),
                  TrendsScreen(store: widget.store, onOpenDay: _openDay),
                  ProfileScreen(store: widget.store),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => showAddEntry(context, widget.store),
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              icon: const Icon(Icons.add),
              label: const Text('Add an entry', style: TextStyle(fontSize: 16)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          // Coming back to Today from the tab bar shows today again.
          if (i == 0 && _tab != 0) _day.value = dateOnly(widget.store.now());
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.auto_graph), selectedIcon: Icon(Icons.auto_graph), label: 'Trends'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
