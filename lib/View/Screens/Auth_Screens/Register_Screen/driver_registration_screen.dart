// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';

// class DriverVehicleOnboardingScreen extends StatefulWidget {
//   @override
//   _DriverVehicleOnboardingScreenState createState() =>
//       _DriverVehicleOnboardingScreenState();
// }

// class _DriverVehicleOnboardingScreenState
//     extends State<DriverVehicleOnboardingScreen> {
//   final firstNameController = TextEditingController();
//   final middleNameController = TextEditingController();
//   final lastNameController = TextEditingController();
//   final idNumberController = TextEditingController();
//   final paymentMobileController = TextEditingController();
//   final referralCodeController = TextEditingController();
//   final licenseExpiryController = TextEditingController();
//   final regController = TextEditingController();
//   final yearController = TextEditingController();

//   String? selectedIdType;
//   String? selectedMake, selectedModel, selectedCategory;

//   final idTypes = ['National ID', 'Passport'];
//   final vehicleMakes = ['Toyota', 'Honda', 'Nissan'];
//   final vehicleModels = ['Corolla', 'Civic', 'Altima'];
//   final vehicleCategories = ['Sedan', 'SUV', 'Truck'];

//   final ImagePicker _picker = ImagePicker();

//   File? profilePic,
//       idFront,
//       idBack,
//       drivingLicense,
//       policeClearance,
//       psvBadge,
//       logbook,
//       vehiclePic,
//       insurance,
//       otherDocs;

//   Future<void> _showUploadOptions(String label, Function(File) onPicked) async {
//     await showModalBottomSheet(
//       context: context,
//       builder:
//           (_) => Wrap(
//             children: [
//               ListTile(
//                 leading: Icon(Icons.camera_alt),
//                 title: Text('Take a photo'),
//                 onTap: () async {
//                   final picked = await _picker.pickImage(
//                     source: ImageSource.camera,
//                   );
//                   if (picked != null) onPicked(File(picked.path));
//                   Navigator.pop(context);
//                 },
//               ),
//               ListTile(
//                 leading: Icon(Icons.photo_library),
//                 title: Text('Choose from gallery'),
//                 onTap: () async {
//                   final picked = await _picker.pickImage(
//                     source: ImageSource.gallery,
//                   );
//                   if (picked != null) onPicked(File(picked.path));
//                   Navigator.pop(context);
//                 },
//               ),
//               ListTile(
//                 leading: Icon(Icons.attach_file),
//                 title: Text('Upload document'),
//                 onTap: () async {
//                   final result = await FilePicker.platform.pickFiles();
//                   if (result?.files.single.path != null) {
//                     onPicked(File(result!.files.single.path!));
//                   }
//                   Navigator.pop(context);
//                 },
//               ),
//             ],
//           ),
//     );
//   }

//   Widget _buildUploadButton(String label, File? file, Function(File) onPicked) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: ElevatedButton.icon(
//         onPressed: () => _showUploadOptions(label, onPicked),
//         icon: Icon(
//           file != null ? Icons.check_circle : Icons.upload_file,
//           color: file != null ? Colors.green : null,
//         ),
//         label: Text(label),
//         style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(45)),
//       ),
//     );
//   }

//   Widget _buildDropdown<T>({
//     required String label,
//     required T? value,
//     required List<T> items,
//     required Function(T?) onChanged,
//   }) {
//     return DropdownButtonFormField<T>(
//       decoration: InputDecoration(labelText: label),
//       value: value,
//       onChanged: onChanged,
//       items:
//           items
//               .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
//               .toList(),
//     );
//   }

//   @override
//   void dispose() {
//     firstNameController.dispose();
//     middleNameController.dispose();
//     lastNameController.dispose();
//     idNumberController.dispose();
//     paymentMobileController.dispose();
//     referralCodeController.dispose();
//     licenseExpiryController.dispose();
//     regController.dispose();
//     yearController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Driver & Vehicle Onboarding")),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             ExpansionTile(
//               title: Text(
//                 "Driver Details",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               children: [
//                 TextFormField(
//                   controller: firstNameController,
//                   decoration: InputDecoration(labelText: "First Name"),
//                 ),
//                 TextFormField(
//                   controller: middleNameController,
//                   decoration: InputDecoration(labelText: "Middle Name"),
//                 ),
//                 TextFormField(
//                   controller: lastNameController,
//                   decoration: InputDecoration(labelText: "Last Name"),
//                 ),
//                 _buildDropdown<String>(
//                   label: "ID Type",
//                   value: selectedIdType,
//                   items: idTypes,
//                   onChanged: (val) => setState(() => selectedIdType = val),
//                 ),
//                 TextFormField(
//                   controller: idNumberController,
//                   decoration: InputDecoration(labelText: "ID Number"),
//                 ),
//                 TextFormField(
//                   controller: paymentMobileController,
//                   decoration: InputDecoration(labelText: "Payment Mobile"),
//                 ),
//                 TextFormField(
//                   controller: referralCodeController,
//                   decoration: InputDecoration(labelText: "Referral Code"),
//                 ),
//                 TextFormField(
//                   controller: licenseExpiryController,
//                   decoration: InputDecoration(labelText: "License Expiry Date"),
//                 ),
//                 _buildUploadButton(
//                   "Upload Profile Picture",
//                   profilePic,
//                   (f) => setState(() => profilePic = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload ID Front",
//                   idFront,
//                   (f) => setState(() => idFront = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload ID Back",
//                   idBack,
//                   (f) => setState(() => idBack = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload Driving License",
//                   drivingLicense,
//                   (f) => setState(() => drivingLicense = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload Police Clearance",
//                   policeClearance,
//                   (f) => setState(() => policeClearance = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload PSV Badge",
//                   psvBadge,
//                   (f) => setState(() => psvBadge = f),
//                 ),
//               ],
//             ),
//             ExpansionTile(
//               title: Text(
//                 "Vehicle Details",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               children: [
//                 _buildDropdown<String>(
//                   label: "Make",
//                   value: selectedMake,
//                   items: vehicleMakes,
//                   onChanged: (val) => setState(() => selectedMake = val),
//                 ),
//                 _buildDropdown<String>(
//                   label: "Model",
//                   value: selectedModel,
//                   items: vehicleModels,
//                   onChanged: (val) => setState(() => selectedModel = val),
//                 ),
//                 _buildDropdown<String>(
//                   label: "Category",
//                   value: selectedCategory,
//                   items: vehicleCategories,
//                   onChanged: (val) => setState(() => selectedCategory = val),
//                 ),
//                 TextFormField(
//                   controller: regController,
//                   decoration: InputDecoration(labelText: "Registration Number"),
//                 ),
//                 TextFormField(
//                   controller: yearController,
//                   decoration: InputDecoration(labelText: "Year"),
//                 ),
//                 _buildUploadButton(
//                   "Upload Logbook",
//                   logbook,
//                   (f) => setState(() => logbook = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload Vehicle Picture",
//                   vehiclePic,
//                   (f) => setState(() => vehiclePic = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload Insurance",
//                   insurance,
//                   (f) => setState(() => insurance = f),
//                 ),
//                 _buildUploadButton(
//                   "Upload Other Documents",
//                   otherDocs,
//                   (f) => setState(() => otherDocs = f),
//                 ),
//               ],
//             ),

//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _submitForm,
//               child: Text("Submit"),
//               style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(50)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _submitForm() async {
//     // Collect and send data to backend
//     // Add API logic here
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text("Form submitted (stub).")));
//   }
// }

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';

class DriverVehicleOnboardingScreen extends StatefulWidget {
  @override
  _DriverVehicleOnboardingScreenState createState() =>
      _DriverVehicleOnboardingScreenState();
}

