import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Save ride data with expiry
Future<void> savePendingRide(
  Map<String, dynamic> rideData,
  int expiryInSeconds,
) async {
  final prefs = await SharedPreferences.getInstance();
  final expiryTime =
      DateTime.now()
          .add(Duration(seconds: expiryInSeconds))
          .millisecondsSinceEpoch;

  await prefs.setString(
    'pendingRide',
    jsonEncode({...rideData, 'expiry': expiryTime}),
  );
}

/// Retrieve pending ride (if valid), otherwise null
Future<Map<String, dynamic>?> getPendingRide() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString('pendingRide');
  if (data == null) return null;

  final decoded = jsonDecode(data);
  final expiry = decoded['expiry'] as int;

  if (DateTime.now().millisecondsSinceEpoch > expiry) {
    // expired → clear it
    await prefs.remove('pendingRide');
    return null;
  }

  // Remove expiry before returning
  decoded.remove('expiry');
  return decoded;
}

/// Clear pending ride manually
Future<void> clearPendingRide() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('pendingRide');
}

/// Helper → should open RideAlertScreen?
Future<Map<String, dynamic>?> shouldOpenRideAlert() async {
  return await getPendingRide();
}

// import 'dart:convert';

// import 'package:shared_preferences/shared_preferences.dart';

// Future<void> savePendingRide(
//   Map<String, dynamic> rideData,
//   int expiryInSeconds,
// ) async {
//   final prefs = await SharedPreferences.getInstance();
//   final expiryTime =
//       DateTime.now()
//           .add(Duration(seconds: expiryInSeconds))
//           .millisecondsSinceEpoch;

//   await prefs.setString(
//     'pendingRide',
//     jsonEncode({...rideData, 'expiry': expiryTime}),
//   );
// }

// Future<Map<String, dynamic>?> getPendingRide() async {
//   final prefs = await SharedPreferences.getInstance();
//   final data = prefs.getString('pendingRide');
//   if (data == null) return null;

//   final decoded = jsonDecode(data);
//   final expiry = decoded['expiry'] as int;

//   if (DateTime.now().millisecondsSinceEpoch > expiry) {
//     // expired → clear it
//     await prefs.remove('pendingRide');
//     return null;
//   }
//   return decoded;
// }
