import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/document_module.dart';
import 'package:aminidriver/Onboarding/document_preview.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/Onboarding/vehicle.dart';
import 'package:aminidriver/Onboarding/vehicle_category.dart';
import 'package:aminidriver/Onboarding/approval_service.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isVehicleReadOnly = false;
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
  bool _isSubmitted = false;
  bool _isSubmittedVehicle = false;

  //final _licenseExpiryController = TextEditingController();

  String? _selectedIdType;
  String? _staus;
  final List<String> _idTypes = ['National ID', 'Passport'];

  List<dynamic> personalDocs = [];
  List<dynamic> vehicleDocs = [];
  bool isLoading = true;
  // final Map<DocumentType, Map<String, dynamic>> _driverDocuments = {};
  // final Map<DocumentType, Map<String, dynamic>> _vehicleDocuments = {};
  Map<int, Map<String, dynamic>> _driverDocuments = {};
  Map<int, Map<String, dynamic>> _vehicleDocuments = {};
  final ApprovalService _approvalService = ApprovalService();

  Future<Map<String, dynamic>> createDocuments({
    required int vehicleCategoryId,
    required String firebaseID,
    required int vehicleId,
  }) async {
    final url = Uri.parse(
      "$baseUrl/create-documents/$vehicleCategoryId?firebaseID=$firebaseID&vehicleId=$vehicleId",
    );

    final response = await http.post(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to create documents: ${response.body}");
    }
  }

  bool _areAllDocsApproved(Map<DocumentType, Map<String, dynamic>> docs) {
    return docs.values.every(
      (doc) => doc['status']?.toLowerCase() == 'approved',
      // (doc['status'] as DocumentStatus).name.toLowerCase() == 'approved',
    );
  }

  bool _areAnyDocumentsApproved(Map<DocumentType, Map<String, dynamic>> docs) {
    return docs.values.any(
      (doc) => (doc['status'] ?? '').toString().toLowerCase() == 'approved',
    );
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverId = user.uid;
      email = user.email ?? '';
    }

    //fetchDriverCategory(driverId);
    // fetchDocumentsForCategory();
    _fetchDriverDetails();
    fetchDriverDocuments();
    //_fetchDocumentStatus();
    //_fetchVehicleDocumentStatus();
    //loadVehicle();
    // fetchDropdownData();
    fetchDropdownData().then((_) {
      loadVehicle(); // 🔁 load after makes are available
    });

    checkAndNavigate(driverId, context);
    // _fetchDocumentStatus();
    // _fetchVehicleDocumentStatus();

    // Fetch document statuses when screen loads
  }

  Future<bool> _onWillPop() async {
    if (Platform.isAndroid) {
      SystemNavigator.pop(); // Closes the app safely
    } else {
      exit(0); // Works on other platforms
    }
    return false; // Prevents default navigation
  }

  Timer? _approvalTimer;

  void checkAndNavigate(String firebaseId, BuildContext context) {
    // Run every 5 seconds
    _approvalTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final status = await _approvalService.checkApprovalStatus(firebaseId);

        if (status == "yes") {
          timer.cancel(); // ✅ Stop the timer
          if (!context.mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NavigationScreen()),
          );
        } else {
          debugPrint("User not approved yet...");
        }
      } catch (e) {
        debugPrint("Error checking approval: $e");
      }
    });
  }

  Future<void> fetchDriverDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final url = Uri.parse(
        "$baseUrl/vehicles/fetchdriverdocuments/${user.uid}",
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final personalDocs = data['personalDocuments'] as List<dynamic>;
        final vehicleDocs = data['vehicleDocuments'] as List<dynamic>;

        setState(() {
          _driverDocuments = {
            for (var doc in personalDocs)
              doc['documentType']: {
                'documentName': doc['documentName'],
                'status': doc['status'].toString(),
                'file': null, // will hold File only if user uploads
                'url': doc['filePath'], // backend file path/URL
              },
          };

          _vehicleDocuments = {
            for (var doc in vehicleDocs)
              doc['documentType']: {
                'documentName': doc['documentName'],
                'status': doc['status'].toString(),
                'file': null, // will hold File only if user uploads
                'url': doc['filePath'], // backend file path/URL
                //'vehicleId': doc['vehicleId'],
              },
          };
        });
      } else {
        throw Exception("Failed to load documents");
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching driver documents: $e");
    }
  }

  Future<Vehicle?> fetchVehicleDetails() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("No logged-in user.");
      _isSubmittedVehicle = false;
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/newdetails/${user.uid}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data == null || data.isEmpty || data['vehicleId'] == null) {
          debugPrint("No vehicle found for this user.");
          _isSubmittedVehicle = false; // no vehicle submitted
          vehicleId = null;
          return null;
        }
        vehicleId = data['vehicleId'];
        _isSubmittedVehicle =
            data['submitted'] ?? false; // ensure false if missing

        _isVehicleReadOnly = _isSubmittedVehicle;
        return Vehicle.fromJson(data);

        // final data = jsonDecode(response.body);
        // vehicleId = data['vehicleId'];
        // _isSubmitted = data['submitted'];
        // return Vehicle.fromJson(data);
      } else {
        debugPrint(
          "Failed to fetch vehicle (${response.statusCode}): ${response.body}",
        );
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching vehicle: $e");
      _isSubmittedVehicle = false;
      return null;
    }
  }

  Future<void> loadVehicle() async {
    final vehicle = await fetchVehicleDetails();
    //vehicleId = vehicle!.vehicleId;

    if (vehicle != null) {
      // Fetch models for the selected make before updating state
      await fetchVehicleModels(vehicle.make.toString());

      if (!mounted) return;

      setState(() {
        selectedMakeId = vehicle.make;
        selectedModelId = vehicle.model;
        vehicleId = vehicle.vehicleId;
        regController.text = vehicle.registrationNumber;
        yearController.text = vehicle.year.toString();
      });
    } else {
      debugPrint("No vehicle found for this user.");
    }
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> submitToBackend() async {
    if (_idNumberController.text.trim().isEmpty ||
        _paymentMobileController.text.trim().isEmpty ||
        _licenseExpiryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all required fields: ID Number, Payment Mobile, and License Expiry.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return; // ⛔ Stop execution if mandatory fields are missing
    }

    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    var uri = Uri.parse('$baseUrl/auth/driver/onboarding'); // Your API endpoint
    var request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';

    // Add form fields
    request.fields['token'] = idToken ?? '';
    request.fields['idNumber'] = _idNumberController.text;
    request.fields['paymentMobile'] = _paymentMobileController.text;
    //request.fields['referralCode'] = _referralCodeController.text;
    request.fields['licenseExpiry'] = _licenseExpiryController.text;

    if (_referralCodeController.text.trim().isNotEmpty) {
      request.fields['referralCode'] = _referralCodeController.text.trim();
    }

    // Send onboarding request
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final responseData = jsonDecode(responseBody);
      _isSubmitted = responseData['submitted'];

      // ✅ Extract vehicleCategory info from backend response
      final categoryType = responseData['vehicleCategory'];
      //final categoryId = responseData['vehicleCategoryId'];
      if (categoryType != null) {
        // 🔹 Now call API to create personal documents
        final createDocsUri = Uri.parse(
          "$baseUrl/vehicles/create-personal-documents/$categoryType?firebaseID=${user?.uid}",
        );
        final docsResponse = await http.post(createDocsUri);
        // final docsResponse = await http.post(
        //   createDocsUri,
        //   // headers: {
        //   //   // "Authorization": "Bearer $idToken",
        //   //   "Content-Type": "application/json",
        //   // },
        // );

        if (docsResponse.statusCode == 200) {
          fetchDriverDocuments();
          // setState(() {
          //   _isSubmitted = true;
          // });

          print("✅ Personal documents created: ${docsResponse.body}");
        } else {
          print("⚠️ Failed to create personal docs: ${docsResponse.body}");
        }
      }

      print('Submission successful');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted successfully')));
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
        _isSubmitted = data['submitted'];
        //_initializeDocuments();

        if (data['licenseExpiry'] != null && data['licenseExpiry'].isNotEmpty) {
          _licenseExpiryDate = DateTime.tryParse(data['licenseExpiry']);
        }
        _isReadOnly = _isSubmitted;
        // _isReadOnly = true;

        fetchDriverDocuments();
        // 🔐 Grey out all fields
        // 🔐 Grey out all fields
      });
    } else {
      debugPrint(
        'Failed to fetch driver onboarding details: ${response.statusCode}',
      );
    }
  }

  Future<void> uploadDocumentToBackend(int type, File file) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (idToken == null || user == null) return;

    final uri = Uri.parse('$baseUrl/auth/documents/upload-file');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';

    request.fields['documentType'] = type.toString();

    final fileName = file.path.split('/').last;

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: fileName),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      await fetchDriverDocuments();
      print('Document uploaded directly to backend!');
    } else {
      print('Backend upload failed: ${response.statusCode}');
    }
  }

  Future<void> deleteDocumentFromBackend(int type) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null) return;

    final uri = Uri.parse(
      '$baseUrl/auth/documents/delete?type=${type.toString()}',
    );
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      if (!mounted) return;
      //fetchDriverDocuments();
      setState(() {
        _driverDocuments[type]!['file'] = null;
        _driverDocuments[type]!['url'] = null;
        _driverDocuments[type]!['status'] = null;
        fetchDriverDocuments();
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

  // Future<void> submitVehicle() async {
  //   if (selectedMakeId == null ||
  //       selectedModelId == null ||
  //       regController.text.trim().isEmpty ||
  //       yearController.text.trim().isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text(
  //           "Please fill all required fields: Make, Model, Year, and Registration Number.",
  //         ),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     setState(() {
  //       _isSubmittedVehicle = false; // ❌ reset submission state
  //     });
  //     return; // ⛔ Stop execution if mandatory fields are missing
  //   }
  //   final uri = Uri.parse("$baseUrl/vehicles/UploadVehicle");

  //   final Map<String, dynamic> body = {
  //     "vehicleOwnerId": driverId,
  //     "firebaseUid": driverId,
  //     "vehicleMake": selectedMakeId,
  //     "vehicleModel": selectedModelId,
  //     "registrationNumber": regController.text,
  //     "year": int.tryParse(yearController.text) ?? 0,
  //     //"submitted":true
  //   };

  //   final response = await http.post(
  //     uri,
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode(body),
  //   );

  //   if (!context.mounted) return;

  //   if (response.statusCode == 200 || response.statusCode == 409) {
  //     final responseData = jsonDecode(response.body);
  //     // setState(() {
  //     //   _isSubmittedVehicle = responseData['submitted'];
  //     //   vehicleId = responseData["vehicleId"]; // ✅ now stored correctly
  //     // });

  //     // 🔹 Get the new vehicleId from backend response
  //     //final vehicleId = responseData["vehicleId"];
  //     //final categoryType = responseData["vehicleCategory"];
  //     // setState(() {
  //     //   vehicleId =
  //     //       responseData["vehicleId"]; // 👈 assign to class-level variable
  //     // });

  //     final int? newVehicleId = responseData["vehicleId"];
  //     final bool submittedFlag = responseData["submitted"] ?? false;

  //     setState(() {
  //       vehicleId = newVehicleId;
  //       _isSubmittedVehicle = submittedFlag;
  //     });

  //     if (vehicleId == null || !_isSubmittedVehicle) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Vehicle registration incomplete. Try again."),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //       return;
  //     }

  //     final categoryType = responseData["vehicleCategory"];
  //     // (Assuming backend returns categoryType along with vehicleId)

  //     // ✅ Call CreateVehicleDocuments API
  //     final docsUri = Uri.parse(
  //       "$baseUrl/vehicles/create-vehicle-documents/$categoryType?vehicleId=$vehicleId",
  //     );

  //     final docsResponse = await http.post(docsUri);

  //     if (docsResponse.statusCode == 200) {
  //       // _fetchVehicleDocumentStatus();
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text("Vehicle registered & docs initialized!"),
  //         ),
  //       );
  //       fetchDriverDocuments();
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             "Vehicle registered but docs failed: ${docsResponse.body}",
  //           ),
  //         ),
  //       );
  //     }

  //     // You can now navigate if needed
  //     // GoRouter.of(context).goNamed(Routes().navigationScreen);
  //   } else {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
  //   }
  // }

  Future<void> submitVehicle() async {
    // ✅ Validate mandatory fields first
    if (selectedMakeId == null ||
        selectedModelId == null ||
        regController.text.trim().isEmpty ||
        yearController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill all required fields: Make, Model, Year, and Registration Number.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSubmittedVehicle = false; // ❌ reset submission state
      });
      return; // ⛔ Stop execution if mandatory fields are missing
    }

    try {
      final uri = Uri.parse("$baseUrl/vehicles/UploadVehicle");

      final Map<String, dynamic> body = {
        "vehicleOwnerId": driverId,
        "firebaseUid": driverId,
        "vehicleMake": selectedMakeId,
        "vehicleModel": selectedModelId,
        "registrationNumber": regController.text.trim(),
        "year": int.tryParse(yearController.text.trim()) ?? 0,
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (!context.mounted) return;

      // ✅ Handle success and conflict responses
      if (response.statusCode == 200 || response.statusCode == 409) {
        final responseData = jsonDecode(response.body);

        // ⚠ Ensure vehicleId and submitted flag exist
        final int? newVehicleId = responseData["vehicleId"];
        final bool submittedFlag = responseData["submitted"] ?? false;

        setState(() {
          vehicleId = newVehicleId;
          _isSubmittedVehicle = submittedFlag;
        });

        if (vehicleId == null || !_isSubmittedVehicle) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Vehicle registration incomplete. Try again."),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        final categoryType = responseData["vehicleCategory"];
        if (categoryType != null) {
          final docsUri = Uri.parse(
            "$baseUrl/vehicles/create-vehicle-documents/$categoryType?vehicleId=$vehicleId",
          );

          final docsResponse = await http.post(docsUri);

          if (docsResponse.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Vehicle registered & docs initialized!"),
                backgroundColor: Colors.green,
              ),
            );
            fetchDriverDocuments(); // Refresh documents
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Vehicle registered but docs failed: ${docsResponse.body}",
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Vehicle registered but category missing."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() => _isSubmittedVehicle = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to register vehicle: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmittedVehicle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error submitting vehicle: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> uploadVehicleDocumentToBackend(
    int type,
    File file,
    int vehicleId, // ⬅ Add this parameter
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (idToken == null || user == null) return;

    final uri = Uri.parse('$baseUrl/vehicles/documents/upload-file');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $idToken';

    request.fields['documentType'] = type.toString();
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
      await fetchDriverDocuments(); //_fetchVehicleDocumentStatus();
      print('✅ Document uploaded successfully: $respStr');
    } else {
      print('❌ Upload failed (${response.statusCode}): $respStr');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $respStr")));
    }
  }

  Future<void> deleteVehicleDocumentFromBackend(int type) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null) return;
    //$baseUrl/vehicles/documents/delete/$vehicleId?type=$type
    //final uri = Uri.parse('$baseUrl/vehicles/documents/delete?type=${type}');
    final uri = Uri.parse(
      '$baseUrl/vehicles/documents/delete/$vehicleId?type=$type',
    );

    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      if (!mounted) return;
      setState(() {
        _vehicleDocuments[type]!['file'] = null;
        _vehicleDocuments[type]!['url'] = null;
        _vehicleDocuments[type]!['status'] = null;
        fetchDriverDocuments();
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

  bool _isUploading = false; // Global flag

  // Future<void> _pickFile(int type) async {
  //   // ✅ Prevent picking another file while upload is ongoing
  //   if (_isUploading) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Please wait for the current upload to finish."),
  //       ),
  //     );
  //     return;
  //   }

  //   showModalBottomSheet(
  //     context: context,
  //     builder:
  //         (_) => Wrap(
  //           children: [
  //             ListTile(
  //               leading: const Icon(Icons.camera_alt),
  //               title: const Text("Take a Photo"),
  //               onTap: () async {
  //                 Navigator.pop(context);
  //                 final picked = await _picker.pickImage(
  //                   source: ImageSource.camera,
  //                 );
  //                 if (picked != null) {
  //                   final file = File(picked.path);
  //                   _handlePickedFile(type, file);
  //                 }
  //               },
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.photo),
  //               title: const Text("Pick from Gallery"),
  //               onTap: () async {
  //                 Navigator.pop(context);
  //                 final picked = await _picker.pickImage(
  //                   source: ImageSource.gallery,
  //                 );
  //                 if (picked != null) {
  //                   final file = File(picked.path);
  //                   _handlePickedFile(type, file);
  //                 }
  //               },
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.attach_file),
  //               title: const Text("Upload Document"),
  //               onTap: () async {
  //                 Navigator.pop(context);
  //                 final result = await FilePicker.platform.pickFiles();
  //                 if (result != null && result.files.single.path != null) {
  //                   final file = File(result.files.single.path!);
  //                   _handlePickedFile(type, file);
  //                 }
  //               },
  //             ),
  //           ],
  //         ),
  //   );
  // }
  Future<void> _pickFile(int type) async {
    // ✅ Prevent picking another file while upload is ongoing
    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please wait for the current upload to finish."),
        ),
      );
      return;
    }

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

  Future<void> _handlePickedFile(int type, File file) async {
    if (_isUploading) {
      // Just in case user triggers it another way
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please wait for the current upload to finish."),
        ),
      );
      return;
    }

    setState(() => _isUploading = true); // 🚀 Start uploading

    try {
      if (_driverDocuments.containsKey(type)) {
        setState(() {
          _driverDocuments[type]!['file'] = file;
        });
        await uploadDocumentToBackend(type, file);
      } else if (_vehicleDocuments.containsKey(type)) {
        setState(() {
          _vehicleDocuments[type]!['file'] = file;
        });
        await uploadVehicleDocumentToBackend(type, file, vehicleId!);
      } else {
        debugPrint("Unknown document type: $type");
      }
    } catch (e) {
      debugPrint("⚠️ Error uploading document: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error uploading document.")),
      );
    } finally {
      setState(() => _isUploading = false); // ✅ Always reset flag
    }
  }

  // Future<void> _handlePickedFile(int type, File file) async {
  //   if (_isUploading) {
  //     // Just in case user triggers it another way
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Please wait for the current upload to finish."),
  //       ),
  //     );
  //     return;
  //   }

  //   setState(() => _isUploading = true); // 🚀 Start uploading

  //   try {
  //     if (_driverDocuments.containsKey(type)) {
  //       setState(() {
  //         _driverDocuments[type]!['file'] = file;
  //       });
  //       await uploadDocumentToBackend(type, file);
  //     } else if (_vehicleDocuments.containsKey(type)) {
  //       setState(() {
  //         _vehicleDocuments[type]!['file'] = file;
  //       });
  //       await uploadVehicleDocumentToBackend(type, file, vehicleId!);
  //     } else {
  //       debugPrint("Unknown document type: $type");
  //     }
  //   } catch (e) {
  //     debugPrint("⚠️ Error uploading document: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Error uploading document.")),
  //     );
  //   } finally {
  //     setState(() => _isUploading = false); // ✅ Always reset flag
  //   }
  // }

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
    _approvalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 👇 Close the app when the phone's back button is pressed
        if (Platform.isAndroid) {
          SystemNavigator.pop(); // safer for Android
        } else {
          exit(0); // fallback for iOS and others
        }
        return false; // prevent normal navigation
      },
      child: Scaffold(
        // appBar: AppBar(
        //   title: const Text(
        //     "Driver Onboarding",
        //     style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        //   ),
        //   centerTitle: true,
        //   backgroundColor: Colors.white,
        //   elevation: 1,
        //   foregroundColor: Colors.black87,
        // ),
        appBar: AppBar(
          title: const Text(
            "Driver Onboarding",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
        //body: Container(
        // color: Colors.grey[100],
        body: Container(
          color: Colors.white,

          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🚘 DRIVER DETAILS SECTION
                    if (showDriverSection) ...[
                      const Text(
                        "Driver Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),

                      BorderedTextFormField(
                        label: "ID Number",
                        controller: _idNumberController,
                        readOnly: _isReadOnly,
                      ),
                      BorderedTextFormField(
                        label: "Payment Mobile",
                        controller: _paymentMobileController,
                        readOnly: _isReadOnly,
                      ),
                      BorderedTextFormField(
                        label: "Referral Code",
                        controller: _referralCodeController,
                        readOnly: _isReadOnly,
                      ),
                      BorderedTextFormField(
                        label: "License Expiry",
                        controller: _licenseExpiryController,
                        readOnly: _isReadOnly,
                        onTap: () async {
                          FocusScope.of(context).requestFocus(FocusNode());
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            _licenseExpiryController.text =
                                pickedDate.toIso8601String().split("T").first;
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "License expiry is required";
                          }
                          try {
                            final parsedDate = DateTime.parse(value);
                            if (parsedDate.isBefore(DateTime.now())) {
                              return "License expiry must be a future date";
                            }
                          } catch (_) {
                            return "Enter a valid date (yyyy-MM-dd)";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    /// 🚗 VEHICLE DETAILS SECTION
                    if (showVehicleSection) ...[
                      const Text(
                        "Vehicle Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      IgnorePointer(
                        ignoring: _isVehicleReadOnly,
                        child: DropdownButtonFormField<int>(
                          //decoration: borderedDecoration('Vehicle Make'),
                          decoration: InputDecoration(
                            labelText: 'Vehicle Make',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),

                          value: selectedMakeId,
                          items:
                              vehicleMakes.map((make) {
                                return DropdownMenuItem<int>(
                                  value: make['id'],
                                  child: Text(
                                    make['name'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
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
                      ),
                      const SizedBox(height: 20),

                      /// 🔹 Vehicle Model
                      IgnorePointer(
                        ignoring: _isVehicleReadOnly,
                        child: DropdownButtonFormField<int>(
                          decoration: borderedDecoration('Vehicle Model'),
                          value: selectedModelId,
                          items:
                              vehicleModels.map((model) {
                                return DropdownMenuItem<int>(
                                  value: model['id'],
                                  child: Text(
                                    model['name'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedModelId = value;
                            });
                          },
                        ),
                      ),

                      BorderedTextFormField(
                        label: "Vehicle Registration",
                        controller: regController,
                        readOnly: _isVehicleReadOnly,
                      ),

                      // BorderedTextFormField(
                      //   label: "Year of Manufacture",
                      //   controller: yearController,
                      //   readOnly: _isReadOnly,
                      // ),
                      BorderedDropdown<String>(
                        label: "Year",
                        value:
                            yearController.text.isEmpty
                                ? null
                                : yearController.text,
                        items: generateYears(),
                        onChanged:
                            (val) =>
                                setState(() => yearController.text = val ?? ''),
                        readOnly: _isSubmittedVehicle,
                      ),

                      const SizedBox(height: 20),
                    ],

                    // SizedBox(
                    //   width: double.infinity, // 🔹 Stretch full width
                    //   child: ElevatedButton(
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor:
                    //           _isSubmitted
                    //               ? Colors.grey
                    //               : Colors
                    //                   .black, // black before submit, grey after
                    //       foregroundColor: Colors.white, // text color
                    //       padding: const EdgeInsets.symmetric(vertical: 18),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(14),
                    //       ),
                    //       elevation: 0,
                    //     ),
                    //     onPressed:
                    //         _isSubmitted
                    //             ? null // disables button after submission
                    //             : () async {
                    //               if (_formKey.currentState!.validate()) {
                    //                 if (widget.role == UserRole.driver) {
                    //                   await submitToBackend();
                    //                 } else if (widget.role == UserRole.owner) {
                    //                   await submitVehicle();
                    //                 } else {
                    //                   await submitToBackend();
                    //                   await submitVehicle();
                    //                 }
                    //               }
                    //             },
                    //     child: Text(
                    //       _isSubmitted ? "Submitted" : "Submit",
                    //       style: const TextStyle(
                    //         fontSize: 16,
                    //         fontWeight: FontWeight.w600,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (_isSubmitted && _isSubmittedVehicle)
                                  ? Colors.grey
                                  : Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed:
                            (_isSubmitted && _isSubmittedVehicle)
                                ? null // disabled only if both submitted
                                : () async {
                                  if (!_formKey.currentState!.validate())
                                    return;

                                  // 🚗 Check vehicle required
                                  if (showVehicleSection && vehicleId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please add vehicle details first.",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  setState(
                                    () => _isSubmitted = true,
                                  ); // start spinner

                                  try {
                                    // 🔹 Submit driver info
                                    if (showDriverSection) {
                                      await submitToBackend();
                                    }

                                    // 🔹 Submit vehicle info
                                    if (showVehicleSection) {
                                      await submitVehicle();
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Submission successful!"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Submission failed: $e"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    setState(() {
                                      _isSubmitted = false; // stop spinner
                                      _isSubmittedVehicle =
                                          false; // reset vehicle submission
                                    });
                                    return;
                                  }

                                  // ✅ Both submissions done successfully
                                  setState(() {
                                    _isSubmitted = false; // spinner off
                                    // _isSubmittedVehicle is already updated inside submitVehicle()
                                  });
                                },
                        child:
                            (_isSubmitted)
                                ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                                : Text(
                                  (_isSubmitted && _isSubmittedVehicle)
                                      ? "Submitted"
                                      : "Submit",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),

                    // SizedBox(
                    //   width: double.infinity,
                    //   child: ElevatedButton(
                    //     style: ElevatedButton.styleFrom(
                    //       backgroundColor:
                    //           (_isSubmitted && _isSubmittedVehicle)
                    //               ? Colors.grey
                    //               : Colors
                    //                   .black, // black if any not submitted, grey if both submitted
                    //       foregroundColor: Colors.white,
                    //       padding: const EdgeInsets.symmetric(vertical: 18),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(14),
                    //       ),
                    //       elevation: 0,
                    //     ),
                    //     onPressed:
                    //         (_isSubmitted && _isSubmittedVehicle)
                    //             ? null // disables only if both true
                    //             : () async {
                    //               if (_formKey.currentState!.validate()) {
                    //                 // Check if vehicle is missing
                    //                 if (showVehicleSection &&
                    //                     vehicleId == null) {
                    //                   ScaffoldMessenger.of(
                    //                     context,
                    //                   ).showSnackBar(
                    //                     const SnackBar(
                    //                       content: Text(
                    //                         "Please add vehicle details first.",
                    //                       ),
                    //                       backgroundColor: Colors.red,
                    //                     ),
                    //                   );
                    //                   setState(
                    //                     () => _isSubmittedVehicle = false,
                    //                   );
                    //                   return;
                    //                 }

                    //                 setState(() => _isSubmitted = true);

                    //                 try {
                    //                   if (widget.role == UserRole.driver) {
                    //                     await submitToBackend();
                    //                   } else if (widget.role ==
                    //                       UserRole.owner) {
                    //                     await submitVehicle();
                    //                   } else {
                    //                     await submitToBackend();
                    //                     await submitVehicle();
                    //                   }

                    //                   ScaffoldMessenger.of(
                    //                     context,
                    //                   ).showSnackBar(
                    //                     const SnackBar(
                    //                       content: Text(
                    //                         "Submission successful!",
                    //                       ),
                    //                       backgroundColor: Colors.green,
                    //                     ),
                    //                   );
                    //                 } catch (e) {
                    //                   ScaffoldMessenger.of(
                    //                     context,
                    //                   ).showSnackBar(
                    //                     SnackBar(
                    //                       content: Text(
                    //                         "Submission failed: $e",
                    //                       ),
                    //                       backgroundColor: Colors.red,
                    //                     ),
                    //                   );
                    //                   setState(() {
                    //                     _isSubmitted = false;
                    //                     _isSubmittedVehicle = false;
                    //                   });
                    //                 }
                    //               }
                    //             },
                    //     child:
                    //         (_isSubmitted || _isSubmittedVehicle)
                    //             ? const SizedBox(
                    //               height: 24,
                    //               width: 24,
                    //               child: CircularProgressIndicator(
                    //                 color: Colors.white,
                    //                 strokeWidth: 3,
                    //               ),
                    //             )
                    //             : const Text(
                    //               "Submit",
                    //               style: TextStyle(
                    //                 fontSize: 16,
                    //                 fontWeight: FontWeight.w600,
                    //               ),
                    //             ),
                    //   ),
                    // ),
                    const SizedBox(height: 20),

                    /// 📄 DOCUMENTS SECTION
                    const Text(
                      "Upload Required Documents",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (showDriverSection) ...[
                      const Text(
                        "Driver Documents",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._driverDocuments.entries.map((entry) {
                        final type = entry.key;
                        final doc = entry.value;
                        final label = doc['documentName'] ?? type.toString();
                        final file = doc['file'] as File?;
                        final url = doc['url'];
                        final status = doc['status'];
                        // final bool isUploading = doc['isUploading'] == true;

                        final String? fullUrl =
                            url != null && !url.startsWith('http')
                                ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
                                : url;

                        return BorderedUploadButton(
                          label: label,
                          isUploaded: file != null || fullUrl != null,
                          status: doc['status'],

                          // onPressed: () {
                          //   // if (file == null &&
                          //   //     fullUrl == null &&
                          //   //     !isUploading)

                          //   //if (!isUploading && status != 'Approved')
                          //   if (!isUploading &&
                          //       (status ?? '').toLowerCase() != 'approved') {
                          //     _pickFile(type);
                          //   }
                          // },
                          // onPressed: () {
                          //   final isApproved =
                          //       (status ?? '').toLowerCase() == 'approved';

                          //   if (_isUploading) {
                          //     ScaffoldMessenger.of(context).showSnackBar(
                          //       const SnackBar(
                          //         content: Text("Upload in progress..."),
                          //       ),
                          //     );
                          //     return;
                          //   }

                          //   if (isApproved) {
                          //     ScaffoldMessenger.of(context).showSnackBar(
                          //       const SnackBar(
                          //         content: Text("Document already approved"),
                          //       ),
                          //     );
                          //     return;
                          //   }

                          //   _pickFile(type);
                          // },
                          onPressed: () {
                            final isApproved =
                                (status ?? '').toLowerCase() == 'approved';

                            if (_isUploading) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Upload in progress..."),
                                ),
                              );
                              return;
                            }

                            if (isApproved) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Document already approved"),
                                ),
                              );
                              return;
                            }

                            _pickFile(type);
                          },
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
                            if (status == 'Approved') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot delete an approved document',
                                  ),
                                ),
                              );
                              return; // Prevent deletion
                            }
                            await deleteDocumentFromBackend(type);
                            setState(() {
                              _driverDocuments[type]!['file'] = null;
                              _driverDocuments[type]!['url'] = null;
                              _driverDocuments[type]!['status'] = null;
                            });
                          },
                        );
                      }),
                    ],

                    if (showVehicleSection) ...[
                      const Text(
                        "Vehicle Documents",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._vehicleDocuments.entries.map((entry) {
                        final type = entry.key;
                        final doc = entry.value;
                        final label = doc['documentName'] ?? type.toString();
                        final file = doc['file'] as File?;
                        final url = doc['url'];
                        final status = doc['status'];
                        // final bool isUploading = doc['isUploading'] == true;

                        final String? fullUrl =
                            url != null && !url.startsWith('http')
                                ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
                                : url;

                        return BorderedUploadButton(
                          label: label,
                          isUploaded: file != null || fullUrl != null,
                          status: doc['status'],

                          // onPressed: () {
                          //   // if (file == null &&
                          //   //     fullUrl == null &&
                          //   //     !isUploading)
                          //  // if (!isUploading && status != 'Approved')

                          //  if (!isUploading && (status ?? '').toLowerCase() != 'approved')

                          //        {
                          //     _pickFile(type);
                          //   }
                          // },
                          onPressed: () {
                            final isApproved =
                                (status ?? '').toLowerCase() == 'approved';

                            if (_isUploading) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Upload in progress..."),
                                ),
                              );
                              return;
                            }

                            if (isApproved) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Document already approved"),
                                ),
                              );
                              return;
                            }

                            _pickFile(type);
                          },
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
                            if (status == 'Approved') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot delete an approved document',
                                  ),
                                ),
                              );
                              return; // Prevent deletion
                            }
                            await deleteVehicleDocumentFromBackend(type);
                            setState(() {
                              _vehicleDocuments[type]!['file'] = null;
                              _vehicleDocuments[type]!['url'] = null;
                              _vehicleDocuments[type]!['status'] = null;
                            });
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BorderedTextFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const BorderedTextFormField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: readOnly ? Colors.grey[200] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: readOnly ? Colors.grey : Colors.grey.shade400,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
//   @override
//   Widget build(BuildContext context) {
//     return TextFormField(
//       controller: controller,
//       validator: validator,
//       onTap: onTap,
//       readOnly: readOnly, // 👈 Pass it to TextFormField
//       decoration: InputDecoration(
//         labelText: label,
//         border: OutlineInputBorder(),
//       ),
//     );
//   }
// }

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

  // @override
  // Widget build(BuildContext context) {
  //   return GestureDetector(
  //     onLongPress:
  //         isUploaded
  //             ? () async {
  //               final confirmed = await showDialog(
  //                 context: context,
  //                 builder:
  //                     (ctx) => AlertDialog(
  //                       title: const Text("Delete Document?"),
  //                       content: const Text("Are you sure?"),
  //                       actions: [
  //                         TextButton(
  //                           onPressed: () => Navigator.pop(ctx, false),
  //                           child: const Text("Cancel"),
  //                         ),
  //                         TextButton(
  //                           onPressed: () => Navigator.pop(ctx, true),
  //                           child: const Text("Delete"),
  //                         ),
  //                       ],
  //                     ),
  //               );

  //               if (confirmed == true) {
  //                 await onRemove?.call();
  //               }
  //             }
  //             : null,
  //     child: Container(
  //       margin: const EdgeInsets.symmetric(vertical: 8),
  //       padding: const EdgeInsets.all(14),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(14),
  //         border: Border.all(color: Colors.grey.shade300),
  //       ),
  //       child: Row(
  //         children: [
  //           Icon(
  //             isUploaded ? Icons.check_circle : Icons.upload_file,
  //             color: isUploaded ? Colors.green : Colors.black,
  //           ),
  //           const SizedBox(width: 12),

  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   label,
  //                   style: const TextStyle(fontWeight: FontWeight.w600),
  //                 ),
  //                 if (status != null)
  //                   Text(
  //                     status!,
  //                     style: TextStyle(
  //                       color:
  //                           status == "Approved" ? Colors.green : Colors.orange,
  //                       fontSize: 12,
  //                     ),
  //                   ),
  //               ],
  //             ),
  //           ),

  //           if (isUploaded)
  //             IconButton(
  //               icon: const Icon(Icons.remove_red_eye),
  //               onPressed: onPreview,
  //             ),

  //           if (status != "Approved")
  //             IconButton(
  //               icon: const Icon(Icons.delete),
  //               onPressed: () async => await onRemove?.call(),
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior:
          HitTestBehavior.translucent, // ensures taps on empty space register
      onTap: onPressed, // ✅ add this
      onLongPress:
          isUploaded
              ? () async {
                final confirmed = await showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        title: const Text("Delete Document?"),
                        content: const Text("Are you sure?"),
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

                if (confirmed == true) {
                  await onRemove?.call();
                }
              }
              : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded ? Colors.green : Colors.black,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (status != null)
                    Text(
                      status!,
                      style: TextStyle(
                        color:
                            status == "Approved" ? Colors.green : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (isUploaded)
              IconButton(
                icon: const Icon(Icons.remove_red_eye),
                onPressed: onPreview,
              ),
            if (status != "Approved")
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async => await onRemove?.call(),
              ),
          ],
        ),
      ),
    );
  }
}

class BorderedDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final void Function(T?) onChanged;
  final bool readOnly;

  const BorderedDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: readOnly ? Colors.grey[200] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: readOnly ? Colors.grey : Colors.grey.shade400,
            ),
          ),
        ),
        items:
            items
                .map(
                  (e) =>
                      DropdownMenuItem<T>(value: e, child: Text(e.toString())),
                )
                .toList(),
        onChanged: readOnly ? null : onChanged,
      ),
    );
  }
}

List<String> generateYears() {
  final now = DateTime.now().year;
  return List.generate(10, (i) => (now - i).toString());
}

// Submit button with dynamic styling
Widget submitButton(
  BuildContext context,
  bool isSubmitted,
  VoidCallback onTap,
) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSubmitted ? Colors.grey : Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: isSubmitted ? null : onTap,
      child: Text(
        isSubmitted ? 'Submitted' : 'Submit',
        style: const TextStyle(fontSize: 16),
      ),
    ),
  );
}
// import 'dart:convert';
// import 'dart:io';
// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/document_module.dart';
// import 'package:aminidriver/Onboarding/document_preview.dart';
// import 'package:aminidriver/Onboarding/user_role.dart';
// import 'package:aminidriver/Onboarding/vehicle.dart';
// import 'package:aminidriver/Onboarding/vehicle_category.dart';
// import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:path/path.dart' as path;

