import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardShell extends StatelessWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Column(
        children: [
          // Top bar with Logout
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); // Clears all tokens and profile info
                    context.go('/'); // Redirect to login screen
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _getIndex(location),
                  onDestinationSelected: (index) {
                    switch (index) {
                      case 0:
                        context.go('/dashboard/overview');
                        break;
                      case 1:
                        context.go('/dashboard/users');
                        break;
                      case 2:
                        context.go('/dashboard/settlements');
                        break;
                      case 3:
                        context.go('/dashboard/kyc-review');
                        break;
                      case 4:
                        context.go('/dashboard/bets');
                        break;
                      case 5:
                        context.go('/dashboard/stocks');
                        break;
                      case 6:
                        context.go('/dashboard/platform_config');
                        break;
                    }
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people),
                      label: Text('Users'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.attach_money),
                      label: Text('Settlements'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.verified_user),
                      label: Text('KYC Review'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.sports_esports),
                      label: Text('Bets'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.trending_up),
                      label: Text('Stocks'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('Platform Config'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getIndex(String location) {
    if (location.contains('/users')) return 1;
    if (location.contains('/settlements')) return 2;
    if (location.contains('/kyc-review')) return 3;
    if (location.contains('/bets')) return 4;
    if (location.contains('/stocks')) return 5;
    if (location.contains('/platform_config')) return 6;
    return 0;
  }
}
