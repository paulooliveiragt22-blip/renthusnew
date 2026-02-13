import 'package:go_router/go_router.dart';

import 'package:renthus/app_navigator.dart';
import 'package:renthus/features/auth/presentation/pages/role_selection_page.dart';

/// Rotas nomeadas do app.
class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String signUp = '/sign_up';
  static const String clientHome = '/client';
  static const String providerHome = '/provider';
  static const String admin = '/admin';
  static const String bookingDetails = '/booking_details';
  static const String serviceDetail = '/service_detail';
}

/// Configuração do GoRouter.
/// Migração incremental: rotas principais declarativas, Navigator.push
/// ainda funciona para navegação imperativa.
final goRouter = GoRouter(
  navigatorKey: AppNavigator.navigatorKey,
  initialLocation: AppRoutes.home,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => const RoleSelectionPage(),
    ),
  ],
);
