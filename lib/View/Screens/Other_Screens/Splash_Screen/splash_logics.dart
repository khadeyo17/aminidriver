import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:aminidriver/Container/utils/error_notification.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:http/http.dart' as http;

class SplashLogics {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// This method should be called in your SplashScreen `initState`
  void initializeUser(BuildContext context) async {
    final User? user = _auth.currentUser;

    if (user != null) {
      if (!user.emailVerified) {
        await _auth.signOut();
        context.goNamed(Routes().login); // Or a "Verify Email" screen
        return;
      }
      final String email = user.email ?? '';
      final String firebaseUid = user.uid;
      final String? idToken = await user.getIdToken();

      try {
        final response = await http.get(
          Uri.parse("$baseUrl/auth/check-user/$firebaseUid"),
          headers: {HttpHeaders.authorizationHeader: 'Bearer $idToken'},
        );
        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body);
          final String driverId = firebaseUid;

          Timer(const Duration(seconds: 1), () async {
            final vehicles = await checkDriverVehicles(driverId);
            if (vehicles != null && vehicles.isNotEmpty) {
              context.goNamed(Routes().navigationScreen);
            } else {
              context.goNamed(
                Routes().driverConfig,
                extra: {'driverId': driverId, 'email': email},
              );
            }
          });
        } else {
          // User doesn't exist → redirect to registration
          Timer(const Duration(seconds: 2), () {
            context.goNamed(Routes().register);
          });
        }
      } catch (e) {
        ErrorNotification().showError(
          context,
          "Failed to validate user. Check your connection",
        );
        // ignore: use_build_context_synchronously
        //ErrorNotification(context, "Failed to validate user. Check your connection.");
      }
    } else {
      // No Firebase user logged in
      Timer(const Duration(seconds: 1), () {
        context.goNamed(Routes().register);
      });
    }
  }

  Future<List<dynamic>?> checkDriverVehicles(String firebaseId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/driver-vehicles/by-driver/$firebaseId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // If it's a map containing 'vehicles' key
        if (data is Map && data.containsKey('vehicles')) {
          return data['vehicles'] is List ? data['vehicles'] : [];
        }

        // If it's directly a list
        if (data is List) {
          return data;
        }

        return [];
      } else {
        print("API returned status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching driver vehicles: $e");
      return null;
    }
  }

  // Future<bool> checkIfUserHasVehicle(String driverId) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse(
  //         "http://192.168.27.145:7047/api/driver-vehicles/by-driver/$driverId",
  //       ),
  //     );

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);

  //       // Option 1: If your API returns a map with a `vehicles` array
  //       if (data is Map && data.containsKey('vehicles')) {
  //         return data['vehicles'] is List && data['vehicles'].isNotEmpty;
  //       }

  //       // Option 2: If your API returns a list directly (no wrapping map)
  //       if (data is List) {
  //         return data.isNotEmpty;
  //       }

  //       return false;
  //     } else {
  //       print("Non-200 from API: ${response.statusCode}");
  //       return false;
  //     }
  //   } catch (e) {
  //     print("Error checking vehicle: $e");
  //     return false;
  //   }
  // }

  // Future<bool> checkIfUserHasVehicle(String driverId) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse(
  //         "http://192.168.27.145:7047/api/driver-vehicles/by-driver/$driverId",
  //       ),
  //     );
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       return data is List && data.isNotEmpty;
  //     } else {
  //       return false;
  //     }
  //   } catch (e) {
  //     print("Error checking vehicle: $e");
  //     return false;
  //   }
  // }

  /// [checkPermissions] checking the permission status

  void checkPermissions(BuildContext context) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
        LocationPermission permission2 = await Geolocator.checkPermission();
        if (context.mounted &&
            (permission2 == LocationPermission.whileInUse ||
                permission2 == LocationPermission.always)) {
          initializeUser(context);
        } else {
          if (context.mounted) {
            ErrorNotification().showError(
              context,
              "Location Access is required to run Trippo.",
            );
          }

          await Future.delayed(const Duration(seconds: 2));
          SystemChannels.platform.invokeMethod(
            "SystemNavigator.exitApplication",
          );
        }
        return;
      } else if (context.mounted &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always)) {
        initializeUser(context);
        return;
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        if (context.mounted) {
          ErrorNotification().showError(
            context,
            "Location Access is required to run Amini driver.",
          );
          await Future.delayed(const Duration(seconds: 2));
          SystemChannels.platform.invokeMethod(
            "SystemNavigator.exitApplication",
          );
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "An Error Occurred $e");
      }
    }
  }
}