// class DocumentModel2 {
//   final int id;
//   final DocumentType documentType; // enum index
//   final String documentName; // readable string

//   DocumentModel2({
//     required this.id,
//     required this.documentType,
//     required this.documentName,
//   });

//   factory DocumentModel2.fromJson(Map<String, dynamic> json) {
//     return DocumentModel2(
//       id: json['id'], // PascalCase from backend
//       // documentType: json['documentType'], // PascalCase
//       documentType: DocumentType.values[json['documentType'] as int],
//       documentName: json['documentName'].toString(), // PascalCase
//     );
//   }
// }

// class CategoryDocumentsResponse {
//   final String vehicleCategory;
//   final List<DocumentModel2> personalDocuments;
//   final List<DocumentModel2> vehicleDocuments;

//   CategoryDocumentsResponse({
//     required this.vehicleCategory,
//     required this.personalDocuments,
//     required this.vehicleDocuments,
//   });

//   factory CategoryDocumentsResponse.fromJson(Map<String, dynamic> json) {
//     return CategoryDocumentsResponse(
//       vehicleCategory: json['vehicleCategory'].toString(), // PascalCase
//       personalDocuments:
//           (json['personalDocuments'] as List)
//               .map((e) => DocumentModel2.fromJson(e))
//               .toList(),
//       vehicleDocuments:
//           (json['vehicleDocuments'] as List)
//               .map((e) => DocumentModel2.fromJson(e))
//               .toList(),
//     );
//   }
// }

