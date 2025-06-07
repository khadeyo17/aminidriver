// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:go_router/go_router.dart';

// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/View/Routes/routes.dart';

// class VehicleOnboardingScreen extends StatefulWidget {
//   const VehicleOnboardingScreen({Key? key}) : super(key: key);

//   @override
//   State<VehicleOnboardingScreen> createState() =>
//       _VehicleOnboardingScreenState();
// }

// class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
//   String? selectedMake, selectedModel, selectedCategory;
//   List<String> vehicleMakes = [];
//   List<String> vehicleModels = [];
//   List<String> vehicleCategories = [];

//   final regController = TextEditingController();
//   final yearController = TextEditingController();

//   String driverId = '';
//   String email = '';

//   File? logbook, vehiclePic, insurance, otherDocs;
//   final ImagePicker _picker = ImagePicker();

//   Map<String, String> uploadStatus = {
//     "logbook": "Upload Logbook",
//     "vehiclePic": "Upload Vehicle Picture",
//     "insurance": "Upload Insurance",
//     "otherDocs": "Upload Other Documents",
//   };

//   // Map<String, File?> uploadStatus = {
//   //   "logbook": null,
//   //   "vehiclePic": null,
//   //   "insurance": null,
//   //   "otherDocs": null,
//   // };

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
//     try {
//       final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
//       final categoryRes = await http.get(
//         Uri.parse("$baseUrl/vehicles/categories"),
//       );

//       if (makeRes.statusCode == 200 && categoryRes.statusCode == 200) {
//         setState(() {
//           vehicleMakes = List<String>.from(json.decode(makeRes.body));
//           vehicleCategories = List<String>.from(json.decode(categoryRes.body));
//         });
//       }
//     } catch (e) {
//       debugPrint("Failed to fetch dropdown data: $e");
//     }
//   }

//   Future<void> fetchVehicleModels(String make) async {
//     try {
//       final modelRes = await http.get(
//         Uri.parse('$baseUrl/vehicles/models?make=$make'),
//       );
//       if (modelRes.statusCode == 200) {
//         setState(() {
//           vehicleModels = List<String>.from(json.decode(modelRes.body));
//           selectedModel = null;
//         });
//       }
//     } catch (e) {
//       debugPrint("Failed to fetch vehicle models: $e");
//     }
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

//     if (!context.mounted) return;

//     if (response.statusCode == 200) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Vehicle registered successfully!")),
//       );
//       await Future.delayed(const Duration(milliseconds: 500));
//       GoRouter.of(context).goNamed(Routes().navigationScreen);
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
//     }
//   }

//   Future<void> showUploadOptions(String key, Function(File) onPicked) async {
//     showModalBottomSheet(
//       context: context,
//       builder:
//           (_) => Wrap(
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
//     regController.dispose();
//     yearController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Vehicle Onboarding"),
//         backgroundColor: Colors.blue,
//         iconTheme: const IconThemeData(color: Colors.white),
//         titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             TextField(
//               controller: regController,
//               decoration: const InputDecoration(
//                 labelText: 'Registration Number',
//               ),
//             ),
//             const SizedBox(height: 10),
//             TextField(
//               controller: yearController,
//               decoration: const InputDecoration(labelText: 'Year'),
//               keyboardType: TextInputType.number,
//             ),
//             const SizedBox(height: 10),
//             DropdownButton<String>(
//               isExpanded: true,
//               value: selectedMake,
//               hint: const Text('Select Vehicle Make'),
//               onChanged: (make) {
//                 setState(() {
//                   selectedMake = make;
//                   selectedModel = null;
//                 });
//                 if (make != null) fetchVehicleModels(make);
//               },
//               items:
//                   vehicleMakes
//                       .map(
//                         (make) =>
//                             DropdownMenuItem(value: make, child: Text(make)),
//                       )
//                       .toList(),
//             ),
//             const SizedBox(height: 10),
//             DropdownButton<String>(
//               isExpanded: true,
//               value: selectedModel,
//               hint: const Text('Select Vehicle Model'),
//               onChanged: (model) => setState(() => selectedModel = model),
//               items:
//                   vehicleModels
//                       .map(
//                         (model) =>
//                             DropdownMenuItem(value: model, child: Text(model)),
//                       )
//                       .toList(),
//             ),
//             const SizedBox(height: 10),
//             DropdownButton<String>(
//               isExpanded: true,
//               value: selectedCategory,
//               hint: const Text('Select Vehicle Category'),
//               onChanged: (cat) => setState(() => selectedCategory = cat),
//               items:
//                   vehicleCategories
//                       .map(
//                         (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
//                       )
//                       .toList(),
//             ),
//             const SizedBox(height: 20),
//             ...["logbook", "vehiclePic", "insurance", "otherDocs"].map((key) {
//               return Padding(
//                 padding: const EdgeInsets.only(bottom: 10),
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//                   onPressed:
//                       () => showUploadOptions(key, (file) {
//                         setState(() {
//                           if (key == "logbook") logbook = file;
//                           if (key == "vehiclePic") vehiclePic = file;
//                           if (key == "insurance") insurance = file;
//                           if (key == "otherDocs") otherDocs = file;

