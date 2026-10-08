import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../models/summary.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'today_screen.dart';
import 'week_screen.dart';

/// Bottom navigation between the Today landing page and the weekly summary.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final FeedingStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  /// The day shown on the Today tab. The week tab sets it when a day is tapped.
  final _day = ValueNotifier<DateTime>(dateOnly(DateTime.now()));

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
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Column(
          children: [
            if (widget.store.syncError != null)
              MaterialBanner(
                backgroundColor: AppColors.cream,
                content: Text(widget.store.syncError!),
                actions: [
                  TextButton(
                    onPressed: () => widget.store.setSyncResult(),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _tab,
                    children: [
                      TodayScreen(store: widget.store, day: _day),
                      WeekScreen(store: widget.store, onOpenDay: _openDay),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 12,
                    child: SafeArea(
                      child: IconButton(
                        tooltip: 'Account',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AccountScreen(store: widget.store),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_outline, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mint,
        onDestinationSelected: (i) {
          // Coming back to Today from the tab bar shows today again.
          if (i == 0 && _tab != 0) _day.value = dateOnly(DateTime.now());
          if (i == 1 && _tab != 1) widget.store.track('week_viewed', {'weeks_back': 0});
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Week',
          ),
        ],
      ),
    );
  }
}