// class DriverOnboardingScreen extends StatefulWidget {
//   //final VoidCallback onCompleted;
//   //final bool skipVehicleOnboarding;

//   final UserRole role;
//   final VehicleCategory? category;
//   const DriverOnboardingScreen({
//     super.key,

//     //required this.onCompleted,
//     required this.role,
//     this.category,
//     //this.skipVehicleOnboarding = false,
//   });

//   @override
//   State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
// }

// class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
//   final _formKey = GlobalKey<FormState>();

//   bool get showDriverSection =>
//       widget.role == UserRole.driver || widget.role == UserRole.driverOwner;

//   bool get showVehicleSection =>
//       widget.role == UserRole.owner || widget.role == UserRole.driverOwner;

//   bool _isReadOnly = false;
//   VehicleCategory? _vehicleCategory;

//   final TextEditingController _licenseExpiryController =
//       TextEditingController();
//   DateTime? _licenseExpiryDate;

//   final _idNumberController = TextEditingController();
//   final _paymentMobileController = TextEditingController();
//   final _referralCodeController = TextEditingController();

//   int? selectedMakeId, selectedModelId, selectedCategoryId;
//   List<Map<String, dynamic>> vehicleMakes = [];
//   List<Map<String, dynamic>> vehicleModels = [];
//   //List<Map<String, dynamic>> vehicleCategories = [];
//   final regController = TextEditingController();
//   final yearController = TextEditingController();
//   String driverId = '';
//   String email = '';
//   String? FetchedDriver = '';
//   int? vehicleId;

//   //final _licenseExpiryController = TextEditingController();

//   String? _selectedIdType;
//   final List<String> _idTypes = ['National ID', 'Passport'];
//   final Map<DocumentModel2, Map<String, dynamic>> _driverDocuments1 = {};
//   final Map<DocumentModel2, Map<String, dynamic>> _vehicleDocuments1 = {};
//   final Map<DocumentType, Map<String, dynamic>> _driverDocuments = {};
//   final Map<DocumentType, Map<String, dynamic>> _vehicleDocuments = {};

//   Future<void> fetchDriverCategory(String firebaseId) async {
//     try {
//       final url = Uri.parse(
//         "$baseUrl/vehicles/fetchdrivercategory/$firebaseId",
//       );
//       final res = await http.get(url);

//       if (res.statusCode == 200) {
//         final decoded = json.decode(res.body);

//         try {
//           // ✅ Backend returns PascalCase "vehiclecategoryid" → "vehicleCategoryId"
//           int category = decoded['vehiclecategoryid'];

//           final resDocs = await http.get(
//             Uri.parse("$baseUrl/vehicles/getdocuments/$category"),
//           );

//           if (resDocs.statusCode == 200) {
//             final decodedDocs = json.decode(resDocs.body);

//             // ✅ Use PascalCase mapping
//             final response = CategoryDocumentsResponse.fromJson(decodedDocs);
//             if (mounted) {
//               setState(() {
//                 _driverDocuments1.clear();
//                 _vehicleDocuments1.clear();
//                 _driverDocuments.clear();
//                 _vehicleDocuments.clear();

//                 // --- Driver documents ---
//                 for (var doc in response.personalDocuments) {
//                   // Save backend info
//                   _driverDocuments1[doc] = {
//                     'label': doc.documentName,
//                     'backendId': doc.id,
//                     'documentType': doc.documentType, // DocumentType enum
//                   };

//                   // Initialize UI state
//                   _driverDocuments[doc.documentType] = {
//                     'label': doc.documentName,
//                   };
//                   //   // 'file': null,
//                   //   // // 'status':
//                   //   // //     DocumentStatus.underReview.toString(), // keep as enum
//                   //   // 'url': null,
//                   //   'label': doc.documentName,
//                   //   // 'backendDoc':
//                   //   //     doc, // optional: keep reference to DocumentModel2
//                   // };
//                 }

//                 // --- Vehicle documents ---
//                 for (var doc in response.vehicleDocuments) {
//                   _vehicleDocuments1[doc] = {
//                     'label': doc.documentName,
//                     'backendId': doc.id,
//                     'documentType': doc.documentType,
//                   };

//                   _vehicleDocuments[doc.documentType] = {
//                     'label': doc.documentName,
//                   };
//                   // 'file': null,
//                   // // 'status':
//                   // //     DocumentStatus.underReview.toString(), // keep as enum
//                   // 'url': null,
//                   //   'label': doc.documentName,
//                   //   //'backendDoc': doc,
//                   // };
//                 }
//               });

//               debugPrint("Decoded documents JSON: $decodedDocs");
//             } else {
//               debugPrint("Failed to fetch documents: ${resDocs.statusCode}");
//             }
//           }
//         } catch (e) {
//           debugPrint("Error fetching documents: $e");
//         }

//         debugPrint("Driver category: ${decoded['vehiclecategoryid']}");
//       } else {
//         debugPrint("Failed to fetch category: ${res.statusCode} - ${res.body}");
//       }
//     } catch (e) {
//       debugPrint("Error fetching category: $e");
//     }
//   }

//   // Future<void> fetchDocumentsForCategory() async {
//   //   try {
//   //     final res = await http.get(
//   //       //Uri.parse("$baseUrl/vehicles/getdocuments/$widget.category"),
//   //       //Uri.parse("$baseUrl/vehicles/getdocuments/${widget.category?.index}"),
//   //       Uri.parse(
//   //         "$baseUrl/vehicles/getdocuments/getdocuments/$widget.category!",
//   //       ),
//   //     );

//   //     if (res.statusCode == 200) {
//   //       final decoded = json.decode(res.body);
//   //       final response = CategoryDocumentsResponse.fromJson(decoded);

//   //       setState(() {
//   //         // _driverDocuments.clear();
//   //         // _vehicleDocuments.clear();

//   //         // for (var doc in response.personalDocuments) {
//   //         //   _driverDocuments[doc.documentType] = {
//   //         //     'file': null,
//   //         //     'status': null,
//   //         //     'url': null,
//   //         //     'label': doc.documentName,
//   //         //   };
//   //         // }

//   //         // for (var doc in response.vehicleDocuments) {
//   //         //   _vehicleDocuments[doc.documentType] = {
//   //         //     'file': null,
//   //         //     'status': null,
//   //         //     'url': null,
//   //         //     'label': doc.documentName,
//   //         //   };
//   //         // }

//   //         // for (var doc in response.personalDocuments) {
//   //         //   final type = DocumentType.values[doc.documentType];
//   //         //   _driverDocuments[type] = {
//   //         //     'file': null,
//   //         //     'status': null,
//   //         //     'url': null,
//   //         //     'label': doc.documentName,
//   //         //   };
//   //         // }

//   //         // for (var doc in response.vehicleDocuments) {
//   //         //   final type = DocumentType.values[doc.documentType];
//   //         //   _vehicleDocuments[type] = {
//   //         //     'file': null,
//   //         //     'status': null,
//   //         //     'url': null,
//   //         //     'label': doc.documentName,
//   //         //   };
//   //         // }
//   //       });
//   //     } else {
//   //       debugPrint("Failed to fetch documents: ${res.statusCode}");
//   //     }
//   //   } catch (e) {
//   //     debugPrint("Error fetching documents: $e");
//   //   }
//   // }