//                           uploadStatus[key] = "$key Uploaded ✅";
//                           //uploadStatus[key] = "otherDocs Uploaded ✅";
//                         });
//                       }),
//                   child: Text(uploadStatus[key]!),
//                 ),
//               );
//             }),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
//               onPressed: submitVehicle,
//               child: const Text("Submit Vehicle"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'dart:io';
import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/View/Routes/routes.dart';

class VehicleOnboardingScreen extends StatefulWidget {
  final bool skipDriverOnboarding;
  final bool hasownerOnboarding;
  const VehicleOnboardingScreen({
    Key? key,
    this.skipDriverOnboarding = false,
    this.hasownerOnboarding = false,
  }) : super(key: key);

  @override
  State<VehicleOnboardingScreen> createState() =>
      _VehicleOnboardingScreenState();
}

class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
  String? selectedMake, selectedModel, selectedCategory;
  List<String> vehicleMakes = [];
  List<String> vehicleModels = [];
  List<String> vehicleCategories = [];

  final fullnameController = TextEditingController();
  final regController = TextEditingController();
  final yearController = TextEditingController();

  String driverId = '';
  String email = '';

  File? logbook, vehiclePic, insurance, otherDocs;
  //final ImagePicker _picker = ImagePicker();

  final Map<String, File?> _documents = {
    'logbook': null,
    'vehiclePic': null,
    'insurance': null,
  };

  final Map<String, String> _docLabels = {
    'logbook': 'Upload Logbook',
    'vehiclePic': 'Upload Vehicle Pictures',
    'insurance': 'Upload Insurance',
  };

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFile(String key) async {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take a Photo"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    setState(() {
                      _documents[key] = File(picked.path);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Pick from Gallery"),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    setState(() {
                      _documents[key] = File(picked.path);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text("Upload Document"),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null && result.files.single.path != null) {
                    setState(() {
                      _documents[key] = File(result.files.single.path!);
                    });
                  }
                },
              ),
            ],
          ),
    );
  }

  // Map<String, String> uploadStatus = {
  //   "logbook": "Upload Logbook",
  //   "vehiclePic": "Upload Vehicle Picture",
  //   "insurance": "Upload Insurance",
  //   "otherDocs": "Upload Other Documents",
  // };

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverId = user.uid;
      email = user.email ?? '';
    }
    fetchDropdownData();
  }

  Future<void> fetchDropdownData() async {
    try {
      final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
      final categoryRes = await http.get(
        Uri.parse("$baseUrl/vehicles/categories"),
      );

      if (makeRes.statusCode == 200 && categoryRes.statusCode == 200) {
        setState(() {
          vehicleMakes = List<String>.from(json.decode(makeRes.body));
          vehicleCategories = List<String>.from(json.decode(categoryRes.body));
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch dropdown data: $e");
    }
  }

  Future<void> fetchVehicleModels(String make) async {
    try {
      final modelRes = await http.get(
        Uri.parse('$baseUrl/vehicles/models?make=$make'),
      );
      if (modelRes.statusCode == 200) {
        setState(() {
          vehicleModels = List<String>.from(json.decode(modelRes.body));
          selectedModel = null;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch vehicle models: $e");
    }
  }

  Future<void> submitVehicle() async {
    // final uri = Uri.parse("$baseUrl/driver-vehicles");

    // final Map<String, dynamic> body = {
    //   "email": email,
    //   "vehicleOwnerId": driverId,
    //   "firebaseId": driverId,
    //   "vehicleMake": selectedMake,
    //   "vehicleModel": selectedModel,
    //   "vehicleCategory": selectedCategory,
    //   "registrationNumber": regController.text,
    //   "year": int.tryParse(yearController.text) ?? 0,
    //   "logbook":
    //       logbook != null ? base64Encode(logbook!.readAsBytesSync()) : null,
    //   "vehiclePicture":
    //       vehiclePic != null
    //           ? base64Encode(vehiclePic!.readAsBytesSync())
    //           : null,
    //   "insurance":
    //       insurance != null ? base64Encode(insurance!.readAsBytesSync()) : null,
    //   "otherDocuments":
    //       otherDocs != null ? base64Encode(otherDocs!.readAsBytesSync()) : null,
    // };

    // final response = await http.post(
    //   uri,
    //   headers: {"Content-Type": "application/json"},
    //   body: jsonEncode(body),
    // );

    // if (!context.mounted) return;

    // if (response.statusCode == 200) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text("Vehicle registered successfully!")),
    //   );
    //   await Future.delayed(const Duration(milliseconds: 500));
    //   GoRouter.of(context).goNamed(Routes().navigationScreen);
    // } else {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
    // }

    await Future.delayed(const Duration(milliseconds: 500));
    GoRouter.of(context).goNamed(Routes().navigationScreen);
  }

  Future<void> showUploadOptions(String key, Function(File) onPicked) async {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) onPicked(File(pickedFile.path));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) onPicked(File(pickedFile.path));
                },
              ),
            ],
          ),
    );
  }

  InputDecoration borderedDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  Widget borderedDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String? Function(dynamic val) validator,
  }) {
    return InputDecorator(
      decoration: borderedDecoration(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(label),
          onChanged: onChanged,
          items:
              items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(item.toString()),
                );
              }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    regController.dispose();
    yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vehicle Onboarding"),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (widget.hasownerOnboarding) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: fullnameController,
                decoration: borderedDecoration('Owner Full Name'),
                // validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: regController,
              decoration: borderedDecoration('Registration Number'),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: yearController,
              decoration: borderedDecoration('Year'),
              keyboardType: TextInputType.number,
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            borderedDropdown<String>(
              label: 'Select Vehicle Make',
              value: selectedMake,
              items: vehicleMakes,
              onChanged: (make) {
                setState(() {
                  selectedMake = make;
                  selectedModel = null;
                });
                if (make != null) fetchVehicleModels(make);
              },
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            borderedDropdown<String>(
              label: 'Select Vehicle Model',
              value: selectedModel,
              items: vehicleModels,
              onChanged: (model) => setState(() => selectedModel = model),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            borderedDropdown<String>(
              label: 'Select Vehicle Category',
              value: selectedCategory,
              items: vehicleCategories,
              onChanged: (cat) => setState(() => selectedCategory = cat),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            ..._documents.keys.map((key) {
              final file = _documents[key];
              final label = _docLabels[key]!;
              return BorderedUploadButton(
                label: label,
                isUploaded: file != null,
                onPressed: () => _pickFile(key),
              );
            }),

            // const SizedBox(height: 20),
            // ...["logbook", "vehiclePic", "insurance", "otherDocs"].map((key) {
            //   return Padding(
            //     padding: const EdgeInsets.only(bottom: 12),
            //     child: ElevatedButton(
            //       style: ElevatedButton.styleFrom(
            //         backgroundColor: Colors.blue,
            //         padding: const EdgeInsets.symmetric(vertical: 16),
            //       ),
            //       onPressed:
            //           () => showUploadOptions(key, (file) {
            //             setState(() {
            //               if (key == "logbook") logbook = file;
            //               if (key == "vehiclePic") vehiclePic = file;
            //               if (key == "insurance") insurance = file;
            //               if (key == "otherDocs") otherDocs = file;

            //               uploadStatus[key] = "$key Uploaded ✅";
            //             });
            //           }),
            //       child: Text(uploadStatus[key]!),
            //     ),
            //   );
            // }),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: submitVehicle,
              child: const Text("Submit Vehicle"),
            ),
          ],
        ),
      ),
    );
  }
}
