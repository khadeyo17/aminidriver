//import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
//import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/driver_registration_screen';
import 'package:aminidriver/Onboarding/role_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Login_Screen/login_screen.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
import 'package:aminidriver/View/Screens/Other_Screens/Splash_Screen/splash_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/${Routes().splash}',
  routes: allRoutes,
);

final List<RouteBase> allRoutes = [
  // Other Screen Routes
  GoRoute(
    name: Routes().splash,
    path: '/${Routes().splash}',
    builder: (BuildContext context, GoRouterState state) {
      return const SplashScreen();
    },
  ),

  //Auth Routes
  GoRoute(
    name: Routes().login,
    path: '/${Routes().login}',
    builder: (BuildContext context, GoRouterState state) {
      return const LoginScreen();
    },
  ),

  GoRoute(
    name: Routes().register,
    path: '/${Routes().register}',
    builder: (BuildContext context, GoRouterState state) {
      return RegisterScreen(onSubmit: (driverData) {});
    },
  ),
  GoRoute(
    name: Routes().driverConfig,
    path: '/${Routes().driverConfig}',
    builder: (BuildContext context, GoRouterState state) {
      //return VehicleOnboardingScreen();
      //return DriverOnboardingScreen();
      //return VehicleOnboardingScreen();
      return RoleSelectionScreen();
      //DriverVehicleOnboardingForm()
    },
  ),
  GoRoute(
    name: 'RoleConfig',
    path: '/role-config',
    builder: (context, state) => RoleSelectionScreen(),
  ),
  // GoRoute(
  //   name: Routes().driverConfig,
  //   path: '/${Routes().driverConfig}',
  //   builder: (BuildContext context, GoRouterState state) {
  //     final driverId =
  //         state.extra is Map ? (state.extra as Map)['driverId'] as String : '';
  //     final email =
  //         state.extra is Map ? (state.extra as Map)['email'] as String : '';

  //     return VehicleOnboardingScreen(driverId: driverId, email: email);
  //   },
  // ),
  GoRoute(
    name: Routes().navigationScreen,
    path: '/${Routes().navigationScreen}',
    builder: (BuildContext context, GoRouterState state) {
      return const NavigationScreen();
    },
  ),

  //Main Routes
];