//   void _initializeDocuments() {
//     _driverDocuments.clear();
//     _vehicleDocuments.clear();

//     switch (_vehicleCategory) {
//       case VehicleCategory.passenger:
//         _driverDocuments.addAll({
//           DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
//           DocumentType.idFront: {'file': null, 'status': null, 'url': null},
//           DocumentType.idBack: {'file': null, 'status': null, 'url': null},
//           DocumentType.drivingLicense: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.policeClearance: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.psvBadge: {'file': null, 'status': null, 'url': null},
//         });

//         _vehicleDocuments.addAll({
//           DocumentType.logbook: {'file': null, 'status': null, 'url': null},
//           DocumentType.vehiclePicture: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.insuranceCover: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.psvCertificate: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           if (_vehicleCategory == VehicleCategory.ambulance)
//             DocumentType.healthCertificate: {
//               'file': null,
//               'status': null,
//               'url': null,
//             },
//         });

//         break;
//       case VehicleCategory.ambulance:
//         _driverDocuments.addAll({
//           DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
//           DocumentType.idFront: {'file': null, 'status': null, 'url': null},
//           DocumentType.idBack: {'file': null, 'status': null, 'url': null},
//           DocumentType.drivingLicense: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.policeClearance: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.psvBadge: {'file': null, 'status': null, 'url': null},
//         });

//         _vehicleDocuments.addAll({
//           DocumentType.logbook: {'file': null, 'status': null, 'url': null},
//           DocumentType.vehiclePicture: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.insuranceCover: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.psvCertificate: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.healthCertificate: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//         });
//         break;
//       case VehicleCategory.cargo:
//       case VehicleCategory.movers:
//       case VehicleCategory.carhire:
//       case VehicleCategory.waterBowser:
//       case VehicleCategory.exhauster:
//       case VehicleCategory.breakdown:
//         _driverDocuments.addAll({
//           DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
//           DocumentType.idFront: {'file': null, 'status': null, 'url': null},
//           DocumentType.idBack: {'file': null, 'status': null, 'url': null},
//           DocumentType.drivingLicense: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//         });

//         _vehicleDocuments.addAll({
//           DocumentType.logbook: {'file': null, 'status': null, 'url': null},
//           DocumentType.insuranceCover: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//         });
//         break;

//       case VehicleCategory.matatu:
//       case VehicleCategory.mechanical:
//         _driverDocuments.addAll({
//           DocumentType.CertificateOfIncorporation: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//         });
//         _vehicleDocuments.addAll({
//           DocumentType.logbook: {'file': null, 'status': null, 'url': null},
//           DocumentType.vehiclePicture: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.insuranceCover: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//           DocumentType.psvCertificate: {
//             'file': null,
//             'status': null,
//             'url': null,
//           },
//         });
//         break;
//       default:
//         _driverDocuments.addAll({
//           DocumentType.profilePic: {'file': null, 'status': null, 'url': null},
//         }); // = {DocumentType.profilePic: {}};
//     }
//   }

//   // bool _areAllDocsApproved(Map<DocumentType, Map<String, dynamic>> docs) {
//   //   return docs.values.every(
//   //    // (doc) => doc['status']?.toLowerCase() == 'approved',
//   //     (doc['status'] as DocumentStatus).name.toLowerCase() == 'approved',
//   //   );
//   // }
//   bool _areAllDocsApproved(Map<DocumentType, Map<String, dynamic>> docs) {
//     return docs.values.every((doc) {
//       final status = doc['status'] as DocumentStatus?; // nullable
//       return status != null && status == DocumentStatus.approved.toString();
//     });
//   }
//   // bool _areAllDocsApproved(Map<DocumentType, Map<String, dynamic>> docs) {
//   //   return docs.values.every(
//   //     (doc) => (doc['status'] as DocumentStatus?) == DocumentStatus.approved,
//   //   );
//   // }

//   bool _areAnyDocumentsApproved(Map<DocumentType, Map<String, dynamic>> docs) {
//     return docs.values.any(
//       (doc) => (doc['status'] ?? '').toString().toLowerCase() == 'approved',
//     );
//   }

//   Future<void> _checkAndRedirectIfAllApproved() async {
//     final driverDocsApproved = _areAllDocsApproved(_driverDocuments);
//     final vehicleDocsApproved = _areAllDocsApproved(_vehicleDocuments);

//     final hasAnyDriverDocApproved = _areAnyDocumentsApproved(_driverDocuments);
//     final hasAnyVehicleDocApproved = _areAnyDocumentsApproved(
//       _vehicleDocuments,
//     );

//     // 🛑 Block navigation if none uploaded & approved
//     final hasAtLeastOneApproved =
//         (widget.role == UserRole.driver && hasAnyDriverDocApproved) ||
//         (widget.role == UserRole.owner && hasAnyVehicleDocApproved) ||
//         (widget.role == UserRole.driverOwner &&
//             (hasAnyDriverDocApproved || hasAnyVehicleDocApproved));

//     if (!hasAtLeastOneApproved) {
//       debugPrint(
//         "🚫 No required documents uploaded/approved. Blocking navigation.",
//       );
//       return; // do nothing
//     }

//     // ✅ Allow only when ALL docs required for role are approved
//     final allApproved =
//         (widget.role == UserRole.driver && driverDocsApproved) ||
//         (widget.role == UserRole.owner && vehicleDocsApproved) ||
//         (widget.role == UserRole.driverOwner &&
//             driverDocsApproved &&
//             vehicleDocsApproved);

//     if (allApproved) {
//       Future.delayed(const Duration(milliseconds: 300), () {
//         if (mounted) {
//           context.goNamed(Routes().navigationScreen);
//         }
//       });
//     }
//   }

//   // final Map<DocumentType, String> _docLabels = {
//   //   DocumentType.profilePic: 'Upload Profile Picture',
//   //   DocumentType.idFront: 'Upload ID Front',
//   //   DocumentType.idBack: 'Upload ID Back',
//   //   DocumentType.drivingLicense: 'Upload Driving License',
//   //   DocumentType.policeClearance: 'Upload Police Clearance',
//   //   DocumentType.psvBadge: 'Upload PSV Badge',
//   //   DocumentType.healthCertificate: 'Upload Health Cert',
//   //   DocumentType.CertificateOfIncorporation: 'Upload Cert of incorporation',
//   //   DocumentType.logbook: 'Upload logbook',
//   //   DocumentType.vehiclePicture: 'Upload Vehicle Pic',
//   //   DocumentType.insuranceCover: 'Upload Insurance',
//   //   DocumentType.psvCertificate: 'Upload Psv Certificate',
//   // };
//   @override
//   void initState() {
//     super.initState();
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       driverId = user.uid;
//       email = user.email ?? '';
//     }
//     fetchDriverCategory(driverId);
//     // fetchDocumentsForCategory();
//     _fetchDriverDetails();
//     _fetchDocumentStatus();
//     _fetchVehicleDocumentStatus();
//     //loadVehicle();
//     // fetchDropdownData();
//     fetchDropdownData().then((_) {
//       loadVehicle(); // 🔁 load after makes are available
//     });

//     // Fetch document statuses when screen loads
//   }

//   bool _areAllRequiredDocumentsUploaded() {
//     bool allDriverDocsUploaded = _driverDocuments.values.every(
//       (doc) =>
//           doc['file'] != null ||
//           (doc['url'] != null && doc['url'].toString().isNotEmpty),
//     );

//     bool allVehicleDocsUploaded = _vehicleDocuments.values.every(
//       (doc) =>
//           doc['file'] != null ||
//           (doc['url'] != null && doc['url'].toString().isNotEmpty),
//     );

//     return allDriverDocsUploaded && allVehicleDocsUploaded;
//   }

//   Future<Vehicle?> fetchVehicleDetails() async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();

//     if (idToken == null) return null;

//     final response = await http.get(
//       Uri.parse('$baseUrl/vehicles/details'),
//       headers: {'Authorization': 'Bearer $idToken'},
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       return Vehicle.fromJson(data);
//     } else {
//       debugPrint("Failed to fetch vehicle: ${response.statusCode}");
//       return null;
//     }
//   }

//   Future<void> loadVehicle() async {
//     final vehicle = await fetchVehicleDetails();

//     if (vehicle != null) {
//       // Load models for the selected make first
//       await fetchVehicleModels(vehicle.make.toString());
//       if (!mounted) return;

//       setState(() {
//         selectedMakeId = vehicle.make;
//         selectedModelId = vehicle.model;
//         // selectedCategoryId = vehicle.categoryId; // if needed
//         vehicleId = vehicle.vehicleId;
//         regController.text = vehicle.registrationNumber;
//         yearController.text = vehicle.year.toString();
//       });
//     }
//   }

//   final ImagePicker _picker = ImagePicker();

//   Future<void> submitToBackend() async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();

//     var uri = Uri.parse('$baseUrl/auth/driver/onboarding'); // Your API endpoint
//     var request = http.MultipartRequest('POST', uri);

//     request.headers['Authorization'] = 'Bearer $idToken';

//     // Add form fields
//     request.fields['token'] = idToken ?? '';
//     //request.fields['idType'] = _selectedIdType ?? '';
//     request.fields['idNumber'] = _idNumberController.text;
//     request.fields['paymentMobile'] = _paymentMobileController.text;
//     request.fields['referralCode'] = _referralCodeController.text;
//     request.fields['licenseExpiry'] = _licenseExpiryController.text;

//     // Send request
//     final response = await request.send();

//     if (response.statusCode == 200) {
//       print('Submission successful');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Submitted successfully')));
//       //widget.onCompleted();
//     } else {
//       print('Failed: ${response.statusCode}');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Submission failed')));
//     }
//   }

//   Future<void> _fetchDriverDetails() async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();

//     if (user == null || idToken == null) return;

//     final response = await http.get(
//       Uri.parse('$baseUrl/auth/driver/details'),
//       headers: {'Authorization': 'Bearer $idToken'},
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       if (!mounted) return;
//       setState(() {
//         _idNumberController.text = data['idNumber'] ?? '';
//         _paymentMobileController.text = data['paymentMobile'] ?? '';
//         _referralCodeController.text = data['referralCode'] ?? '';
//         _licenseExpiryController.text = data['licenseExpiry'] ?? '';
//         _vehicleCategory = parseVehicleCategory(data['category'] ?? -1);
//         FetchedDriver = data['idNumber'] ?? '';
//         _initializeDocuments();

//         if (data['licenseExpiry'] != null && data['licenseExpiry'].isNotEmpty) {
//           _licenseExpiryDate = DateTime.tryParse(data['licenseExpiry']);
//         }

//         _isReadOnly = true; // 🔐 Grey out all fields
//       });
//     } else {
//       debugPrint(
//         'Failed to fetch driver onboarding details: ${response.statusCode}',
//       );
//     }
//   }

//   Future<void> uploadDocumentToBackend(DocumentType type, File file) async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();

//     if (idToken == null || user == null) return;

//     final uri = Uri.parse('$baseUrl/auth/documents/upload-file');
//     final request = http.MultipartRequest('POST', uri);

//     request.headers['Authorization'] = 'Bearer $idToken';

//     request.fields['documentType'] = type.name;

//     final fileName = file.path.split('/').last;

//     request.files.add(
//       await http.MultipartFile.fromPath('file', file.path, filename: fileName),
//     );

//     final response = await request.send();

//     if (response.statusCode == 200) {
//       await _fetchDocumentStatus();
//       print('Document uploaded directly to backend!');
//     } else {
//       print('Backend upload failed: ${response.statusCode}');
//     }
//   }

