import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class DriverOnboardingController {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final middleNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final idNumberController = TextEditingController();
  final paymentMobileController = TextEditingController();
  final referralCodeController = TextEditingController();
  final licenseExpiryController = TextEditingController();

  String? selectedIdType;
  List<String> idTypes = ['National ID', 'Passport'];

  final Map<String, File?> documents = {
    'profilePic': null,
    'idFront': null,
    'idBack': null,
    'drivingLicense': null,
    'policeClearance': null,
    'psvBadge': null,
  };

  final Map<String, String> docLabels = {
    'profilePic': 'Upload Profile Picture',
    'idFront': 'Upload ID Front',
    'idBack': 'Upload ID Back',
    'drivingLicense': 'Upload Driving License',
    'policeClearance': 'Upload Police Clearance',
    'psvBadge': 'Upload PSV Badge',
  };

  final ImagePicker _picker = ImagePicker();

  Future<void> pickFile(
    BuildContext context,
    String key,
    VoidCallback onUpdated,
  ) async {
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
                    documents[key] = File(picked.path);
                    onUpdated();
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
                    documents[key] = File(picked.path);
                    onUpdated();
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
                    documents[key] = File(result.files.single.path!);
                    onUpdated();
                  }
                },
              ),
            ],
          ),
    );
  }

  Map<String, dynamic> collectData() {
    return {
      'firstName': firstNameController.text,
      'middleName': middleNameController.text,
      'lastName': lastNameController.text,
      'idType': selectedIdType,
      'idNumber': idNumberController.text,
      'paymentMobile': paymentMobileController.text,
      'referralCode': referralCodeController.text,
      'licenseExpiry': licenseExpiryController.text,
      'documents': documents,
    };
  }

  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    idNumberController.dispose();
    paymentMobileController.dispose();
    referralCodeController.dispose();
    licenseExpiryController.dispose();
  }
}
