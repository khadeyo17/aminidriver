import 'dart:convert';
import 'dart:io';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/document_module.dart';
import 'package:aminidriver/Onboarding/document_preview.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/Onboarding/vehicle.dart';
import 'package:aminidriver/Onboarding/vehicle_category.dart';
import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class DriverOnboardingScreen extends StatefulWidget {
  //final VoidCallback onCompleted;
  //final bool skipVehicleOnboarding;

  final UserRole role;
  const DriverOnboardingScreen({
    super.key,

    //required this.onCompleted,
    required this.role,
    //this.skipVehicleOnboarding = false,
  });

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get showDriverSection =>
      widget.role == UserRole.driver || widget.role == UserRole.driverOwner;

  bool get showVehicleSection =>
      widget.role == UserRole.owner || widget.role == UserRole.driverOwner;

  bool _isReadOnly = false;
  VehicleCategory? _vehicleCategory;

  final TextEditingController _licenseExpiryController =
      TextEditingController();
  DateTime? _licenseExpiryDate;

  final _idNumberController = TextEditingController();
  final _paymentMobileController = TextEditingController();
  final _referralCodeController = TextEditingController();

  int? selectedMakeId, selectedModelId, selectedCategoryId;
  List<Map<String, dynamic>> vehicleMakes = [];
  List<Map<String, dynamic>> vehicleModels = [];
  //List<Map<String, dynamic>> vehicleCategories = [];
  final regController = TextEditingController();
  final yearController = TextEditingController();
  String driverId = '';
  String email = '';
  String? FetchedDriver = '';
  int? vehicleId;

  //final _licenseExpiryController = TextEditingController();

  String? _selectedIdType;
  final List<String> _idTypes = ['National ID', 'Passport'];
  final Map<DocumentType, Map<String, dynamic>> _driverDocuments = {};
  final Map<DocumentType, Map<String, dynamic>> _vehicleDocuments = {};

  void _initializeDocuments() {
    _driverDocuments.clear();
    _vehicleDocuments.clear();

    switch (_vehicleCategory) {
      case VehicleCategory.passenger:
        _driverDocuments.addAll({
          DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
          DocumentType.idFront: {'file': null, 'status': null, 'url': null},
          DocumentType.idBack: {'file': null, 'status': null, 'url': null},
          DocumentType.drivingLicense: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.policeClearance: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.psvBadge: {'file': null, 'status': null, 'url': null},
        });

        _vehicleDocuments.addAll({
          DocumentType.logbook: {'file': null, 'status': null, 'url': null},
          DocumentType.vehiclePicture: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.insuranceCover: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.psvCertificate: {
            'file': null,
            'status': null,
            'url': null,
          },
          if (_vehicleCategory == VehicleCategory.ambulance)
            DocumentType.healthCertificate: {
              'file': null,
              'status': null,
              'url': null,
            },
        });

        break;
      case VehicleCategory.ambulance:
        _driverDocuments.addAll({
          DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
          DocumentType.idFront: {'file': null, 'status': null, 'url': null},
          DocumentType.idBack: {'file': null, 'status': null, 'url': null},
          DocumentType.drivingLicense: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.policeClearance: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.psvBadge: {'file': null, 'status': null, 'url': null},
        });

        _vehicleDocuments.addAll({
          DocumentType.logbook: {'file': null, 'status': null, 'url': null},
          DocumentType.vehiclePicture: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.insuranceCover: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.psvCertificate: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.healthCertificate: {
            'file': null,
            'status': null,
            'url': null,
          },
        });
        break;
      case VehicleCategory.cargo:
      case VehicleCategory.movers:
      case VehicleCategory.carhire:
      case VehicleCategory.waterBowser:
      case VehicleCategory.exhauster:
      case VehicleCategory.breakdown:
        _driverDocuments.addAll({
          DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
          DocumentType.idFront: {'file': null, 'status': null, 'url': null},
          DocumentType.idBack: {'file': null, 'status': null, 'url': null},
          DocumentType.drivingLicense: {
            'file': null,
            'status': null,
            'url': null,
          },
        });

        _vehicleDocuments.addAll({
          DocumentType.logbook: {'file': null, 'status': null, 'url': null},
          DocumentType.insuranceCover: {
            'file': null,
            'status': null,
            'url': null,
          },
        });
        break;

      case VehicleCategory.matatu:
      case VehicleCategory.mechanical:
        _driverDocuments.addAll({
          DocumentType.CertificateOfIncorporation: {
            'file': null,
            'status': null,
            'url': null,
          },
        });
        _vehicleDocuments.addAll({
          DocumentType.logbook: {'file': null, 'status': null, 'url': null},
          DocumentType.vehiclePicture: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.insuranceCover: {
            'file': null,
            'status': null,
            'url': null,
          },
          DocumentType.psvCertificate: {
            'file': null,
            'status': null,
            'url': null,
          },
        });
        break;
      default:
        _driverDocuments.addAll({
          DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
        }); // = {DocumentType.profilePic: {}};
    }
  }

  // bool _areAllDocumentsApproved() {
  //   final documents = [];

  //   if (widget.role == UserRole.driver || widget.role == UserRole.driverOwner) {
  //     documents.addAll(_driverDocuments.values);
  //   }

  //   if (widget.role == UserRole.owner || widget.role == UserRole.driverOwner) {
  //     documents.addAll(_vehicleDocuments.values);
  //   }

  //   // Return true only if all relevant docs are marked as "Approved"
  //   return documents.isNotEmpty &&
  //       documents.every(
  //         (doc) => (doc['status'] ?? '').toString().toLowerCase() == 'approved',
  //       );
  // }

  bool _areAllDocsApproved(Map<DocumentType, Map<String, dynamic>> docs) {
    return docs.values.every(
      (doc) => doc['status']?.toLowerCase() == 'approved',
    );
  }

  Future<void> _checkAndRedirectIfAllApproved() async {
    final allDriverDocsApproved = _areAllDocsApproved(_driverDocuments);
    final allVehicleDocsApproved = _areAllDocsApproved(_vehicleDocuments);

    if (allDriverDocsApproved && allVehicleDocsApproved) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          context.goNamed(Routes().navigationScreen);
        }
      });
    }
  }

  final Map<DocumentType, String> _docLabels = {
    DocumentType.profilePic: 'Upload Profile Picture',
    DocumentType.idFront: 'Upload ID Front',
    DocumentType.idBack: 'Upload ID Back',
    DocumentType.drivingLicense: 'Upload Driving License',
    DocumentType.policeClearance: 'Upload Police Clearance',
    DocumentType.psvBadge: 'Upload PSV Badge',
    DocumentType.healthCertificate: 'Upload Health Cert',
    DocumentType.CertificateOfIncorporation: 'Upload Cert of incorporation',
    DocumentType.logbook: 'Upload logbook',
    DocumentType.vehiclePicture: 'Upload Vehicle Pic',
    DocumentType.insuranceCover: 'Upload Insurance',
    DocumentType.psvCertificate: 'Upload Psv Certificate',
  };
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverId = user.uid;
      email = user.email ?? '';
    }
    _fetchDriverDetails();
    _fetchDocumentStatus();
    _fetchVehicleDocumentStatus();
    //loadVehicle();
    // fetchDropdownData();
    fetchDropdownData().then((_) {
      loadVehicle(); // 🔁 load after makes are available
    });

    // Fetch document statuses when screen loads
  }

  bool _areAllRequiredDocumentsUploaded() {
    bool allDriverDocsUploaded = _driverDocuments.values.every(
      (doc) =>
          doc['file'] != null ||
          (doc['url'] != null && doc['url'].toString().isNotEmpty),
    );

    bool allVehicleDocsUploaded = _vehicleDocuments.values.every(
      (doc) =>
          doc['file'] != null ||
          (doc['url'] != null && doc['url'].toString().isNotEmpty),
    );

    return allDriverDocsUploaded && allVehicleDocsUploaded;
  }

  Future<Vehicle?> fetchVehicleDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (idToken == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/details'),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Vehicle.fromJson(data);
    } else {
      debugPrint("Failed to fetch vehicle: ${response.statusCode}");
      return null;
    }
  }

  Future<void> loadVehicle() async {
    final vehicle = await fetchVehicleDetails();

    if (vehicle != null) {
      // Load models for the selected make first
      await fetchVehicleModels(vehicle.make.toString());
      if (!mounted) return;

      setState(() {
        selectedMakeId = vehicle.make;
        selectedModelId = vehicle.model;
        // selectedCategoryId = vehicle.categoryId; // if needed
        vehicleId = vehicle.vehicleId;
        regController.text = vehicle.registrationNumber;
        yearController.text = vehicle.year.toString();
      });
    }
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> submitToBackend() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    var uri = Uri.parse('$baseUrl/auth/driver/onboarding'); // Your API endpoint
    var request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';

    // Add form fields
    request.fields['token'] = idToken ?? '';
    //request.fields['idType'] = _selectedIdType ?? '';
    request.fields['idNumber'] = _idNumberController.text;
    request.fields['paymentMobile'] = _paymentMobileController.text;
    request.fields['referralCode'] = _referralCodeController.text;
    request.fields['licenseExpiry'] = _licenseExpiryController.text;

    // Send request
    final response = await request.send();

    if (response.statusCode == 200) {
      print('Submission successful');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted successfully')));
      //widget.onCompleted();
    } else {
      print('Failed: ${response.statusCode}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submission failed')));
    }
  }

  Future<void> _fetchDriverDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (user == null || idToken == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/auth/driver/details'),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        _idNumberController.text = data['idNumber'] ?? '';
        _paymentMobileController.text = data['paymentMobile'] ?? '';
        _referralCodeController.text = data['referralCode'] ?? '';
        _licenseExpiryController.text = data['licenseExpiry'] ?? '';
        _vehicleCategory = parseVehicleCategory(data['category'] ?? -1);
        FetchedDriver = data['idNumber'] ?? '';
        _initializeDocuments();

        if (data['licenseExpiry'] != null && data['licenseExpiry'].isNotEmpty) {
          _licenseExpiryDate = DateTime.tryParse(data['licenseExpiry']);
        }

        _isReadOnly = true; // 🔐 Grey out all fields
      });
    } else {
      debugPrint(
        'Failed to fetch driver onboarding details: ${response.statusCode}',
      );
    }
  }

  Future<void> uploadDocumentToBackend(DocumentType type, File file) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (idToken == null || user == null) return;

    final uri = Uri.parse('$baseUrl/auth/documents/upload-file');
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
      if (!mounted) return;
      setState(() {
        _driverDocuments[type]!['file'] = null;
        _driverDocuments[type]!['url'] = null;
        _driverDocuments[type]!['status'] = null;
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
    //final user = FirebaseAuth.instance.currentUser;
    User? user;
    int retries = 0;

    // 🔁 Retry until user is available (max 5 attempts)
    while (user == null && retries < 5) {
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        retries++;
      }
    }

    if (user == null) {
      debugPrint("❌ Firebase user is still null after retries.");
      return;
    }

    final idToken = await user.getIdToken();

    final response = await http.get(
      Uri.parse("$baseUrl/auth/documents/status/${user?.uid}"),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        for (var docJson in data) {
          final doc = DocumentModel.fromJson(docJson);
          _driverDocuments[doc.documentType] = {
            'file': null, // or File(doc.filePath) if local
            'status': doc.status.label, // ✅ Use label here
            'url': doc.filePath,
          };

          // final doc = DocumentModel.fromJson(docJson);
          // if (_driverDocuments.containsKey(doc.documentType)) {
          //   _driverDocuments[doc.documentType] = {
          //     'file': null,
          //     'status': doc.status.label,
          //     'url': doc.filePath,
          //   };
          // }
        }
      });
      _checkAndRedirectIfAllApproved();
      // if (_areAllDocumentsApproved()) {
      //   Future.delayed(const Duration(milliseconds: 300), () {
      //     if (mounted) {
      //       context.goNamed(
      //         Routes().navigationScreen,
      //       ); // Or use Navigator.pushReplacement
      //     }
      //   });
      // }
    } else {
      debugPrint('Failed to fetch document statuses');
    }
  }

  /////vehicledeatils
  Future<void> fetchDropdownData() async {
    try {
      final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
      // final categoryRes = await http.get(
      //   Uri.parse("$baseUrl/vehicles/categories"),
      // );

      if (makeRes.statusCode == 200) {
        final decodedMake = json.decode(makeRes.body);
        //final decodedCategory = json.decode(categoryRes.body);
        if (!mounted) return;
        setState(() {
          vehicleMakes = List<Map<String, dynamic>>.from(decodedMake);
          //vehicleCategories = List<Map<String, dynamic>>.from(decodedCategory);
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
        if (!mounted) return;
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
      //"vehicleCategoryId": selectedCategoryId,
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
      //await Future.delayed(const Duration(milliseconds: 500));
      //GoRouter.of(context).goNamed(Routes().navigationScreen);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
    }

    //await Future.delayed(const Duration(milliseconds: 500));
    //GoRouter.of(context).goNamed(Routes().navigationScreen);
  }

  Future<void> uploadVehicleDocumentToBackend(
    DocumentType type,
    File file,
    int vehicleId, // ⬅ Add this parameter
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (idToken == null || user == null) return;

    final uri = Uri.parse('$baseUrl/vehicles/documents/upload-file');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';

    request.fields['documentType'] = type.name;
    request.fields['vehicleId'] = vehicleId.toString(); // ✅ This is critical

    final fileName = path.basename(file.path);
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: fileName),
    );

    final response = await request.send();
    final respStr =
        await response.stream.bytesToString(); // 📦 Check server message
    if (!mounted) return;
    if (response.statusCode == 200) {
      await _fetchVehicleDocumentStatus();
      print('✅ Document uploaded successfully: $respStr');
    } else {
      print('❌ Upload failed (${response.statusCode}): $respStr');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $respStr")));
    }
  }

  Future<void> deleteVehicleDocumentFromBackend(DocumentType type) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null) return;

    final uri = Uri.parse(
      '$baseUrl/vehicles/documents/delete?type=${type.name}',
    );
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      if (!mounted) return;
      setState(() {
        _vehicleDocuments[type]!['file'] = null;
        _vehicleDocuments[type]!['url'] = null;
        _vehicleDocuments[type]!['status'] = null;
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

  Future<void> _fetchVehicleDocumentStatus() async {
    User? user;
    int retries = 0;

    // 🔁 Retry until user is available (max 5 attempts)
    while (user == null && retries < 5) {
      user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        retries++;
      }
    }

    if (user == null) {
      debugPrint("❌ Firebase user is still null after retries.");
      return;
    }

    final idToken = await user.getIdToken();

    final response = await http.get(
      Uri.parse("$baseUrl/vehicles/documents/status/${user?.uid}"),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        for (var docJson in data) {
          final doc = DocumentModel.fromJson(docJson);
          _vehicleDocuments[doc.documentType] = {
            'file': null, // or File(doc.filePath) if local
            'status': doc.status.label, // ✅ Use label here
            'url': doc.filePath,
          };
        }
      });
      _checkAndRedirectIfAllApproved();
      // if (_areAllDocumentsApproved()) {
      //   Future.delayed(const Duration(milliseconds: 300), () {
      //     if (mounted) {
      //       context.goNamed(Routes().navigationScreen);
      //     }
      //   });
      // }
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
                    final file = File(picked.path);
                    _handlePickedFile(type, file);
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
                    final file = File(picked.path);
                    _handlePickedFile(type, file);
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
                    final file = File(result.files.single.path!);
                    _handlePickedFile(type, file);
                  }
                },
              ),
            ],
          ),
    );
  }

  Future<void> _handlePickedFile(DocumentType type, File file) async {
    // Check if it's a driver document
    if (_driverDocuments.containsKey(type)) {
      if (FetchedDriver == null) {
        debugPrint(
          "Driver ID not found. Make sure Driver is registered before uploading documents.",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please submit details first.")),
        );
        return;
      }

      setState(() {
        _driverDocuments[type]!['file'] = file;
      });
      await uploadDocumentToBackend(type, file);
    } else if (_vehicleDocuments.containsKey(type)) {
      if (vehicleId == null) {
        debugPrint(
          "Vehicle ID not found. Make sure vehicle is registered before uploading documents.",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please submit details first.")),
        );
        return;
      }

      setState(() {
        _vehicleDocuments[type]!['file'] = file;
      });
      await uploadVehicleDocumentToBackend(
        type,
        file,
        vehicleId!,
      ); // ✅ pass vehicleId
    } else {
      debugPrint("Unknown document type: $type");
    }
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

  @override
  void dispose() {
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
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        // title: const Text("Driver Onboarding"),
        // // backgroundColor: Colors.blue,
        // iconTheme: IconThemeData(color: Colors.grey[700]),
        // titleTextStyle: TextStyle(color: Colors.grey[700], fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// -----------------------------
                /// 🚘 DRIVER DETAILS SECTION
                /// -----------------------------
                if (showDriverSection) ...[
                  Text(
                    "Driver Details",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _idNumberController,
                    decoration: borderedDecoration("ID Number"),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _paymentMobileController,
                    decoration: borderedDecoration("Payment Mobile"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _referralCodeController,
                    decoration: borderedDecoration("Referral Code"),
                  ),
                  const SizedBox(height: 12),

                  // TextFormField(
                  //   controller: _licenseExpiryController,
                  //   decoration: borderedDecoration("License Expiry"),
                  //   onTap: _selectLicenseExpiryDate(context),
                  //   readOnly: true,
                  // ),
                  TextFormField(
                    controller: _licenseExpiryController,
                    decoration: borderedDecoration("License Expiry"),
                    readOnly: true,
                    onTap: () => _selectLicenseExpiryDate(context),
                  ),

                  const SizedBox(height: 24),
                ],

                /// -----------------------------
                /// 🚗 VEHICLE DETAILS SECTION
                /// -----------------------------
                ///
                if (showVehicleSection) ...[
                  Text(
                    "Vehicle Details",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    decoration: borderedDecoration('Vehicle Make'),
                    value: selectedMakeId,
                    items:
                        vehicleMakes.map((make) {
                          return DropdownMenuItem<int>(
                            value: make['id'],
                            child: Text(make['name']),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMakeId = value;
                        selectedModelId = null;
                      });
                      final selectedMake = vehicleMakes.firstWhere(
                        (m) => m['id'] == value,
                      );
                      fetchVehicleModels(selectedMake['name']);
                    },
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    decoration: borderedDecoration('Vehicle Model'),
                    value: selectedModelId,
                    items:
                        vehicleModels.map((model) {
                          return DropdownMenuItem<int>(
                            value: model['id'],
                            child: Text(model['name']),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedModelId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // DropdownButtonFormField<int>(
                  //   decoration: borderedDecoration('Vehicle Category'),
                  //   value: selectedCategoryId,
                  //   items:
                  //       vehicleCategories.map((cat) {
                  //         return DropdownMenuItem<int>(
                  //           value: cat['id'],
                  //           child: Text(cat['name']),
                  //         );
                  //       }).toList(),
                  //   onChanged: (value) {
                  //     setState(() {
                  //       selectedCategoryId = value;
                  //     });
                  //   },
                  // ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: regController,
                    decoration: borderedDecoration("Vehicle Registration"),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: yearController,
                    decoration: borderedDecoration("Year of Manufacture"),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 24),
                ],
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // onPressed: () async {
                  //   if (_formKey.currentState!.validate()) {
                  //     await submitToBackend();
                  //     await submitVehicle();
                  //     // if (context.mounted) {
                  //     //   GoRouter.of(context).goNamed(Routes().navigationScreen);
                  //     // }
                  //   }
                  // },
                  onPressed: ()
                  // _areAllRequiredDocumentsUploaded()
                  //? ()
                  async {
                    if (_formKey.currentState!.validate()) {
                      await submitToBackend();
                      await submitVehicle();
                      // context.goNamed(Routes().navigationScreen); // if needed
                    }
                  },
                  // : null, // disables the button
                  child: const Center(
                    child: Text(
                      "Submit your details",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                /// -----------------------------
                /// 📄 DOCUMENTS SECTION
                /// -----------------------------
                // Text(
                //   "Upload Required Documents",
                //   style: Theme.of(context).textTheme.headlineSmall,
                // ),
                // const SizedBox(height: 12),

                // ...[
                //   ..._driverDocuments.entries.map((entry) {
                //     final type = entry.key;
                //     final doc = entry.value;
                //     final label = _docLabels[type] ?? type.name;
                //     final file = doc['file'] as File?;
                //     final url = doc['url'];

                //     final String? fullUrl =
                //         url != null && !url.startsWith('http')
                //             ? '$baseUrldoc${url!.startsWith('/') ? url : '/$url'}'
                //             : url;

                //     return Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         BorderedUploadButton(
                //           label: label,
                //           isUploaded: file != null || fullUrl != null,
                //           status: doc['status'],
                //           onPressed: () => _pickFile(type),
                //           onPreview: () {
                //             if (file != null) {
                //               Navigator.push(
                //                 context,
                //                 MaterialPageRoute(
                //                   builder: (_) => PreviewScreen(file: file),
                //                 ),
                //               );
                //             } else if (fullUrl != null) {
                //               Navigator.push(
                //                 context,
                //                 MaterialPageRoute(
                //                   builder: (_) => PreviewScreen(url: fullUrl),
                //                 ),
                //               );
                //             }
                //           },
                //           onRemove: () async {
                //             await deleteDocumentFromBackend(type);
                //             setState(() {
                //               _driverDocuments[type]!['file'] = null;
                //               _driverDocuments[type]!['url'] = null;
                //               _driverDocuments[type]!['status'] = null;
                //             });
                //           },
                //         ),
                //       ],
                //     );
                //   }),

                //   ..._vehicleDocuments.entries.map((entry) {
                //     final type = entry.key;
                //     final doc = entry.value;
                //     final label = _docLabels[type] ?? type.name;
                //     final file = doc['file'] as File?;
                //     final url = doc['url'];

                //     final String? fullUrl =
                //         url != null && !url.startsWith('http')
                //             ? '$baseUrldoc${url!.startsWith('/') ? url : '/$url'}'
                //             : url;

                //     return Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         BorderedUploadButton(
                //           label: label,
                //           isUploaded: file != null || fullUrl != null,
                //           status: doc['status'],
                //           onPressed: () => _pickFile(type),
                //           onPreview: () {
                //             if (file != null) {
                //               Navigator.push(
                //                 context,
                //                 MaterialPageRoute(
                //                   builder: (_) => PreviewScreen(file: file),
                //                 ),
                //               );
                //             } else if (fullUrl != null) {
                //               Navigator.push(
                //                 context,
                //                 MaterialPageRoute(
                //                   builder: (_) => PreviewScreen(url: fullUrl),
                //                 ),
                //               );
                //             }
                //           },
                //           onRemove: () async {
                //             await deleteVehicleDocumentFromBackend(type);
                //             setState(() {
                //               _vehicleDocuments[type]!['file'] = null;
                //               _vehicleDocuments[type]!['url'] = null;
                //               _vehicleDocuments[type]!['status'] = null;
                //             });
                //           },
                //         ),
                //       ],
                //     );
                //   }),
                // ],

                /// -----------------------------
                /// 📄 DOCUMENTS SECTION
                /// -----------------------------
                Text(
                  "Upload Required Documents",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),

                if (showDriverSection) ...[
                  const Text(
                    "Driver Documents",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._driverDocuments.entries.map((entry) {
                    final type = entry.key;
                    final doc = entry.value;
                    final label = _docLabels[type] ?? type.name;
                    final file = doc['file'] as File?;
                    final url = doc['url'];

                    final String? fullUrl =
                        url != null && !url.startsWith('http')
                            ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
                            : url;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BorderedUploadButton(
                          label: label,
                          isUploaded: file != null || fullUrl != null,
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
                            } else if (fullUrl != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PreviewScreen(url: fullUrl),
                                ),
                              );
                            }
                          },
                          onRemove: () async {
                            await deleteDocumentFromBackend(type);
                            setState(() {
                              _driverDocuments[type]!['file'] = null;
                              _driverDocuments[type]!['url'] = null;
                              _driverDocuments[type]!['status'] = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  }),
                ],

                if (showVehicleSection) ...[
                  const Text(
                    "Vehicle Documents",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._vehicleDocuments.entries.map((entry) {
                    final type = entry.key;
                    final doc = entry.value;
                    final label = _docLabels[type] ?? type.name;
                    final file = doc['file'] as File?;
                    final url = doc['url'];

                    final String? fullUrl =
                        url != null && !url.startsWith('http')
                            ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
                            : url;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BorderedUploadButton(
                          label: label,
                          isUploaded: file != null || fullUrl != null,
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
                            } else if (fullUrl != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PreviewScreen(url: fullUrl),
                                ),
                              );
                            }
                          },
                          onRemove: () async {
                            await deleteVehicleDocumentFromBackend(type);
                            setState(() {
                              _vehicleDocuments[type]!['file'] = null;
                              _vehicleDocuments[type]!['url'] = null;
                              _vehicleDocuments[type]!['status'] = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  }),
                ],
              ],
            ),
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

class BorderedUploadButton extends StatelessWidget {
  final String label;
  final bool isUploaded;
  final String? status;
  final VoidCallback onPressed;
  final VoidCallback? onPreview;
  final Future<void> Function()? onRemove;

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
      //onLongPress: isUploaded ? onRemove : null, // Long press to remove
      onLongPress:
          isUploaded
              ? () async {
                final confirmed = await showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text("Delete Document?"),
                        content: const Text(
                          "Are you sure you want to delete this document?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                );

                // if (confirmed == true && onRemove != null) {
                //   await onRemove();
                // }

                if (confirmed == true) {
                  await onRemove?.call(); // ✅ Safe null-aware function call
                }
              }
              : null,
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

  Widget _buildStatusChip(String status) {
    final normalized = status.toLowerCase().replaceAll(' ', '');

    late final String label;
    late final Color color;

    switch (normalized) {
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
}

// String _docLabel(DocumentType type) {
//   switch (type) {
//     case DocumentType.profilePic:
//       return 'Upload Profile Picture';
//     case DocumentType.idFront:
//       return 'Upload ID Front';
//     case DocumentType.idBack:
//       return 'Upload ID Back';
//     case DocumentType.drivingLicense:
//       return 'Upload Driving License';
//     case DocumentType.policeClearance:
//       return 'Upload Police Clearance';
//     case DocumentType.psvBadge:
//       return 'Upload PSV Badge';
//     default:
//       return type.name; // for vehicle docs or fallback
//   }
// }

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
  // Future<void> uploadDocumentToBackend(DocumentType type, File file) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   final idToken = await user?.getIdToken();

  //   // Upload to Firebase Storage
  //   final extension = path.extension(file.path); // e.g., .jpg, .pdf, .docx

  //   final storageRef = FirebaseStorage.instance.ref().child(
  //     'documents/${user!.uid}/${type.name}_${DateTime.now().millisecondsSinceEpoch}$extension',
  //   );

  //   final uploadTask = storageRef.putFile(file); // do not await here
  //   final snapshot = await uploadTask.whenComplete(
  //     () => null,
  //   ); // wait for upload to finish
  //   final downloadUrl = await snapshot.ref.getDownloadURL(); // THEN get the URL
  //   // final uploadTask = await storageRef.putFile(file);
  //   // final downloadUrl = await storageRef.getDownloadURL();

  //   // Send metadata to backend
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/documents/upload'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({
  //       'token': idToken,
  //       'documentType': type.name, // Make sure enum matches backend type
  //       'filePath': downloadUrl,
  //     }),
  //   );

  //   if (response.statusCode == 200) {
  //     print('Document metadata saved!');
  //   } else {
  //     print('Failed: ${response.statusCode}');
  //   }
  // }

  // Future<void> uploadDocumentToBackend(DocumentType type, File file) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   final idToken = await user?.getIdToken();

  //   if (user == null) {
  //     print("❌ User is null");
  //     return;
  //   }

  //   if (!file.existsSync()) {
  //     print("❌ File does not exist at ${file.path}");
  //     return;
  //   }

  //   try {
  //     final extension = path.extension(file.path); // .jpg, .pdf, etc.
  //     final fileName =
  //         '${type.name}_${DateTime.now().millisecondsSinceEpoch}$extension';

  //     final storageRef = FirebaseStorage.instance.ref().child(
  //       'documents/${user.uid}/$fileName',
  //     );

  //     print("📤 Uploading to Firebase Storage: ${storageRef.fullPath}");

  //     // Upload
  //     final uploadTask = storageRef.putFile(file);

  //     final snapshot = await uploadTask.whenComplete(() => null);

  //     // Check if upload failed
  //     if (snapshot.state != TaskState.success) {
  //       print("❌ Upload failed. State: ${snapshot.state}");
  //       return;
  //     }

  //     final downloadUrl = await snapshot.ref.getDownloadURL();

  //     // Send metadata to backend
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/documents/upload'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'token': idToken,
  //         'documentType': type.name,
  //         'filePath': downloadUrl,
  //       }),
  //     );

  //     if (response.statusCode == 200) {
  //       print("✅ Document metadata saved to backend!");
  //     } else {
  //       print("❌ Failed to save metadata: ${response.statusCode}");
  //     }
  //   } on FirebaseException catch (e) {
  //     print("🔥 FirebaseException: ${e.code} - ${e.message}");
  //   } catch (e) {
  //     print("🔥 Unexpected error: $e");
  //   }
  // }