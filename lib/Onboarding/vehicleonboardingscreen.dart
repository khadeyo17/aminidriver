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
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/document_module.dart';
import 'package:aminidriver/Onboarding/document_preview.dart';
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
  //String? selectedMake, selectedModel, selectedCategory;
  int? selectedMakeId, selectedModelId, selectedCategoryId;

  // List<String> vehicleMakes = [];
  // List<String> vehicleModels = [];
  // List<String> vehicleCategories = [];

  List<Map<String, dynamic>> vehicleMakes = [];
  List<Map<String, dynamic>> vehicleModels = [];
  List<Map<String, dynamic>> vehicleCategories = [];

  //final fullnameController = TextEditingController();
  final regController = TextEditingController();
  final yearController = TextEditingController();

  String driverId = '';
  String email = '';

  File? logbook, vehiclePic, insurance, otherDocs;
  //final ImagePicker _picker = ImagePicker();

  final Map<DocumentType, Map<String, dynamic>> _documents = {
    DocumentType.logbook: {'file': null, 'status': null, 'url': null},
    DocumentType.vehiclePicture: {'file': null, 'status': null, 'url': null},
    DocumentType.insuranceCover: {'file': null, 'status': null, 'url': null},
    DocumentType.psvCertificate: {'file': null, 'status': null, 'url': null},
    DocumentType.healthCertificate: {'file': null, 'status': null, 'url': null},
    DocumentType.psvBadge: {'file': null, 'status': null, 'url': null},
    //DocumentType.psvBadge: 'Upload PSV Badge',
  };
  final Map<DocumentType, String> _docLabels = {
    DocumentType.logbook: 'Upload logbook',
    DocumentType.vehiclePicture: 'Upload Vehicle Pic',
    DocumentType.insuranceCover: 'Upload Insurance',
    DocumentType.psvCertificate: 'Upload Psv Certificate',
    DocumentType.healthCertificate: 'Upload Health Certificate',
    DocumentType.psvBadge: 'Upload PSV Badge',
  };

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverId = user.uid;
      email = user.email ?? '';
    }
    fetchDropdownData();
    _fetchDocumentStatus();
  }

  Future<void> fetchDropdownData() async {
    try {
      final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
      final categoryRes = await http.get(
        Uri.parse("$baseUrl/vehicles/categories"),
      );

      if (makeRes.statusCode == 200 && categoryRes.statusCode == 200) {
        final decodedMake = json.decode(makeRes.body);
        final decodedCategory = json.decode(categoryRes.body);
        setState(() {
          vehicleMakes = List<Map<String, dynamic>>.from(decodedMake);
          vehicleCategories = List<Map<String, dynamic>>.from(decodedCategory);
          // vehicleMakes = List<String>.from(json.decode(makeRes.body));
          // vehicleCategories = List<String>.from(json.decode(categoryRes.body));
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
        final decodedModels = json.decode(modelRes.body);
        setState(() {
          vehicleModels = List<Map<String, dynamic>>.from(decodedModels);
          selectedModelId = null;
        });
        // setState(() {
        //   vehicleModels = List<String>.from(json.decode(modelRes.body));
        //   selectedModel = null;
        // });
      }
    } catch (e) {
      debugPrint("Failed to fetch vehicle models: $e");
    }
  }

  Future<void> submitVehicle() async {
    final uri = Uri.parse("$baseUrl/vehicles/UploadVehicle");

    final Map<String, dynamic> body = {
      // "email": email,
      "vehicleOwnerId": driverId,
      "firebaseUid": driverId,
      "vehicleMake": selectedMakeId,
      "vehicleModel": selectedModelId,
      "vehicleCategoryId": selectedCategoryId,
      "registrationNumber": regController.text,
      "year": int.tryParse(yearController.text) ?? 0,
    };

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (!context.mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vehicle registered successfully!")),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      GoRouter.of(context).goNamed(Routes().navigationScreen);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
    }

    await Future.delayed(const Duration(milliseconds: 500));
    GoRouter.of(context).goNamed(Routes().navigationScreen);
  }

  Future<void> uploadDocumentToBackend(DocumentType type, File file) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (idToken == null || user == null) return;

    final uri = Uri.parse('$baseUrl/vehicles/documents/upload-file');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';

    request.fields['documentType'] = type.name;

    final fileName = file.path.split('/').last;

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: fileName),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      await _fetchDocumentStatus();
      print('Document uploaded directly to backend!');
    } else {
      print('Backend upload failed: ${response.statusCode}');
    }
  }

  Future<void> deleteDocumentFromBackend(DocumentType type) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null) return;

    final uri = Uri.parse('$baseUrl/auth/documents/delete?type=${type.name}');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _documents[type]!['file'] = null;
        _documents[type]!['url'] = null;
        _documents[type]!['status'] = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Document deleted successfully')));
    } else {
      debugPrint('Failed to delete: ${response.statusCode}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete document')));
    }
  }

  Future<void> _fetchDocumentStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    final response = await http.get(
      Uri.parse("$baseUrl/vehicles/documents/status/${user?.uid}"),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        for (var docJson in data) {
          final doc = DocumentModel.fromJson(docJson);
          // _documents[doc.documentType] = {
          //   'file': null, // or File(doc.filePath) if local
          //   'status': doc.status, // ✅ Use label here
          //   'url': doc.filePath,
          // };
        }
      });
    } else {
      debugPrint('Failed to fetch document statuses');
    }
  }

  Future<void> _pickFile(DocumentType type) async {
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
                      _documents[type]!['file'] = File(picked.path);
                    });
                    await uploadDocumentToBackend(type, File(picked.path));
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
                      _documents[type]!['file'] = File(picked.path);
                    });
                    await uploadDocumentToBackend(type, File(picked.path));
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
                      _documents[type]!['file'] = File(
                        result.files.single.path!,
                      );
                    });
                    await uploadDocumentToBackend(
                      type,
                      File(result.files.single.path!),
                    );
                  }
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
    required List<DropdownMenuItem<T>> items,
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
          items: items,
        ),
      ),
    );
  }

  // Widget borderedDropdown<T>({
  //   required String label,
  //   required T? value,
  //   required List<T> items,
  //   required Function(T?) onChanged,
  //   required String? Function(dynamic val) validator,
  // }) {
  //   return InputDecorator(
  //     decoration: borderedDecoration(label),
  //     child: DropdownButtonHideUnderline(
  //       child: DropdownButton<T>(
  //         isExpanded: true,
  //         value: value,
  //         hint: Text(label),
  //         onChanged: onChanged,
  //         items:
  //             items.map((item) {
  //               return DropdownMenuItem<T>(
  //                 value: item,
  //                 child: Text(item.toString()),
  //               );
  //             }).toList(),
  //       ),
  //     ),
  //   );
  // }

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
            if (widget.hasownerOnboarding) ...[],
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

            // borderedDropdown<int>(
            //   label: 'Select Vehicle Make',
            //   value: selectedMakeId,
            //   items: vehicleMakes,
            //   onChanged: (make) {
            //     setState(() {
            //       selectedMake = make;
            //       selectedModel = null;
            //     });
            //     if (make != null) fetchVehicleModels(make);
            //   },
            //   validator: (val) => val!.isEmpty ? 'Required' : null,
            // ),
            borderedDropdown<int>(
              label: 'Select Vehicle Make',
              value: selectedMakeId,
              items:
                  vehicleMakes.map((make) {
                    return DropdownMenuItem<int>(
                      value: make['id'],
                      child: Text(make['name']),
                    );
                  }).toList(),
              onChanged: (id) {
                setState(() {
                  selectedMakeId = id;
                  selectedModelId = null;
                });
                final selectedMake = vehicleMakes.firstWhere(
                  (m) => m['id'] == id,
                );
                fetchVehicleModels(selectedMake['name']);
              },
              validator: (val) => val == null ? 'Required' : null,
            ),

            // const SizedBox(height: 12),
            // borderedDropdown<String>(
            //   label: 'Select Vehicle Model',
            //   value: selectedModel,
            //   items: vehicleModels,
            //   onChanged: (model) => setState(() => selectedModel = model),
            //   validator: (val) => val!.isEmpty ? 'Required' : null,
            // ),
            borderedDropdown<int>(
              label: 'Select Vehicle Model',
              value: selectedModelId,
              items:
                  vehicleModels.map((model) {
                    return DropdownMenuItem<int>(
                      value: model['id'],
                      child: Text(model['name']),
                    );
                  }).toList(),
              onChanged: (id) => setState(() => selectedModelId = id),
              validator: (val) => val == null ? 'Required' : null,
            ),

            // const SizedBox(height: 12),
            // borderedDropdown<String>(
            //   label: 'Select Vehicle Category',
            //   value: selectedCategory,
            //   items: vehicleCategories,
            //   onChanged: (cat) => setState(() => selectedCategory = cat),
            //   validator: (val) => val!.isEmpty ? 'Required' : null,
            // ),
            borderedDropdown<int>(
              label: 'Select Vehicle Category',
              value: selectedCategoryId,
              items:
                  vehicleCategories.map((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'],
                      child: Text(cat['name']),
                    );
                  }).toList(),
              onChanged: (id) => setState(() => selectedCategoryId = id),
              validator: (val) => val == null ? 'Required' : null,
            ),

            ..._documents.entries.map((entry) {
              final type = entry.key;
              final doc = entry.value;
              final label = _docLabels[type] ?? type.name;
              final file = doc['file'] as File?;
              final url = doc['url'];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BorderedUploadButton(
                    label: label,
                    isUploaded: file != null || url != null,
                    status: doc['status'],
                    onPressed: () => _pickFile(type),
                    onPreview: () {
                      if (file != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreviewScreen(file: file),
                          ),
                        );
                      } else if (url != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreviewScreen(url: url),
                          ),
                        );
                      }
                    },

                    // onRemove: () {
                    //   setState(() {
                    //     _documents[type]!['file'] = null;
                    //     _documents[type]!['url'] = null;
                    //     _documents[type]!['status'] = null;
                    //   });
                    // },
                    onRemove: () async {
                      await deleteDocumentFromBackend(
                        type,
                      ); // ❗ delete on backend
                      setState(() {
                        _documents[type]!['file'] = null;
                        _documents[type]!['url'] = null;
                        _documents[type]!['status'] = null;
                      });
                    },
                  ),
                ],
              );
            }),

            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
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

class BorderedUploadButton extends StatelessWidget {
  final String label;
  final bool isUploaded;
  final String? status;
  final VoidCallback onPressed;
  final VoidCallback? onPreview;
  final VoidCallback? onRemove;

  const BorderedUploadButton({
    super.key,
    required this.label,
    required this.isUploaded,
    required this.onPressed,
    this.status,
    this.onPreview,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isUploaded ? onRemove : null, // Long press to remove
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          border: Border.all(color: Colors.grey, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          onTap: isUploaded ? onPreview ?? onPressed : onPressed,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(color: Colors.white)),
              ),
              if (status != null) _buildStatusChip(status!),
            ],
          ),
          trailing: Icon(
            isUploaded ? Icons.check_circle : Icons.upload_file,
            color: isUploaded ? Colors.greenAccent : Colors.white,
          ),
        ),
      ),
    );
  }
}

Widget _buildStatusChip(String status) {
  late final String label;
  late final Color color;

  switch (status.toLowerCase()) {
    case 'approved':
      label = 'Approved';
      color = Colors.green;
      break;
    case 'rejected':
      label = 'Rejected';
      color = Colors.redAccent;
      break;
    case 'underreview':
    default:
      label = 'Under Review';
      color = Colors.orange;
      break;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}
