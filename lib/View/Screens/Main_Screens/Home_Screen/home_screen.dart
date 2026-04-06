import 'dart:convert';

import 'package:aminidriver/Container/utils/keys.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool loadingMetrics = true;
  bool isOnline = false;

  int totalCompleted = 0;
  int totalCancelled = 0;
  int weeklyCompleted = 0;
  int weeklyCancelled = 0;
  int dailyCompleted = 0;
  int dailyCancelled = 0;

  double totalCompletedEarnings = 0.0;
  double weeklyCompletedEarnings = 0.0;
  double dailyCompletedEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardFromApi();
  }

  Future<void> _fetchDashboardFromApi() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final url = Uri.parse('$baseUrl/rides/dashboard/${user.uid}');
      final response = await Dio().get(url.toString());

      if (response.statusCode == 200) {
        final data = response.data;

        setState(() {
          isOnline = data['isOnline'] ?? false;
          totalCompleted = data['totalCompleted'] ?? 0;
          totalCancelled = data['totalCancelled'] ?? 0;
          weeklyCompleted = data['weeklyCompleted'] ?? 0;
          weeklyCancelled = data['weeklyCancelled'] ?? 0;
          dailyCompleted = data['dailyCompleted'] ?? 0;
          dailyCancelled = data['dailyCancelled'] ?? 0;
          totalCompletedEarnings =
              (data['totalCompletedEarnings'] ?? 0).toDouble();
          weeklyCompletedEarnings =
              (data['weeklyCompletedEarnings'] ?? 0).toDouble();
          dailyCompletedEarnings =
              (data['dailyCompletedEarnings'] ?? 0).toDouble();
          loadingMetrics = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching dashboard: $e");
      setState(() => loadingMetrics = false);
    }
  }

  Future<void> updateDriverStatus(String firebaseUid, bool isOnline) async {
    final url = Uri.parse("$baseUrl/rides/updatedriver-status/$firebaseUid");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(isOnline), // <-- send true or false
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        this.isOnline = data["driver"]["isOnline"];
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data["message"])));
    } else {
      debugPrint("Failed to update status: ${response.body}");
    }
  }

  // Future<void> updateDriverAvailability(
  //   String firebaseUid,
  //   bool newStatus,
  // ) async {
  //   final url = Uri.parse('$baseUrl/rides/updatedriver-status/$firebaseUid');

  //   try {
  //     final response = await Dio().put(
  //       url.toString(),
  //       data: newStatus,
  //       options: Options(headers: {'Content-Type': 'application/json'}),
  //     );

  //     if (response.statusCode == 200) {
  //       setState(() => isOnline = newStatus);
  //       if (newStatus) {
  //         DriverLocationService().startSendingLocation();
  //       }
  //       print("✅ Driver availability updated");
  //     } else {
  //       print("❌ Failed: ${response.statusCode}");
  //     }
  //   } catch (e) {
  //     print("❌ Error updating availability: $e");
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              loadingMetrics
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    children: [
                      _buildStatusBadge(),
                      const SizedBox(height: 16),
                      _buildToggleButton(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildDashboardGrid()),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Text(
            isOnline ? 'You are Online' : 'You are Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isOnline ? Colors.red : Colors.green,
        minimumSize: const Size(double.infinity, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await updateDriverStatus(user.uid, !isOnline);
      },
      child: Text(
        isOnline ? "Go Offline" : "Go Online",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildMetricTile(
          'Total Completed',
          totalCompleted,
          totalCompletedEarnings,
          Colors.green,
          Icons.check_circle,
        ),
        _buildMetricTile(
          'Total Cancelled',
          totalCancelled,
          0,
          Colors.red,
          Icons.cancel,
        ),
        _buildMetricTile(
          'Weekly Completed',
          weeklyCompleted,
          weeklyCompletedEarnings,
          Colors.blue,
          Icons.calendar_today,
        ),
        _buildMetricTile(
          'Weekly Cancelled',
          weeklyCancelled,
          0,
          Colors.orange,
          Icons.event_busy,
        ),
        _buildMetricTile(
          'Daily Completed',
          dailyCompleted,
          dailyCompletedEarnings,
          Colors.purple,
          Icons.today,
        ),
        _buildMetricTile(
          'Daily Cancelled',
          dailyCancelled,
          0,
          Colors.brown,
          Icons.block,
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    String title,
    int count,
    double earnings,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count rides',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (earnings > 0)
            Text(
              'KES ${earnings.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/driver_location_live.dart';
// import 'package:dio/dio.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';

// class HomeScreen extends ConsumerStatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends ConsumerState<HomeScreen> {
//   // Dashboard metrics
//   int totalCompleted = 0;
//   int totalCancelled = 0;
//   int weeklyCompleted = 0;
//   int weeklyCancelled = 0;
//   int dailyCompleted = 0;
//   int dailyCancelled = 0;

//   double totalCompletedEarnings = 0.0;
//   double weeklyCompletedEarnings = 0.0;
//   double dailyCompletedEarnings = 0.0;

//   bool loadingMetrics = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchDashboardMetrics();
//   }

//   /// Fetch metrics from Firebase Rides node
//   Future<void> _fetchDashboardMetrics() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) return;

//       final snapshot = await FirebaseDatabase.instance
//           .ref('rides')
//           .orderByChild('driverId')
//           .equalTo(user.uid)
//           .get();

//       if (!snapshot.exists) {
//         setState(() => loadingMetrics = false);
//         return;
//       }

//       final rides = snapshot.value as Map<dynamic, dynamic>;
//       final now = DateTime.now();
//       final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
//       final startOfDay = DateTime(now.year, now.month, now.day);

//       int completed = 0;
//       int cancelled = 0;
//       int weekCompleted = 0;
//       int weekCancelled = 0;
//       int dayCompleted = 0;
//       int dayCancelled = 0;
//       double totalEarnings = 0.0;
//       double weekEarnings = 0.0;
//       double dayEarnings = 0.0;

//       for (var entry in rides.entries) {
//         final ride = entry.value as Map;
//         final status = ride['status'] as String? ?? '';
//         final fare = double.tryParse((ride['fare'] ?? '0').toString()) ?? 0;
//         final rideTime = ride['endedAt'] != null
//             ? DateTime.fromMillisecondsSinceEpoch(ride['endedAt'])
//             : now;

//         if (status == 'completed') {
//           completed++;
//           totalEarnings += fare;
//           if (rideTime.isAfter(startOfWeek)) {
//             weekCompleted++;
//             weekEarnings += fare;
//           }
//           if (rideTime.isAfter(startOfDay)) {
//             dayCompleted++;
//             dayEarnings += fare;
//           }
//         } else if (status == 'cancelled') {
//           cancelled++;
//           if (rideTime.isAfter(startOfWeek)) weekCancelled++;
//           if (rideTime.isAfter(startOfDay)) dayCancelled++;
//         }
//       }

//       setState(() {
//         totalCompleted = completed;
//         totalCancelled = cancelled;
//         weeklyCompleted = weekCompleted;
//         weeklyCancelled = weekCancelled;
//         dailyCompleted = dayCompleted;
//         dailyCancelled = dayCancelled;
//         totalCompletedEarnings = totalEarnings;
//         weeklyCompletedEarnings = weekEarnings;
//         dailyCompletedEarnings = dayEarnings;
//         loadingMetrics = false;
//       });
//     } catch (e) {
//       debugPrint('Error fetching dashboard metrics: $e');
//       setState(() => loadingMetrics = false);
//     }
//   }

//   /// Update driver online/offline status to backend API
//   Future<void> updateDriverAvailability(String firebaseUid, bool isOnline) async {
//     final url = Uri.parse('$baseUrl/rides/updatedriver-status/$firebaseUid');

//     try {
//       final response = await Dio().put(
//         url.toString(),
//         data: isOnline,
//         options: Options(headers: {'Content-Type': 'application/json'}),
//       );

//       if (response.statusCode == 200) {
//         if (isOnline) {
//           DriverLocationService().startSendingLocation();
//         }
//         print("✅ Driver availability updated: ${response.data}");
//       } else {
//         print("❌ Failed to update availability: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("❌ Error updating availability: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Driver Dashboard'),
//         backgroundColor: Colors.deepPurple,
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: loadingMetrics
//               ? const Center(child: CircularProgressIndicator())
//               : Column(
//                   children: [
//                     _buildStatusBadge(isOnline),
//                     const SizedBox(height: 16),
//                     _buildToggleButton(isOnline),
//                     const SizedBox(height: 16),
//                     Expanded(child: _buildDashboardGrid()),
//                   ],
//                 ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusBadge(bool isOnline) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       decoration: BoxDecoration(
//         color: isOnline ? Colors.green : Colors.red,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: const [
//           BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             isOnline ? Icons.check_circle : Icons.cancel,
//             color: Colors.white,
//           ),
//           const SizedBox(width: 10),
//           Text(
//             isOnline ? 'You are Online' : 'You are Offline',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildToggleButton(bool isOnline) {
//     return GestureDetector(
//       onTap: () async {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user == null) return;
//         await updateDriverAvailability(user.uid, !isOnline);
//         ref.read(homeScreenIsDriverActiveProvider.notifier).state = !isOnline;
//       },
//       child: Container(
//         alignment: Alignment.center,
//         width: double.infinity,
//         height: 45,
//         decoration: BoxDecoration(
//           color: isOnline ? Colors.red : Colors.green,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Text(
//           isOnline ? 'Go Offline' : 'Go Online',
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDashboardGrid() {
//     return GridView.count(
//       crossAxisCount: 2,
//       crossAxisSpacing: 12,
//       mainAxisSpacing: 12,
//       childAspectRatio: 1.2,
//       children: [
//         _buildMetricTile(
//           'Total Completed',
//           totalCompleted,
//           totalCompletedEarnings,
//           Colors.green,
//           Icons.check_circle,
//         ),
//         _buildMetricTile(
//           'Total Cancelled',
//           totalCancelled,
//           0,
//           Colors.red,
//           Icons.cancel,
//         ),
//         _buildMetricTile(
//           'Weekly Completed',
//           weeklyCompleted,
//           weeklyCompletedEarnings,
//           Colors.blue,
//           Icons.calendar_today,
//         ),
//         _buildMetricTile(
//           'Weekly Cancelled',
//           weeklyCancelled,
//           0,
//           Colors.orange,
//           Icons.event_busy,
//         ),
//         _buildMetricTile(
//           'Daily Completed',
//           dailyCompleted,
//           dailyCompletedEarnings,
//           Colors.purple,
//           Icons.today,
//         ),
//         _buildMetricTile(
//           'Daily Cancelled',
//           dailyCancelled,
//           0,
//           Colors.brown,
//           Icons.block,
//         ),
//       ],
//     );
//   }

//   Widget _buildMetricTile(
//       String title, int count, double earnings, Color color, IconData icon) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.15),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Icon(icon, color: color, size: 32),
//           const SizedBox(height: 8),
//           Text(title,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: color)),
//           const SizedBox(height: 6),
//           Text('$count rides',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: color)),
//           if (earnings > 0) ...[
//             const SizedBox(height: 4),
//             Text('KES ${earnings.toStringAsFixed(2)}',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                     color: color)),
//           ],
//         ],
//       ),
//     );
//   }
// }
// // import 'dart:async';
// // import 'package:aminidriver/Container/utils/keys.dart';
// // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // import 'package:dio/dio.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_database/firebase_database.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';

// // class HomeScreen extends ConsumerStatefulWidget {
// //   const HomeScreen({super.key});

// //   @override
// //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // }

// // class _HomeScreenState extends ConsumerState<HomeScreen> {
// //   // Dashboard metrics
// //   int totalCompleted = 0;
// //   int totalCancelled = 0;
// //   int weeklyCompleted = 0;
// //   int weeklyCancelled = 0;
// //   int dailyCompleted = 0;
// //   int dailyCancelled = 0;

// //   double totalCompletedEarnings = 0.0;
// //   double weeklyCompletedEarnings = 0.0;
// //   double dailyCompletedEarnings = 0.0;

// //   bool loadingMetrics = true;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _fetchDashboardMetrics();
// //   }

// //   Future<void> _fetchDashboardMetrics() async {
// //     try {
// //       final user = FirebaseAuth.instance.currentUser;
// //       if (user == null) return;

// //       final snapshot =
// //           await FirebaseDatabase.instance
// //               .ref('rides')
// //               .orderByChild('driverId')
// //               .equalTo(user.uid)
// //               .get();

// //       if (!snapshot.exists) {
// //         setState(() => loadingMetrics = false);
// //         return;
// //       }

// //       final rides = snapshot.value as Map<dynamic, dynamic>;
// //       final now = DateTime.now();
// //       final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
// //       final startOfDay = DateTime(now.year, now.month, now.day);

// //       int completed = 0;
// //       int cancelled = 0;
// //       int weekCompleted = 0;
// //       int weekCancelled = 0;
// //       int dayCompleted = 0;
// //       int dayCancelled = 0;
// //       double totalEarnings = 0.0;
// //       double weekEarnings = 0.0;
// //       double dayEarnings = 0.0;

// //       for (var entry in rides.entries) {
// //         final ride = entry.value as Map;
// //         final status = ride['status'] as String? ?? '';
// //         final fare = double.tryParse((ride['fare'] ?? '0').toString()) ?? 0;
// //         final rideTime =
// //             ride['endedAt'] != null
// //                 ? DateTime.fromMillisecondsSinceEpoch(ride['endedAt'])
// //                 : now;

// //         if (status == 'completed') {
// //           completed++;
// //           totalEarnings += fare;
// //           if (rideTime.isAfter(startOfWeek)) {
// //             weekCompleted++;
// //             weekEarnings += fare;
// //           }
// //           if (rideTime.isAfter(startOfDay)) {
// //             dayCompleted++;
// //             dayEarnings += fare;
// //           }
// //         } else if (status == 'cancelled') {
// //           cancelled++;
// //           if (rideTime.isAfter(startOfWeek)) weekCancelled++;
// //           if (rideTime.isAfter(startOfDay)) dayCancelled++;
// //         }
// //       }

// //       setState(() {
// //         totalCompleted = completed;
// //         totalCancelled = cancelled;
// //         weeklyCompleted = weekCompleted;
// //         weeklyCancelled = weekCancelled;
// //         dailyCompleted = dayCompleted;
// //         dailyCancelled = dayCancelled;
// //         totalCompletedEarnings = totalEarnings;
// //         weeklyCompletedEarnings = weekEarnings;
// //         dailyCompletedEarnings = dayEarnings;
// //         loadingMetrics = false;
// //       });
// //     } catch (e) {
// //       debugPrint('Error fetching dashboard metrics: $e');
// //       setState(() => loadingMetrics = false);
// //     }
// //   }

// //   /// Toggle driver availability (online/offline)
// //   Future<void> _toggleDriverStatus(bool currentStatus) async {
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user == null) {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(const SnackBar(content: Text('User not logged in')));
// //       return;
// //     }

// //     final newStatus = !currentStatus;
// //     final firebaseUid = user.uid;

// //     final url = Uri.parse('$baseUrl/rides/updatedriver-status/$firebaseUid');

// //     try {
// //       final response = await Dio().put(
// //         url.toString(),
// //         data: newStatus,
// //         options: Options(headers: {'Content-Type': 'application/json'}),
// //       );

// //       if (response.statusCode == 200) {
// //         // Update provider state
// //         ref.read(homeScreenIsDriverActiveProvider.notifier).state = newStatus;

// //         if (newStatus) {
// //           DriverLocationService().startSendingLocation();
// //         }

// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text(
// //               newStatus ? "You are now Online" : "You are now Offline",
// //             ),
// //           ),
// //         );

// //         debugPrint("✅ Driver availability updated: ${response.data}");
// //       } else {
// //         debugPrint("❌ Failed to update availability: ${response.statusCode}");
// //       }
// //     } catch (e) {
// //       debugPrint("❌ Error updating availability: $e");
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text('Driver Dashboard'),
// //         backgroundColor: Colors.deepPurple,
// //         centerTitle: true,
// //       ),
// //       body: SafeArea(
// //         child: Padding(
// //           padding: const EdgeInsets.all(16),
// //           child:
// //               loadingMetrics
// //                   ? const Center(child: CircularProgressIndicator())
// //                   : Column(
// //                     children: [
// //                       _buildStatusBadge(isOnline),
// //                       const SizedBox(height: 16),
// //                       _buildToggleButton(isOnline),
// //                       const SizedBox(height: 16),
// //                       Expanded(child: _buildDashboardGrid()),
// //                       const SizedBox(height: 16),
// //                       _buildBarChartPlaceholder(),
// //                     ],
// //                   ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildStatusBadge(bool isOnline) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// //       decoration: BoxDecoration(
// //         color: isOnline ? Colors.green : Colors.red,
// //         borderRadius: BorderRadius.circular(12),
// //         boxShadow: const [
// //           BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
// //         ],
// //       ),
// //       child: Row(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Icon(
// //             isOnline ? Icons.check_circle : Icons.cancel,
// //             color: Colors.white,
// //           ),
// //           const SizedBox(width: 10),
// //           Text(
// //             isOnline ? 'You are Online' : 'You are Offline',
// //             style: const TextStyle(
// //               color: Colors.white,
// //               fontSize: 16,
// //               fontWeight: FontWeight.bold,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildToggleButton(bool isOnline) {
// //     return GestureDetector(
// //       onTap: () => _toggleDriverStatus(isOnline),
// //       child: Container(
// //         alignment: Alignment.center,
// //         width: double.infinity,
// //         height: 45,
// //         decoration: BoxDecoration(
// //           color: isOnline ? Colors.red : Colors.green,
// //           borderRadius: BorderRadius.circular(10),
// //         ),
// //         child: Text(
// //           isOnline ? 'Go Offline' : 'Go Online',
// //           style: const TextStyle(
// //             color: Colors.white,
// //             fontWeight: FontWeight.bold,
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildDashboardGrid() {
// //     return GridView.count(
// //       crossAxisCount: 2,
// //       crossAxisSpacing: 12,
// //       mainAxisSpacing: 12,
// //       childAspectRatio: 1.2,
// //       children: [
// //         _buildMetricTile(
// //           'Total Completed',
// //           totalCompleted,
// //           totalCompletedEarnings,
// //           Colors.green,
// //           Icons.check_circle,
// //         ),
// //         _buildMetricTile(
// //           'Total Cancelled',
// //           totalCancelled,
// //           0,
// //           Colors.red,
// //           Icons.cancel,
// //         ),
// //         _buildMetricTile(
// //           'Weekly Completed',
// //           weeklyCompleted,
// //           weeklyCompletedEarnings,
// //           Colors.blue,
// //           Icons.calendar_today,
// //         ),
// //         _buildMetricTile(
// //           'Weekly Cancelled',
// //           weeklyCancelled,
// //           0,
// //           Colors.orange,
// //           Icons.event_busy,
// //         ),
// //         _buildMetricTile(
// //           'Daily Completed',
// //           dailyCompleted,
// //           dailyCompletedEarnings,
// //           Colors.purple,
// //           Icons.today,
// //         ),
// //         _buildMetricTile(
// //           'Daily Cancelled',
// //           dailyCancelled,
// //           0,
// //           Colors.brown,
// //           Icons.block,
// //         ),
// //       ],
// //     );
// //   }

// //   Widget _buildMetricTile(
// //     String title,
// //     int count,
// //     double earnings,
// //     Color color,
// //     IconData icon,
// //   ) {
// //     return Container(
// //       padding: const EdgeInsets.all(16),
// //       decoration: BoxDecoration(
// //         color: color.withOpacity(0.15),
// //         borderRadius: BorderRadius.circular(12),
// //       ),
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         crossAxisAlignment: CrossAxisAlignment.center,
// //         children: [
// //           Icon(icon, color: color, size: 32),
// //           const SizedBox(height: 8),
// //           Text(
// //             title,
// //             textAlign: TextAlign.center,
// //             style: TextStyle(
// //               fontSize: 14,
// //               fontWeight: FontWeight.bold,
// //               color: color,
// //             ),
// //           ),
// //           const SizedBox(height: 6),
// //           Text(
// //             '$count rides',
// //             textAlign: TextAlign.center,
// //             style: TextStyle(
// //               fontSize: 16,
// //               fontWeight: FontWeight.bold,
// //               color: color,
// //             ),
// //           ),
// //           if (earnings > 0) ...[
// //             const SizedBox(height: 4),
// //             Text(
// //               'KES ${earnings.toStringAsFixed(2)}',
// //               textAlign: TextAlign.center,
// //               style: TextStyle(
// //                 fontSize: 14,
// //                 fontWeight: FontWeight.w500,
// //                 color: color,
// //               ),
// //             ),
// //           ],
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildBarChartPlaceholder() {
// //     return Container(
// //       height: 180,
// //       width: double.infinity,
// //       decoration: BoxDecoration(
// //         color: Colors.grey[200],
// //         borderRadius: BorderRadius.circular(12),
// //       ),
// //       alignment: Alignment.center,
// //       child: const Text(
// //         'Bar Chart Placeholder\n(Integrate charts_flutter or fl_chart)',
// //         textAlign: TextAlign.center,
// //         style: TextStyle(color: Colors.grey, fontSize: 16),
// //       ),
// //     );
// //   }
// // }
// // // import 'dart:async';
// // // import 'package:aminidriver/Container/utils/keys.dart';
// // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // import 'package:dio/dio.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:firebase_database/firebase_database.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';

// // // class HomeScreen extends ConsumerStatefulWidget {
// // //   const HomeScreen({super.key});

// // //   @override
// // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // }

// // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // //   // Dashboard metrics
// // //   int totalCompleted = 0;
// // //   int totalCancelled = 0;
// // //   int weeklyCompleted = 0;
// // //   int weeklyCancelled = 0;
// // //   int dailyCompleted = 0;
// // //   int dailyCancelled = 0;

// // //   double totalCompletedEarnings = 0.0;
// // //   double weeklyCompletedEarnings = 0.0;
// // //   double dailyCompletedEarnings = 0.0;

// // //   bool loadingMetrics = true;

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _fetchDashboardMetrics();
// // //   }

// // //   Future<void> _fetchDashboardMetrics() async {
// // //     try {
// // //       final user = FirebaseAuth.instance.currentUser;
// // //       if (user == null) return;

// // //       final snapshot = await FirebaseDatabase.instance
// // //           .ref('rides')
// // //           .orderByChild('driverId')
// // //           .equalTo(user.uid)
// // //           .get();

// // //       if (!snapshot.exists) {
// // //         setState(() => loadingMetrics = false);
// // //         return;
// // //       }

// // //       final rides = snapshot.value as Map<dynamic, dynamic>;
// // //       final now = DateTime.now();
// // //       final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
// // //       final startOfDay = DateTime(now.year, now.month, now.day);

// // //       int completed = 0;
// // //       int cancelled = 0;
// // //       int weekCompleted = 0;
// // //       int weekCancelled = 0;
// // //       int dayCompleted = 0;
// // //       int dayCancelled = 0;
// // //       double totalEarnings = 0.0;
// // //       double weekEarnings = 0.0;
// // //       double dayEarnings = 0.0;

// // //       for (var entry in rides.entries) {
// // //         final ride = entry.value as Map;
// // //         final status = ride['status'] as String? ?? '';
// // //         final fare = double.tryParse((ride['fare'] ?? '0').toString()) ?? 0;
// // //         final rideTime = ride['endedAt'] != null
// // //             ? DateTime.fromMillisecondsSinceEpoch(ride['endedAt'])
// // //             : now;

// // //         if (status == 'completed') {
// // //           completed++;
// // //           totalEarnings += fare;
// // //           if (rideTime.isAfter(startOfWeek)) {
// // //             weekCompleted++;
// // //             weekEarnings += fare;
// // //           }
// // //           if (rideTime.isAfter(startOfDay)) {
// // //             dayCompleted++;
// // //             dayEarnings += fare;
// // //           }
// // //         } else if (status == 'cancelled') {
// // //           cancelled++;
// // //           if (rideTime.isAfter(startOfWeek)) weekCancelled++;
// // //           if (rideTime.isAfter(startOfDay)) dayCancelled++;
// // //         }
// // //       }

// // //       setState(() {
// // //         totalCompleted = completed;
// // //         totalCancelled = cancelled;
// // //         weeklyCompleted = weekCompleted;
// // //         weeklyCancelled = weekCancelled;
// // //         dailyCompleted = dayCompleted;
// // //         dailyCancelled = dayCancelled;
// // //         totalCompletedEarnings = totalEarnings;
// // //         weeklyCompletedEarnings = weekEarnings;
// // //         dailyCompletedEarnings = dayEarnings;
// // //         loadingMetrics = false;
// // //       });
// // //     } catch (e) {
// // //       debugPrint('Error fetching dashboard metrics: $e');
// // //       setState(() => loadingMetrics = false);
// // //     }
// // //   }
// // //   Future<void> updateDriverAvailability(
// // //     String firebaseUid,
// // //     bool isOnline,
// // //   ) async {
// // //     final url = Uri.parse('$baseUrl/rides/updatedriver-status/$firebaseUid');

// // //     try {
// // //       final response = await Dio().put(
// // //         url.toString(),
// // //         data: isOnline,
// // //         options: Options(headers: {'Content-Type': 'application/json'}),
// // //       );

// // //       if (response.statusCode == 200) {
// // //         DriverLocationService().startSendingLocation();
// // //         print("✅ Driver availability updated: ${response.data}");
// // //       } else {
// // //         print("❌ Failed to update availability: ${response.statusCode}");
// // //       }
// // //     } catch (e) {
// // //       print("❌ Error updating availability: $e");
// // //     }
// // //   }

// // //   // Future<void> _toggleDriverStatus() async {
// // //   //   final user = FirebaseAuth.instance.currentUser;
// // //   //   if (user == null) {
// // //   //     ScaffoldMessenger.of(context).showSnackBar(
// // //   //       const SnackBar(content: Text('User not logged in')),
// // //   //     );
// // //   //     return;
// // //   //   }

// // //   //   final isOnline = ref.read(homeScreenIsDriverActiveProvider);
// // //   //   if (!isOnline) {
// // //   //     await HomeLogics().getDriverOnline(context, ref);
// // //   //   } else {
// // //   //     await HomeLogics().getDriverOffline(context, ref);
// // //   //   }
// // //   // }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         title: const Text('Driver Dashboard'),
// // //         backgroundColor: Colors.deepPurple,
// // //         centerTitle: true,
// // //       ),
// // //       body: SafeArea(
// // //         child: Padding(
// // //           padding: const EdgeInsets.all(16),
// // //           child: loadingMetrics
// // //               ? const Center(child: CircularProgressIndicator())
// // //               : Column(
// // //                   children: [
// // //                     _buildStatusBadge(isOnline),
// // //                     const SizedBox(height: 16),
// // //                     _buildToggleButton(isOnline),
// // //                     const SizedBox(height: 16),
// // //                     Expanded(child: _buildDashboardGrid()),
// // //                     const SizedBox(height: 16),
// // //                     _buildBarChartPlaceholder(),
// // //                   ],
// // //                 ),
// // //         ),
// // //       ),
// // //     );
// // //   }

// // //   Widget _buildStatusBadge(bool isOnline) {
// // //     return Container(
// // //       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// // //       decoration: BoxDecoration(
// // //         color: isOnline ? Colors.green : Colors.red,
// // //         borderRadius: BorderRadius.circular(12),
// // //         boxShadow: const [
// // //           BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
// // //         ],
// // //       ),
// // //       child: Row(
// // //         mainAxisSize: MainAxisSize.min,
// // //         children: [
// // //           Icon(
// // //             isOnline ? Icons.check_circle : Icons.cancel,
// // //             color: Colors.white,
// // //           ),
// // //           const SizedBox(width: 10),
// // //           Text(
// // //             isOnline ? 'You are Online' : 'You are Offline',
// // //             style: const TextStyle(
// // //               color: Colors.white,
// // //               fontSize: 16,
// // //               fontWeight: FontWeight.bold,
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }

// // //   Widget _buildToggleButton(bool isOnline) {
// // //     return GestureDetector(
// // //       onTap: updateDriverAvailability(),
// // //       child: Container(
// // //         alignment: Alignment.center,
// // //         width: double.infinity,
// // //         height: 45,
// // //         decoration: BoxDecoration(
// // //           color: isOnline ? Colors.red : Colors.green,
// // //           borderRadius: BorderRadius.circular(10),
// // //         ),
// // //         child: Text(
// // //           isOnline ? 'Go Offline' : 'Go Online',
// // //           style: const TextStyle(
// // //             color: Colors.white,
// // //             fontWeight: FontWeight.bold,
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }

// // //   Widget _buildDashboardGrid() {
// // //     return GridView.count(
// // //       crossAxisCount: 2,
// // //       crossAxisSpacing: 12,
// // //       mainAxisSpacing: 12,
// // //       childAspectRatio: 1.2,
// // //       children: [
// // //         _buildMetricTile(
// // //           'Total Completed',
// // //           totalCompleted,
// // //           totalCompletedEarnings,
// // //           Colors.green,
// // //           Icons.check_circle,
// // //         ),
// // //         _buildMetricTile(
// // //           'Total Cancelled',
// // //           totalCancelled,
// // //           0,
// // //           Colors.red,
// // //           Icons.cancel,
// // //         ),
// // //         _buildMetricTile(
// // //           'Weekly Completed',
// // //           weeklyCompleted,
// // //           weeklyCompletedEarnings,
// // //           Colors.blue,
// // //           Icons.calendar_today,
// // //         ),
// // //         _buildMetricTile(
// // //           'Weekly Cancelled',
// // //           weeklyCancelled,
// // //           0,
// // //           Colors.orange,
// // //           Icons.event_busy,
// // //         ),
// // //         _buildMetricTile(
// // //           'Daily Completed',
// // //           dailyCompleted,
// // //           dailyCompletedEarnings,
// // //           Colors.purple,
// // //           Icons.today,
// // //         ),
// // //         _buildMetricTile(
// // //           'Daily Cancelled',
// // //           dailyCancelled,
// // //           0,
// // //           Colors.brown,
// // //           Icons.block,
// // //         ),
// // //       ],
// // //     );
// // //   }

// // //   Widget _buildMetricTile(String title, int count, double earnings, Color color, IconData icon) {
// // //     return Container(
// // //       padding: const EdgeInsets.all(16),
// // //       decoration: BoxDecoration(
// // //         color: color.withOpacity(0.15),
// // //         borderRadius: BorderRadius.circular(12),
// // //       ),
// // //       child: Column(
// // //         mainAxisAlignment: MainAxisAlignment.center,
// // //         crossAxisAlignment: CrossAxisAlignment.center,
// // //         children: [
// // //           Icon(icon, color: color, size: 32),
// // //           const SizedBox(height: 8),
// // //           Text(title,
// // //               textAlign: TextAlign.center,
// // //               style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
// // //           const SizedBox(height: 6),
// // //           Text('$count rides',
// // //               textAlign: TextAlign.center,
// // //               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
// // //           if (earnings > 0) ...[
// // //             const SizedBox(height: 4),
// // //             Text('KES ${earnings.toStringAsFixed(2)}',
// // //                 textAlign: TextAlign.center,
// // //                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
// // //           ],
// // //         ],
// // //       ),
// // //     );
// // //   }

// // //   Widget _buildBarChartPlaceholder() {
// // //     return Container(
// // //       height: 180,
// // //       width: double.infinity,
// // //       decoration: BoxDecoration(
// // //         color: Colors.grey[200],
// // //         borderRadius: BorderRadius.circular(12),
// // //       ),
// // //       alignment: Alignment.center,
// // //       child: const Text(
// // //         'Bar Chart Placeholder\n(Integrate charts_flutter or fl_chart)',
// // //         textAlign: TextAlign.center,
// // //         style: TextStyle(color: Colors.grey, fontSize: 16),
// // //       ),
// // //     );
// // //   }
// // // }

// // // // import 'dart:async';
// // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // import 'package:firebase_database/firebase_database.dart';
// // // // import 'package:flutter/material.dart';
// // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';

// // // // class HomeScreen extends ConsumerStatefulWidget {
// // // //   const HomeScreen({super.key});

// // // //   @override
// // // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // // }

// // // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // // //   // Dashboard metrics
// // // //   int totalCompleted = 0;
// // // //   int totalCancelled = 0;
// // // //   int weeklyCompleted = 0;
// // // //   int weeklyCancelled = 0;
// // // //   int dailyCompleted = 0;
// // // //   int dailyCancelled = 0;
// // // //   double totalEarnings = 0.0;
// // // //   bool loadingMetrics = true;

// // // //   @override
// // // //   void initState() {
// // // //     super.initState();
// // // //     _fetchDashboardMetrics();
// // // //   }

// // // //   Future<void> _fetchDashboardMetrics() async {
// // // //     try {
// // // //       final user = FirebaseAuth.instance.currentUser;
// // // //       if (user == null) return;

// // // //       final snapshot =
// // // //           await FirebaseDatabase.instance
// // // //               .ref('rides')
// // // //               .orderByChild('driverId')
// // // //               .equalTo(user.uid)
// // // //               .get();

// // // //       if (!snapshot.exists) return;

// // // //       final rides = snapshot.value as Map<dynamic, dynamic>;

// // // //       final now = DateTime.now();
// // // //       final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
// // // //       final startOfDay = DateTime(now.year, now.month, now.day);

// // // //       int completed = 0;
// // // //       int cancelled = 0;
// // // //       int weekCompleted = 0;
// // // //       int weekCancelled = 0;
// // // //       int dayCompleted = 0;
// // // //       int dayCancelled = 0;
// // // //       double earnings = 0.0;

// // // //       for (var entry in rides.entries) {
// // // //         final ride = entry.value as Map;
// // // //         final status = ride['status'] as String? ?? '';
// // // //         final fare = double.tryParse((ride['fare'] ?? '0').toString()) ?? 0;
// // // //         final rideTime =
// // // //             ride['endedAt'] != null
// // // //                 ? DateTime.fromMillisecondsSinceEpoch(ride['endedAt'])
// // // //                 : now;

// // // //         if (status == 'completed') {
// // // //           completed++;
// // // //           earnings += fare;
// // // //           if (rideTime.isAfter(startOfWeek)) weekCompleted++;
// // // //           if (rideTime.isAfter(startOfDay)) dayCompleted++;
// // // //         } else if (status == 'cancelled') {
// // // //           cancelled++;
// // // //           if (rideTime.isAfter(startOfWeek)) weekCancelled++;
// // // //           if (rideTime.isAfter(startOfDay)) dayCancelled++;
// // // //         }
// // // //       }

// // // //       setState(() {
// // // //         totalCompleted = completed;
// // // //         totalCancelled = cancelled;
// // // //         weeklyCompleted = weekCompleted;
// // // //         weeklyCancelled = weekCancelled;
// // // //         dailyCompleted = dayCompleted;
// // // //         dailyCancelled = dayCancelled;
// // // //         totalEarnings = earnings;
// // // //         loadingMetrics = false;
// // // //       });
// // // //     } catch (e) {
// // // //       debugPrint('Error fetching dashboard metrics: $e');
// // // //     }
// // // //   }

// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// // // //     return Scaffold(
// // // //       appBar: AppBar(
// // // //         title: const Text('Driver Dashboard'),
// // // //         backgroundColor: Colors.yellow[700],
// // // //       ),
// // // //       body: SafeArea(
// // // //         child: Padding(
// // // //           padding: const EdgeInsets.all(16),
// // // //           child:
// // // //               loadingMetrics
// // // //                   ? const Center(child: CircularProgressIndicator())
// // // //                   : Column(
// // // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // // //                     children: [
// // // //                       _buildStatusBadge(isOnline),
// // // //                       const SizedBox(height: 20),
// // // //                       // _buildToggleButton(isOnline),
// // // //                       const SizedBox(height: 20),
// // // //                       Expanded(child: _buildDashboardGrid()),
// // // //                     ],
// // // //                   ),
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }

// // // //   Widget _buildStatusBadge(bool isOnline) {
// // // //     return Container(
// // // //       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// // // //       decoration: BoxDecoration(
// // // //         color: isOnline ? Colors.green : Colors.red,
// // // //         borderRadius: BorderRadius.circular(12),
// // // //         boxShadow: const [
// // // //           BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
// // // //         ],
// // // //       ),
// // // //       child: Row(
// // // //         mainAxisSize: MainAxisSize.min,
// // // //         children: [
// // // //           Icon(
// // // //             isOnline ? Icons.check_circle : Icons.cancel,
// // // //             color: Colors.white,
// // // //           ),
// // // //           const SizedBox(width: 10),
// // // //           Text(
// // // //             isOnline ? 'You are Online' : 'You are Offline',
// // // //             style: const TextStyle(
// // // //               color: Colors.white,
// // // //               fontSize: 16,
// // // //               fontWeight: FontWeight.bold,
// // // //             ),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //     );
// // // //   }

// // // //   // Widget _buildToggleButton(bool isOnline) {
// // // //   //   return GestureDetector(
// // // //   //     onTap: () async {
// // // //   //       if (!mounted) return;

// // // //   //       final user = FirebaseAuth.instance.currentUser;
// // // //   //       if (user == null) {
// // // //   //         ScaffoldMessenger.of(
// // // //   //           context,
// // // //   //         ).showSnackBar(const SnackBar(content: Text('User not logged in')));
// // // //   //         return;
// // // //   //       }

// // // //   //       if (!isOnline) {
// // // //   //         await HomeLogics().getDriverOnline(context, ref,);
// // // //   //       } else {
// // // //   //         await HomeLogics().getDriverOffline(context, ref);
// // // //   //       }
// // // //   //     },
// // // //   //     child: Container(
// // // //   //       alignment: Alignment.center,
// // // //   //       width: double.infinity,
// // // //   //       height: 45,
// // // //   //       decoration: BoxDecoration(
// // // //   //         color: isOnline ? Colors.red : Colors.green,
// // // //   //         borderRadius: BorderRadius.circular(10),
// // // //   //       ),
// // // //   //       child: Text(
// // // //   //         isOnline ? 'Go Offline' : 'Go Online',
// // // //   //         style: const TextStyle(
// // // //   //           color: Colors.white,
// // // //   //           fontWeight: FontWeight.bold,
// // // //   //         ),
// // // //   //       ),
// // // //   //     ),
// // // //   //   );
// // // //   // }

// // // //   Widget _buildDashboardGrid() {
// // // //     return GridView.count(
// // // //       crossAxisCount: 2,
// // // //       crossAxisSpacing: 12,
// // // //       mainAxisSpacing: 12,
// // // //       childAspectRatio: 1.2,
// // // //       children: [
// // // //         _buildMetricTile(
// // // //           'Total Completed',
// // // //           totalCompleted.toString(),
// // // //           Colors.green,
// // // //         ),
// // // //         _buildMetricTile(
// // // //           'Total Cancelled',
// // // //           totalCancelled.toString(),
// // // //           Colors.red,
// // // //         ),
// // // //         _buildMetricTile(
// // // //           'Weekly Completed',
// // // //           weeklyCompleted.toString(),
// // // //           Colors.green.shade700,
// // // //         ),
// // // //         _buildMetricTile(
// // // //           'Weekly Cancelled',
// // // //           weeklyCancelled.toString(),
// // // //           Colors.red.shade700,
// // // //         ),
// // // //         _buildMetricTile(
// // // //           'Daily Completed',
// // // //           dailyCompleted.toString(),
// // // //           Colors.green.shade400,
// // // //         ),
// // // //         _buildMetricTile(
// // // //           'Daily Cancelled',
// // // //           dailyCancelled.toString(),
// // // //           Colors.red.shade400,
// // // //         ),
// // // //         _buildMetricTile(
// // // //           'Total Earnings',
// // // //           'KES ${totalEarnings.toStringAsFixed(2)}',
// // // //           Colors.orange,
// // // //         ),
// // // //       ],
// // // //     );
// // // //   }

// // // //   Widget _buildMetricTile(String title, String value, Color color) {
// // // //     return Container(
// // // //       padding: const EdgeInsets.all(16),
// // // //       decoration: BoxDecoration(
// // // //         color: color.withOpacity(0.15),
// // // //         borderRadius: BorderRadius.circular(12),
// // // //       ),
// // // //       child: Column(
// // // //         crossAxisAlignment: CrossAxisAlignment.start,
// // // //         children: [
// // // //           Text(
// // // //             title,
// // // //             style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
// // // //           ),
// // // //           const SizedBox(height: 8),
// // // //           Text(
// // // //             value,
// // // //             style: TextStyle(
// // // //               fontSize: 18,
// // // //               fontWeight: FontWeight.bold,
// // // //               color: color,
// // // //             ),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //     );
// // // //   }
// // // // }
// // // // // import 'dart:async';
// // // // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // // // import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
// // // // // import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
// // // // // import 'package:aminidriver/main.dart';
// // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // import 'package:geolocator/geolocator.dart';
// // // // // import 'package:go_router/go_router.dart';
// // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';

// // // // // class HomeScreen extends ConsumerStatefulWidget {
// // // // //   const HomeScreen({super.key});

// // // // //   @override
// // // // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // // // }

// // // // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // // // //   late final GoogleMapController _mapController;
// // // // //   LatLng _initialPosition = const LatLng(1.2921, 36.8219);
// // // // //   final messagingService = MessagingService();

// // // // //   final Set<Marker> _markers = {};
// // // // //   final Set<Circle> _circles = {};
// // // // //   final Set<Polyline> _polylines = {};
// // // // //   StreamSubscription<DatabaseEvent>? _driverLocationSub;
// // // // //   Timer? _rideCheckTimer;
// // // // //   DateTime? _lastCameraUpdate;

// // // // //   @override
// // // // //   void initState() {
// // // // //     super.initState();
// // // // //     _initializeHomeScreen();
// // // // //   }

// // // // //   Future<void> _initializeHomeScreen() async {
// // // // //     await _setInitialLocation();
// // // // //     await _initializeMessaging();
// // // // //     _listenToDriverLocation();

// // // // //     // Check ongoing trip once after build
// // // // //     // WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // //     //   checkOngoingTrip(context);
// // // // //     // });

// // // // //     // Periodic check for ride updates
// // // // //     // _rideCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
// // // // //     //   _checkPendingRide();
// // // // //     // });
// // // // //   }

// // // // //   Future<void> _initializeMessaging() async {
// // // // //     // Setup FCM once
// // // // //     await messagingService.checkInitialMessage(context, ref);
// // // // //     await messagingService.init(context, ref);

// // // // //     FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// // // // //       if (message.data.containsKey('rideId')) {
// // // // //         await savePendingRide(message.data, 300);
// // // // //         WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // //           _openRideScreen(message.data);
// // // // //         });
// // // // //       }
// // // // //     });

// // // // //     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// // // // //       if (message.data.containsKey('rideId')) {
// // // // //         await savePendingRide(message.data, 300);
// // // // //         WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // //           _openRideScreen(message.data);
// // // // //         });
// // // // //       }
// // // // //     });

// // // // //     final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
// // // // //     if (initialMessage != null && initialMessage.data.containsKey('rideId')) {
// // // // //       await savePendingRide(initialMessage.data, 300);
// // // // //       WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // //         _openRideScreen(initialMessage.data);
// // // // //       });
// // // // //     }
// // // // //   }

// // // // //   void _openRideScreen(Map<String, dynamic> data) {
// // // // //     final context = navigatorKey.currentContext;
// // // // //     if (context != null) context.push('/ride-alert', extra: data);
// // // // //   }

// // // // //   Future<void> _setInitialLocation() async {
// // // // //     try {
// // // // //       final pos = await Geolocator.getCurrentPosition();
// // // // //       _initialPosition = LatLng(pos.latitude, pos.longitude);
// // // // //       _addOrUpdateDriverMarker(_initialPosition);
// // // // //       setState(() {}); // Only once
// // // // //     } catch (e) {
// // // // //       debugPrint('Error fetching location: $e');
// // // // //     }
// // // // //   }

// // // // //   void _listenToDriverLocation() {
// // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // //     if (user == null) return;

// // // // //     final driverLocationRef = FirebaseDatabase.instance.ref(
// // // // //       "drivers/${user.uid}/location",
// // // // //     );

// // // // //     _driverLocationSub = driverLocationRef.onValue.listen((event) {
// // // // //       final data = event.snapshot.value as Map?;
// // // // //       if (data != null) {
// // // // //         final newPosition = LatLng(
// // // // //           (data['lat'] as num).toDouble(),
// // // // //           (data['lng'] as num).toDouble(),
// // // // //         );
// // // // //         _addOrUpdateDriverMarker(newPosition);
// // // // //         _animateCameraThrottled(newPosition);
// // // // //       }
// // // // //     });
// // // // //   }

// // // // //   Future<void> _animateCameraThrottled(LatLng position) async {
// // // // //     if (_lastCameraUpdate != null &&
// // // // //         DateTime.now().difference(_lastCameraUpdate!).inMilliseconds < 1500) {
// // // // //       return; // skip if too soon
// // // // //     }
// // // // //     _lastCameraUpdate = DateTime.now();
// // // // //     _mapController.animateCamera(
// // // // //       CameraUpdate.newCameraPosition(
// // // // //         CameraPosition(target: position, zoom: 16),
// // // // //       ),
// // // // //     );
// // // // //   }

// // // // //   void _addOrUpdateDriverMarker(LatLng position) {
// // // // //     _markers.removeWhere((m) => m.markerId.value == 'driver');
// // // // //     _markers.add(
// // // // //       Marker(
// // // // //         markerId: const MarkerId('driver'),
// // // // //         position: position,
// // // // //         infoWindow: const InfoWindow(title: 'You'),
// // // // //       ),
// // // // //     );
// // // // //   }

// // // // //   // Future<void> _checkPendingRide() async {
// // // // //   //   final pendingRide = await getPendingRide();
// // // // //   //   if (pendingRide == null && mounted) {
// // // // //   //     Navigator.push(
// // // // //   //       context,
// // // // //   //       MaterialPageRoute(builder: (_) => NavigationScreen()),
// // // // //   //     );
// // // // //   //   }
// // // // //   // }

// // // // //   // Future<void> checkOngoingTrip(BuildContext context) async {
// // // // //   //   final user = FirebaseAuth.instance.currentUser;
// // // // //   //   if (user == null) return;

// // // // //   //   final rideSnapshot =
// // // // //   //       await FirebaseDatabase.instance
// // // // //   //           .ref('rides')
// // // // //   //           .orderByChild('driverId')
// // // // //   //           .equalTo(user.uid)
// // // // //   //           .get();

// // // // //   //   if (!rideSnapshot.exists) return;

// // // // //   //   final rides = rideSnapshot.value as Map<dynamic, dynamic>;
// // // // //   //   final ongoingRide = rides.entries.firstWhere(
// // // // //   //     (entry) => entry.value['status'] == 'in-progress',
// // // // //   //     orElse: () => null,
// // // // //   //   );

// // // // //   //   if (ongoingRide != null) {
// // // // //   //     final pickupLat = ongoingRide.value['pickup']['lat'];
// // // // //   //     final pickupLng = ongoingRide.value['pickup']['lng'];
// // // // //   //     final destLat = ongoingRide.value['destination']['lat'];
// // // // //   //     final destLng = ongoingRide.value['destination']['lng'];

// // // // //   //     Navigator.pushReplacement(
// // // // //   //       context,
// // // // //   //       MaterialPageRoute(
// // // // //   //         builder:
// // // // //   //             (_) => LiveTrackingScreen(
// // // // //   //               rideId: ongoingRide.key,
// // // // //   //               pickup: LatLng(pickupLat, pickupLng),
// // // // //   //               destination: LatLng(destLat, destLng),
// // // // //   //             ),
// // // // //   //       ),
// // // // //   //     );
// // // // //   //   }
// // // // //   // }

// // // // //   void _onMapCreated(GoogleMapController controller) {
// // // // //     _mapController = controller;

// // // // //     // Load markers/circles/polylines from providers once
// // // // //     final markers = ref.read(homeScreenMainMarkersProviderOSM);
// // // // //     final circles = ref.read(homeScreenMainCirclesProviderOSM);
// // // // //     final polylines = ref.read(homeScreenMainPolylinesProviderOSM);

// // // // //     setState(() {
// // // // //       _markers.addAll(
// // // // //         markers.map(
// // // // //           (e) => Marker(
// // // // //             markerId: MarkerId(e.key.toString()),
// // // // //             position: LatLng(e.point.latitude, e.point.longitude),
// // // // //           ),
// // // // //         ),
// // // // //       );
// // // // //       _circles.addAll(
// // // // //         circles.map(
// // // // //           (e) => Circle(
// // // // //             circleId: CircleId(e.key.toString()),
// // // // //             center: LatLng(e.point.latitude, e.point.longitude),
// // // // //             radius: e.radius,
// // // // //             fillColor: e.color,
// // // // //             strokeColor: e.borderColor,
// // // // //             strokeWidth: e.borderStrokeWidth.toInt(),
// // // // //           ),
// // // // //         ),
// // // // //       );
// // // // //       _polylines.addAll(
// // // // //         polylines.asMap().entries.map((entry) {
// // // // //           final e = entry.value;
// // // // //           return Polyline(
// // // // //             polylineId: PolylineId('polyline_${entry.key}'),
// // // // //             points:
// // // // //                 e.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
// // // // //             color: e.color,
// // // // //             width: e.strokeWidth.toInt(),
// // // // //           );
// // // // //         }),
// // // // //       );
// // // // //     });
// // // // //   }

// // // // //   @override
// // // // //   void dispose() {
// // // // //     _rideCheckTimer?.cancel();
// // // // //     _driverLocationSub?.cancel();
// // // // //     super.dispose();
// // // // //   }

// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     final size = MediaQuery.sizeOf(context);
// // // // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// // // // //     return Scaffold(
// // // // //       body: SafeArea(
// // // // //         child: Stack(
// // // // //           children: [
// // // // //             GoogleMap(
// // // // //               initialCameraPosition: CameraPosition(
// // // // //                 target: _initialPosition,
// // // // //                 zoom: 14,
// // // // //               ),
// // // // //               onMapCreated: _onMapCreated,
// // // // //               markers: _markers,
// // // // //               circles: _circles,
// // // // //               polylines: _polylines,
// // // // //               myLocationEnabled: true,
// // // // //               myLocationButtonEnabled: true,
// // // // //               zoomControlsEnabled: false,
// // // // //             ),
// // // // //             if (!isOnline)
// // // // //               Container(
// // // // //                 width: size.width,
// // // // //                 height: size.height,
// // // // //                 color: Colors.black.withOpacity(0.6),
// // // // //               ),
// // // // //             Positioned(
// // // // //               top: isOnline ? 30 : size.height * 0.4,
// // // // //               left: 20,
// // // // //               right: 20,
// // // // //               child: Column(
// // // // //                 children: [
// // // // //                   _buildStatusBadge(isOnline),
// // // // //                   const SizedBox(height: 20),
// // // // //                   _buildToggleButton(isOnline),
// // // // //                 ],
// // // // //               ),
// // // // //             ),
// // // // //           ],
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }

// // // // //   Widget _buildStatusBadge(bool isOnline) {
// // // // //     return Container(
// // // // //       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// // // // //       decoration: BoxDecoration(
// // // // //         color: isOnline ? Colors.yellow[700] : Colors.blue,
// // // // //         borderRadius: BorderRadius.circular(12),
// // // // //         boxShadow: const [
// // // // //           BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
// // // // //         ],
// // // // //       ),
// // // // //       child: Row(
// // // // //         mainAxisSize: MainAxisSize.min,
// // // // //         children: [
// // // // //           Icon(
// // // // //             isOnline ? Icons.check_circle : Icons.cancel,
// // // // //             color: Colors.white,
// // // // //           ),
// // // // //           const SizedBox(width: 10),
// // // // //           Text(
// // // // //             isOnline ? 'You are Online' : 'You are Offline',
// // // // //             style: const TextStyle(
// // // // //               color: Colors.white,
// // // // //               fontSize: 16,
// // // // //               fontWeight: FontWeight.bold,
// // // // //             ),
// // // // //           ),
// // // // //         ],
// // // // //       ),
// // // // //     );
// // // // //   }

// // // // //   Widget _buildToggleButton(bool isOnline) {
// // // // //     return GestureDetector(
// // // // //       onTap: () async {
// // // // //         if (!mounted) return;

// // // // //         final user = FirebaseAuth.instance.currentUser;
// // // // //         if (user == null) {
// // // // //           ScaffoldMessenger.of(
// // // // //             context,
// // // // //           ).showSnackBar(const SnackBar(content: Text('User not logged in')));
// // // // //           return;
// // // // //         }

// // // // //         if (_initialPosition.latitude == 0.0 &&
// // // // //             _initialPosition.longitude == 0.0) {
// // // // //           ScaffoldMessenger.of(context).showSnackBar(
// // // // //             const SnackBar(content: Text('Fetching location. Please wait...')),
// // // // //           );
// // // // //           await _setInitialLocation(); // Try fetching location again
// // // // //           return;
// // // // //         }

// // // // //         if (!isOnline) {
// // // // //           await HomeLogics().getDriverOnline(context, ref, _mapController);
// // // // //         } else {
// // // // //           await HomeLogics().getDriverOffline(context, ref);
// // // // //         }
// // // // //       },
// // // // //       child: Container(
// // // // //         alignment: Alignment.center,
// // // // //         width: 180,
// // // // //         height: 45,
// // // // //         decoration: BoxDecoration(
// // // // //           color: isOnline ? Colors.blue : Colors.yellow,
// // // // //           borderRadius: BorderRadius.circular(10),
// // // // //         ),
// // // // //         child: Text(
// // // // //           isOnline ? 'Go Offline' : 'Go Online',
// // // // //           style: const TextStyle(
// // // // //             color: Colors.white,
// // // // //             fontWeight: FontWeight.bold,
// // // // //           ),
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }
// // // // // // import 'dart:async';
// // // // // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // // // // import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
// // // // // // import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
// // // // // // import 'package:aminidriver/main.dart';
// // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // // import 'package:flutter/material.dart';
// // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // import 'package:go_router/go_router.dart';
// // // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';

// // // // // // class HomeScreen extends ConsumerStatefulWidget {
// // // // // //   const HomeScreen({super.key});

// // // // // //   @override
// // // // // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // // // // }

// // // // // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // // // // //   //late GoogleMapController _mapController;
// // // // // //   final Completer<GoogleMapController> _mapControllerCompleter = Completer();

// // // // // //   LatLng _initialPosition = const LatLng(0.0, 0.0);
// // // // // //   final messagingService = MessagingService();

// // // // // //   final Set<Marker> _markers = {};
// // // // // //   final Set<Circle> _circles = {};
// // // // // //   final Set<Polyline> _polylines = {};
// // // // // //   Timer? _rideCheckTimer;
// // // // // //   @override
// // // // // //   void initState() {
// // // // // //     super.initState();
// // // // // //     _setInitialLocation();
// // // // // //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // //       checkOngoingTrip(context);
// // // // // //     });

// // // // // //     _rideCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
// // // // // //       WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
// // // // // //       //_initialize(); //setupFCM();
// // // // // //       // _checkPendingRide();
// // // // // //     });
// // // // // //     // WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());

// // // // // //     //_listenToDriverLocation();
// // // // // //   }

// // // // // //   void setupFCM() {
// // // // // //     // 🚀 When user taps a notification while app is in background
// // // // // //     FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// // // // // //       if (message.data.containsKey('rideId')) {
// // // // // //         await savePendingRide(message.data, 300);
// // // // // //         WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // //           _openRideScreen(message.data);
// // // // // //         });
// // // // // //         //_openRideScreen(message.data);
// // // // // //       }
// // // // // //       // else {
// // // // // //       //   _openMessagesScreen();
// // // // // //       // }
// // // // // //     });

// // // // // //     // 🚀 When app was terminated and opened via a notification (cold start)
// // // // // //     FirebaseMessaging.instance.getInitialMessage().then((message) async {
// // // // // //       if (message != null && message.data.containsKey('rideId')) {
// // // // // //         await savePendingRide(message.data, 300);
// // // // // //         WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // //           _openRideScreen(message.data);
// // // // // //         });
// // // // // //         //_openRideScreen(message.data);
// // // // // //       }
// // // // // //     });

// // // // // //     // 🚀 Foreground messages
// // // // // //     // FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// // // // // //     //   if (message.data.containsKey('rideId')) {
// // // // // //     //     await savePendingRide(message.data, 300);
// // // // // //     //     _openRideScreen(message.data);
// // // // // //     //   }
// // // // // //     // });

// // // // // //     FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// // // // // //       if (message.data.containsKey('rideId')) {
// // // // // //         await savePendingRide(message.data, 300);
// // // // // //         WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // //           _openRideScreen(message.data);
// // // // // //         });
// // // // // //       }
// // // // // //     });
// // // // // //   }

// // // // // //   void _openRideScreen(Map<String, dynamic> data) {
// // // // // //     final context = navigatorKey.currentContext;
// // // // // //     if (context == null) return;

// // // // // //     context.push('/ride-alert', extra: data);
// // // // // //   }

// // // // // //   Future<void> _setInitialLocation() async {
// // // // // //     final pos = await Geolocator.getCurrentPosition();
// // // // // //     final initialLatLng = LatLng(pos.latitude, pos.longitude);
// // // // // //     setState(() {
// // // // // //       _initialPosition = initialLatLng;
// // // // // //       _addOrUpdateDriverMarker(initialLatLng);
// // // // // //     });
// // // // // //   }

// // // // // //   Future<void> _checkPendingRide() async {
// // // // // //     final pendingRide = await getPendingRide();
// // // // // //     if (pendingRide == null) {
// // // // // //       if (!mounted) return;
// // // // // //       Navigator.pushReplacement(
// // // // // //         context,
// // // // // //         MaterialPageRoute(builder: (_) => NavigationScreen()),
// // // // // //       );
// // // // // //     }
// // // // // //   }

// // // // // //   // Future<void> _checkRideAlert() async {
// // // // // //   //   final user = FirebaseAuth.instance.currentUser;
// // // // // //   //   if (user == null) return;

// // // // // //   //   final rideSnapshot =
// // // // // //   //       await FirebaseDatabase.instance
// // // // // //   //           .ref('rides')
// // // // // //   //           .orderByChild('driverId')
// // // // // //   //           .equalTo(user.uid)
// // // // // //   //           .get();

// // // // // //   //   if (!rideSnapshot.exists) return;

// // // // // //   //   final rides = rideSnapshot.value as Map<dynamic, dynamic>;

// // // // // //   //   // Look for new ride requests that are "pending"
// // // // // //   //   final pendingRides = rides.entries.where(
// // // // // //   //     (entry) => entry.value['status'] == 'pending',
// // // // // //   //   );

// // // // // //   //   if (pendingRides.isNotEmpty) {
// // // // // //   //     final ride = pendingRides.first;
// // // // // //   //     final rideId = ride.key;
// // // // // //   //     final pickup = ride.value['pickup'];
// // // // // //   //     final destination = ride.value['destination'];
// // // // // //   //     final rider = ride.value['riderName'] ?? 'Rider';

// // // // // //   //     // Show RideAlertScreen only if not already visible
// // // // // //   //     if (mounted) {
// // // // // //   //       Navigator.push(
// // // // // //   //         context,
// // // // // //   //         MaterialPageRoute(
// // // // // //   //           builder:
// // // // // //   //               (_) => RideAlertScreen(
// // // // // //   //                 rideId: rideId,
// // // // // //   //                 rider: rider,
// // // // // //   //                 pickupName: pickup['name'],
// // // // // //   //                 destinationName: destination['name'],
// // // // // //   //                 pickupLat: pickup['lat'],
// // // // // //   //                 pickupLng: pickup['lng'],
// // // // // //   //                 destLat: destination['lat'],
// // // // // //   //                 destLng: destination['lng'],
// // // // // //   //               ),
// // // // // //   //         ),
// // // // // //   //       );
// // // // // //   //     }
// // // // // //   //   }
// // // // // //   // }

// // // // // //   Future<void> checkOngoingTrip(BuildContext context) async {
// // // // // //     final userId = FirebaseAuth.instance.currentUser;

// // // // // //     if (userId != null) {
// // // // // //       final rideSnapshot =
// // // // // //           await FirebaseDatabase.instance
// // // // // //               .ref('rides')
// // // // // //               .orderByChild('driverId')
// // // // // //               .equalTo(userId.uid)
// // // // // //               .get();

// // // // // //       if (rideSnapshot.exists) {
// // // // // //         final rides = rideSnapshot.value as Map<dynamic, dynamic>;

// // // // // //         // Find ongoing ride
// // // // // //         final ongoingRides = rides.entries.where(
// // // // // //           (entry) => entry.value['status'] == 'in-progress',
// // // // // //         );

// // // // // //         if (ongoingRides.isNotEmpty) {
// // // // // //           final ongoingRide = ongoingRides.first;

// // // // // //           final rideId = ongoingRide.key;
// // // // // //           final pickupLat = ongoingRide.value['pickup']['lat'];
// // // // // //           final pickupLng = ongoingRide.value['pickup']['lng'];
// // // // // //           final destLat = ongoingRide.value['destination']['lat'];
// // // // // //           final destLng = ongoingRide.value['destination']['lng'];

// // // // // //           // Navigate to LiveTrackingScreen
// // // // // //           Navigator.pushReplacement(
// // // // // //             context,
// // // // // //             MaterialPageRoute(
// // // // // //               builder:
// // // // // //                   (_) => LiveTrackingScreen(
// // // // // //                     rideId: rideId,
// // // // // //                     pickup: LatLng(pickupLat, pickupLng),
// // // // // //                     destination: LatLng(destLat, destLng),
// // // // // //                   ),
// // // // // //             ),
// // // // // //           );
// // // // // //         }
// // // // // //       }
// // // // // //     }
// // // // // //   }

// // // // // //   void _addOrUpdateDriverMarker(LatLng position) {
// // // // // //     _markers.removeWhere((m) => m.markerId.value == 'driver');
// // // // // //     _markers.add(
// // // // // //       Marker(
// // // // // //         markerId: const MarkerId('driver'),
// // // // // //         position: position,
// // // // // //         infoWindow: const InfoWindow(title: "You"),
// // // // // //       ),
// // // // // //     );
// // // // // //   }

// // // // // //   Future<void> _initialize() async {
// // // // // //     await messagingService.checkInitialMessage(context, ref);

// // // // // //     // if (!mounted) return;
// // // // // //     // await HomeLogics().fetchAndUpdateDriverStatus(ref);

// // // // // //     if (!mounted) return;
// // // // // //     await messagingService.init(context, ref);

// // // // // //     // if (!mounted) return;
// // // // // //     // await _setInitialLocation();

// // // // // //     _listenToDriverLocation();
// // // // // //   }

// // // // // //   // Future<void> _setInitialLocation() async {
// // // // // //   //   try {
// // // // // //   //     final pos = await Geolocator.getCurrentPosition();
// // // // // //   //     final initialLatLng = LatLng(pos.latitude, pos.longitude);

// // // // // //   //     setState(() {
// // // // // //   //       _initialPosition = initialLatLng;
// // // // // //   //       _addOrUpdateDriverMarker(initialLatLng);
// // // // // //   //     });

// // // // // //   //     final firestoreRepo = ref.read(globalFirestoreRepoProvider);
// // // // // //   //     await firestoreRepo.getDriverDetails(context);
// // // // // //   //   } catch (e) {
// // // // // //   //     print("Location error: $e");
// // // // // //   //   }
// // // // // //   // }

// // // // // //   // void _listenToDriverLocation() {
// // // // // //   //   // final uid = FirebaseAuth.instance.currentUser?.uid;
// // // // // //   //   // if (uid == null) return;
// // // // // //   //   final user = FirebaseAuth.instance.currentUser;
// // // // // //   //   if (user == null) {
// // // // // //   //     ScaffoldMessenger.of(
// // // // // //   //       context,
// // // // // //   //     ).showSnackBar(const SnackBar(content: Text("User not logged in")));
// // // // // //   //     return;
// // // // // //   //   }
// // // // // //   //   final uid = user.uid;

// // // // // //   //   final driverLocationRef = FirebaseDatabase.instance.ref(
// // // // // //   //     "drivers/$uid/location",
// // // // // //   //   );

// // // // // //   //   driverLocationRef.onValue.listen((event) {
// // // // // //   //     final data = event.snapshot.value as Map?;
// // // // // //   //     if (data != null && mounted) {
// // // // // //   //       final lat = (data['lat'] as num).toDouble();
// // // // // //   //       final lng = (data['lng'] as num).toDouble();
// // // // // //   //       final newPosition = LatLng(lat, lng);

// // // // // //   //       setState(() {
// // // // // //   //         _initialPosition = newPosition;
// // // // // //   //         _addOrUpdateDriverMarker(newPosition);
// // // // // //   //       });

// // // // // //   //       _animateCameraThrottled(newPosition);
// // // // // //   //     }
// // // // // //   //   });
// // // // // //   // }

// // // // // //   StreamSubscription<DatabaseEvent>? _driverLocationSub;

// // // // // //   void _listenToDriverLocation() {
// // // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // // //     if (user == null) return;

// // // // // //     final uid = user.uid;
// // // // // //     final driverLocationRef = FirebaseDatabase.instance.ref(
// // // // // //       "drivers/$uid/location",
// // // // // //     );

// // // // // //     _driverLocationSub = driverLocationRef.onValue.listen((event) {
// // // // // //       if (!mounted) return; // <--- check mounted before using setState
// // // // // //       final data = event.snapshot.value as Map?;
// // // // // //       if (data != null) {
// // // // // //         final lat = (data['lat'] as num).toDouble();
// // // // // //         final lng = (data['lng'] as num).toDouble();
// // // // // //         final newPosition = LatLng(lat, lng);

// // // // // //         setState(() {
// // // // // //           _initialPosition = newPosition;
// // // // // //           _addOrUpdateDriverMarker(newPosition);
// // // // // //         });

// // // // // //         _animateCameraThrottled(newPosition);
// // // // // //       }
// // // // // //     });
// // // // // //   }

// // // // // //   DateTime? _lastCameraUpdate;

// // // // // //   Future<void> _animateCameraThrottled(LatLng position) async {
// // // // // //     if (!_mapControllerCompleter.isCompleted) return;

// // // // // //     final now = DateTime.now();
// // // // // //     if (_lastCameraUpdate != null &&
// // // // // //         now.difference(_lastCameraUpdate!).inMilliseconds < 1500) {
// // // // // //       return; // skip if too soon
// // // // // //     }
// // // // // //     _lastCameraUpdate = now;

// // // // // //     final controller = await _mapControllerCompleter.future;
// // // // // //     controller.animateCamera(CameraUpdate.newLatLng(position));
// // // // // //   }

// // // // // //   // void _listenToDriverLocation() {
// // // // // //   //   final driverLocationRef = FirebaseDatabase.instance.ref(
// // // // // //   //     "drivers/driverId/location",
// // // // // //   //   );

// // // // // //   //   driverLocationRef.onValue.listen((event) async {
// // // // // //   //     final data = event.snapshot.value as Map?;
// // // // // //   //     if (data != null && mounted) {
// // // // // //   //       final lat = (data['latitude'] as num).toDouble();
// // // // // //   //       final lng = (data['longitude'] as num).toDouble();
// // // // // //   //       final newPosition = LatLng(lat, lng);

// // // // // //   //       setState(() {
// // // // // //   //         _initialPosition = newPosition;
// // // // // //   //         _addOrUpdateDriverMarker(newPosition);
// // // // // //   //       });

// // // // // //   //       await _animateCamera(newPosition); // Safe now
// // // // // //   //     }
// // // // // //   //   });
// // // // // //   // }

// // // // // //   // Future<void> _animateCamera(LatLng position) async {
// // // // // //   //   final controller = await _mapControllerCompleter.future;
// // // // // //   //   controller.animateCamera(CameraUpdate.newLatLng(position));
// // // // // //   // }
// // // // // //   // @override
// // // // // //   // void dispose() {
// // // // // //   //   _driverLocationSub?.cancel(); // stop listening when widget unmounts
// // // // // //   //   super.dispose();
// // // // // //   // }

// // // // // //   Future<void> _animateCamera(LatLng position) async {
// // // // // //     if (!_mapControllerCompleter.isCompleted) return;
// // // // // //     final controller = await _mapControllerCompleter.future;
// // // // // //     controller.animateCamera(
// // // // // //       CameraUpdate.newCameraPosition(
// // // // // //         CameraPosition(target: position, zoom: 16), // keep a stable zoom
// // // // // //       ),
// // // // // //     );
// // // // // //   }

// // // // // //   void _onMapCreated(GoogleMapController controller) {
// // // // // //     _mapControllerCompleter.complete(controller);

// // // // // //     final markers = ref.read(homeScreenMainMarkersProviderOSM);
// // // // // //     final circles = ref.read(homeScreenMainCirclesProviderOSM);
// // // // // //     final polylines = ref.read(homeScreenMainPolylinesProviderOSM);

// // // // // //     setState(() {
// // // // // //       _markers.addAll(
// // // // // //         markers.map(
// // // // // //           (e) => Marker(
// // // // // //             markerId: MarkerId(e.key.toString()),
// // // // // //             position: LatLng(e.point.latitude, e.point.longitude),
// // // // // //           ),
// // // // // //         ),
// // // // // //       );

// // // // // //       _circles.addAll(
// // // // // //         circles.map(
// // // // // //           (e) => Circle(
// // // // // //             circleId: CircleId(e.key.toString()),
// // // // // //             center: LatLng(e.point.latitude, e.point.longitude),
// // // // // //             radius: e.radius,
// // // // // //             fillColor: e.color,
// // // // // //             strokeColor: e.borderColor,
// // // // // //             strokeWidth: e.borderStrokeWidth.toInt(),
// // // // // //           ),
// // // // // //         ),
// // // // // //       );

// // // // // //       _polylines.addAll(
// // // // // //         polylines.asMap().entries.map((entry) {
// // // // // //           final e = entry.value;
// // // // // //           return Polyline(
// // // // // //             polylineId: PolylineId('polyline_${entry.key}'),
// // // // // //             points:
// // // // // //                 e.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
// // // // // //             color: e.color,
// // // // // //             width: e.strokeWidth.toInt(),
// // // // // //           );
// // // // // //         }),
// // // // // //       );
// // // // // //     });
// // // // // //   }

// // // // // //   @override
// // // // // //   void dispose() {
// // // // // //     _rideCheckTimer?.cancel();
// // // // // //     _driverLocationSub?.cancel();
// // // // // //     super.dispose();
// // // // // //   }

// // // // // //   @override
// // // // // //   Widget build(BuildContext context) {
// // // // // //     final size = MediaQuery.sizeOf(context);
// // // // // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// // // // // //     return Scaffold(
// // // // // //       body: SafeArea(
// // // // // //         child: Stack(
// // // // // //           children: [
// // // // // //             GoogleMap(
// // // // // //               initialCameraPosition: CameraPosition(
// // // // // //                 target: _initialPosition,
// // // // // //                 zoom: 14,
// // // // // //               ),
// // // // // //               onMapCreated: _onMapCreated,
// // // // // //               markers: _markers,
// // // // // //               circles: _circles,
// // // // // //               polylines: _polylines,
// // // // // //               myLocationEnabled: true,
// // // // // //               myLocationButtonEnabled: true,
// // // // // //               zoomControlsEnabled: false,
// // // // // //             ),
// // // // // //             if (!isOnline)
// // // // // //               Container(
// // // // // //                 width: size.width,
// // // // // //                 height: size.height,
// // // // // //                 color: Colors.black.withOpacity(0.6),
// // // // // //               ),
// // // // // //             Positioned(
// // // // // //               top: isOnline ? 30 : size.height * 0.4,
// // // // // //               left: 20,
// // // // // //               right: 20,
// // // // // //               child: Column(
// // // // // //                 children: [
// // // // // //                   _buildStatusBadge(isOnline),
// // // // // //                   const SizedBox(height: 20),
// // // // // //                   _buildToggleButton(isOnline),
// // // // // //                 ],
// // // // // //               ),
// // // // // //             ),
// // // // // //           ],
// // // // // //         ),
// // // // // //       ),
// // // // // //     );
// // // // // //   }

// // // // // //   Widget _buildStatusBadge(bool isOnline) {
// // // // // //     return Container(
// // // // // //       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
// // // // // //       decoration: BoxDecoration(
// // // // // //         color: isOnline ? Colors.yellow[700] : Colors.blue,
// // // // // //         borderRadius: BorderRadius.circular(12),
// // // // // //         boxShadow: const [
// // // // // //           BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
// // // // // //         ],
// // // // // //       ),
// // // // // //       child: Row(
// // // // // //         mainAxisSize: MainAxisSize.min,
// // // // // //         children: [
// // // // // //           Icon(
// // // // // //             isOnline ? Icons.check_circle : Icons.cancel,
// // // // // //             color: Colors.white,
// // // // // //           ),
// // // // // //           const SizedBox(width: 10),
// // // // // //           Text(
// // // // // //             isOnline ? 'You are Online' : 'You are Offline',
// // // // // //             style: const TextStyle(
// // // // // //               color: Colors.white,
// // // // // //               fontSize: 16,
// // // // // //               fontWeight: FontWeight.bold,
// // // // // //             ),
// // // // // //           ),
// // // // // //         ],
// // // // // //       ),
// // // // // //     );
// // // // // //   }

// // // // // //   Widget _buildToggleButton(bool isOnline) {
// // // // // //     return GestureDetector(
// // // // // //       // onTap: () async {
// // // // // //       //   if (!isOnline) {
// // // // // //       //     await HomeLogics().getDriverOnline(context, ref, _mapController);
// // // // // //       //   } else {
// // // // // //       //     await HomeLogics().getDriverOffline(context, ref);
// // // // // //       //   }
// // // // // //       // },
// // // // // //       onTap: () async {
// // // // // //         final controller =
// // // // // //             await _mapControllerCompleter.future; // wait for map controller
// // // // // //         if (!isOnline) {
// // // // // //           await HomeLogics().getDriverOnline(context, ref, controller);
// // // // // //         } else {
// // // // // //           await HomeLogics().getDriverOffline(context, ref);
// // // // // //         }
// // // // // //       },
// // // // // //       child: Container(
// // // // // //         alignment: Alignment.center,
// // // // // //         width: 180,
// // // // // //         height: 45,
// // // // // //         decoration: BoxDecoration(
// // // // // //           color: isOnline ? Colors.blue : Colors.yellow,
// // // // // //           borderRadius: BorderRadius.circular(10),
// // // // // //         ),
// // // // // //         child: Text(
// // // // // //           isOnline ? 'Go Offline' : 'Go Online',
// // // // // //           style: const TextStyle(
// // // // // //             color: Colors.white,
// // // // // //             fontWeight: FontWeight.bold,
// // // // // //           ),
// // // // // //         ),
// // // // // //       ),
// // // // // //     );
// // // // // //   }
// // // // // // }
// // // // // // // import 'dart:async';
// // // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // // import 'package:flutter/material.dart';
// // // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';

// // // // // // // class HomeScreen extends ConsumerStatefulWidget {
// // // // // // //   const HomeScreen({super.key});

// // // // // // //   @override
// // // // // // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // // // // // }

// // // // // // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // // // // // //   late GoogleMapController _mapController;
// // // // // // //   LatLng _initialPosition = LatLng(0.0, 0.0);
// // // // // // //   final messagingService = MessagingService();

// // // // // // //   final Set<Marker> _markers = {};
// // // // // // //   final Set<Circle> _circles = {};
// // // // // // //   final Set<Polyline> _polylines = {};

// // // // // // //   @override
// // // // // // //   void initState() {
// // // // // // //     super.initState();
// // // // // // //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // // //       _initialize();
// // // // // // //     });
// // // // // // //   }

// // // // // // //   Future<void> _initialize() async {
// // // // // // //     await messagingService.checkInitialMessage(context, ref);

// // // // // // //     if (!mounted) return;
// // // // // // //     await HomeLogics().fetchAndUpdateDriverStatus(ref);

// // // // // // //     if (!mounted) return;
// // // // // // //     await messagingService.init(context, ref);

// // // // // // //     if (!mounted) return;
// // // // // // //     await _setInitialLocation();

// // // // // // //     _listenToDriverLocation();
// // // // // // //   }

// // // // // // //   void _listenToDriverLocation() {
// // // // // // //     // Reference to driver's location in Realtime DB
// // // // // // //     final driverLocationRef = FirebaseDatabase.instance.ref(
// // // // // // //       "drivers/driverId/location",
// // // // // // //     );

// // // // // // //     driverLocationRef.onValue.listen((event) {
// // // // // // //       final data = event.snapshot.value as Map?;
// // // // // // //       if (data != null && mounted) {
// // // // // // //         final lat = (data['latitude'] as num).toDouble();
// // // // // // //         final lng = (data['longitude'] as num).toDouble();
// // // // // // //         final newPosition = LatLng(lat, lng);

// // // // // // //         setState(() {
// // // // // // //           _initialPosition = newPosition;
// // // // // // //           _markers.clear();
// // // // // // //           _markers.add(
// // // // // // //             Marker(
// // // // // // //               markerId: const MarkerId('driver'),
// // // // // // //               position: newPosition,
// // // // // // //               infoWindow: const InfoWindow(title: "You"),
// // // // // // //             ),
// // // // // // //           );
// // // // // // //         });

// // // // // // //         // Center map on driver's location
// // // // // // //         _mapController.animateCamera(CameraUpdate.newLatLng(newPosition));
// // // // // // //       }
// // // // // // //     });
// // // // // // //   }

// // // // // // //   Future<void> _setInitialLocation() async {
// // // // // // //     try {
// // // // // // //       // 1️⃣ Get current device location
// // // // // // //       final pos = await Geolocator.getCurrentPosition();
// // // // // // //       setState(() {
// // // // // // //         _initialPosition = LatLng(pos.latitude, pos.longitude);

// // // // // // //         // Optional: place initial marker for driver
// // // // // // //         _markers.clear();
// // // // // // //         _markers.add(
// // // // // // //           Marker(
// // // // // // //             markerId: const MarkerId('driver'),
// // // // // // //             position: _initialPosition,
// // // // // // //             infoWindow: const InfoWindow(title: "You"),
// // // // // // //           ),
// // // // // // //         );
// // // // // // //       });

// // // // // // //       // 2️⃣ Fetch driver details from Firestore (your existing logic)
// // // // // // //       final firestoreRepo = ref.read(globalFirestoreRepoProvider);
// // // // // // //       await firestoreRepo.getDriverDetails(context);

// // // // // // //       // 3️⃣ Start listening to live location updates from Realtime DB
// // // // // // //       _listenToDriverLocation(); // <-- Add this
// // // // // // //     } catch (e) {
// // // // // // //       print("Location error: $e");
// // // // // // //     }
// // // // // // //   }

// // // // // // //   void _onMapCreated(GoogleMapController controller) {
// // // // // // //     _mapController = controller;

// // // // // // //     // Listen to providers and update markers/circles/polylines
// // // // // // //     final markers = ref.read(homeScreenMainMarkersProviderOSM);
// // // // // // //     final circles = ref.read(homeScreenMainCirclesProviderOSM);
// // // // // // //     final polylines = ref.read(homeScreenMainPolylinesProviderOSM);

// // // // // // //     setState(() {
// // // // // // //       _markers.addAll(
// // // // // // //         markers
// // // // // // //             .map(
// // // // // // //               (e) => Marker(
// // // // // // //                 markerId: MarkerId(e.key.toString()),
// // // // // // //                 position: LatLng(e.point.latitude, e.point.longitude),
// // // // // // //               ),
// // // // // // //             )
// // // // // // //             .toList(),
// // // // // // //       );
// // // // // // //       _circles.addAll(
// // // // // // //         circles
// // // // // // //             .map(
// // // // // // //               (e) => Circle(
// // // // // // //                 circleId: CircleId(e.key.toString()),
// // // // // // //                 center: LatLng(
// // // // // // //                   e.point.latitude,
// // // // // // //                   e.point.longitude,
// // // // // // //                 ), // use .point
// // // // // // //                 radius: e.radius,
// // // // // // //                 fillColor: e.color,
// // // // // // //                 strokeColor: e.borderColor,
// // // // // // //                 strokeWidth: e.borderStrokeWidth.toInt(),
// // // // // // //               ),
// // // // // // //             )
// // // // // // //             .toList(),
// // // // // // //       );

// // // // // // //       // _circles.addAll(
// // // // // // //       //   circles
// // // // // // //       //       .map(
// // // // // // //       //         (e) => Circle(
// // // // // // //       //           circleId: CircleId(e.key.toString()),
// // // // // // //       //           center: LatLng(e.center.latitude, e.center.longitude),
// // // // // // //       //           radius: e.radius,
// // // // // // //       //           fillColor: e.color,
// // // // // // //       //           strokeColor: e.borderColor,
// // // // // // //       //           strokeWidth: e.borderStrokeWidth.toInt(),
// // // // // // //       //         ),
// // // // // // //       //       )
// // // // // // //       //       .toList(),
// // // // // // //       // );

// // // // // // //       _polylines.addAll(
// // // // // // //         polylines.asMap().entries.map((entry) {
// // // // // // //           final index = entry.key;
// // // // // // //           final e = entry.value;
// // // // // // //           return Polyline(
// // // // // // //             polylineId: PolylineId('polyline_$index'),
// // // // // // //             points:
// // // // // // //                 e.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
// // // // // // //             color: e.color,
// // // // // // //             width: e.strokeWidth.toInt(),
// // // // // // //           );
// // // // // // //         }).toList(),
// // // // // // //       );
// // // // // // //     });
// // // // // // //   }

// // // // // // //   @override
// // // // // // //   Widget build(BuildContext context) {
// // // // // // //     Size size = MediaQuery.sizeOf(context);
// // // // // // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// // // // // // //     return Scaffold(
// // // // // // //       body: SafeArea(
// // // // // // //         child: Stack(
// // // // // // //           children: [
// // // // // // //             GoogleMap(
// // // // // // //               initialCameraPosition: CameraPosition(
// // // // // // //                 target: _initialPosition,
// // // // // // //                 zoom: 14,
// // // // // // //               ),
// // // // // // //               onMapCreated: _onMapCreated,
// // // // // // //               markers: _markers,
// // // // // // //               circles: _circles,
// // // // // // //               polylines: _polylines,
// // // // // // //               myLocationEnabled: true,
// // // // // // //               myLocationButtonEnabled: true,
// // // // // // //               zoomControlsEnabled: false,
// // // // // // //             ),

// // // // // // //             if (!isOnline)
// // // // // // //               Container(
// // // // // // //                 width: size.width,
// // // // // // //                 height: size.height,
// // // // // // //                 color: Colors.black.withOpacity(0.6),
// // // // // // //               ),

// // // // // // //             Positioned(
// // // // // // //               top: isOnline ? 30 : size.height * 0.4,
// // // // // // //               left: 20,
// // // // // // //               right: 20,
// // // // // // //               child: Column(
// // // // // // //                 children: [
// // // // // // //                   Container(
// // // // // // //                     padding: const EdgeInsets.symmetric(
// // // // // // //                       vertical: 12,
// // // // // // //                       horizontal: 16,
// // // // // // //                     ),
// // // // // // //                     decoration: BoxDecoration(
// // // // // // //                       color: isOnline ? Colors.yellow[700] : Colors.blue,
// // // // // // //                       borderRadius: BorderRadius.circular(12),
// // // // // // //                       boxShadow: const [
// // // // // // //                         BoxShadow(
// // // // // // //                           color: Colors.black26,
// // // // // // //                           blurRadius: 6,
// // // // // // //                           offset: Offset(0, 4),
// // // // // // //                         ),
// // // // // // //                       ],
// // // // // // //                     ),
// // // // // // //                     child: Row(
// // // // // // //                       mainAxisSize: MainAxisSize.min,
// // // // // // //                       children: [
// // // // // // //                         Icon(
// // // // // // //                           isOnline ? Icons.check_circle : Icons.cancel,
// // // // // // //                           color: Colors.white,
// // // // // // //                         ),
// // // // // // //                         const SizedBox(width: 10),
// // // // // // //                         Text(
// // // // // // //                           isOnline ? 'You are Online' : 'You are Offline',
// // // // // // //                           style: const TextStyle(
// // // // // // //                             color: Colors.white,
// // // // // // //                             fontSize: 16,
// // // // // // //                             fontWeight: FontWeight.bold,
// // // // // // //                           ),
// // // // // // //                         ),
// // // // // // //                       ],
// // // // // // //                     ),
// // // // // // //                   ),
// // // // // // //                   const SizedBox(height: 20),
// // // // // // //                   GestureDetector(
// // // // // // //                     onTap: () async {
// // // // // // //                       if (!isOnline) {
// // // // // // //                         await HomeLogics().getDriverOnline(
// // // // // // //                           context,
// // // // // // //                           ref,
// // // // // // //                           _mapController,
// // // // // // //                         );
// // // // // // //                       } else {
// // // // // // //                         await HomeLogics().getDriverOffline(context, ref);
// // // // // // //                       }
// // // // // // //                     },
// // // // // // //                     child: Container(
// // // // // // //                       alignment: Alignment.center,
// // // // // // //                       width: 180,
// // // // // // //                       height: 45,
// // // // // // //                       decoration: BoxDecoration(
// // // // // // //                         color: isOnline ? Colors.blue : Colors.yellow,
// // // // // // //                         borderRadius: BorderRadius.circular(10),
// // // // // // //                       ),
// // // // // // //                       child: Text(
// // // // // // //                         isOnline ? 'Go Offline' : 'Go Online',
// // // // // // //                         style: const TextStyle(
// // // // // // //                           color: Colors.white,
// // // // // // //                           fontWeight: FontWeight.bold,
// // // // // // //                         ),
// // // // // // //                       ),
// // // // // // //                     ),
// // // // // // //                   ),
// // // // // // //                 ],
// // // // // // //               ),
// // // // // // //             ),
// // // // // // //           ],
// // // // // // //         ),
// // // // // // //       ),
// // // // // // //     );
// // // // // // //   }
// // // // // // // }



// // // // // // // // import 'dart:async';
// // // // // // // // import 'package:aminidriver/main.dart';
// // // // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // // // import 'package:flutter_map/flutter_map.dart';
// // // // // // // // import 'package:latlong2/latlong.dart';
// // // // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // // // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';

// // // // // // // // class HomeScreen extends ConsumerStatefulWidget {
// // // // // // // //   const HomeScreen({super.key});

// // // // // // // //   @override
// // // // // // // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // // // // // // }

// // // // // // // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // // // // // // //   final MapController _mapController = MapController();
// // // // // // // //   LatLng _initialPosition = LatLng(0.0, 0.0);
// // // // // // // //   //StreamSubscription<DatabaseEvent>? _rideSubscription;
// // // // // // // //   //bool _navigatedToLiveScreen = false; // guard against multiple pushes
// // // // // // // //   final messagingService = MessagingService();
// // // // // // // //   @override
// // // // // // // //   void initState() {
// // // // // // // //     super.initState();

// // // // // // // //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // // // //       _initialize();
// // // // // // // //     });
// // // // // // // //   }

// // // // // // // //   Future<void> _initialize() async {
// // // // // // // //     // Safe to call context/mounted here
// // // // // // // //     await messagingService.checkInitialMessage(context, ref);

// // // // // // // //     if (!mounted) return;
// // // // // // // //     await HomeLogics().fetchAndUpdateDriverStatus(ref);

// // // // // // // //     if (!mounted) return;
// // // // // // // //     await messagingService.init(context, ref);

// // // // // // // //     if (!mounted) return;
// // // // // // // //     await _setInitialLocation();

// // // // // // // //     //_listenForRideStatus();
// // // // // // // //   }


// // // // // // // //   Future<void> _setInitialLocation() async {
// // // // // // // //     try {
// // // // // // // //       final pos = await Geolocator.getCurrentPosition();
// // // // // // // //       setState(() {
// // // // // // // //         _initialPosition = LatLng(pos.latitude, pos.longitude);
// // // // // // // //       });

// // // // // // // //       final firestoreRepo = ref.read(globalFirestoreRepoProvider);
// // // // // // // //       await firestoreRepo.getDriverDetails(context);
// // // // // // // //     } catch (e) {
// // // // // // // //       print("Location error: $e");
// // // // // // // //     }
// // // // // // // //   }

// // // // // // // //   @override
// // // // // // // //   Widget build(BuildContext context) {
// // // // // // // //     Size size = MediaQuery.sizeOf(context);
// // // // // // // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// // // // // // // //     return Scaffold(
// // // // // // // //       body: SafeArea(
// // // // // // // //         child: Stack(
// // // // // // // //           children: [
// // // // // // // //             FlutterMap(
// // // // // // // //               mapController: _mapController,
// // // // // // // //               options: MapOptions(
// // // // // // // //                 center: _initialPosition,
// // // // // // // //                 zoom: 14,
// // // // // // // //                 onTap: (tapPosition, point) {},
// // // // // // // //               ),
// // // // // // // //               children: [
// // // // // // // //                 TileLayer(
// // // // // // // //                   urlTemplate:
// // // // // // // //                       'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
// // // // // // // //                   subdomains: ['a', 'b', 'c'],
// // // // // // // //                   userAgentPackageName: 'com.example.aminidriver',
// // // // // // // //                 ),
// // // // // // // //                 CircleLayer(
// // // // // // // //                   circles: ref.watch(homeScreenMainCirclesProviderOSM),
// // // // // // // //                 ),
// // // // // // // //                 PolylineLayer(
// // // // // // // //                   polylines: ref.watch(homeScreenMainPolylinesProviderOSM),
// // // // // // // //                 ),
// // // // // // // //                 MarkerLayer(
// // // // // // // //                   markers: ref.watch(homeScreenMainMarkersProviderOSM),
// // // // // // // //                 ),
// // // // // // // //               ],
// // // // // // // //             ),

// // // // // // // //             if (!isOnline)
// // // // // // // //               Container(
// // // // // // // //                 width: size.width,
// // // // // // // //                 height: size.height,
// // // // // // // //                 color: Colors.black.withOpacity(0.6),
// // // // // // // //               ),

// // // // // // // //             Positioned(
// // // // // // // //               top: isOnline ? 30 : size.height * 0.4,
// // // // // // // //               left: 20,
// // // // // // // //               right: 20,
// // // // // // // //               child: Column(
// // // // // // // //                 children: [
// // // // // // // //                   Container(
// // // // // // // //                     padding: const EdgeInsets.symmetric(
// // // // // // // //                       vertical: 12,
// // // // // // // //                       horizontal: 16,
// // // // // // // //                     ),
// // // // // // // //                     decoration: BoxDecoration(
// // // // // // // //                       color: isOnline ? Colors.yellow[700] : Colors.blue,
// // // // // // // //                       borderRadius: BorderRadius.circular(12),
// // // // // // // //                       boxShadow: [
// // // // // // // //                         BoxShadow(
// // // // // // // //                           color: Colors.black26,
// // // // // // // //                           blurRadius: 6,
// // // // // // // //                           offset: Offset(0, 4),
// // // // // // // //                         ),
// // // // // // // //                       ],
// // // // // // // //                     ),
// // // // // // // //                     child: Row(
// // // // // // // //                       mainAxisSize: MainAxisSize.min,
// // // // // // // //                       children: [
// // // // // // // //                         Icon(
// // // // // // // //                           isOnline ? Icons.check_circle : Icons.cancel,
// // // // // // // //                           color: Colors.white,
// // // // // // // //                         ),
// // // // // // // //                         SizedBox(width: 10),
// // // // // // // //                         Text(
// // // // // // // //                           isOnline ? 'You are Online' : 'You are Offline',
// // // // // // // //                           style: TextStyle(
// // // // // // // //                             color: Colors.white,
// // // // // // // //                             fontSize: 16,
// // // // // // // //                             fontWeight: FontWeight.bold,
// // // // // // // //                           ),
// // // // // // // //                         ),
// // // // // // // //                       ],
// // // // // // // //                     ),
// // // // // // // //                   ),
// // // // // // // //                   const SizedBox(height: 20),
// // // // // // // //                   GestureDetector(
// // // // // // // //                     onTap: () async {
// // // // // // // //                       if (!isOnline) {
// // // // // // // //                         await HomeLogics().getDriverOnline(
// // // // // // // //                           context,
// // // // // // // //                           ref,
// // // // // // // //                           _mapController,
// // // // // // // //                         );
// // // // // // // //                       } else {
// // // // // // // //                         await HomeLogics().getDriverOffline(context, ref);
// // // // // // // //                       }
// // // // // // // //                     },

// // // // // // // //                     child: Container(
// // // // // // // //                       alignment: Alignment.center,
// // // // // // // //                       width: 180,
// // // // // // // //                       height: 45,
// // // // // // // //                       decoration: BoxDecoration(
// // // // // // // //                         color: isOnline ? Colors.blue : Colors.yellow,
// // // // // // // //                         borderRadius: BorderRadius.circular(10),
// // // // // // // //                       ),
// // // // // // // //                       child: Text(
// // // // // // // //                         isOnline ? 'Go Offline' : 'Go Online',
// // // // // // // //                         style: TextStyle(
// // // // // // // //                           color: Colors.white,
// // // // // // // //                           fontWeight: FontWeight.bold,
// // // // // // // //                         ),
// // // // // // // //                       ),
// // // // // // // //                     ),
// // // // // // // //                   ),
// // // // // // // //                 ],
// // // // // // // //               ),
// // // // // // // //             ),
// // // // // // // //           ],
// // // // // // // //         ),
// // // // // // // //       ),
// // // // // // // //     );
// // // // // // // //   }
// // // // // // // // }


// // // // // // // //   // @override
// // // // // // // //   // void initState() {
// // // // // // // //   //   super.initState();
// // // // // // // //   //   Future.microtask(() async {
// // // // // // // //   //     //await HomeLogics().fetchAndUpdateDriverStatus(ref);
// // // // // // // //   //     //await messagingService.init(context, ref);
// // // // // // // //   //     await messagingService.checkInitialMessage(context, ref);

// // // // // // // //   //     WidgetsBinding.instance.addPostFrameCallback((_) async {
// // // // // // // //   //       await HomeLogics().fetchAndUpdateDriverStatus(ref);
// // // // // // // //   //       if (mounted) {
// // // // // // // //   //         await messagingService.init(context, ref);
// // // // // // // //   //       }
// // // // // // // //   //     });
// // // // // // // //   //     // if (mounted) {
// // // // // // // //   //     //   await messagingService.checkInitialMessage(context, ref);
// // // // // // // //   //     // }
// // // // // // // //   //     await _setInitialLocation();
// // // // // // // //   //   });
// // // // // // // //   // }

// // // // // // // //   // @override
// // // // // // // //   // void didChangeDependencies() {
// // // // // // // //   //   super.didChangeDependencies();

// // // // // // // //   //   if (initialRideMessage != null) {
// // // // // // // //   //     final message = initialRideMessage!;
// // // // // // // //   //     initialRideMessage = null;

// // // // // // // //   //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // // // //   //       // Navigate to HomeScreen if not already there
// // // // // // // //   //       if (ModalRoute.of(context)?.settings.name != '/home') {
// // // // // // // //   //         Navigator.pushReplacementNamed(context, '/home');
// // // // // // // //   //       }

// // // // // // // //   //       // Delay again to allow screen to mount before handling message
// // // // // // // //   //       Future.delayed(Duration(milliseconds: 300), () {
// // // // // // // //   //         messagingService.handleMessage(context, ref, message);
// // // // // // // //   //       });
// // // // // // // //   //     });
// // // // // // // //   //   }
// // // // // // // //   // }

// // // // // // // //   // @override
// // // // // // // //   // void initState() {
// // // // // // // //   //   super.initState();
// // // // // // // //   //   Future.microtask(() async {
// // // // // // // //   //     // final messagingService = MessagingService();
// // // // // // // //   //     // messagingService.init(context, ref);

// // // // // // // //   //     await _setInitialLocation();
// // // // // // // //   //     await HomeLogics().fetchAndUpdateDriverStatus(ref);
// // // // // // // //   //     final messagingService = MessagingService();
// // // // // // // //   //     if (mounted) {
// // // // // // // //   //       //await messagingService.init(context, ref);
// // // // // // // //   //       await messagingService.checkInitialMessage(context, ref);
// // // // // // // //   //     }
// // // // // // // //   //   });
// // // // // // // //   // }
// // // // // // // //   //   @override
// // // // // // // //   // void didChangeDependencies() {
// // // // // // // //   //   super.didChangeDependencies();

// // // // // // // //   //   if (initialRideMessage != null) {
// // // // // // // //   //     final message = initialRideMessage!;
// // // // // // // //   //     initialRideMessage = null;

// // // // // // // //   //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // // // // // // //   //       // Navigate to HomeScreen if not already there
// // // // // // // //   //       if (ModalRoute.of(context)?.settings.name != '/home') {
// // // // // // // //   //         Navigator.pushReplacementNamed(context, '/home');
// // // // // // // //   //       }

// // // // // // // //   //       // Delay again slightly to allow home screen to mount
// // // // // // // //   //       Future.delayed(Duration(milliseconds: 300), () {
// // // // // // // //   //         messagingService.handleMessage(context, ref, message);
// // // // // // // //   //       });
// // // // // // // //   //     });
// // // // // // // //   //   }
// // // // // // // //   // }


// // // // // // // //   // void _listenForRideStatus() {
// // // // // // // //   //     // You’ll need the current driver’s rideId from provider or API
// // // // // // // //   //     final rideId = "some_ride_id"; // replace with actual value
// // // // // // // //   //     final driverId = "some_driver_id"; // replace with actual value

// // // // // // // //   //     final rideRef = FirebaseDatabase.instance.ref("rides/$rideId");

// // // // // // // //   //     _rideSubscription = rideRef.onValue.listen((event) {
// // // // // // // //   //       final data = event.snapshot.value as Map?;
// // // // // // // //   //       if (data == null) return;

// // // // // // // //   //       final status = data["status"];
// // // // // // // //   //       if (status == "in_progress" && !_navigatedToLiveScreen) {
// // // // // // // //   //         _navigatedToLiveScreen = true;

// // // // // // // //   //         Navigator.push(
// // // // // // // //   //           context,
// // // // // // // //   //           MaterialPageRoute(
// // // // // // // //   //             builder: (_) => RideInProgressLiveScreen(
// // // // // // // //   //               rideId: rideId,
// // // // // // // //   //               driverId: driverId,
// // // // // // // //   //               pickup: LatLng(data["pickup"]["lat"], data["pickup"]["lng"]),
// // // // // // // //   //               destination: LatLng(data["destination"]["lat"], data["destination"]["lng"]),
// // // // // // // //   //               baseFare: 100, // or pass from DB
// // // // // // // //   //               perKmFare: 50,
// // // // // // // //   //             ),
// // // // // // // //   //           ),
// // // // // // // //   //         );
// // // // // // // //   //       }
// // // // // // // //   //     });
// // // // // // // //   //   }


// // // // // // // // // import 'dart:async';
// // // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // // // // // // // import '../../../../Container/utils/set_blackmap.dart';
// // // // // // // // // import 'package:geoflutterfire2/geoflutterfire2.dart';

// // // // // // // // // final geo = GeoFlutterFire();

// // // // // // // // // class HomeScreen extends ConsumerStatefulWidget {
// // // // // // // // //   const HomeScreen({super.key});

// // // // // // // // //   @override
// // // // // // // // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // // // // // // // }

// // // // // // // // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // // // // // // // //   final Completer<GoogleMapController> _mapController = Completer();
// // // // // // // // //   GoogleMapController? controller;
// // // // // // // // //   CameraPosition _initialPosition = const CameraPosition(
// // // // // // // // //     target: LatLng(0.0, 0.0),
// // // // // // // // //     zoom: 14,
// // // // // // // // //   );

// // // // // // // // //   @override
// // // // // // // // //   void initState() {
// // // // // // // // //     super.initState();
// // // // // // // // //     MessagingService().init(context);
// // // // // // // // //   }

// // // // // // // // //   @override
// // // // // // // // //   Widget build(BuildContext context) {
// // // // // // // // //     Size size = MediaQuery.sizeOf(context);
// // // // // // // // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);
// // // // // // // // //     final firestoreRepo = ref.watch(
// // // // // // // // //       globalFirestoreRepoProvider,
// // // // // // // // //     ); // Properly watch the Firestore provider

// // // // // // // // //     return Scaffold(
// // // // // // // // //       body: SafeArea(
// // // // // // // // //         child: Stack(
// // // // // // // // //           children: [
// // // // // // // // //             GoogleMap(
// // // // // // // // //               mapType: MapType.normal,
// // // // // // // // //               myLocationButtonEnabled: true,
// // // // // // // // //               myLocationEnabled: true,
// // // // // // // // //               zoomControlsEnabled: false,
// // // // // // // // //               initialCameraPosition: _initialPosition,
// // // // // // // // //               polylines: ref.watch(homeScreenMainPolylinesProvider),
// // // // // // // // //               markers: ref.watch(homeScreenMainMarkersProvider),
// // // // // // // // //               circles: ref.watch(homeScreenMainCirclesProvider),
// // // // // // // // //               onMapCreated: (map) async {
// // // // // // // // //                 _mapController.complete(map);
// // // // // // // // //                 controller = map;
// // // // // // // // //                 SetBlackMap().setBlackMapTheme(map);

// // // // // // // // //                 // Get current location and details
// // // // // // // // //                 HomeLogics().getDriverLoc(context, ref, map);
// // // // // // // // //                 await firestoreRepo.getDriverDetails(
// // // // // // // // //                   context,
// // // // // // // // //                 ); // Proper async function call
// // // // // // // // //               },
// // // // // // // // //             ),

// // // // // // // // //             // If driver is offline, overlay black shade
// // // // // // // // //             if (!isOnline)
// // // // // // // // //               Container(
// // // // // // // // //                 width: size.width,
// // // // // // // // //                 height: size.height,
// // // // // // // // //                 color: Colors.black,
// // // // // // // // //               ),

// // // // // // // // //             // Status and Toggle Button
// // // // // // // // //             Positioned(
// // // // // // // // //               top: isOnline ? 30 : size.height * 0.4,
// // // // // // // // //               left: 20,
// // // // // // // // //               right: 20,
// // // // // // // // //               child: Column(
// // // // // // // // //                 children: [
// // // // // // // // //                   Container(
// // // // // // // // //                     padding: const EdgeInsets.symmetric(
// // // // // // // // //                       vertical: 12,
// // // // // // // // //                       horizontal: 16,
// // // // // // // // //                     ),
// // // // // // // // //                     decoration: BoxDecoration(
// // // // // // // // //                       color: isOnline ? Colors.yellow[700] : Colors.blue,
// // // // // // // // //                       borderRadius: BorderRadius.circular(12),
// // // // // // // // //                       boxShadow: [
// // // // // // // // //                         BoxShadow(
// // // // // // // // //                           color: Colors.black26,
// // // // // // // // //                           blurRadius: 6,
// // // // // // // // //                           offset: Offset(0, 4),
// // // // // // // // //                         ),
// // // // // // // // //                       ],
// // // // // // // // //                     ),
// // // // // // // // //                     child: Row(
// // // // // // // // //                       mainAxisSize: MainAxisSize.min,
// // // // // // // // //                       children: [
// // // // // // // // //                         Icon(
// // // // // // // // //                           isOnline ? Icons.check_circle : Icons.cancel,
// // // // // // // // //                           color: Colors.white,
// // // // // // // // //                         ),
// // // // // // // // //                         SizedBox(width: 10),
// // // // // // // // //                         Text(
// // // // // // // // //                           isOnline ? 'You are Online' : 'You are Offline',
// // // // // // // // //                           style: TextStyle(
// // // // // // // // //                             color: Colors.white,
// // // // // // // // //                             fontSize: 16,
// // // // // // // // //                             fontWeight: FontWeight.bold,
// // // // // // // // //                           ),
// // // // // // // // //                         ),
// // // // // // // // //                       ],
// // // // // // // // //                     ),
// // // // // // // // //                   ),
// // // // // // // // //                   const SizedBox(height: 20),
// // // // // // // // //                   GestureDetector(
// // // // // // // // //                     onTap: () async {
// // // // // // // // //                       if (!isOnline) {
// // // // // // // // //                         await HomeLogics().getDriverOnline(
// // // // // // // // //                           context,
// // // // // // // // //                           ref,
// // // // // // // // //                           controller!,
// // // // // // // // //                         );
// // // // // // // // //                       } else {
// // // // // // // // //                         await HomeLogics().getDriverOffline(context, ref);
// // // // // // // // //                       }
// // // // // // // // //                     },
// // // // // // // // //                     child: Container(
// // // // // // // // //                       alignment: Alignment.center,
// // // // // // // // //                       width: 180,
// // // // // // // // //                       height: 45,
// // // // // // // // //                       decoration: BoxDecoration(
// // // // // // // // //                         color: isOnline ? Colors.blue : Colors.yellow,
// // // // // // // // //                         borderRadius: BorderRadius.circular(10),
// // // // // // // // //                       ),
// // // // // // // // //                       child: Text(
// // // // // // // // //                         isOnline ? 'Go Offline' : 'Go Online',
// // // // // // // // //                         style: TextStyle(
// // // // // // // // //                           color: Colors.white,
// // // // // // // // //                           fontWeight: FontWeight.bold,
// // // // // // // // //                         ),
// // // // // // // // //                       ),
// // // // // // // // //                     ),
// // // // // // // // //                   ),
// // // // // // // // //                 ],
// // // // // // // // //               ),
// // // // // // // // //             ),
// // // // // // // // //           ],
// // // // // // // // //         ),
// // // // // // // // //       ),
// // // // // // // // //     );
// // // // // // // // //   }
// // // // // // // // // }

// // // // // // // // // import 'dart:async';
// // // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // // // // // import 'package:aminidriver/Container/Repositories/firestore_repo.dart';
// // // // // // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // // // // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // // // // // // // import '../../../../Container/utils/set_blackmap.dart';
// // // // // // // // // import 'package:geoflutterfire2/geoflutterfire2.dart';

// // // // // // // // // final geo = GeoFlutterFire();

// // // // // // // // // class HomeScreen extends ConsumerStatefulWidget {
// // // // // // // // //   const HomeScreen({super.key});

// // // // // // // // //   @override
// // // // // // // // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // // // // // // // }

// // // // // // // // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // // // // // // // //   CameraPosition initpos = const CameraPosition(
// // // // // // // // //     target: LatLng(0.0, 0.0),
// // // // // // // // //     zoom: 14,
// // // // // // // // //   );

// // // // // // // // //   final Completer<GoogleMapController> completer = Completer();
// // // // // // // // //   GoogleMapController? controller;
// // // // // // // // //   Geolocator geoLocator = Geolocator();

// // // // // // // // //   @override
// // // // // // // // //   void initState() {
// // // // // // // // //     super.initState();
// // // // // // // // //     MessagingService().init(context);
// // // // // // // // //   }

// // // // // // // // //   @override
// // // // // // // // //   Widget build(BuildContext context) {
// // // // // // // // //     Size size = MediaQuery.sizeOf(context);

// // // // // // // // //     return Scaffold(
// // // // // // // // //       body: SafeArea(
// // // // // // // // //         child: SizedBox(
// // // // // // // // //           width: size.width,
// // // // // // // // //           height: size.height,
// // // // // // // // //           child: Stack(
// // // // // // // // //             children: [
// // // // // // // // //               GoogleMap(
// // // // // // // // //                 mapType: MapType.normal,
// // // // // // // // //                 myLocationButtonEnabled: true,
// // // // // // // // //                 trafficEnabled: true,
// // // // // // // // //                 compassEnabled: true,
// // // // // // // // //                 buildingsEnabled: true,
// // // // // // // // //                 myLocationEnabled: true,
// // // // // // // // //                 zoomControlsEnabled: false,
// // // // // // // // //                 zoomGesturesEnabled: true,
// // // // // // // // //                 initialCameraPosition: initpos,
// // // // // // // // //                 polylines: ref.watch(homeScreenMainPolylinesProvider),
// // // // // // // // //                 markers: ref.watch(homeScreenMainMarkersProvider),
// // // // // // // // //                 circles: ref.watch(homeScreenMainCirclesProvider),
// // // // // // // // //                 onMapCreated: (map) {
// // // // // // // // //                   completer.complete(map);
// // // // // // // // //                   controller = map;
// // // // // // // // //                   SetBlackMap().setBlackMapTheme(map);
// // // // // // // // //                   HomeLogics().getDriverLoc(context, ref, controller!);
// // // // // // // // //                   ref
// // // // // // // // //                       .watch(globalFirestoreRepoProvider)
// // // // // // // // //                       .getDriverDetails(context);
// // // // // // // // //                 },
// // // // // // // // //               ),
// // // // // // // // //               ref.watch(homeScreenIsDriverActiveProvider)
// // // // // // // // //                   ? Container()
// // // // // // // // //                   : Container(
// // // // // // // // //                     height: size.height,
// // // // // // // // //                     width: size.width,
// // // // // // // // //                     color: Colors.black54,
// // // // // // // // //                   ),
// // // // // // // // //               Positioned(
// // // // // // // // //                 top:
// // // // // // // // //                     !ref.watch(homeScreenIsDriverActiveProvider)
// // // // // // // // //                         ? size.height * 0.45
// // // // // // // // //                         : 45,
// // // // // // // // //                 left: 0,
// // // // // // // // //                 right: 0,
// // // // // // // // //                 child: Row(
// // // // // // // // //                   mainAxisAlignment: MainAxisAlignment.center,
// // // // // // // // //                   crossAxisAlignment: CrossAxisAlignment.center,
// // // // // // // // //                   children: [
// // // // // // // // //                     InkWell(
// // // // // // // // //                       onTap: () {
// // // // // // // // //                         if (!ref.watch(homeScreenIsDriverActiveProvider)) {
// // // // // // // // //                           HomeLogics().getDriverOnline(
// // // // // // // // //                             context,
// // // // // // // // //                             ref,
// // // // // // // // //                             controller!,
// // // // // // // // //                           );
// // // // // // // // //                         } else {
// // // // // // // // //                           HomeLogics().getDriverOffline(context, ref);
// // // // // // // // //                         }
// // // // // // // // //                       },
// // // // // // // // //                       child: Container(
// // // // // // // // //                         alignment: Alignment.center,
// // // // // // // // //                         height: 45,
// // // // // // // // //                         width: 200,
// // // // // // // // //                         decoration: BoxDecoration(
// // // // // // // // //                           borderRadius: BorderRadius.circular(14),
// // // // // // // // //                           color: Colors.blue,
// // // // // // // // //                         ),
// // // // // // // // //                         child:
// // // // // // // // //                             !ref.watch(homeScreenIsDriverActiveProvider)
// // // // // // // // //                                 ? const Text("You are Offline")
// // // // // // // // //                                 : const Icon(
// // // // // // // // //                                   Icons.phonelink_ring_outlined,
// // // // // // // // //                                   color: Colors.white,
// // // // // // // // //                                   size: 20,
// // // // // // // // //                                 ),
// // // // // // // // //                       ),
// // // // // // // // //                     ),
// // // // // // // // //                   ],
// // // // // // // // //                 ),
// // // // // // // // //               ),
// // // // // // // // //             ],
// // // // // // // // //           ),
// // // // // // // // //         ),
// // // // // // // // //       ),
// // // // // // // // //     );
// // // // // // // // //   }
// // // // // // // // // }
