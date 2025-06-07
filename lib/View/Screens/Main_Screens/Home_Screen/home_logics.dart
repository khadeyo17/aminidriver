import 'dart:io';

import 'package:aminidriver/Container/Repositories/address_parser_repo.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:aminidriver/Container/utils/error_notification.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';

final geo = GeoFlutterFire();

class HomeLogics {
  /// Get driver's current location and animate map to it
  Future<void> getDriverLoc(
    BuildContext context,
    WidgetRef ref,
    GoogleMapController controller,
  ) async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 14),
        ),
      );

      if (context.mounted) {
        await ref
            .watch(globalAddressParserProvider)
            .humanReadableAddress(pos, context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Unable to fetch location: $e");
      }
    }
  }

  /// Bring driver online and update backend
  Future<void> getDriverOnline(
    BuildContext context,
    WidgetRef ref,
    GoogleMapController controller,
  ) async {
    try {
      //final location = ref.watch(homeScreenDriversLocationProvider);
      final location = ref.read(homeScreenDriversLocationProvider);
      if (location == null) {
        ErrorNotification().showError(context, "Location data unavailable.");
        return;
      }

      final myLocation = geo.point(
        latitude: location.locationLatitude!,
        longitude: location.locationLongitude!,
      );

      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverLocationStatus(context, myLocation);

      // Listen and update location in real-time
      Geolocator.getPositionStream().listen((event) async {
        final liveLocation = geo.point(
          latitude: event.latitude,
          longitude: event.longitude,
        );
        await ref
            .read(globalFirestoreRepoProvider)
            .setDriverLocationStatus(context, liveLocation);
      });

      final driverPos = LatLng(
        location.locationLatitude!,
        location.locationLongitude!,
      );
      controller.animateCamera(CameraUpdate.newLatLng(driverPos));

      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverStatus(context, "Idle");

      ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => true);
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to go online: $e");
      }
    }
  }

  /// Take driver offline and update backend
  Future<void> getDriverOffline(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => false);

      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverStatus(context, "offline");
      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverLocationStatus(context, null);

      await Future.delayed(const Duration(seconds: 2));

      if (context.mounted) {
        ErrorNotification().showSuccess(context, "You are now Offline");
      }

      // Optional: close app when offline
      SystemChannels.platform.invokeMethod("SystemNavigator.pop");
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to go offline: $e");
      }
    }
  }

  /// Send FCM notification to user on trip request response
  Future<void> sendNotificationToUser(
    BuildContext context,
    String driverRes,
  ) async {
    try {
      await Dio().post(
        "https://fcm.googleapis.com/fcm/send",
        options: Options(
          headers: {
            HttpHeaders.contentTypeHeader: "application/json",
            HttpHeaders.authorizationHeader: "Bearer YOUR_FCM_SERVER_KEY",
          },
        ),
        data: {
          "data": {"screen": "home"},
          "notification": {
            "title": "Driver's Response",
            "status": driverRes,
            "body":
                "The Driver has $driverRes your request. "
                "${driverRes == "accepted" ? "They will arrive soon." : "Sorry, the Driver is not available."}",
          },
          "to": "USER_FCM_TOKEN",
        },
      );
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Notification failed: $e");
      }
    }
  }
}
