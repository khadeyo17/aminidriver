// import 'package:aminidriver/Onboarding/driveronboardingcontroller.dart';
// import 'package:flutter/material.dart';

// class DriverOnboardingScreen extends StatefulWidget {
//   const DriverOnboardingScreen({super.key});

//   @override
//   State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
// }

// class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
//   final DriverOnboardingController controller = DriverOnboardingController();

//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Driver Onboarding')),
//       body: Form(
//         key: controller.formKey,
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             children: [
//               _buildTextField(controller.firstNameController, 'First Name'),
//               _buildTextField(controller.middleNameController, 'Middle Name'),
//               _buildTextField(controller.lastNameController, 'Last Name'),
//               _buildDropdownField(),
//               _buildTextField(controller.idNumberController, 'ID Number'),
//               _buildTextField(
//                 controller.paymentMobileController,
//                 'Payment Mobile',
//               ),
//               _buildTextField(
//                 controller.referralCodeController,
//                 'Referral Code',
//               ),
//               _buildTextField(
//                 controller.licenseExpiryController,
//                 'License Expiry',
//               ),
//               const SizedBox(height: 20),
//               const Divider(),
//               ...controller.docLabels.entries.map((entry) {
//                 final key = entry.key;
//                 final label = entry.value;
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 8),
//                   child: ElevatedButton.icon(
//                     icon: Icon(
//                       controller.documents[key] != null
//                           ? Icons.check_circle
//                           : Icons.upload_file,
//                     ),
//                     label: Text(label),
//                     onPressed: () async {
//                       await controller.pickFile(
//                         context,
//                         key,
//                         () => setState(() {}),
//                       );
//                     },
//                   ),
//                 );
//               }).toList(),
//               const SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: () {
//                   if (controller.formKey.currentState!.validate()) {
//                     final data = controller.collectData();
//                     // You can now send `data` to backend or process it
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Form submitted!')),
//                     );
//                   }
//                 },
//                 child: const Text('Submit'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(TextEditingController controller, String label) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: TextFormField(
//         controller: controller,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//         ),
//         validator:
//             (value) => value == null || value.isEmpty ? 'Required' : null,
//       ),
//     );
//   }

//   Widget _buildDropdownField() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: DropdownButtonFormField<String>(
//         value: controller.selectedIdType,
//         decoration: const InputDecoration(
//           labelText: 'ID Type',
//           border: OutlineInputBorder(),
//         ),
//         items:
//             controller.idTypes
//                 .map((type) => DropdownMenuItem(value: type, child: Text(type)))
//                 .toList(),
//         onChanged: (value) => setState(() => controller.selectedIdType = value),
//         validator: (value) => value == null ? 'Required' : null,
//       ),
//     );
//   }
// }

