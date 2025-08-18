import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:aminidriver/Container/utils/error_notification.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
import 'package:aminidriver/Onboarding/ride_alert.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SplashLogics {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void initializeUser(BuildContext context) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      Timer(const Duration(seconds: 1), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen()),
        );
        //context.goNamed(Routes().register);
      });
      return;
    }

    double parseToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final String firebaseUid = user.uid;
    bool hasBackendData = false;
    bool hasFirestoreData = false;
    final uid = user.uid;
    final phone = user.phoneNumber ?? '';
    final email = user.email ?? '';
    final token = await user.getIdToken();
    final fcmToken = await FirebaseMessaging.instance.getToken();

    try {
      final String? idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse(
          "http://192.168.100.160:7047/api/auth/check-user/$firebaseUid",
        ),
        headers: {
          //   HttpHeaders.authorizationHeader: 'Bearer $idToken',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      );
      String? phoneFromBackend;
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        phoneFromBackend = userData['phone'];
        //final UserRole role = userData['role'];
        final int roleIndex = userData['role'] ?? 0;
        final UserRole role = UserRole.values[roleIndex];
        hasBackendData =
            phoneFromBackend != null && phoneFromBackend.trim().isNotEmpty;

        if (hasBackendData) {
          final bool isApproved = userData['isApproved'] ?? false;
          final response = await http.post(
            Uri.parse('$baseUrl/auth/update-fcm-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'token': token, // Firebase ID token
              'fcmToken': fcmToken, // Device's FCM token
            }),
          );
          if (response.statusCode == 200) {
            if (isApproved) {
              final pendingRide = await getPendingRide();
              Future.delayed(const Duration(seconds: 3), () {
                if (!context.mounted) return;

                if (pendingRide != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => RideAlertScreen(
                            rideId: pendingRide['rideId'] ?? '',
                            rider: pendingRide['rider'] ?? '',
                            pickupName: pendingRide['pickupName'] ?? '',
                            destinationName:
                                pendingRide['destinationName'] ?? '',

                            // pickupLat:
                            //     (pendingRide['pickupLat'] as num?)
                            //         ?.toDouble() ??
                            //     0.0,
                            // pickupLng:
                            //     (pendingRide['pickupLng'] as num?)
                            //         ?.toDouble() ??
                            //     0.0,
                            // destLat:
                            //     (pendingRide['destLat'] as num?)?.toDouble() ??
                            //     0.0,
                            // destLng:
                            //     (pendingRide['destLng'] as num?)?.toDouble() ??
                            //     0.0,
                            pickupLat: parseToDouble(pendingRide['pickupLat']),
                            pickupLng: parseToDouble(pendingRide['pickupLng']),
                            destLat: parseToDouble(pendingRide['destLat']),
                            destLng: parseToDouble(pendingRide['destLng']),
                          ),
                    ),
                  );
                  return; // stop further navigation
                }
                context.goNamed(Routes().navigationScreen);
              });
              //context.goNamed(Routes().navigationScreen);
              return;
            } else {
              if (role == UserRole.passenger) {
                // do something
                return;
              }
              final pendingRide = await getPendingRide();
              switch (role) {
                case UserRole.driver:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => DriverOnboardingScreen(role: UserRole.driver),
                    ),
                  );
                  break;

                case UserRole.owner:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => DriverOnboardingScreen(role: UserRole.owner),
                    ),
                  );
                  break;
                case UserRole.driverOwner:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => DriverOnboardingScreen(
                            role: UserRole.driverOwner,
                          ),
                    ),
                  );
                  break;

                case UserRole.passenger:
                default:
                  if (pendingRide != null) {
                    context.goNamed(Routes().ridealert);
                    return; // stop further navigation
                  }
                  context.goNamed(Routes().navigationScreen);
                  break;
              }
            }
            // context.goNamed(Routes().home);
          } else {
            final pendingRide = await getPendingRide();
            Future.delayed(const Duration(seconds: 3), () {
              if (!context.mounted) return;
              if (pendingRide != null) {
                context.goNamed(Routes().ridealert);
                return; // stop further navigation
              }
              context.goNamed(Routes().navigationScreen);
            });
            //debugPrint("Failed to validate token, contact amini support");
          }
        } else {
          context.goNamed(Routes().profilesetupscreen);
          //  debugPrint("Failed to validate user, contact amini support");
        }
      } else {
        context.goNamed(Routes().register);
      }
    } catch (e) {
      debugPrint("Backend or Firestore check failed: $e");
      // Optionally: navigate to error screen or retry
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
