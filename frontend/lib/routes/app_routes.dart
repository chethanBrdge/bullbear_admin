
import 'package:go_router/go_router.dart';
import '../screens/login/login_screen.dart';
import '../screens/dashboard/dashboard_shell.dart';
 

import '../screens/dashboard/kyc_review.dart';
import '../screens/dashboard/overview.dart';
import '../screens/dashboard/settlements.dart';
import '../screens/dashboard/users.dart';
import '../screens/dashboard/bets_screen.dart';
import '../screens/dashboard/stocks.dart';
import '../screens/dashboard/kyc_details_page.dart';
import '../screens/dashboard/user_details.dart';
import '../screens/dashboard/platform_config.dart';
import '../screens/dashboard/user_bets.dart';

import '../screens/dashboard/stock_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final isLoggingIn = state.uri.path == '/login';

    if (token != null && isLoggingIn) {
      return '/dashboard/overview'; // already logged in
    }

    if (token == null && !isLoggingIn) {
      return '/login'; // not logged in, trying to access dashboard
    }

    return null; // no redirect
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
  builder: (context, state, child) => DashboardShell(child: child),
  routes: [
    GoRoute(
      path: '/dashboard/overview',
      builder: (context, state) => const OverviewScreen(),
    ),
    GoRoute(
      path: '/dashboard/users',
      builder: (context, state) => const UsersAdminScreen(),
    ),
    GoRoute(
      path: '/dashboard/settlements',
      builder: (context, state) => const SettlementsScreen(),
    ),
    GoRoute(
      path: '/dashboard/kyc-review',
      builder: (context, state) => const KycReviewScreen(),
    ),
    GoRoute(
      path: '/dashboard/bets',
      builder: (context, state) => const BetsScreen(),
    ),
    GoRoute(
      path: '/dashboard/stocks',
      builder: (context, state) => const StocksScreen(),
    ),
    GoRoute(
      path: '/dashboard/platform_config',
      builder: (context, state) => const PlatformConfigScreen() ,
    ),
    GoRoute(
      path: '/dashboard/stocks/:symbol',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol']!;
        return MarketBySymbolScreen(symbol: symbol);
      },
    ),
    GoRoute(
      path: '/dashboard/user_bets/:username',
      builder: (context, state) {
        final username = state.pathParameters['username']!;
        return UserBetsScreen(username: username);
      },
    ),
    GoRoute(
      path: '/dashboard/kyc/:id',
      builder: (context, state) {
        final kycId = state.pathParameters['id']!;
        return KycDetailPage(kycId: kycId);
      },
    ),

    GoRoute(
      path: '/dashboard/user_details/:username',
      builder: (context, state) {
        final username = state.pathParameters['username']!;
        return UserDetails(username: username);
      },
    ),

  ],
),
  ],
);
