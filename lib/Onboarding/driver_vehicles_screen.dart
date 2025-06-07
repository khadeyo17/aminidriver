// import 'package:flutter/material.dart';

// class DriverVehiclesScreen extends StatelessWidget {
//   final String driverName;
//   final List<Map<String, String>> vehicles;

//   const DriverVehiclesScreen({
//     super.key,
//     required this.driverName,
//     required this.vehicles,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('My Vehicles'),
//         backgroundColor: Colors.blue,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Driver: $driverName',
//               style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             vehicles.isEmpty
//                 ? const Center(child: Text('No vehicles assigned.'))
//                 : Expanded(
//                   child: ListView.builder(
//                     itemCount: vehicles.length,
//                     itemBuilder: (context, index) {
//                       final vehicle = vehicles[index];
//                       return Card(
//                         margin: const EdgeInsets.symmetric(vertical: 6),
//                         child: ListTile(
//                           leading: const Icon(Icons.directions_car),
//                           title: Text(vehicle['model'] ?? 'Unknown Model'),
//                           subtitle: Text(
//                             'Reg: ${vehicle['regNumber'] ?? 'N/A'}',
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//           ],
//         ),
//       ),
//     );
//   }
// }