//   Future<void> deleteDocumentFromBackend(DocumentType type) async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();
//     if (idToken == null) return;

//     final uri = Uri.parse('$baseUrl/auth/documents/delete?type=${type.name}');
//     final response = await http.delete(
//       uri,
//       headers: {'Authorization': 'Bearer $idToken'},
//     );

//     if (response.statusCode == 200) {
//       if (!mounted) return;
//       setState(() {
//         _driverDocuments[type]!['file'] = null;
//         _driverDocuments[type]!['url'] = null;
//         _driverDocuments[type]!['status'] = null;
//       });
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Document deleted successfully')));
//     } else {
//       debugPrint('Failed to delete: ${response.statusCode}');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to delete document')));
//     }
//   }

//   // Future<void> _fetchDocumentStatus() async {
//   //   //final user = FirebaseAuth.instance.currentUser;
//   //   User? user;
//   //   int retries = 0;

//   //   // 🔁 Retry until user is available (max 5 attempts)
//   //   while (user == null && retries < 5) {
//   //     user = FirebaseAuth.instance.currentUser;
//   //     if (user == null) {
//   //       await Future.delayed(const Duration(milliseconds: 300));
//   //       retries++;
//   //     }
//   //   }

//   //   if (user == null) {
//   //     debugPrint("❌ Firebase user is still null after retries.");
//   //     return;
//   //   }

//   //   final idToken = await user.getIdToken();

//   //   final response = await http.get(
//   //     Uri.parse("$baseUrl/auth/documents/status/${user?.uid}"),
//   //     headers: {'Authorization': 'Bearer $idToken'},
//   //   );

//   //   if (response.statusCode == 200) {
//   //     final List<dynamic> data = jsonDecode(response.body);
//   //     if (!mounted) return;
//   //     setState(() {
//   //       for (var docJson in data) {
//   //         final doc = DocumentModel.fromJson(docJson);
//   //         // _driverDocuments[doc.documentType] = {
//   //         //   'file': null, // or File(doc.filePath) if local
//   //         //   'status': doc.status.label, // ✅ Use label here
//   //         //   'url': doc.filePath,
//   //         // };

//   //         _driverDocuments[doc.documentType] = {
//   //           'file': null,
//   //           'status': doc.status, // keep as DocumentStatus enum
//   //           'url': doc.filePath,
//   //         };

//   //         // final doc = DocumentModel.fromJson(docJson);
//   //         // if (_driverDocuments.containsKey(doc.documentType)) {
//   //         //   _driverDocuments[doc.documentType] = {
//   //         //     'file': null,
//   //         //     'status': doc.status.label,
//   //         //     'url': doc.filePath,
//   //         //   };
//   //         // }
//   //       }
//   //     });
//   //     _checkAndRedirectIfAllApproved();
//   //     // if (_areAllDocumentsApproved()) {
//   //     //   Future.delayed(const Duration(milliseconds: 300), () {
//   //     //     if (mounted) {
//   //     //       context.goNamed(
//   //     //         Routes().navigationScreen,
//   //     //       ); // Or use Navigator.pushReplacement
//   //     //     }
//   //     //   });
//   //     // }
//   //   } else {
//   //     debugPrint('Failed to fetch document statuses');
//   //   }
//   // }
//   Future<void> _fetchDocumentStatus() async {
//     User? user;
//     int retries = 0;

//     // 🔁 Retry until user is available (max 5 attempts)
//     while (user == null && retries < 5) {
//       user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         await Future.delayed(const Duration(milliseconds: 300));
//         retries++;
//       }
//     }

//     if (user == null) {
//       debugPrint("❌ Firebase user is still null after retries.");
//       return;
//     }

//     final idToken = await user.getIdToken();

//     try {
//       final response = await http.get(
//         Uri.parse("$baseUrl/auth/documents/status/${user.uid}"),
//         headers: {'Authorization': 'Bearer $idToken'},
//       );

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         final List<dynamic> data = jsonDecode(response.body);

//         setState(() {
//           _driverDocuments.clear();

//           for (var docJson in data) {
//             final doc = DocumentModel.fromJson(docJson);
//             _driverDocuments[doc.documentType] = {
//               'file': null,
//               'status': doc.status, // keep enum
//               'url': doc.filePath,
//             };
//           }
//         });

//         // Ensure setState completes
//         await Future.delayed(const Duration(milliseconds: 50));

//         if (!mounted) return;
//         _checkAndRedirectIfAllApproved();
//       } else {
//         debugPrint(
//           '❌ Failed to fetch document statuses: ${response.statusCode}',
//         );
//       }
//     } catch (e) {
//       debugPrint('❌ Error fetching document statuses: $e');
//     }
//   }

//   /////vehicledeatils
//   Future<void> fetchDropdownData() async {
//     try {
//       final makeRes = await http.get(Uri.parse("$baseUrl/vehicles/makes"));
//       // final categoryRes = await http.get(
//       //   Uri.parse("$baseUrl/vehicles/categories"),
//       // );

//       if (makeRes.statusCode == 200) {
//         final decodedMake = json.decode(makeRes.body);
//         //final decodedCategory = json.decode(categoryRes.body);
//         if (!mounted) return;
//         setState(() {
//           vehicleMakes = List<Map<String, dynamic>>.from(decodedMake);
//           //vehicleCategories = List<Map<String, dynamic>>.from(decodedCategory);
//           // vehicleMakes = List<String>.from(json.decode(makeRes.body));
//           // vehicleCategories = List<String>.from(json.decode(categoryRes.body));
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
//         final decodedModels = json.decode(modelRes.body);
//         if (!mounted) return;
//         setState(() {
//           vehicleModels = List<Map<String, dynamic>>.from(decodedModels);
//           selectedModelId = null;
//         });
//         // setState(() {
//         //   vehicleModels = List<String>.from(json.decode(modelRes.body));
//         //   selectedModel = null;
//         // });
//       }
//     } catch (e) {
//       debugPrint("Failed to fetch vehicle models: $e");
//     }
//   }

//   Future<void> submitVehicle() async {
//     final uri = Uri.parse("$baseUrl/vehicles/UploadVehicle");

//     final Map<String, dynamic> body = {
//       // "email": email,
//       "vehicleOwnerId": driverId,
//       "firebaseUid": driverId,
//       "vehicleMake": selectedMakeId,
//       "vehicleModel": selectedModelId,
//       //"vehicleCategoryId": selectedCategoryId,
//       "registrationNumber": regController.text,
//       "year": int.tryParse(yearController.text) ?? 0,
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
//       //await Future.delayed(const Duration(milliseconds: 500));
//       //GoRouter.of(context).goNamed(Routes().navigationScreen);
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
//     }

//     //await Future.delayed(const Duration(milliseconds: 500));
//     //GoRouter.of(context).goNamed(Routes().navigationScreen);
//   }

//   Future<void> uploadVehicleDocumentToBackend(
//     DocumentType type,
//     File file,
//     int vehicleId, // ⬅ Add this parameter
//   ) async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();

//     if (idToken == null || user == null) return;

//     final uri = Uri.parse('$baseUrl/vehicles/documents/upload-file');
//     final request = http.MultipartRequest('POST', uri);

//     request.headers['Authorization'] = 'Bearer $idToken';

//     request.fields['documentType'] = type.name;
//     request.fields['vehicleId'] = vehicleId.toString(); // ✅ This is critical

//     final fileName = path.basename(file.path);
//     request.files.add(
//       await http.MultipartFile.fromPath('file', file.path, filename: fileName),
//     );

//     final response = await request.send();
//     final respStr =
//         await response.stream.bytesToString(); // 📦 Check server message
//     if (!mounted) return;
//     if (response.statusCode == 200) {
//       await _fetchVehicleDocumentStatus();
//       print('✅ Document uploaded successfully: $respStr');
//     } else {
//       print('❌ Upload failed (${response.statusCode}): $respStr');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Upload failed: $respStr")));
//     }
//   }

//   Future<void> deleteVehicleDocumentFromBackend(DocumentType type) async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();
//     if (idToken == null) return;

//     final uri = Uri.parse(
//       '$baseUrl/vehicles/documents/delete?type=${type.name}',
//     );
//     final response = await http.delete(
//       uri,
//       headers: {'Authorization': 'Bearer $idToken'},
//     );

//     if (response.statusCode == 200) {
//       if (!mounted) return;
//       setState(() {
//         _vehicleDocuments[type]!['file'] = null;
//         _vehicleDocuments[type]!['url'] = null;
//         _vehicleDocuments[type]!['status'] = null;
//       });
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Document deleted successfully')));
//     } else {
//       debugPrint('Failed to delete: ${response.statusCode}');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to delete document')));
//     }
//   }

//   Future<void> _fetchVehicleDocumentStatus() async {
//     User? user;
//     int retries = 0;

//     // 🔁 Retry until user is available (max 5 attempts)
//     while (user == null && retries < 5) {
//       user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         await Future.delayed(const Duration(milliseconds: 300));
//         retries++;
//       }
//     }

//     if (user == null) {
//       debugPrint("❌ Firebase user is still null after retries.");
//       return;
//     }

//     final idToken = await user.getIdToken();

//     final response = await http.get(
//       Uri.parse("$baseUrl/vehicles/documents/status/${user?.uid}"),
//       headers: {'Authorization': 'Bearer $idToken'},
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> data = jsonDecode(response.body);
//       if (!mounted) return;
//       setState(() {
//         for (var docJson in data) {
//           final doc = DocumentModel.fromJson(docJson);
//           _vehicleDocuments[doc.documentType] = {
//             'file': null, // or File(doc.filePath) if local
//             'status': doc.status.label, // ✅ Use label here
//             'url': doc.filePath,
//           };
//         }
//       });
//       _checkAndRedirectIfAllApproved();
//       // if (_areAllDocumentsApproved()) {
//       //   Future.delayed(const Duration(milliseconds: 300), () {
//       //     if (mounted) {
//       //       context.goNamed(Routes().navigationScreen);
//       //     }
//       //   });
//       // }
//     } else {
//       debugPrint('Failed to fetch document statuses');
//     }
//   }

//   Future<void> _pickFile(DocumentType type) async {
//     showModalBottomSheet(
//       context: context,
//       builder:
//           (_) => Wrap(
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.camera_alt),
//                 title: const Text("Take a Photo"),
//                 onTap: () async {
//                   Navigator.pop(context);
//                   final picked = await _picker.pickImage(
//                     source: ImageSource.camera,
//                   );
//                   if (picked != null) {
//                     final file = File(picked.path);
//                     _handlePickedFile(type, file);
//                   }
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.photo),
//                 title: const Text("Pick from Gallery"),
//                 onTap: () async {
//                   Navigator.pop(context);
//                   final picked = await _picker.pickImage(
//                     source: ImageSource.gallery,
//                   );
//                   if (picked != null) {
//                     final file = File(picked.path);
//                     _handlePickedFile(type, file);
//                   }
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.attach_file),
//                 title: const Text("Upload Document"),
//                 onTap: () async {
//                   Navigator.pop(context);
//                   final result = await FilePicker.platform.pickFiles();
//                   if (result != null && result.files.single.path != null) {
//                     final file = File(result.files.single.path!);
//                     _handlePickedFile(type, file);
//                   }
//                 },
//               ),
//             ],
//           ),
//     );
//   }

