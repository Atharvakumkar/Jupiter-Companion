import 'package:go_router/go_router.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/fuel_expenses/presentation/fuel_expense_screen.dart';
import '../features/maintenance/presentation/maintenance_screen.dart';
import '../features/maps/presentation/live_route_map_screen.dart';
import '../features/onboarding/presentation/auth_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/parking/presentation/parking_screen.dart';
import '../features/rides/presentation/ride_detail_screen.dart';
import '../features/rides/presentation/ride_history_screen.dart';
import '../features/rides/presentation/ride_recording_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/telemetry/presentation/live_telemetry_screen.dart';
import '../features/vehicle_connection/presentation/bluetooth_diagnostic_screen.dart';
import 'widgets/scaffold_with_nav_bar.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/recording',
      builder: (context, state) => const RideRecordingScreen(),
    ),
    GoRoute(
      path: '/live_map',
      builder: (context, state) => const LiveRouteMapScreen(),
    ),
    GoRoute(
      path: '/ride_detail/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return RideDetailScreen(rideId: id);
      },
    ),
    GoRoute(
      path: '/telemetry',
      builder: (context, state) => const LiveTelemetryScreen(),
    ),
    GoRoute(
      path: '/diagnostics',
      builder: (context, state) => const BluetoothDiagnosticScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // Shell Route with persistent Bottom Navigation
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const RideHistoryScreen(),
        ),
        GoRoute(
          path: '/fuel',
          builder: (context, state) => const FuelExpenseScreen(),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (context, state) => const MaintenanceScreen(),
        ),
        GoRoute(
          path: '/parking',
          builder: (context, state) => const ParkingScreen(),
        ),
      ],
    ),
  ],
);
