import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../jap/jap_screen.dart';
import '../panchang/panchang_screen.dart';
import '../rashifal/screens/rashifal_screen.dart';
import '../settings/more_screen.dart';
import 'home_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final screens = [
      const HomeScreen(),
      const JapScreen(),
      const PanchangScreen(),
      const RashifalScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          8 + MediaQuery.paddingOf(c).bottom,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(c).cardTheme.color,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x125C4535),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (v) => setState(() => index = v),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l.t('home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.spa_outlined),
                  selectedIcon: const Icon(Icons.spa),
                  label: l.t('jap'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month),
                  label: l.t('panchang'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  selectedIcon: const Icon(Icons.auto_awesome),
                  label: l.t('rashifal'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu),
                  label: l.t('more'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
