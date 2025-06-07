import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import '../../Model/direction_model.dart';
import '../utils/error_notification.dart';

final globalAddressParserProvider = Provider<AddressParser>((ref) {
  return AddressParser();
});

class AddressParser {
  Future<String?> humanReadableAddress(
    Position userPosition,
    context,
    WidgetRef ref,
  ) async {
    try {
      final lat = userPosition.latitude.toStringAsFixed(6);
      final lng = userPosition.longitude.toStringAsFixed(6);
      print('Latitude: $lat, Longitude: $lng');

      if (userPosition.latitude == 0.0 || userPosition.longitude == 0.0) {
        ErrorNotification().showError(context, "Invalid location coordinates.");
        return null;
      }

      final url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$mapKey";

      final res = await Dio().get(url);

      print('Geocoding API response: ${res.data}');

      if (res.statusCode == 200) {
        final results = res.data["results"];
        if (results != null && results.isNotEmpty) {
          final formattedAddress = results[0]["formatted_address"];

          final model = Direction(
            locationLatitude: userPosition.latitude,
            locationLongitude: userPosition.longitude,
            humanReadableAddress: formattedAddress,
          );

          ref
              .read(homeScreenDriversLocationProvider.notifier)
              .setLocation(model);

          return formattedAddress;
        } else {
          ErrorNotification().showError(context, "No address found.");
        }
      } else {
        ErrorNotification().showError(context, "Failed to get address.");
      }
    } catch (e) {
      ErrorNotification().showError(context, "An error occurred: $e");
    }

    return null;
  }
}

// import 'package:dio/dio.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// import '../../Model/direction_model.dart';
// import '../utils/error_notification.dart';

// /// [addressParserProvider] used to cache the [AddressParser] class to prevent it from creating multiple instances
// final globalAddressParserProvider = Provider<AddressParser>((ref) {
//   return AddressParser();
// });

// /// This [AddressParser] has function [humanReadableAddress] which creates address that is in a readable form
// /// from the provided [userPosition]'s latitude and longitude and returns response in form of [Direction] model.
// class AddressParser {
//   Future<String?> humanReadableAddress(
//     Position userPosition,
//     context,
//     WidgetRef ref,
//   ) async {
//     try {
//       print(
//         'Latitude: ${userPosition.latitude}, Longitude: ${userPosition.longitude}',
//       );

//       // Check if coordinates are valid
//       if (userPosition.latitude == 0.0 || userPosition.longitude == 0.0) {
//         ErrorNotification().showError(context, "Invalid location coordinates.");
//         return null;
//       }

//       final url =
//           "https://maps.googleapis.com/maps/api/geocode/json?latlng=${userPosition.latitude},${userPosition.longitude}&key=$mapKey";

//       final res = await Dio().get(url);

//       if (res.statusCode == 200) {
//         final results = res.data["results"];
//         if (results != null && results.isNotEmpty) {
//           final formattedAddress = results[0]["formatted_address"];

//           // Create Direction model and update state
//           final model = Direction(
//             locationLatitude: userPosition.latitude,
//             locationLongitude: userPosition.longitude,
//             humanReadableAddress: formattedAddress,
//           );

//           // Update location using StateNotifier
//           ref
//               .read(homeScreenDriversLocationProvider.notifier)
//               .setLocation(model);

//           return formattedAddress;
//         } else {
//           ErrorNotification().showError(context, "No address found.");
//         }
//       } else {
//         ErrorNotification().showError(context, "Failed to get address.");
//       }
//     } catch (e) {
//       ErrorNotification().showError(context, "An error occurred: $e");
//     }

//     return null;
//   }
// }

// import 'package:dio/dio.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// import '../../Model/direction_model.dart';
// import '../utils/error_notification.dart';

// /// [addressParserProvider] used to cache the [AddressParser] class to prevent it from creating multiple instances
// final globalAddressParserProvider = Provider<AddressParser>((ref) {
//   return AddressParser();
// });

// /// This [AddressParser] has function [humanReadableAddress] which creates address that is in a readable form
// /// from the provided [userPosition]'s latitude and longitude and returns response in form of [Direction] model.
// class AddressParser {
//   Future<String?> humanReadableAddress(
//     Position userPosition,
//     context,
//     WidgetRef ref,
//   ) async {
//     try {
//       print('Latitude: ${userPosition.latitude}, Longitude: ${userPosition.longitude}');
//       final url =
//           "https://maps.googleapis.com/maps/api/geocode/json?latlng=${userPosition.latitude},${userPosition.longitude}&key=$mapKey";

//       final res = await Dio().get(url);

//       if (res.statusCode == 200) {
//         final results = res.data["results"];
//         if (results != null && results.isNotEmpty) {
//           final formattedAddress = results[0]["formatted_address"];

//           final model = Direction(
//             locationLatitude: userPosition.latitude,
//             locationLongitude: userPosition.longitude,
//             humanReadableAddress: formattedAddress,
//           );

//           // Update location using StateNotifier
//           ref
//               .read(homeScreenDriversLocationProvider.notifier)
//               .setLocation(model);

//           return formattedAddress;
//         } else {
//           ErrorNotification().showError(context, "No address found.");
//         }
//       } else {
//         ErrorNotification().showError(context, "Failed to get address.");
//       }
//     } catch (e) {
//       ErrorNotification().showError(context, "An error occurred: $e");
//     }

//     return null;
//   }
// }

// import 'package:dio/dio.dart';

// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// import '../../Model/direction_model.dart';
// import '../utils/error_notification.dart';

// /// [addressParserProvider] used to cache the [AddressParser] class to prevent it from creating multiple instances

// final globalAddressParserProvider = Provider<AddressParser>((ref) {
//   return AddressParser();
// });

// /// This [AddressParser] has function [humanReadableAddress] which creates address that is in a readable form
// /// from the provided [userPosition]'s latitude and longitude and returns response in form of [DIrection] model.

// class AddressParser {
//   dynamic humanReadableAddress(
//     Position userPosition,
//     context,
//     WidgetRef ref,
//   ) async {
//     try {
//       String url =
//           "https://maps.googleapis.com/maps/api/geocode/json?latlng=${userPosition.latitude},${userPosition.longitude}&key=$mapKey";

//       Response res = await Dio().get(url);

//       if (res.statusCode == 200) {
//         Direction model = Direction(
//           locationLatitude: userPosition.latitude,
//           locationLongitude: userPosition.longitude,
//           humanReadableAddress: res.data["results"][0]["formatted_address"],
//         );
//         // ref
//         //     .read(homeScreenDriversLocationProvider.notifier)
//         //     .update((state) => model);
//         ref.read(homeScreenDriversLocationProvider.notifier).setLocation(model);

//         return res.data["results"][0]["formatted_address"];
//       } else {
//         ErrorNotification().showError(context, "Failed to get data");
//       }
//     } catch (e) {
//       ErrorNotification().showError(context, "An Error Occurred $e");
//     }
//   }
// }
