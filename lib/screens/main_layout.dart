import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/my-cases')) return 1;
    if (location.startsWith('/call')) return 2;
    if (location.startsWith('/advisors')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/my-cases');
        break;
      case 2:
        context.go('/call');
        break;
      case 3:
        context.go('/advisors');
        break;
      case 4:
         // Assuming profile route exists, if not placeholders used
         // For now we wire it to the route we know or create new ones
         // In original plain profile was at /profile, let's keep consistent
         // But main.dart needs to update routes.
        context.go('/home'); // Temporary fallback if route missing
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.briefcase),
            label: 'My Cases',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.phone),
            label: 'Call',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.users),
            label: 'Advisors',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