import 'dart:io';
import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class DriverOnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  final bool skipVehicleOnboarding;
  const DriverOnboardingScreen({
    super.key,
    //required Null Function() onCompleted,
    //required this.onCompleted,
    required this.onCompleted,
    this.skipVehicleOnboarding = false,
  });
  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _licenseExpiryController =
      TextEditingController();
  DateTime? _licenseExpiryDate;

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _paymentMobileController = TextEditingController();
  final _referralCodeController = TextEditingController();
  //final _licenseExpiryController = TextEditingController();

  String? _selectedIdType;
  final List<String> _idTypes = ['National ID', 'Passport'];

  final Map<String, File?> _documents = {
    'profilePic': null,
    'idFront': null,
    'idBack': null,
    'drivingLicense': null,
    'policeClearance': null,
    'psvBadge': null,
  };

  final Map<String, String> _docLabels = {
    'profilePic': 'Upload Profile Picture',
    'idFront': 'Upload ID Front',
    'idBack': 'Upload ID Back',
    'drivingLicense': 'Upload Driving License',
    'policeClearance': 'Upload Police Clearance',
    'psvBadge': 'Upload PSV Badge',
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

  Future<void> _selectLicenseExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _licenseExpiryDate = picked;
        _licenseExpiryController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
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
    required void Function(T?) onChanged,
    required String? Function(T?) validator,
  }) {
    return DropdownButtonFormField<T>(
      decoration: borderedDecoration(label),
      value: value,
      hint: Text(label),
      onChanged: onChanged,
      validator: validator,
      items:
          items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
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
  //         validator: validator,
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

  String? phoneValidator(String? val) {
    if (val == null || val.isEmpty) return 'Required';
    final regex = RegExp(r'^(?:0|\+254)?7\d{8}$');
    if (!regex.hasMatch(val)) return 'Enter a valid phone number';
    return null;
  }

  String? licenseExpiryValidator(String? val) {
    if (val == null || val.isEmpty) return 'Required';
    try {
      final date = DateTime.parse(val);
      if (date.isBefore(DateTime.now()))
        return 'Expiry date must be in the future';
    } catch (e) {
      return 'Enter a valid date (YYYY-MM-DD)';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'firstName': _firstNameController.text,
        'middleName': _middleNameController.text,
        'lastName': _lastNameController.text,
        'idType': _selectedIdType,
        'idNumber': _idNumberController.text,
        'paymentMobile': _paymentMobileController.text,
        'referralCode': _referralCodeController.text,
        'licenseExpiry': _licenseExpiryController.text,
        'documents': _documents,
      };

      print("Collected data: $data");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Form Submitted')));
      widget.onCompleted();

      if (!widget.skipVehicleOnboarding) {
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VehicleOnboardingScreen(),
            ),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _idNumberController.dispose();
    _paymentMobileController.dispose();
    _referralCodeController.dispose();
    _licenseExpiryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Onboarding"),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _firstNameController,
                decoration: borderedDecoration('First Name'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 8),
              TextFormField(
                controller: _middleNameController,
                decoration: borderedDecoration('Middle Name'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lastNameController,
                decoration: borderedDecoration('Last Name'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 12),
              borderedDropdown<String>(
                label: 'Select ID Type',
                value: _selectedIdType,
                items: _idTypes,
                onChanged: (val) => setState(() => _selectedIdType = val),
                validator:
                    (val) => val == null || val.isEmpty ? 'Required' : null,
              ),

              // Container(
              //   decoration: BoxDecoration(
              //     border: Border.all(color: Colors.blue, width: 2),
              //     borderRadius: BorderRadius.circular(8),
              //   ),
              //   padding: const EdgeInsets.symmetric(horizontal: 12),
              //   margin: const EdgeInsets.symmetric(vertical: 6),
              //   child: DropdownButtonFormField<String>(
              //     value: _selectedIdType,
              //     items:
              //         _idTypes
              //             .map(
              //               (type) => DropdownMenuItem(
              //                 value: type,
              //                 child: Text(type),
              //               ),
              //             )
              //             .toList(),
              //     onChanged: (val) => setState(() => _selectedIdType = val),
              //     decoration: const InputDecoration(
              //       labelText: 'ID Type',
              //       border: InputBorder.none,
              //     ),
              //     validator: (val) => val == null ? 'Select ID Type' : null,
              //   ),
              // ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _idNumberController,
                decoration: borderedDecoration('ID Number'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 8),
              TextFormField(
                controller: _paymentMobileController,
                decoration: borderedDecoration('Payment Mobile'),
                //validator: (val) => val!.isEmpty ? 'Required' : null,
                validator: phoneValidator,
              ),

              const SizedBox(height: 8),
              TextFormField(
                controller: _referralCodeController,
                decoration: borderedDecoration('Referral Code'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 8),
              TextFormField(
                controller: _licenseExpiryController,
                decoration: borderedDecoration('License Expiry Date'),
                onTap: () => _selectLicenseExpiryDate(context),
                //keyboardType: TextInputType.datetime,
                validator: licenseExpiryValidator,

                // decoration: borderedDecoration('License Expiry'),
                // validator: (val) => val!.isEmpty ? 'Required' : null,
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

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: _submit,
                child: const Text("Submit your details"),
              ),
              //const SizedBox(height: 20),
              //ElevatedButton(onPressed: _submit, child: const Text("Submit")),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable yellow-bordered text field
class BorderedTextFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const BorderedTextFormField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 2), //color: Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        validator: validator,
      ),
    );
  }
}

/// Reusable yellow-bordered upload button
class BorderedUploadButton extends StatelessWidget {
  final String label;
  final bool isUploaded;
  final VoidCallback onPressed;

  const BorderedUploadButton({
    super.key,
    required this.label,
    required this.isUploaded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue,
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(label),
        trailing: Icon(isUploaded ? Icons.check_circle : Icons.upload_file),
        onTap: onPressed,
      ),
    );
  }
}

// class LicenseExpiryPicker extends StatefulWidget {
//   @override
//   _LicenseExpiryPickerState createState() => _LicenseExpiryPickerState();
// }

// class _LicenseExpiryPickerState extends State<LicenseExpiryPicker> {
//   final TextEditingController _licenseExpiryController = TextEditingController();
//   DateTime? _licenseExpiryDate;

//   Future<void> _selectDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _licenseExpiryDate ?? DateTime.now(),
//       firstDate: DateTime.now(),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null) {
//       setState(() {
//         _licenseExpiryDate = picked;
//         _licenseExpiryController.text = DateFormat('yyyy-MM-dd').format(picked);
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return TextFormField(
//       controller: _licenseExpiryController,
//       readOnly: true,
//       decoration: InputDecoration(
//         labelText: 'License Expiry Date',
//         suffixIcon: Icon(Icons.calendar_today),
//       ),
//       onTap: () => _selectDate(context),
//     );
//   }
// }
