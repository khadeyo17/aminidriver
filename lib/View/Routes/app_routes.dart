//import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
//import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/driver_registration_screen';
import 'package:aminidriver/Onboarding/ride_alert.dart';
import 'package:aminidriver/Onboarding/role_screen.dart';
import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/mobile_otp_verification_screen.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/profile_setup_screen.dart';
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
  // GoRoute(
  //   name: Routes().login,
  //   path: '/${Routes().login}',
  //   builder: (BuildContext context, GoRouterState state) {
  //     return const LoginScreen();
  //   },
  // ),

  // GoRoute(
  //   name: Routes().register,
  //   path: '/${Routes().register}',
  //   builder: (BuildContext context, GoRouterState state) {
  //     return RegisterScreen(onSubmit: (driverData) {});
  //   },
  // ),
  GoRoute(
    name: 'otp',
    path: '/otp',
    pageBuilder: (context, state) {
      final extras = state.extra as Map<String, dynamic>?;

      if (extras == null ||
          extras['verificationId'] == null ||
          extras['phoneNumber'] == null) {
        return MaterialPage(
          child: Scaffold(
            body: Center(
              child: Text('Verification ID is missing. Please retry.'),
            ),
          ),
        );
      }

      return MaterialPage(
        child: OTPVerificationScreen(
          verificationId: extras['verificationId'],
          phoneNumber: extras['phoneNumber'],
          method: extras['method'],
        ),
      );
    },
  ),
  // GoRoute(
  //   // name: 'ridealert',
  //   // path: '/ride-alert',
  //   name: Routes().ridealert,
  //   path: '/${Routes().ridealert}',

  //   builder: (context, state) {
  //     final data = (state.extra ?? {}) as Map<String, dynamic>;

  //     return RideAlertScreen(
  //       rideId: data['rideId'] ?? '',
  //       rider: data['rider'] ?? '',
  //       pickupName: data['pickupName'] ?? '',
  //       destinationName: data['destinationName'] ?? '',
  //       pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? 0.0,
  //       pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? 0.0,
  //       destLat: (data['destLat'] as num?)?.toDouble() ?? 0.0,
  //       destLng: (data['destLng'] as num?)?.toDouble() ?? 0.0,
  //     );
  //   },

  //   // builder: (context, state) {
  //   //   final data = state.extra as Map<String, dynamic>;
  //   //   return RideAlertScreen(
  //   //     rideId: data['rideId'],
  //   //     rider: data['rider'] ?? '',
  //   //     pickupName: data['pickupName'] ?? '',
  //   //     destinationName: data['destinationName'] ?? '',
  //   //     pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? 0.0,
  //   //     pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? 0.0,
  //   //     destLat: (data['destLat'] as num?)?.toDouble() ?? 0.0,
  //   //     destLng: (data['destLng'] as num?)?.toDouble() ?? 0.0,
  //   //   );
  //   // },
  // ),
  GoRoute(
    name: Routes().ridealert,
    path: '/${Routes().ridealert}',
    builder: (context, state) {
      final data = (state.extra ?? {}) as Map<String, dynamic>;

      return RideAlertScreen(
        rideId: data['rideId'] ?? '',
        rider: data['rider'] ?? '',
        pickupName: data['pickupName'] ?? '',
        destinationName: data['destinationName'] ?? '',
        pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? 0.0,
        pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? 0.0,
        destLat: (data['destLat'] as num?)?.toDouble() ?? 0.0,
        destLng: (data['destLng'] as num?)?.toDouble() ?? 0.0,
      );
    },
  ),

  GoRoute(
    path: '/register',
    name: 'register',
    builder: (BuildContext context, GoRouterState state) {
      return const RegisterScreen();
    },
    //builder: (context, state) => RegisterScreen(),
  ),
  GoRoute(
    path: '/profilesetupscreen',
    name: 'profilesetupscreen',
    builder: (BuildContext context, GoRouterState state) {
      return const ProfileSetupScreen();
    },
    //builder: (context, state) => RegisterScreen(),
  ),

  // GoRoute(
  //   name: Routes().driverConfig,
  //   path: '/${Routes().driverConfig}',
  //   builder: (BuildContext context, GoRouterState state) {
  //     //return VehicleOnboardingScreen();
  //     //return DriverOnboardingScreen();
  //     //return VehicleOnboardingScreen();
  //     return RoleSelectionScreen(isCorporate: selectedUserType == 'Corporate');
  //     //DriverVehicleOnboardingForm()
  //   },
  // ),
  // GoRoute(
  //   name: Routes().driverConfig,
  //   path: '/${Routes().driverConfig}',
  //   builder: (BuildContext context, GoRouterState state) {
  //     final isCorporate = state.extra as bool? ?? false;
  //     return RoleSelectionScreen(isCorporate: isCorporate);
  //   },
  // ),

  // GoRoute(
  //   name: 'RoleConfig',
  //   path: '/role-config',
  //   builder: (context, state) => RoleSelectionScreen(isCorporate: selectedUserType == 'Corporate'),
  // ),
  // GoRoute(
  //   name: 'RoleConfig',
  //   path: '/role-config',
  //   builder: (context, state) {
  //     final isCorporate = state.extra as bool? ?? false;
  //     return RoleSelectionScreen(isCorporate: isCorporate);
  //   },
  // ),

  // GoRoute(
  //   name: 'vehicleOnboarding',
  //   path: '/vehicleOnboarding',
  //   builder: (context, state) {
  //     final isCorporate = state.extra as bool? ?? false;
  //     return VehicleOnboardingScreen();
  //   },
  // ),
  GoRoute(
    name: 'vehicleonboarding',
    path: '/vehicleonboarding',
    builder: (context, state) {
      final extras = state.extra as Map<String, dynamic>? ?? {};

      return VehicleOnboardingScreen(
        skipDriverOnboarding: extras['skipDriverOnboarding'] ?? false,
        hasownerOnboarding: extras['hasownerOnboarding'] ?? false,
      );
    },
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
