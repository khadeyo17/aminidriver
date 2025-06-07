// import 'dart:convert';
// import 'dart:io';
// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/driveronboardingcontroller.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:go_router/go_router.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class VehicleOnboardingController extends StatefulWidget {
//   @override
//   _VehicleOnboardingControllerState createState() =>
//       _VehicleOnboardingControllerState();

//   @override
//   void dispose() {
//     regController.dispose();
//     yearController.dispose();
//     super.dispose();
//   }
// }

// class _VehicleOnboardingControllerState
//     extends State<VehicleOnboardingController> {
//   String? selectedMake, selectedModel, selectedCategory;
//   List<String> vehicleMakes = [];
//   List<String> vehicleModels = [];
//   List<String> vehicleCategories = [];

//   String driverId = "";
//   String email = "";

//   // Controllers for vehicle-related fields
//   final regController = TextEditingController();
//   final yearController = TextEditingController();

//   // Controller for the DriverOnboardingController (if needed)
//   final driverController = DriverOnboardingController();

//   File? logbook, vehiclePic, insurance, otherDocs;
//   final ImagePicker _picker = ImagePicker();

//   Map<String, String> uploadStatus = {
//     "logbook": "Upload Logbook",
//     "vehiclePic": "Upload Vehicle Picture",
//     "insurance": "Upload Insurance",
//   };

//   @override
//   void initState() {
//     super.initState();
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       driverId = user.uid;
//       email = user.email ?? '';
//     }
//     fetchDropdownData();
//   }

//   Future<void> fetchDropdownData() async {
//     final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
//     final categoryRes = await http.get(
//       Uri.parse("$baseUrl/vehicles/categories"),
//     );
//     setState(() {
//       vehicleMakes = List<String>.from(json.decode(makeRes.body));
//       vehicleCategories = List<String>.from(json.decode(categoryRes.body));
//     });
//   }

//   Future<void> fetchVehicleModels(String make) async {
//     final modelRes = await http.get(
//       Uri.parse('$baseUrl/vehicles/models?make=$make'),
//     );
//     setState(() {
//       vehicleModels = List<String>.from(json.decode(modelRes.body));
//       selectedModel = null;
//     });
//   }

//   Future<void> submitVehicle() async {
//     final uri = Uri.parse("$baseUrl/driver-vehicles");

//     final Map<String, dynamic> body = {
//       "email": email,
//       "vehicleOwnerId": driverId,
//       "firebaseId": driverId,
//       "vehicleMake": selectedMake,
//       "vehicleModel": selectedModel,
//       "vehicleCategory": selectedCategory,
//       "registrationNumber": regController.text,
//       "year": int.tryParse(yearController.text) ?? 0,
//       "logbook":
//           logbook != null ? base64Encode(logbook!.readAsBytesSync()) : null,
//       "vehiclePicture":
//           vehiclePic != null
//               ? base64Encode(vehiclePic!.readAsBytesSync())
//               : null,
//       "insurance":
//           insurance != null ? base64Encode(insurance!.readAsBytesSync()) : null,
//       "otherDocuments":
//           otherDocs != null ? base64Encode(otherDocs!.readAsBytesSync()) : null,
//     };

//     final response = await http.post(
//       uri,
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode(body),
//     );

//     if (context.mounted) {
//       if (response.statusCode == 200) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Vehicle registered successfully!")),
//         );
//         await Future.delayed(const Duration(milliseconds: 500));
//         GoRouter.of(context).goNamed(Routes().navigationScreen);
//       } else {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
//       }
//     }
//   }

//   Future<void> showUploadOptions(
//     String fileKey,
//     Function(File) onPicked,
//   ) async {
//     showModalBottomSheet(
//       context: context,
//       builder:
//           (context) => Wrap(
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.camera_alt),
//                 title: const Text('Take a Photo'),
//                 onTap: () async {
//                   Navigator.pop(context);
//                   final pickedFile = await _picker.pickImage(
//                     source: ImageSource.camera,
//                   );
//                   if (pickedFile != null) onPicked(File(pickedFile.path));
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.photo_library),
//                 title: const Text('Choose from Gallery'),
//                 onTap: () async {
//                   Navigator.pop(context);
//                   final pickedFile = await _picker.pickImage(
//                     source: ImageSource.gallery,
//                   );
//                   if (pickedFile != null) onPicked(File(pickedFile.path));
//                 },
//               ),
//             ],
//           ),
//     );
//   }

//   @override
//   void dispose() {
//     // Dispose the controllers here
//     regController.dispose();
//     yearController.dispose();
//     driverController.dispose(); // Dispose the driver controller if necessary
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.blue,
//         title: const Text(
//           'Vehicle Onboarding',
//           style: TextStyle(color: Colors.white),
//         ),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             // Vehicle details input
//             TextField(
//               controller: regController,
//               decoration: const InputDecoration(
//                 labelText: 'Registration Number',
//               ),
//             ),
//             TextField(
//               controller: yearController,
//               decoration: const InputDecoration(labelText: 'Year'),
//               keyboardType: TextInputType.number,
//             ),
//             DropdownButton<String>(
//               value: selectedMake,
//               hint: const Text('Select Vehicle Make'),
//               onChanged: (make) {
//                 setState(() {
//                   selectedMake = make;
//                 });
//                 fetchVehicleModels(make!);
//               },
//               items:
//                   vehicleMakes.map((make) {
//                     return DropdownMenuItem(value: make, child: Text(make));
//                   }).toList(),
//             ),
//             DropdownButton<String>(
//               value: selectedModel,
//               hint: const Text('Select Vehicle Model'),
//               onChanged: (model) {
//                 setState(() {
//                   selectedModel = model;
//                 });
//               },
//               items:
//                   vehicleModels.map((model) {
//                     return DropdownMenuItem(value: model, child: Text(model));
//                   }).toList(),
//             ),
//             DropdownButton<String>(
//               value: selectedCategory,
//               hint: const Text('Select Vehicle Category'),
//               onChanged: (category) {
//                 setState(() {
//                   selectedCategory = category;
//                 });
//               },
//               items:
//                   vehicleCategories.map((category) {
//                     return DropdownMenuItem(
//                       value: category,
//                       child: Text(category),
//                     );
//                   }).toList(),
//             ),
//             const SizedBox(height: 16),
//             ...["logbook", "vehiclePic", "insurance", "otherDocs"].map((key) {
//               return Padding(
//                 padding: const EdgeInsets.only(bottom: 12),
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                   ),
//                   onPressed:
//                       () => showUploadOptions(key, (f) {
//                         setState(() {
//                           if (key == "logbook") logbook = f;
//                           if (key == "vehiclePic") vehiclePic = f;
//                           if (key == "insurance") insurance = f;
//                           if (key == "otherDocs") otherDocs = f;
//                           uploadStatus[key] = "Uploaded ✅";
//                         });
//                       }),
//                   child: Text(uploadStatus[key]!),
//                 ),
//               );
//             }).toList(),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: submitVehicle,
//               child: const Text("Submit Vehicle"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