//   Future<void> _handlePickedFile(DocumentType type, File file) async {
//     // Check if it's a driver document
//     if (_driverDocuments.containsKey(type)) {
//       // if (FetchedDriver == null) {
//       //   debugPrint(
//       //     "Driver ID not found. Make sure Driver is registered before uploading documents.",
//       //   );
//       //   ScaffoldMessenger.of(context).showSnackBar(
//       //     const SnackBar(content: Text("Please submit driver details first.")),
//       //   );
//       //   return;
//       // }

//       setState(() {
//         _driverDocuments[type]!['file'] = file;
//       });
//       await uploadDocumentToBackend(type, file);
//     } else if (_vehicleDocuments.containsKey(type)) {
//       // if (vehicleId == null) {
//       //   debugPrint(
//       //     "Vehicle ID not found. Make sure vehicle is registered before uploading documents.",
//       //   );
//       //   ScaffoldMessenger.of(context).showSnackBar(
//       //     const SnackBar(content: Text("Please submit vehicle details first.")),
//       //   );
//       //   return;
//       // }

//       setState(() {
//         _vehicleDocuments[type]!['file'] = file;
//       });
//       await uploadVehicleDocumentToBackend(
//         type,
//         file,
//         vehicleId!,
//       ); // ✅ pass vehicleId
//     } else {
//       debugPrint("Unknown document type: $type");
//     }
//   }

//   Future<void> _selectLicenseExpiryDate(BuildContext context) async {
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

//   InputDecoration borderedDecoration(String label) {
//     return InputDecoration(
//       labelText: label,
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//     );
//   }

//   Widget borderedDropdown<T>({
//     required String label,
//     required T? value,
//     required List<T> items,
//     required void Function(T?) onChanged,
//     required String? Function(T?) validator,
//   }) {
//     return DropdownButtonFormField<T>(
//       decoration: borderedDecoration(label),
//       value: value,
//       hint: Text(label),
//       onChanged: onChanged,
//       validator: validator,
//       items:
//           items.map((item) {
//             return DropdownMenuItem<T>(
//               value: item,
//               child: Text(item.toString()),
//             );
//           }).toList(),
//     );
//   }

//   String? phoneValidator(String? val) {
//     if (val == null || val.isEmpty) return 'Required';
//     final regex = RegExp(r'^(?:0|\+254)?7\d{8}$');
//     if (!regex.hasMatch(val)) return 'Enter a valid phone number';
//     return null;
//   }

//   String? licenseExpiryValidator(String? val) {
//     if (val == null || val.isEmpty) return 'Required';
//     try {
//       final date = DateTime.parse(val);
//       if (date.isBefore(DateTime.now()))
//         return 'Expiry date must be in the future';
//     } catch (e) {
//       return 'Enter a valid date (YYYY-MM-DD)';
//     }
//     return null;
//   }

//   @override
//   void dispose() {
//     _idNumberController.dispose();
//     _paymentMobileController.dispose();
//     _referralCodeController.dispose();
//     _licenseExpiryController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Driver Onboarding"),
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black,
//         // title: const Text("Driver Onboarding"),
//         // // backgroundColor: Colors.blue,
//         // iconTheme: IconThemeData(color: Colors.grey[700]),
//         // titleTextStyle: TextStyle(color: Colors.grey[700], fontSize: 20),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 /// -----------------------------
//                 /// 🚘 DRIVER DETAILS SECTION
//                 /// -----------------------------
//                 if (showDriverSection) ...[
//                   Text(
//                     "Driver Details",
//                     style: Theme.of(context).textTheme.headlineSmall,
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: _idNumberController,
//                     decoration: borderedDecoration("ID Number"),
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: _paymentMobileController,
//                     decoration: borderedDecoration("Payment Mobile"),
//                     keyboardType: TextInputType.phone,
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: _referralCodeController,
//                     decoration: borderedDecoration("Referral Code"),
//                   ),
//                   const SizedBox(height: 12),

//                   // TextFormField(
//                   //   controller: _licenseExpiryController,
//                   //   decoration: borderedDecoration("License Expiry"),
//                   //   onTap: _selectLicenseExpiryDate(context),
//                   //   readOnly: true,
//                   // ),
//                   TextFormField(
//                     controller: _licenseExpiryController,
//                     decoration: borderedDecoration("License Expiry"),
//                     readOnly: true,
//                     onTap: () => _selectLicenseExpiryDate(context),
//                   ),

//                   const SizedBox(height: 24),
//                 ],

//                 /// -----------------------------
//                 /// 🚗 VEHICLE DETAILS SECTION
//                 /// -----------------------------
//                 ///
//                 if (showVehicleSection) ...[
//                   Text(
//                     "Vehicle Details",
//                     style: Theme.of(context).textTheme.headlineSmall,
//                   ),
//                   const SizedBox(height: 12),

//                   DropdownButtonFormField<int>(
//                     decoration: borderedDecoration('Vehicle Make'),
//                     value: selectedMakeId,
//                     items:
//                         vehicleMakes.map((make) {
//                           return DropdownMenuItem<int>(
//                             value: make['id'],
//                             child: Text(make['name']),
//                           );
//                         }).toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         selectedMakeId = value;
//                         selectedModelId = null;
//                       });
//                       final selectedMake = vehicleMakes.firstWhere(
//                         (m) => m['id'] == value,
//                       );
//                       fetchVehicleModels(selectedMake['name']);
//                     },
//                   ),
//                   const SizedBox(height: 12),

//                   DropdownButtonFormField<int>(
//                     decoration: borderedDecoration('Vehicle Model'),
//                     value: selectedModelId,
//                     items:
//                         vehicleModels.map((model) {
//                           return DropdownMenuItem<int>(
//                             value: model['id'],
//                             child: Text(model['name']),
//                           );
//                         }).toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         selectedModelId = value;
//                       });
//                     },
//                   ),
//                   const SizedBox(height: 12),

//                   // DropdownButtonFormField<int>(
//                   //   decoration: borderedDecoration('Vehicle Category'),
//                   //   value: selectedCategoryId,
//                   //   items:
//                   //       vehicleCategories.map((cat) {
//                   //         return DropdownMenuItem<int>(
//                   //           value: cat['id'],
//                   //           child: Text(cat['name']),
//                   //         );
//                   //       }).toList(),
//                   //   onChanged: (value) {
//                   //     setState(() {
//                   //       selectedCategoryId = value;
//                   //     });
//                   //   },
//                   // ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: regController,
//                     decoration: borderedDecoration("Vehicle Registration"),
//                   ),
//                   const SizedBox(height: 12),

//                   TextFormField(
//                     controller: yearController,
//                     decoration: borderedDecoration("Year of Manufacture"),
//                     keyboardType: TextInputType.number,
//                   ),

//                   const SizedBox(height: 24),
//                 ],
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.grey[700],
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 18),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                   // onPressed: () async {
//                   //   if (_formKey.currentState!.validate()) {
//                   //     await submitToBackend();
//                   //     await submitVehicle();
//                   //     // if (context.mounted) {
//                   //     //   GoRouter.of(context).goNamed(Routes().navigationScreen);
//                   //     // }
//                   //   }
//                   // },
//                   onPressed: ()
//                   // _areAllRequiredDocumentsUploaded()
//                   //? ()
//                   async {
//                     if (_formKey.currentState!.validate()) {
//                       await submitToBackend();
//                       await submitVehicle();
//                       // context.goNamed(Routes().navigationScreen); // if needed
//                     }
//                   },
//                   // : null, // disables the button
//                   child: const Center(
//                     child: Text(
//                       "Submit your details",
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),

//                 /// -----------------------------
//                 /// 📄 DOCUMENTS SECTION
//                 /// -----------------------------
//                 Text(
//                   "Upload Required Documents",
//                   style: Theme.of(context).textTheme.headlineSmall,
//                 ),
//                 const SizedBox(height: 12),

//                 // if (showDriverSection) ...[
//                 //   const Text(
//                 //     "Driver Documents",
//                 //     style: TextStyle(fontWeight: FontWeight.bold),
//                 //   ),
//                 //   const SizedBox(height: 8),
//                 //   ..._driverDocuments.entries.map((entry) {
//                 //     final type = entry.key;
//                 //     final doc = entry.value;
//                 //     final label = _docLabels[type] ?? type.name;
//                 //     final file = doc['file'] as File?;
//                 //     final url = doc['url'];

//                 //     final String? fullUrl =
//                 //         url != null && !url.startsWith('http')
//                 //             ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
//                 //             : url;