class _DriverVehicleOnboardingScreenState
    extends State<DriverVehicleOnboardingScreen> {
  // Driver details controllers
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final idNumberController = TextEditingController();
  final paymentMobileController = TextEditingController();
  final referralCodeController = TextEditingController();
  final licenseExpiryController = TextEditingController();

  // Vehicle details controllers
  final regController = TextEditingController();
  final yearController = TextEditingController();

  String? selectedIdType;
  String? selectedMake, selectedModel, selectedCategory;

  List<String> idTypes = ['National ID', 'Passport'];
  List<String> vehicleMakes = ['Toyota', 'Honda', 'Nissan']; // Example makes
  List<String> vehicleModels = ['Corolla', 'Civic', 'Altima']; // Example models
  List<String> vehicleCategories = [
    'Sedan',
    'SUV',
    'Truck',
  ]; // Example categories

  // Image files for documents
  File? profilePic, idFront, idBack, drivingLicense, policeClearance, psvBadge;
  File? logbook, vehiclePic, insurance, otherDocs;
  final ImagePicker _picker = ImagePicker();

  Map<String, String> uploadStatus = {
    "logbook": "Upload Logbook",
    "vehiclePic": "Upload Vehicle Picture",
    "insurance": "Upload Insurance",
    "otherDocs": "Upload Other Documents",
    "profilePic": "Upload Profile Picture",
    "idFront": "Upload ID Front",
    "idBack": "Upload ID Back",
    "drivingLicense": "Upload Driving License",
    "policeClearance": "Upload Police Clearance",
    "psvBadge": "Upload PSV Badge",
  };

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    idNumberController.dispose();
    paymentMobileController.dispose();
    referralCodeController.dispose();
    licenseExpiryController.dispose();
    regController.dispose();
    yearController.dispose();
    super.dispose();
  }

  Future<void> submitForm() async {
    final user = FirebaseAuth.instance.currentUser;
    String driverId = user?.uid ?? '';
    String email = user?.email ?? '';

    // Collect driver data
    final Map<String, dynamic> driverData = {
      'firstName': firstNameController.text,
      'middleName': middleNameController.text,
      'lastName': lastNameController.text,
      'idType': selectedIdType,
      'idNumber': idNumberController.text,
      'paymentMobile': paymentMobileController.text,
      'referralCode': referralCodeController.text,
      'licenseExpiry': licenseExpiryController.text,
      'documents': {
        'profilePic':
            profilePic != null
                ? base64Encode(profilePic!.readAsBytesSync())
                : null,
        'idFront':
            idFront != null ? base64Encode(idFront!.readAsBytesSync()) : null,
        'idBack':
            idBack != null ? base64Encode(idBack!.readAsBytesSync()) : null,
        'drivingLicense':
            drivingLicense != null
                ? base64Encode(drivingLicense!.readAsBytesSync())
                : null,
        'policeClearance':
            policeClearance != null
                ? base64Encode(policeClearance!.readAsBytesSync())
                : null,
        'psvBadge':
            psvBadge != null ? base64Encode(psvBadge!.readAsBytesSync()) : null,
      },
    };

    // Collect vehicle data
    final Map<String, dynamic> vehicleData = {
      "email": email,
      "vehicleOwnerId": driverId,
      "vehicleMake": selectedMake,
      "vehicleModel": selectedModel,
      "vehicleCategory": selectedCategory,
      "registrationNumber": regController.text,
      "year": int.tryParse(yearController.text) ?? 0,
      "logbook":
          logbook != null ? base64Encode(logbook!.readAsBytesSync()) : null,
      "vehiclePicture":
          vehiclePic != null
              ? base64Encode(vehiclePic!.readAsBytesSync())
              : null,
      "insurance":
          insurance != null ? base64Encode(insurance!.readAsBytesSync()) : null,
      "otherDocuments":
          otherDocs != null ? base64Encode(otherDocs!.readAsBytesSync()) : null,
    };

    // Send data to the backend API (use your API endpoint here)
    final response = await http.post(
      Uri.parse('YOUR_BACKEND_API_URL'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'driverData': driverData, 'vehicleData': vehicleData}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Onboarding successful!")));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
    }
  }

  Future<void> showUploadOptions(
    String fileKey,
    Function(File) onPicked,
  ) async {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Wrap(
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
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Upload Document'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null && result.files.single.path != null) {
                    onPicked(File(result.files.single.path!));
                  }
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme's text color (black or white)
    final theme = Theme.of(context);
    final textColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text("Driver & Vehicle Onboarding"),
        backgroundColor: Colors.blue,
      ),
      body: Container(
        color: Colors.blue[50], // Set background color
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Driver Details Section
            ExpansionTile(
              title: Text(
                "Driver Details",
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                TextFormField(
                  controller: firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                TextFormField(
                  controller: middleNameController,
                  decoration: InputDecoration(
                    labelText: 'Middle Name',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                TextFormField(
                  controller: lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                DropdownButton<String>(
                  value: selectedIdType,
                  hint: Text(
                    "Select ID Type",
                    style: TextStyle(color: textColor),
                  ),
                  onChanged: (value) {
                    setState(() {
                      selectedIdType = value;
                    });
                  },
                  items:
                      idTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                ),
                TextFormField(
                  controller: idNumberController,
                  decoration: InputDecoration(
                    labelText: 'ID Number',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                TextFormField(
                  controller: paymentMobileController,
                  decoration: InputDecoration(
                    labelText: 'Payment Mobile',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                TextFormField(
                  controller: referralCodeController,
                  decoration: InputDecoration(
                    labelText: 'Referral Code',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                TextFormField(
                  controller: licenseExpiryController,
                  decoration: InputDecoration(
                    labelText: 'License Expiry Date',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                // Document Uploads for Driver
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "profilePic",
                        (file) => setState(() => profilePic = file),
                      ),
                  child: Text(
                    uploadStatus["profilePic"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "idFront",
                        (file) => setState(() => idFront = file),
                      ),
                  child: Text(
                    uploadStatus["idFront"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "idBack",
                        (file) => setState(() => idBack = file),
                      ),
                  child: Text(
                    uploadStatus["idBack"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "drivingLicense",
                        (file) => setState(() => drivingLicense = file),
                      ),
                  child: Text(
                    uploadStatus["drivingLicense"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "policeClearance",
                        (file) => setState(() => policeClearance = file),
                      ),
                  child: Text(
                    uploadStatus["policeClearance"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "psvBadge",
                        (file) => setState(() => psvBadge = file),
                      ),
                  child: Text(
                    uploadStatus["psvBadge"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Vehicle Details Section
            ExpansionTile(
              title: Text(
                "Vehicle Details",
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                DropdownButton<String>(
                  value: selectedMake,
                  hint: Text(
                    "Select Vehicle Make",
                    style: TextStyle(color: textColor),
                  ),
                  onChanged: (value) {
                    setState(() {
                      selectedMake = value;
                    });
                  },
                  items:
                      vehicleMakes.map((make) {
                        return DropdownMenuItem<String>(
                          value: make,
                          child: Text(make, style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                ),
                DropdownButton<String>(
                  value: selectedModel,
                  hint: Text(
                    "Select Vehicle Model",
                    style: TextStyle(color: textColor),
                  ),
                  onChanged: (value) {
                    setState(() {
                      selectedModel = value;
                    });
                  },
                  items:
                      vehicleModels.map((model) {
                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            model,
                            style: TextStyle(color: textColor),
                          ),
                        );
                      }).toList(),
                ),
                DropdownButton<String>(
                  value: selectedCategory,
                  hint: Text(
                    "Select Vehicle Category",
                    style: TextStyle(color: textColor),
                  ),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                  items:
                      vehicleCategories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category,
                            style: TextStyle(color: textColor),
                          ),
                        );
                      }).toList(),
                ),
                TextFormField(
                  controller: regController,
                  decoration: InputDecoration(
                    labelText: 'Registration Number',
                    labelStyle: TextStyle(color: textColor),
                  ),
                ),
                TextFormField(
                  controller: yearController,
                  decoration: InputDecoration(
                    labelText: 'Year of Manufacture',
                    labelStyle: TextStyle(color: textColor),
                  ),
                  keyboardType: TextInputType.number,
                ),
                // Document Uploads for Vehicle
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "logbook",
                        (file) => setState(() => logbook = file),
                      ),
                  child: Text(
                    uploadStatus["logbook"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "vehiclePic",
                        (file) => setState(() => vehiclePic = file),
                      ),
                  child: Text(
                    uploadStatus["vehiclePic"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "insurance",
                        (file) => setState(() => insurance = file),
                      ),
                  child: Text(
                    uploadStatus["insurance"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      () => showUploadOptions(
                        "otherDocs",
                        (file) => setState(() => otherDocs = file),
                      ),
                  child: Text(
                    uploadStatus["otherDocs"]!,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitForm,
              child: Text("Submit"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}


// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:file_picker/file_picker.dart';

// class DriverVehicleOnboardingScreen extends StatefulWidget {
//   @override
//   _DriverVehicleOnboardingScreenState createState() =>
//       _DriverVehicleOnboardingScreenState();
// }

// class _DriverVehicleOnboardingScreenState
//     extends State<DriverVehicleOnboardingScreen> {
//   // Driver details controllers
//   final firstNameController = TextEditingController();
//   final middleNameController = TextEditingController();
//   final lastNameController = TextEditingController();
//   final idNumberController = TextEditingController();
//   final paymentMobileController = TextEditingController();
//   final referralCodeController = TextEditingController();
//   final licenseExpiryController = TextEditingController();

//   // Vehicle details controllers
//   final regController = TextEditingController();
//   final yearController = TextEditingController();

//   String? selectedIdType;
//   String? selectedMake, selectedModel, selectedCategory;

//   List<String> idTypes = ['National ID', 'Passport'];
//   List<String> vehicleMakes = ['Toyota', 'Honda', 'Nissan']; // Example makes
//   List<String> vehicleModels = ['Corolla', 'Civic', 'Altima']; // Example models
//   List<String> vehicleCategories = [
//     'Sedan',
//     'SUV',
//     'Truck',
//   ]; // Example categories

//   // Image files for documents
//   File? profilePic, idFront, idBack, drivingLicense, policeClearance, psvBadge;
//   File? logbook, vehiclePic, insurance, otherDocs;
//   final ImagePicker _picker = ImagePicker();

//   Map<String, String> uploadStatus = {
//     "logbook": "Upload Logbook",
//     "vehiclePic": "Upload Vehicle Picture",
//     "insurance": "Upload Insurance",
//     "otherDocs": "Upload Other Documents",
//     "profilePic": "Upload Profile Picture",
//     "idFront": "Upload ID Front",
//     "idBack": "Upload ID Back",
//     "drivingLicense": "Upload Driving License",
//     "policeClearance": "Upload Police Clearance",
//     "psvBadge": "Upload PSV Badge",
//   };

//   @override
//   void dispose() {
//     firstNameController.dispose();
//     middleNameController.dispose();
//     lastNameController.dispose();
//     idNumberController.dispose();
//     paymentMobileController.dispose();
//     referralCodeController.dispose();
//     licenseExpiryController.dispose();
//     regController.dispose();
//     yearController.dispose();
//     super.dispose();
//   }

//   Future<void> submitForm() async {
//     final user = FirebaseAuth.instance.currentUser;
//     String driverId = user?.uid ?? '';
//     String email = user?.email ?? '';

//     // Collect driver data
//     final Map<String, dynamic> driverData = {
//       'firstName': firstNameController.text,
//       'middleName': middleNameController.text,
//       'lastName': lastNameController.text,
//       'idType': selectedIdType,
//       'idNumber': idNumberController.text,
//       'paymentMobile': paymentMobileController.text,
//       'referralCode': referralCodeController.text,
//       'licenseExpiry': licenseExpiryController.text,
//       'documents': {
//         'profilePic':
//             profilePic != null
//                 ? base64Encode(profilePic!.readAsBytesSync())
//                 : null,
//         'idFront':
//             idFront != null ? base64Encode(idFront!.readAsBytesSync()) : null,
//         'idBack':
//             idBack != null ? base64Encode(idBack!.readAsBytesSync()) : null,
//         'drivingLicense':
//             drivingLicense != null
//                 ? base64Encode(drivingLicense!.readAsBytesSync())
//                 : null,
//         'policeClearance':
//             policeClearance != null
//                 ? base64Encode(policeClearance!.readAsBytesSync())
//                 : null,
//         'psvBadge':
//             psvBadge != null ? base64Encode(psvBadge!.readAsBytesSync()) : null,
//       },
//     };

//     // Collect vehicle data
//     final Map<String, dynamic> vehicleData = {
//       "email": email,
//       "vehicleOwnerId": driverId,
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

//     // Send data to the backend API (use your API endpoint here)
//     final response = await http.post(
//       Uri.parse('YOUR_BACKEND_API_URL'),
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({'driverData': driverData, 'vehicleData': vehicleData}),
//     );

//     if (response.statusCode == 200) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Onboarding successful!")));
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
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
//               ListTile(
//                 leading: const Icon(Icons.attach_file),
//                 title: const Text('Upload Document'),
//                 onTap: () async {
//                   Navigator.pop(context);
//                   final result = await FilePicker.platform.pickFiles();
//                   if (result != null && result.files.single.path != null) {
//                     onPicked(File(result.files.single.path!));
//                   }
//                 },
//               ),
//             ],
//           ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Driver & Vehicle Onboarding"),
//         backgroundColor: Colors.blue,
//       ),
//       body: Container(
//         color: Colors.blue[50], // Set background color
//         padding: const EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             // Driver Details Section
//             ExpansionTile(
//               title: Text(
//                 "Driver Details",
//                 style: TextStyle(
//                   color: Colors.blue,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               children: [
//                 TextFormField(
//                   controller: firstNameController,
//                   decoration: InputDecoration(labelText: 'First Name'),
//                 ),
//                 TextFormField(
//                   controller: middleNameController,
//                   decoration: InputDecoration(labelText: 'Middle Name'),
//                 ),
//                 TextFormField(
//                   controller: lastNameController,
//                   decoration: InputDecoration(labelText: 'Last Name'),
//                 ),
//                 DropdownButton<String>(
//                   value: selectedIdType,
//                   hint: Text("Select ID Type"),
//                   onChanged: (value) {
//                     setState(() {
//                       selectedIdType = value;
//                     });
//                   },
//                   items:
//                       idTypes.map((type) {
//                         return DropdownMenuItem<String>(
//                           value: type,
//                           child: Text(type),
//                         );
//                       }).toList(),
//                 ),
//                 TextFormField(
//                   controller: idNumberController,
//                   decoration: InputDecoration(labelText: 'ID Number'),
//                 ),
//                 TextFormField(
//                   controller: paymentMobileController,
//                   decoration: InputDecoration(labelText: 'Payment Mobile'),
//                 ),
//                 TextFormField(
//                   controller: referralCodeController,
//                   decoration: InputDecoration(labelText: 'Referral Code'),
//                 ),
//                 TextFormField(
//                   controller: licenseExpiryController,
//                   decoration: InputDecoration(labelText: 'License Expiry Date'),
//                 ),
//                 // Document Uploads for Driver
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "profilePic",
//                         (file) => setState(() => profilePic = file),
//                       ),
//                   child: Text(uploadStatus["profilePic"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "idFront",
//                         (file) => setState(() => idFront = file),
//                       ),
//                   child: Text(uploadStatus["idFront"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "idBack",
//                         (file) => setState(() => idBack = file),
//                       ),
//                   child: Text(uploadStatus["idBack"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "drivingLicense",
//                         (file) => setState(() => drivingLicense = file),
//                       ),
//                   child: Text(uploadStatus["drivingLicense"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "policeClearance",
//                         (file) => setState(() => policeClearance = file),
//                       ),
//                   child: Text(uploadStatus["policeClearance"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "psvBadge",
//                         (file) => setState(() => psvBadge = file),
//                       ),
//                   child: Text(uploadStatus["psvBadge"]!),
//                 ),
//               ],
//             ),
//             SizedBox(height: 20),
//             // Vehicle Details Section
//             ExpansionTile(
//               title: Text(
//                 "Vehicle Details",
//                 style: TextStyle(
//                   color: Colors.blue,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               children: [
//                 DropdownButton<String>(
//                   value: selectedMake,
//                   hint: Text("Select Vehicle Make"),
//                   onChanged: (value) {
//                     setState(() {
//                       selectedMake = value;
//                     });
//                   },
//                   items:
//                       vehicleMakes.map((make) {
//                         return DropdownMenuItem<String>(
//                           value: make,
//                           child: Text(make),
//                         );
//                       }).toList(),
//                 ),
//                 DropdownButton<String>(
//                   value: selectedModel,
//                   hint: Text("Select Vehicle Model"),
//                   onChanged: (value) {
//                     setState(() {
//                       selectedModel = value;
//                     });
//                   },
//                   items:
//                       vehicleModels.map((model) {
//                         return DropdownMenuItem<String>(
//                           value: model,
//                           child: Text(model),
//                         );
//                       }).toList(),
//                 ),
//                 DropdownButton<String>(
//                   value: selectedCategory,
//                   hint: Text("Select Vehicle Category"),
//                   onChanged: (value) {
//                     setState(() {
//                       selectedCategory = value;
//                     });
//                   },
//                   items:
//                       vehicleCategories.map((category) {
//                         return DropdownMenuItem<String>(
//                           value: category,
//                           child: Text(category),
//                         );
//                       }).toList(),
//                 ),
//                 TextFormField(
//                   controller: regController,
//                   decoration: InputDecoration(labelText: 'Registration Number'),
//                 ),
//                 TextFormField(
//                   controller: yearController,
//                   decoration: InputDecoration(labelText: 'Year of Manufacture'),
//                   keyboardType: TextInputType.number,
//                 ),
//                 // Document Uploads for Vehicle
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "logbook",
//                         (file) => setState(() => logbook = file),
//                       ),
//                   child: Text(uploadStatus["logbook"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "vehiclePic",
//                         (file) => setState(() => vehiclePic = file),
//                       ),
//                   child: Text(uploadStatus["vehiclePic"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "insurance",
//                         (file) => setState(() => insurance = file),
//                       ),
//                   child: Text(uploadStatus["insurance"]!),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                       () => showUploadOptions(
//                         "otherDocs",
//                         (file) => setState(() => otherDocs = file),
//                       ),
//                   child: Text(uploadStatus["otherDocs"]!),
//                 ),
//               ],
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: submitForm,
//               child: Text("Submit"),
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:go_router/go_router.dart';
// import 'driveronboardingcontroller.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:aminidriver/Container/utils/api_constant.dart';

// class VehicleOnboardingScreen extends StatefulWidget {
//   @override
//   State<VehicleOnboardingScreen> createState() =>
//       _VehicleOnboardingScreenState();
// }

// class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
//   final regController = TextEditingController();
//   final yearController = TextEditingController();
//   final controller = DriverOnboardingController();

//   String? selectedMake, selectedModel, selectedCategory;
//   List<String> vehicleMakes = [];
//   List<String> vehicleModels = [];
//   List<String> vehicleCategories = [];

//   File? logbook, vehiclePic, insurance, otherDocs;
//   final ImagePicker _picker = ImagePicker();

//   String driverId = "";
//   String email = "";

//   Map<String, String> uploadStatus = {
//     "logbook": "Upload Logbook",
//     "vehiclePic": "Upload Vehicle Picture",
//     "insurance": "Upload Insurance",
//     "otherDocs": "Upload Other Documents",
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
//               ListTile(
//                 leading: const Icon(Icons.attach_file),
//                 title: const Text('Choose Document'),
//                 onTap: () async {
//                   Navigator.pop(context);
//                   final result = await FilePicker.platform.pickFiles();
//                   if (result != null && result.files.single.path != null) {
//                     onPicked(File(result.files.single.path!));
//                   }
//                 },
//               ),
//             ],
//           ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.blue,
//         title: const Text(
//           'Driver & Vehicle Onboarding',
//           style: TextStyle(color: Colors.white),
//         ),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: ListView(
//           children: [
//             // Driver Information Section
//             ExpansionTile(
//               title: Text(
//                 "Driver Information",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               children: [
//                 TextFormField(
//                   controller: regController,
//                   decoration: InputDecoration(
//                     labelText: "Registration Number",
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 TextFormField(
//                   controller: yearController,
//                   decoration: InputDecoration(
//                     labelText: "Year",
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             // Vehicle Information Section
//             ExpansionTile(
//               title: Text(
//                 "Vehicle Information",
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               children: [
//                 DropdownButtonFormField<String>(
//                   value: selectedMake,
//                   onChanged: (value) {
//                     setState(() {
//                       selectedMake = value;
//                       fetchVehicleModels(value!);
//                     });
//                   },
//                   items:
//                       vehicleMakes
//                           .map(
//                             (make) => DropdownMenuItem<String>(
//                               value: make,
//                               child: Text(make),
//                             ),
//                           )
//                           .toList(),
//                   decoration: InputDecoration(
//                     labelText: 'Vehicle Make',
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 DropdownButtonFormField<String>(
//                   value: selectedModel,
//                   onChanged: (value) {
//                     setState(() {
//                       selectedModel = value;
//                     });
//                   },
//                   items:
//                       vehicleModels
//                           .map(
//                             (model) => DropdownMenuItem<String>(
//                               value: model,
//                               child: Text(model),
//                             ),
//                           )
//                           .toList(),
//                   decoration: InputDecoration(
//                     labelText: 'Vehicle Model',
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 DropdownButtonFormField<String>(
//                   value: selectedCategory,
//                   onChanged: (value) {
//                     setState(() {
//                       selectedCategory = value;
//                     });
//                   },
//                   items:
//                       vehicleCategories
//                           .map(
//                             (category) => DropdownMenuItem<String>(
//                               value: category,
//                               child: Text(category),
//                             ),
//                           )
//                           .toList(),
//                   decoration: InputDecoration(
//                     labelText: 'Vehicle Category',
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             // Upload Documents Section
//             ...["logbook", "vehiclePic", "insurance", "otherDocs"].map((key) {
//               return Padding(
//                 padding: const EdgeInsets.only(bottom: 12),
//                 child: ElevatedButton.icon(
//                   icon: const Icon(Icons.upload_file),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue.shade700,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     textStyle: const TextStyle(fontWeight: FontWeight.bold),
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
//                   label: Text(uploadStatus[key]!),
//                 ),
//               );
//             }).toList(),
//             const SizedBox(height: 24),
//             // Submit Button
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.yellow.shade800,
//                 foregroundColor: Colors.black,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 textStyle: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               onPressed: submitVehicle,
//               child: const Text('Submit All Details'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }



// // import 'dart:convert';
// // import 'dart:io';

// // import 'package:flutter/material.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'package:file_picker/file_picker.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:go_router/go_router.dart';

// // import 'driveronboardingcontroller.dart';
// // import 'driveronboardingform.dart';
// // import 'package:aminidriver/View/Routes/routes.dart';
// // import 'package:aminidriver/Container/utils/api_constant.dart';

// // class VehicleOnboardingScreen extends StatefulWidget {
// //   @override
// //   State<VehicleOnboardingScreen> createState() => _VehicleOnboardingScreenState();
// // }

// // class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
// //   final regController = TextEditingController();
// //   final yearController = TextEditingController();
// //   final controller = DriverOnboardingController();

// //   String? selectedMake, selectedModel, selectedCategory;
// //   List<String> vehicleMakes = [];
// //   List<String> vehicleModels = [];
// //   List<String> vehicleCategories = [];

// //   File? logbook, vehiclePic, insurance, otherDocs;
// //   final ImagePicker _picker = ImagePicker();

// //   String driverId = "";
// //   String email = "";

// //   Map<String, String> uploadStatus = {
// //     "logbook": "Upload Logbook",
// //     "vehiclePic": "Upload Vehicle Picture",
// //     "insurance": "Upload Insurance",
// //     "otherDocs": "Upload Other Documents",
// //   };

// //   @override
// //   void initState() {
// //     super.initState();
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user != null) {
// //       driverId = user.uid;
// //       email = user.email ?? '';
// //     }
// //     fetchDropdownData();
// //   }

// //   Future<void> fetchDropdownData() async {
// //     final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
// //     final categoryRes = await http.get(Uri.parse("$baseUrl/vehicles/categories"));
// //     setState(() {
// //       vehicleMakes = List<String>.from(json.decode(makeRes.body));
// //       vehicleCategories = List<String>.from(json.decode(categoryRes.body));
// //     });
// //   }

// //   Future<void> fetchVehicleModels(String make) async {
// //     final modelRes = await http.get(Uri.parse('$baseUrl/vehicles/models?make=$make'));
// //     setState(() {
// //       vehicleModels = List<String>.from(json.decode(modelRes.body));
// //       selectedModel = null;
// //     });
// //   }

// //   Future<void> submitVehicle() async {
// //     final uri = Uri.parse("$baseUrl/driver-vehicles");

// //     final Map<String, dynamic> body = {
// //       "email": email,
// //       "vehicleOwnerId": driverId,
// //       "firebaseId": driverId,
// //       "vehicleMake": selectedMake,
// //       "vehicleModel": selectedModel,
// //       "vehicleCategory": selectedCategory,
// //       "registrationNumber": regController.text,
// //       "year": int.tryParse(yearController.text) ?? 0,
// //       "logbook": logbook != null ? base64Encode(logbook!.readAsBytesSync()) : null,
// //       "vehiclePicture": vehiclePic != null ? base64Encode(vehiclePic!.readAsBytesSync()) : null,
// //       "insurance": insurance != null ? base64Encode(insurance!.readAsBytesSync()) : null,
// //       "otherDocuments": otherDocs != null ? base64Encode(otherDocs!.readAsBytesSync()) : null,
// //     };

// //     final response = await http.post(
// //       uri,
// //       headers: {"Content-Type": "application/json"},
// //       body: jsonEncode(body),
// //     );

// //     if (context.mounted) {
// //       if (response.statusCode == 200) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text("Vehicle registered successfully!")),
// //         );
// //         await Future.delayed(const Duration(milliseconds: 500));
// //         GoRouter.of(context).goNamed(Routes().navigationScreen);
// //       } else {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text("Failed: ${response.body}")),
// //         );
// //       }
// //     }
// //   }

// //   Future<void> showUploadOptions(String fileKey, Function(File) onPicked) async {
// //     showModalBottomSheet(
// //       context: context,
// //       builder: (context) => Wrap(
// //         children: [
// //           ListTile(
// //             leading: const Icon(Icons.camera_alt),
// //             title: const Text('Take a Photo'),
// //             onTap: () async {
// //               Navigator.pop(context);
// //               final pickedFile = await _picker.pickImage(source: ImageSource.camera);
// //               if (pickedFile != null) onPicked(File(pickedFile.path));
// //             },
// //           ),
// //           ListTile(
// //             leading: const Icon(Icons.photo_library),
// //             title: const Text('Choose from Gallery'),
// //             onTap: () async {
// //               Navigator.pop(context);
// //               final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
// //               if (pickedFile != null) onPicked(File(pickedFile.path));
// //             },
// //           ),
// //           ListTile(
// //             leading: const Icon(Icons.attach_file),
// //             title: const Text('Choose Document'),
// //             onTap: () async {
// //               Navigator.pop(context);
// //               final result = await FilePicker.platform.pickFiles();
// //               if (result != null && result.files.single.path != null) {
// //                 onPicked(File(result.files.single.path!));
// //               }
// //             },
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         backgroundColor: Colors.blue,
// //         title: const Text('Driver & Vehicle Onboarding', style: TextStyle(color: Colors.white)),
// //         iconTheme: const IconThemeData(color: Colors.white),
// //       ),
// //       body: Padding(
// //         padding: const EdgeInsets.all(16.0),
// //         child: ListView(
// //           children: [
// //             DriverOnboardingForm(
// //               controller: controller,
// //               makes: vehicleMakes,
// //               categories: vehicleCategories,
// //               models: vehicleModels,
// //               selectedMake: selectedMake,
// //               selectedModel: selectedModel,
// //               selectedCategory: selectedCategory,
// //               onMakeChanged: (value) {
// //                 fetchVehicleModels(value);
// //                 setState(() => selectedMake = value);
// //               },
// //               onModelChanged: (value) => setState(() => selectedModel = value),
// //               onCategoryChanged: (value) => setState(() => selectedCategory = value),
// //               onSubmit: (data) {
// //                 regController.text = data['registrationNumber'] ?? '';
// //                 yearController.text = data['year'] ?? '';
// //                 selectedMake = data['vehicleMake'];
// //                 selectedModel = data['vehicleModel'];
// //                 selectedCategory = data['vehicleCategory'];
// //                 submitVehicle();
// //               },
// //             ),
// //             const SizedBox(height: 16),
// //             ...["logbook", "vehiclePic", "insurance", "otherDocs"].map((key) {
// //               return Padding(
// //                 padding: const EdgeInsets.only(bottom: 12),
// //                 child: ElevatedButton.icon(
// //                   icon: const Icon(Icons.upload_file),
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: Colors.blue.shade700,
// //                     foregroundColor: Colors.white,
// //                     padding: const EdgeInsets.symmetric(vertical: 14),
// //                     textStyle: const TextStyle(fontWeight: FontWeight.bold),
// //                   ),
// //                   onPressed: () => showUploadOptions(key, (f) {
// //                     setState(() {
// //                       if (key == "logbook") logbook = f;
// //                       if (key == "vehiclePic") vehiclePic = f;
// //                       if (key == "insurance") insurance = f;
// //                       if (key == "otherDocs") otherDocs = f;
// //                       uploadStatus[key] = "Uploaded ✅";
// //                     });
// //                   }),
// //                   label: Text(uploadStatus[key]!),
// //                 ),
// //               );
// //             }).toList(),
// //             const SizedBox(height: 24),
// //             ElevatedButton(
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.yellow.shade800,
// //                 foregroundColor: Colors.black,
// //                 padding: const EdgeInsets.symmetric(vertical: 16),
// //                 textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //               ),
// //               onPressed: submitVehicle,
// //               child: const Text('Submit All Details'),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }



// // import 'dart:convert';
// // import 'dart:io';
// // import 'package:aminidriver/Container/utils/api_constant.dart';
// // import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/driveronboardingform.dart';
// // import 'package:file_picker/file_picker.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:aminidriver/View/Routes/routes.dart';
// // import 'package:go_router/go_router.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'driveronboardingcontroller.dart';

// // class VehicleOnboardingScreen extends StatefulWidget {
// //   @override
// //   State<VehicleOnboardingScreen> createState() =>
// //       _VehicleOnboardingScreenState();
// // }

// // class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
// //   String? selectedMake, selectedModel, selectedCategory;
// //   List<String> vehicleMakes = [];
// //   List<String> vehicleModels = [];
// //   List<String> vehicleCategories = [];
// //   String driverId = "";
// //   String email = "";

// //   final regController = TextEditingController();
// //   final yearController = TextEditingController();
// //   final controller = DriverOnboardingController();

// //   File? logbook, vehiclePic, insurance, otherDocs;
// //   final ImagePicker _picker = ImagePicker();
// //   Map<String, String> uploadStatus = {
// //     "logbook": "Upload Logbook",
// //     "vehiclePic": "Upload Vehicle Picture",
// //     "insurance": "Upload Insurance",
// //     "otherDocs": "Upload Other Documents",
// //   };

// //   @override
// //   void initState() {
// //     super.initState();
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user != null) {
// //       driverId = user.uid;
// //       email = user.email ?? '';
// //     }
// //     fetchDropdownData();
// //   }

// //   @override
// //   void dispose() {
// //     controller.dispose();
// //     super.dispose();
// //   }

// //   Future<void> fetchDropdownData() async {
// //     final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
// //     final categoryRes = await http.get(
// //       Uri.parse("$baseUrl/vehicles/categories"),
// //     );
// //     setState(() {
// //       vehicleMakes = List<String>.from(json.decode(makeRes.body));
// //       vehicleCategories = List<String>.from(json.decode(categoryRes.body));
// //     });
// //   }

// //   Future<void> fetchVehicleModels(String make) async {
// //     final modelRes = await http.get(
// //       Uri.parse('$baseUrl/vehicles/models?make=$make'),
// //     );
// //     setState(() {
// //       vehicleModels = List<String>.from(json.decode(modelRes.body));
// //       selectedModel = null;
// //     });
// //   }

// //   Future<void> submitVehicle() async {
// //     final uri = Uri.parse("$baseUrl/driver-vehicles");

// //     final Map<String, dynamic> body = {
// //       "email": email,
// //       "vehicleOwnerId": driverId,
// //       "firebaseId": driverId,
// //       "vehicleMake": selectedMake,
// //       "vehicleModel": selectedModel,
// //       "vehicleCategory": selectedCategory,
// //       "registrationNumber": regController.text,
// //       "year": int.tryParse(yearController.text) ?? 0,
// //       "logbook":
// //           logbook != null ? base64Encode(logbook!.readAsBytesSync()) : null,
// //       "vehiclePicture":
// //           vehiclePic != null
// //               ? base64Encode(vehiclePic!.readAsBytesSync())
// //               : null,
// //       "insurance":
// //           insurance != null ? base64Encode(insurance!.readAsBytesSync()) : null,
// //       "otherDocuments":
// //           otherDocs != null ? base64Encode(otherDocs!.readAsBytesSync()) : null,
// //     };

// //     final response = await http.post(
// //       uri,
// //       headers: {"Content-Type": "application/json"},
// //       body: jsonEncode(body),
// //     );

// //     if (context.mounted) {
// //       if (response.statusCode == 200) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text("Vehicle registered successfully!")),
// //         );
// //         await Future.delayed(const Duration(milliseconds: 500));
// //         GoRouter.of(context).goNamed(Routes().navigationScreen);
// //       } else {
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
// //       }
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         backgroundColor: Colors.blue,
// //         title: const Text(
// //           'Vehicle Onboarding',
// //           style: TextStyle(color: Colors.white),
// //         ),
// //         iconTheme: const IconThemeData(color: Colors.white),
// //       ),
// //       body: Padding(
// //         padding: const EdgeInsets.all(16.0),

// //         // child: ListView(
// //         //   children: [
// //         //     DropdownButtonFormField<String>(
// //         //       decoration: const InputDecoration(labelText: 'Vehicle Make'),
// //         //       value: selectedMake,
// //         //       items:
// //         //           vehicleMakes
// //         //               .map(
// //         //                 (make) =>
// //         //                     DropdownMenuItem(value: make, child: Text(make)),
// //         //               )
// //         //               .toList(),
// //         //       onChanged: (value) {
// //         //         setState(() => selectedMake = value);
// //         //         fetchVehicleModels(value!);
// //         //       },
// //         //     ),
// //         //     DropdownButtonFormField<String>(
// //         //       decoration: const InputDecoration(labelText: 'Vehicle Model'),
// //         //       value: selectedModel,
// //         //       items:
// //         //           vehicleModels
// //         //               .map(
// //         //                 (model) =>
// //         //                     DropdownMenuItem(value: model, child: Text(model)),
// //         //               )
// //         //               .toList(),
// //         //       onChanged: (value) => setState(() => selectedModel = value),
// //         //     ),
// //         //     DropdownButtonFormField<String>(
// //         //       decoration: const InputDecoration(labelText: 'Vehicle Category'),
// //         //       value: selectedCategory,
// //         //       items:
// //         //           vehicleCategories
// //         //               .map(
// //         //                 (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
// //         //               )
// //         //               .toList(),
// //         //       onChanged: (value) => setState(() => selectedCategory = value),
// //         //     ),
// //         //     TextField(
// //         //       controller: regController,
// //         //       decoration: const InputDecoration(
// //         //         labelText: 'Registration Number',
// //         //       ),
// //         //     ),
// //         //     TextField(
// //         //       controller: yearController,
// //         //       decoration: const InputDecoration(labelText: 'Year'),
// //         //       keyboardType: TextInputType.number,
// //         //     ),
// //         //     const SizedBox(height: 16),
// //         //     ...["logbook", "vehiclePic", "insurance", "otherDocs"].map((key) {
// //         //       return Padding(
// //         //         padding: const EdgeInsets.only(bottom: 12),
// //         //         child: ElevatedButton(
// //         //           style: ElevatedButton.styleFrom(
// //         //             backgroundColor: Colors.blue,
// //         //             foregroundColor: Colors.black,
// //         //           ),
// //         //           onPressed:
// //         //               () => showUploadOptions(key, (f) {
// //         //                 setState(() {
// //         //                   if (key == "logbook") logbook = f;
// //         //                   if (key == "vehiclePic") vehiclePic = f;
// //         //                   if (key == "insurance") insurance = f;
// //         //                   if (key == "otherDocs") otherDocs = f;
// //         //                   uploadStatus[key] = "Uploaded ✅";
// //         //                 });
// //         //               }),
// //         //           child: Text(uploadStatus[key]!),
// //         //         ),
// //         //       );
// //         //     }).toList(),
// //         //     ElevatedButton(
// //         //       style: ElevatedButton.styleFrom(
// //         //         backgroundColor: Colors.yellow,
// //         //         foregroundColor: Colors.black,
// //         //       ),
// //         //       onPressed: submitVehicle,
// //         //       child: const Text('Submit'),
// //         //     ),
// //         //   ],
// //         // ),
// //         child: ListView(
// //           children: [
// //             DriverOnboardingForm(
// //               controller: controller,
// //               onSubmit: (data) {
// //                 // Update local state from the form controller data
// //                 regController.text = data['registrationNumber'] ?? '';
// //                 yearController.text = data['year'] ?? '';
// //                 selectedMake = data['vehicleMake'];
// //                 selectedModel = data['vehicleModel'];
// //                 selectedCategory = data['vehicleCategory'];

// //                 // Then submit
// //                 submitVehicle();
// //               },
// //             ),
// //             const SizedBox(height: 16),
// //             ...["logbook", "vehiclePic", "insurance", "otherDocs"].map((key) {
// //               return Padding(
// //                 padding: const EdgeInsets.only(bottom: 12),
// //                 child: ElevatedButton(
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: Colors.blue,
// //                     foregroundColor: Colors.black,
// //                   ),
// //                   onPressed:
// //                       () => showUploadOptions(key, (f) {
// //                         setState(() {
// //                           if (key == "logbook") logbook = f;
// //                           if (key == "vehiclePic") vehiclePic = f;
// //                           if (key == "insurance") insurance = f;
// //                           if (key == "otherDocs") otherDocs = f;
// //                           uploadStatus[key] = "Uploaded ✅";
// //                         });
// //                       }),
// //                   child: Text(uploadStatus[key]!),
// //                 ),
// //               );
// //             }).toList(),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Future<void> showUploadOptions(
// //     String fileKey,
// //     Function(File) onPicked,
// //   ) async {
// //     showModalBottomSheet(
// //       context: context,
// //       builder:
// //           (context) => Wrap(
// //             children: [
// //               ListTile(
// //                 leading: const Icon(Icons.camera_alt),
// //                 title: const Text('Take a Photo'),
// //                 onTap: () async {
// //                   Navigator.pop(context);
// //                   final pickedFile = await _picker.pickImage(
// //                     source: ImageSource.camera,
// //                   );
// //                   if (pickedFile != null) onPicked(File(pickedFile.path));
// //                 },
// //               ),
// //               ListTile(
// //                 leading: const Icon(Icons.photo_library),
// //                 title: const Text('Choose from Gallery'),
// //                 onTap: () async {
// //                   Navigator.pop(context);
// //                   final pickedFile = await _picker.pickImage(
// //                     source: ImageSource.gallery,
// //                   );
// //                   if (pickedFile != null) onPicked(File(pickedFile.path));
// //                 },
// //               ),
// //               ListTile(
// //                 leading: const Icon(Icons.attach_file),
// //                 title: const Text('Choose Document (PDF, etc.)'),
// //                 onTap: () async {
// //                   Navigator.pop(context);
// //                   final result = await FilePicker.platform.pickFiles();
// //                   if (result != null && result.files.single.path != null) {
// //                     onPicked(File(result.files.single.path!));
// //                   }
// //                 },
// //               ),
// //             ],
// //           ),
// //     );
// //   }
// // }

// // import 'dart:convert';
// // import 'dart:io';
// // import 'package:aminidriver/Container/utils/api_constant.dart';
// // import 'package:file_picker/file_picker.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:aminidriver/View/Routes/routes.dart'; //app_routes.dart
// // import 'package:go_router/go_router.dart';
// // import 'package:firebase_auth/firebase_auth.dart';

// // class VehicleOnboardingScreen extends StatefulWidget {
// //   // const VehicleOnboardingScreen({
// //   //   super.key,
// //   //   required this.driverId,
// //   //   required this.email,
// //   // });

// //   @override
// //   State<VehicleOnboardingScreen> createState() =>
// //       _VehicleOnboardingScreenState();
// // }

// // class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
// //   String? selectedMake, selectedModel, selectedCategory;
// //   List<String> vehicleMakes = [];
// //   List<String> vehicleModels = [];
// //   List<String> vehicleCategories = [];
// //   String driverId = "";
// //   String email = "";

// //   final regController = TextEditingController();
// //   final yearController = TextEditingController();

// //   File? logbook, vehiclePic, insurance, otherDocs;
// //   bool isUploading = false;
// //   final ImagePicker _picker = ImagePicker();
// //   Map<String, String> uploadStatus = {
// //     "logbook": "Upload Logbook",
// //     "vehiclePic": "Upload Vehicle Picture",
// //     "insurance": "Upload Insurance",
// //     "otherDocs": "Upload Other Documents",
// //   };
// //   @override
// //   void initState() {
// //     super.initState();

// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user != null) {
// //       driverId = user.uid;
// //       email = user.email ?? '';
// //     }

// //     fetchDropdownData();
// //   }

// //   Future<void> fetchDropdownData() async {
// //     final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
// //     final categoryRes = await http.get(
// //       Uri.parse("$baseUrl/vehicles/categories"),
// //     );
// //     //TypeError (type '_Map<String, dynamic>' is not a subtype of type 'Iterable<dynamic>')
// //     setState(() {
// //       vehicleMakes = List<String>.from(json.decode(makeRes.body));
// //       vehicleCategories = List<String>.from(json.decode(categoryRes.body));
// //     });
// //     // print("makeRes.body: ${makeRes.body}");
// //     // print("categoryRes.body: ${categoryRes.body}");
// //     //setState(() {
// //     // final decodedMakes = json.decode(makeRes.body);
// //     // final decodedCategories = json.decode(categoryRes.body);

// //     // vehicleMakes = List<String>.from(decodedMakes['makes']);
// //     // vehicleCategories = List<String>.from(decodedCategories['categories']);
// //     //   final decodedMakes = json.decode(makeRes.body);
// //     //   final decodedCategories = json.decode(categoryRes.body);

// //     //   vehicleMakes = List<String>.from(decodedMakes['makes'] ?? []);
// //     //   vehicleCategories = List<String>.from(decodedCategories['categories'] ?? []);
// //     // });
// //   }

// //   Future<void> fetchVehicleModels(String make) async {
// //     final modelRes = await http.get(
// //       Uri.parse('$baseUrl/vehicles/models?make=$make'),
// //     );

// //     setState(() {
// //       //final decodedmodels = json.decode(modelRes.body);
// //       //vehicleModels = List<String>.from(decodedmodels['models']);
// //       vehicleModels = List<String>.from(json.decode(modelRes.body));
// //       selectedModel = null; // reset selected model
// //     });
// //   }

// //   Future<void> pickFile(Function(File) onPicked) async {
// //     final result = await FilePicker.platform.pickFiles();
// //     if (result != null && result.files.single.path != null) {
// //       onPicked(File(result.files.single.path!));
// //     }
// //   }

// //   // Function to capture photo using the camera
// //   Future<void> takePhoto(Function(File) onPicked) async {
// //     final pickedFile = await _picker.pickImage(source: ImageSource.camera);
// //     if (pickedFile != null) {
// //       onPicked(File(pickedFile.path));
// //     }
// //   }

// //   Future<void> submitVehicle() async {
// //     final uri = Uri.parse("$baseUrl/driver-vehicles");

// //     final Map<String, dynamic> body = {
// //       // "driverId": driverId,
// //       "email": email,
// //       "firebaseId": driverId,
// //       "vehicleMake": selectedMake,
// //       "vehicleModel": selectedModel,
// //       "vehicleCategory": selectedCategory,
// //       "registrationNumber": regController.text,
// //       "year": int.tryParse(yearController.text) ?? 0,

// //       // If your backend accepts base64 strings, otherwise remove these:
// //       "logbook":
// //           logbook != null ? base64Encode(logbook!.readAsBytesSync()) : null,
// //       "vehiclePicture":
// //           vehiclePic != null
// //               ? base64Encode(vehiclePic!.readAsBytesSync())
// //               : null,
// //       "insurance":
// //           insurance != null ? base64Encode(insurance!.readAsBytesSync()) : null,
// //       "otherDocuments":
// //           otherDocs != null ? base64Encode(otherDocs!.readAsBytesSync()) : null,
// //     };

// //     final response = await http.post(
// //       uri,
// //       headers: {"Content-Type": "application/json"},
// //       body: jsonEncode(body),
// //     );
// //     if (response.statusCode == 200) {
// //       if (context.mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text("Vehicle registered successfully!")),
// //         );

// //         await Future.delayed(const Duration(milliseconds: 500));

// //         if (context.mounted) {
// //           GoRouter.of(context).goNamed(Routes().navigationScreen);
// //         }
// //       }
// //     } else {
// //       if (context.mounted) {
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
// //       }
// //     }
// //     if (response.statusCode == 200) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Vehicle registered successfully!")),
// //       );
// //       await Future.delayed(const Duration(milliseconds: 500));

// //       if (context.mounted) {
// //         GoRouter.of(context).goNamed(Routes().navigationScreen);
// //       }

// //       //GoRouter.of(context).goNamed(Routes().navigationScreen,);
// //     } else {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       //appBar: AppBar(title: const Text('Vehicle Onboarding')),
// //       // No changes to imports or other logic
// //       appBar: AppBar(
// //         backgroundColor: Colors.blue, // Blue bar
// //         title: const Text(
// //           'Vehicle Onboarding',
// //           style: TextStyle(color: Colors.white),
// //         ), // White text
// //       ),

// //       body: Padding(
// //         padding: const EdgeInsets.all(16.0),
// //         child: ListView(
// //           children: [
// //             DropdownButtonFormField<String>(
// //               decoration: const InputDecoration(labelText: 'Vehicle Make'),
// //               value: selectedMake,
// //               dropdownColor: Colors.white,
// //               style: const TextStyle(color: Colors.black),
// //               items:
// //                   vehicleMakes
// //                       .map(
// //                         (make) => DropdownMenuItem(
// //                           value: make,
// //                           child: Text(
// //                             make,
// //                             style: const TextStyle(color: Colors.black),
// //                           ),
// //                         ),
// //                       )
// //                       .toList(),
// //               onChanged: (value) {
// //                 setState(() => selectedMake = value);
// //                 fetchVehicleModels(value!);
// //               },
// //             ),
// //             DropdownButtonFormField<String>(
// //               decoration: const InputDecoration(labelText: 'Vehicle Model'),
// //               value: selectedModel,
// //               dropdownColor: Colors.white,
// //               style: const TextStyle(color: Colors.black),
// //               items:
// //                   vehicleModels
// //                       .map(
// //                         (model) => DropdownMenuItem(
// //                           value: model,
// //                           child: Text(
// //                             model,
// //                             style: const TextStyle(color: Colors.black),
// //                           ),
// //                         ),
// //                       )
// //                       .toList(),
// //               onChanged: (value) => setState(() => selectedModel = value),
// //             ),
// //             DropdownButtonFormField<String>(
// //               decoration: const InputDecoration(labelText: 'Vehicle Category'),
// //               value: selectedCategory,
// //               dropdownColor: Colors.white,
// //               style: const TextStyle(color: Colors.black),
// //               items:
// //                   vehicleCategories
// //                       .map(
// //                         (cat) => DropdownMenuItem(
// //                           value: cat,
// //                           child: Text(
// //                             cat,
// //                             style: const TextStyle(color: Colors.black),
// //                           ),
// //                         ),
// //                       )
// //                       .toList(),
// //               onChanged: (value) => setState(() => selectedCategory = value),
// //             ),
// //             TextField(
// //               controller: regController,
// //               decoration: const InputDecoration(
// //                 labelText: 'Registration Number',
// //               ),
// //               style: const TextStyle(color: Colors.black),
// //             ),
// //             TextField(
// //               controller: yearController,
// //               decoration: const InputDecoration(labelText: 'Year'),
// //               style: const TextStyle(color: Colors.black),
// //             ),
// //             const SizedBox(height: 16),

// //             // Upload Buttons
// //             ElevatedButton(
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.blue,
// //                 foregroundColor: Colors.yellow,
// //               ),
// //               onPressed:
// //                   () => showUploadOptions(
// //                     "logbook",
// //                     (f) => setState(() => logbook = f),
// //                   ),
// //               child: Text(uploadStatus["logbook"]!),
// //             ),
// //             ElevatedButton(
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.blue,
// //                 foregroundColor: Colors.yellow,
// //               ),
// //               onPressed:
// //                   () => showUploadOptions(
// //                     "vehiclePic",
// //                     (f) => setState(() => vehiclePic = f),
// //                   ),
// //               child: Text(uploadStatus["vehiclePic"]!),
// //             ),
// //             ElevatedButton(
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.blue,
// //                 foregroundColor: Colors.yellow,
// //               ),
// //               onPressed:
// //                   () => showUploadOptions(
// //                     "insurance",
// //                     (f) => setState(() => insurance = f),
// //                   ),
// //               child: Text(uploadStatus["insurance"]!),
// //             ),
// //             ElevatedButton(
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.blue,
// //                 foregroundColor: Colors.yellow,
// //               ),
// //               onPressed:
// //                   () => showUploadOptions(
// //                     "otherDocs",
// //                     (f) => setState(() => otherDocs = f),
// //                   ),
// //               child: Text(uploadStatus["otherDocs"]!),
// //             ),

// //             const SizedBox(height: 20),
// //             ElevatedButton(
// //               onPressed: submitVehicle,
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: Colors.blue,
// //                 foregroundColor: Colors.yellow,
// //               ),
// //               child: const Text('Submit'),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Future<void> showUploadOptions(
// //     String fileKey,
// //     Function(File) onPicked,
// //   ) async {
// //     setState(() {
// //       uploadStatus[fileKey] = "Uploading...";
// //     });

// //     showModalBottomSheet(
// //       context: context,
// //       builder:
// //           (context) => Wrap(
// //             children: [
// //               ListTile(
// //                 leading: const Icon(Icons.camera_alt),
// //                 title: const Text('Take a Photo'),
// //                 onTap: () async {
// //                   Navigator.pop(context);
// //                   final pickedFile = await _picker.pickImage(
// //                     source: ImageSource.camera,
// //                   );
// //                   if (pickedFile != null) {
// //                     onPicked(File(pickedFile.path));
// //                     setState(() {
// //                       uploadStatus[fileKey] = "Uploaded ✅";
// //                     });
// //                   }
// //                 },
// //               ),
// //               ListTile(
// //                 leading: const Icon(Icons.photo_library),
// //                 title: const Text('Choose from Gallery'),
// //                 onTap: () async {
// //                   Navigator.pop(context);
// //                   final pickedFile = await _picker.pickImage(
// //                     source: ImageSource.gallery,
// //                   );
// //                   if (pickedFile != null) {
// //                     onPicked(File(pickedFile.path));
// //                     setState(() {
// //                       uploadStatus[fileKey] = "Uploaded ✅";
// //                     });
// //                   }
// //                 },
// //               ),
// //               ListTile(
// //                 leading: const Icon(Icons.attach_file),
// //                 title: const Text('Choose Document (PDF, etc.)'),
// //                 onTap: () async {
// //                   Navigator.pop(context);
// //                   final result = await FilePicker.platform.pickFiles();
// //                   if (result != null && result.files.single.path != null) {
// //                     onPicked(File(result.files.single.path!));
// //                     setState(() {
// //                       uploadStatus[fileKey] = "Uploaded ✅";
// //                     });
// //                   }
// //                 },
// //               ),
// //             ],
// //           ),
// //     );
// //   }
// // }