//                 //     return Column(
//                 //       crossAxisAlignment: CrossAxisAlignment.start,
//                 //       children: [
//                 //         BorderedUploadButton(
//                 //           label: label,
//                 //           isUploaded: file != null || fullUrl != null,
//                 //           status: doc['status'],
//                 //           onPressed: () => _pickFile(type),
//                 //           onPreview: () {
//                 //             if (file != null) {
//                 //               Navigator.push(
//                 //                 context,
//                 //                 MaterialPageRoute(
//                 //                   builder: (_) => PreviewScreen(file: file),
//                 //                 ),
//                 //               );
//                 //             } else if (fullUrl != null) {
//                 //               Navigator.push(
//                 //                 context,
//                 //                 MaterialPageRoute(
//                 //                   builder: (_) => PreviewScreen(url: fullUrl),
//                 //                 ),
//                 //               );
//                 //             }
//                 //           },
//                 //           onRemove: () async {
//                 //             await deleteDocumentFromBackend(type);
//                 //             setState(() {
//                 //               _driverDocuments[type]!['file'] = null;
//                 //               _driverDocuments[type]!['url'] = null;
//                 //               _driverDocuments[type]!['status'] = null;
//                 //             });
//                 //           },
//                 //         ),
//                 //         const SizedBox(height: 10),
//                 //       ],
//                 //     );
//                 //   }),
//                 // ],
//                 if (showDriverSection) ...[
//                   const Text(
//                     "Driver Documents",
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   ..._driverDocuments.entries.map((entry) {
//                     final type = entry.key;
//                     final doc = entry.value;
//                     final label =
//                         doc['label'] ?? type.toString(); // 👈 use API label
//                     final file = doc['file'] as File?;
//                     final url = doc['url'];

//                     final String? fullUrl =
//                         url != null && !url.startsWith('http')
//                             ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
//                             : url;

//                     return Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         BorderedUploadButton(
//                           label: label,
//                           isUploaded: file != null || fullUrl != null,
//                           status: doc['status'].toString(),
//                           onPressed: () => _pickFile(type),
//                           onPreview: () {
//                             if (file != null) {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => PreviewScreen(file: file),
//                                 ),
//                               );
//                             } else if (fullUrl != null) {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => PreviewScreen(url: fullUrl),
//                                 ),
//                               );
//                             }
//                           },
//                           onRemove: () async {
//                             await deleteDocumentFromBackend(type);
//                             setState(() {
//                               _driverDocuments[type]!['file'] = null;
//                               _driverDocuments[type]!['url'] = null;
//                               _driverDocuments[type]!['status'] = null;
//                             });
//                           },
//                         ),
//                         const SizedBox(height: 10),
//                       ],
//                     );
//                   }),
//                 ],

//                 if (showDriverSection) ...[
//                   const Text(
//                     "Vehicle Documents",
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   ..._vehicleDocuments.entries.map((entry) {
//                     final type = entry.key;
//                     final doc = entry.value;
//                     final label =
//                         doc['label'] ?? type.toString(); // 👈 use API label
//                     final file = doc['file'] as File?;
//                     final url = doc['url'];

//                     final String? fullUrl =
//                         url != null && !url.startsWith('http')
//                             ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
//                             : url;

//                     return Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         BorderedUploadButton(
//                           label: label,
//                           isUploaded: file != null || fullUrl != null,
//                           status: doc['status'],
//                           onPressed: () => _pickFile(type),
//                           onPreview: () {
//                             if (file != null) {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => PreviewScreen(file: file),
//                                 ),
//                               );
//                             } else if (fullUrl != null) {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (_) => PreviewScreen(url: fullUrl),
//                                 ),
//                               );
//                             }
//                           },
//                           onRemove: () async {
//                             await deleteDocumentFromBackend(type);
//                             setState(() {
//                               _driverDocuments[type]!['file'] = null;
//                               _driverDocuments[type]!['url'] = null;
//                               _driverDocuments[type]!['status'] = null;
//                             });
//                           },
//                         ),
//                         const SizedBox(height: 10),
//                       ],
//                     );
//                   }),
//                 ],

//                 // if (showVehicleSection) ...[
//                 //   const Text(
//                 //     "Vehicle Documents",
//                 //     style: TextStyle(fontWeight: FontWeight.bold),
//                 //   ),
//                 //   const SizedBox(height: 8),
//                 //   ..._vehicleDocuments.entries.map((entry) {
//                 //     final type = entry.key;
//                 //     final doc = entry.value;
//                 //     final label = _docLabels[type] ?? type.name;
//                 //     final file = doc['file'] as File?;
//                 //     final url = doc['url'];

//                 //     final String? fullUrl =
//                 //         url != null && !url.startsWith('http')
//                 //             ? '$baseUrldoc${url.startsWith('/') ? url : '/$url'}'
//                 //             : url;

//                 //     return Column(
//                 //       crossAxisAlignment: CrossAxisAlignment.start,
//                 //       children: [
//                 //         BorderedUploadButton(
//                 //           label: label,
//                 //           isUploaded: file != null || fullUrl != null,
//                 //           status: doc['status'],
//                 //           onPressed: () => _pickFile(type),
//                 //           onPreview: () {
//                 //             if (file != null) {
//                 //               Navigator.push(
//                 //                 context,
//                 //                 MaterialPageRoute(
//                 //                   builder: (_) => PreviewScreen(file: file),
//                 //                 ),
//                 //               );
//                 //             } else if (fullUrl != null) {
//                 //               Navigator.push(
//                 //                 context,
//                 //                 MaterialPageRoute(
//                 //                   builder: (_) => PreviewScreen(url: fullUrl),
//                 //                 ),
//                 //               );
//                 //             }
//                 //           },
//                 //           onRemove: () async {
//                 //             await deleteVehicleDocumentFromBackend(type);
//                 //             setState(() {
//                 //               _vehicleDocuments[type]!['file'] = null;
//                 //               _vehicleDocuments[type]!['url'] = null;
//                 //               _vehicleDocuments[type]!['status'] = null;
//                 //             });
//                 //           },
//                 //         ),
//                 //         const SizedBox(height: 10),
//                 //       ],
//                 //     );
//                 //   }),
//                 // ],
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Reusable yellow-bordered text field
// class BorderedTextFormField extends StatelessWidget {
//   final String label;
//   final TextEditingController controller;
//   final String? Function(String?)? validator;

//   const BorderedTextFormField({
//     super.key,
//     required this.label,
//     required this.controller,
//     this.validator,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         border: Border.all(width: 2), //color: Colors.blue,
//         borderRadius: BorderRadius.circular(8),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       child: TextFormField(
//         controller: controller,
//         decoration: InputDecoration(labelText: label, border: InputBorder.none),
//         validator: validator,
//       ),
//     );
//   }
// }

// class BorderedUploadButton extends StatelessWidget {
//   final String label;
//   final bool isUploaded;
//   final String? status;
//   final VoidCallback onPressed;
//   final VoidCallback? onPreview;
//   final Future<void> Function()? onRemove;

//   const BorderedUploadButton({
//     super.key,
//     required this.label,
//     required this.isUploaded,
//     required this.onPressed,
//     this.status,
//     this.onPreview,
//     this.onRemove,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       //onLongPress: isUploaded ? onRemove : null, // Long press to remove
//       onLongPress:
//           isUploaded
//               ? () async {
//                 final confirmed = await showDialog(
//                   context: context,
//                   builder:
//                       (ctx) => AlertDialog(
//                         title: const Text("Delete Document?"),
//                         content: const Text(
//                           "Are you sure you want to delete this document?",
//                         ),
//                         actions: [
//                           TextButton(
//                             onPressed: () => Navigator.pop(ctx, false),
//                             child: const Text("Cancel"),
//                           ),
//                           TextButton(
//                             onPressed: () => Navigator.pop(ctx, true),
//                             child: const Text("Delete"),
//                           ),
//                         ],
//                       ),
//                 );

//                 // if (confirmed == true && onRemove != null) {
//                 //   await onRemove();
//                 // }

//                 if (confirmed == true) {
//                   await onRemove?.call(); // ✅ Safe null-aware function call
//                 }
//               }
//               : null,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         decoration: BoxDecoration(
//           color: Colors.grey[700],
//           border: Border.all(color: Colors.grey, width: 2),
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: ListTile(
//           onTap: isUploaded ? onPreview ?? onPressed : onPressed,
//           title: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Text(label, style: const TextStyle(color: Colors.white)),
//               ),
//               if (status != null) _buildStatusChip(status!),
//             ],
//           ),
//           trailing: Icon(
//             isUploaded ? Icons.check_circle : Icons.upload_file,
//             color: isUploaded ? Colors.greenAccent : Colors.white,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusChip(String status) {
//     final normalized = status.toLowerCase().replaceAll(' ', '');

//     late final String label;
//     late final Color color;

//     switch (normalized) {
//       case 'approved':
//         label = 'Approved';
//         color = Colors.green;
//         break;
//       case 'rejected':
//         label = 'Rejected';
//         color = Colors.redAccent;
//         break;
//       case 'underreview':
//       default:
//         label = 'Under Review';
//         color = Colors.orange;
//         break;
//     }

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.9),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Text(
//         label,
//         style: const TextStyle(color: Colors.white, fontSize: 11),
//       ),
//     );
//   }
// }

// // String _docLabel(DocumentType type) {
// //   switch (type) {
// //     case DocumentType.profilePic:
// //       return 'Upload Profile Picture';
// //     case DocumentType.idFront:
// //       return 'Upload ID Front';
// //     case DocumentType.idBack:
// //       return 'Upload ID Back';
// //     case DocumentType.drivingLicense:
// //       return 'Upload Driving License';
// //     case DocumentType.policeClearance:
// //       return 'Upload Police Clearance';
// //     case DocumentType.psvBadge:
// //       return 'Upload PSV Badge';
// //     default:
// //       return type.name; // for vehicle docs or fallback
// //   }
// // }

// // class LicenseExpiryPicker extends StatefulWidget {
// //   @override
// //   _LicenseExpiryPickerState createState() => _LicenseExpiryPickerState();
// // }

// // class _LicenseExpiryPickerState extends State<LicenseExpiryPicker> {
// //   final TextEditingController _licenseExpiryController = TextEditingController();
// //   DateTime? _licenseExpiryDate;

// //   Future<void> _selectDate(BuildContext context) async {
// //     final DateTime? picked = await showDatePicker(
// //       context: context,
// //       initialDate: _licenseExpiryDate ?? DateTime.now(),
// //       firstDate: DateTime.now(),
// //       lastDate: DateTime(2100),
// //     );
// //     if (picked != null) {
// //       setState(() {
// //         _licenseExpiryDate = picked;
// //         _licenseExpiryController.text = DateFormat('yyyy-MM-dd').format(picked);
// //       });
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return TextFormField(
// //       controller: _licenseExpiryController,
// //       readOnly: true,
// //       decoration: InputDecoration(
// //         labelText: 'License Expiry Date',
// //         suffixIcon: Icon(Icons.calendar_today),
// //       ),
// //       onTap: () => _selectDate(context),
// //     );
// //   }
// // }
//   // Future<void> uploadDocumentToBackend(DocumentType type, File file) async {
//   //   final user = FirebaseAuth.instance.currentUser;
//   //   final idToken = await user?.getIdToken();

//   //   // Upload to Firebase Storage
//   //   final extension = path.extension(file.path); // e.g., .jpg, .pdf, .docx

//   //   final storageRef = FirebaseStorage.instance.ref().child(
//   //     'documents/${user!.uid}/${type.name}_${DateTime.now().millisecondsSinceEpoch}$extension',
//   //   );

//   //   final uploadTask = storageRef.putFile(file); // do not await here
//   //   final snapshot = await uploadTask.whenComplete(
//   //     () => null,
//   //   ); // wait for upload to finish
//   //   final downloadUrl = await snapshot.ref.getDownloadURL(); // THEN get the URL
//   //   // final uploadTask = await storageRef.putFile(file);
//   //   // final downloadUrl = await storageRef.getDownloadURL();

//   //   // Send metadata to backend
//   //   final response = await http.post(
//   //     Uri.parse('$baseUrl/documents/upload'),
//   //     headers: {'Content-Type': 'application/json'},
//   //     body: jsonEncode({
//   //       'token': idToken,
//   //       'documentType': type.name, // Make sure enum matches backend type
//   //       'filePath': downloadUrl,
//   //     }),
//   //   );

//   //   if (response.statusCode == 200) {
//   //     print('Document metadata saved!');
//   //   } else {
//   //     print('Failed: ${response.statusCode}');
//   //   }
//   // }

//   // Future<void> uploadDocumentToBackend(DocumentType type, File file) async {
//   //   final user = FirebaseAuth.instance.currentUser;
//   //   final idToken = await user?.getIdToken();

//   //   if (user == null) {
//   //     print("❌ User is null");
//   //     return;
//   //   }

//   //   if (!file.existsSync()) {
//   //     print("❌ File does not exist at ${file.path}");
//   //     return;
//   //   }

//   //   try {
//   //     final extension = path.extension(file.path); // .jpg, .pdf, etc.
//   //     final fileName =
//   //         '${type.name}_${DateTime.now().millisecondsSinceEpoch}$extension';

//   //     final storageRef = FirebaseStorage.instance.ref().child(
//   //       'documents/${user.uid}/$fileName',
//   //     );

//   //     print("📤 Uploading to Firebase Storage: ${storageRef.fullPath}");

//   //     // Upload
//   //     final uploadTask = storageRef.putFile(file);

//   //     final snapshot = await uploadTask.whenComplete(() => null);

//   //     // Check if upload failed
//   //     if (snapshot.state != TaskState.success) {
//   //       print("❌ Upload failed. State: ${snapshot.state}");
//   //       return;
//   //     }

//   //     final downloadUrl = await snapshot.ref.getDownloadURL();

//   //     // Send metadata to backend
//   //     final response = await http.post(
//   //       Uri.parse('$baseUrl/documents/upload'),
//   //       headers: {'Content-Type': 'application/json'},
//   //       body: jsonEncode({
//   //         'token': idToken,
//   //         'documentType': type.name,
//   //         'filePath': downloadUrl,
//   //       }),
//   //     );

//   //     if (response.statusCode == 200) {
//   //       print("✅ Document metadata saved to backend!");
//   //     } else {
//   //       print("❌ Failed to save metadata: ${response.statusCode}");
//   //     }
//   //   } on FirebaseException catch (e) {
//   //     print("🔥 FirebaseException: ${e.code} - ${e.message}");
//   //   } catch (e) {
//   //     print("🔥 Unexpected error: $e");
//   //   }
//   // }
