import 'dart:convert';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddVehicleDriverCategoryScreen extends StatefulWidget {
  final int vehicleId;
  final int? vehicleCategoryId;

  const AddVehicleDriverCategoryScreen({
    super.key,
    required this.vehicleId,
    this.vehicleCategoryId,
  });

  @override
  State<AddVehicleDriverCategoryScreen> createState() =>
      _AddVehicleDriverCategoryScreenState();
}

class _AddVehicleDriverCategoryScreenState
    extends State<AddVehicleDriverCategoryScreen> {
  List<Map<String, dynamic>> subCategories = [];
  int? selectedSubCategoryId;
  bool isLoading = false;
  String? firebaseId;

  @override
  void initState() {
    super.initState();
    _setFirebaseIdAndLoad();
  }

  Future<void> _setFirebaseIdAndLoad() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      firebaseId = user.uid;
      await fetchSubCategories();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
    }
  }

  Future<void> fetchSubCategories() async {
    setState(() => isLoading = true);

    final response = await http.get(
      Uri.parse(
        "$baseUrl/vehicles/get/subcategories/${widget.vehicleCategoryId}",
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        subCategories =
            data
                .map<Map<String, dynamic>>(
                  (item) => {'id': item['id'], 'name': item['name']},
                )
                .toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load subcategories")),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> submitCategory() async {
    if (selectedSubCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a subcategory")),
      );
      return;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/vehicles/add/drivervehiclecategory"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "firebaseId": firebaseId,
        "vehicleId": widget.vehicleId,
        "vehicleCategoryId": widget.vehicleCategoryId,
        "vehicleSubCategoryId": selectedSubCategoryId,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Category added successfully")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Vehicle Category")),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select Vehicle SubCategory:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: const TextTheme(
                          titleMedium: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        canvasColor: Colors.white, // dropdown background
                      ),
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: selectedSubCategoryId,
                        decoration: InputDecoration(
                          hintText: "Select subcategory",
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 2,
                            ),
                          ),
                        ),
                        items:
                            subCategories
                                .map(
                                  (sub) => DropdownMenuItem<int>(
                                    value: sub['id'],
                                    child: Text(
                                      sub['name'],
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() => selectedSubCategoryId = value);
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // black button
                          foregroundColor: Colors.white, // white text
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          "Submit",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

// import 'dart:convert';
// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/vehicle_category.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class AddVehicleDriverCategoryScreen extends StatefulWidget {
//   final int vehicleId;
//   final int? vehicleCategoryId;

//   const AddVehicleDriverCategoryScreen({
//     super.key,

//     required this.vehicleId,
//     this.vehicleCategoryId,
//   });

//   @override
//   State<AddVehicleDriverCategoryScreen> createState() =>
//       _AddVehicleDriverCategoryScreenState();
// }

// class _AddVehicleDriverCategoryScreenState
//     extends State<AddVehicleDriverCategoryScreen> {
//   List<Map<String, dynamic>> subCategories = [];
//   int? selectedSubCategoryId;
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();

//     _setFirebaseIdAndLoad();
//     fetchSubCategories();
//   }

//   String? firebaseId;

//   Future<void> _setFirebaseIdAndLoad() async {
//     final User? user = FirebaseAuth.instance.currentUser;

//     if (user != null) {
//       firebaseId = user.uid;
//       print("✅ Firebase UID: $firebaseId");
//       await fetchSubCategories();
//     } else {
//       print("❌ User not logged in.");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("User not logged in")));
//     }
//   }

//   Future<void> fetchSubCategories() async {
//     setState(() {
//       isLoading = true;
//     });

//     final response = await http.get(
//       Uri.parse(
//         "$baseUrl/vehicles/get/subcategories/${widget.vehicleCategoryId}",
//       ), // 🔁 Replace with your actual endpoint
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> data = jsonDecode(response.body);
//       setState(() {
//         subCategories =
//             data
//                 .map<Map<String, dynamic>>(
//                   (item) => {'id': item['id'], 'name': item['name']},
//                 )
//                 .toList();
//       });
//       //Navigator.pop(context, true);
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Failed to load subcategories")));
//     }

//     setState(() {
//       isLoading = false;
//     });
//   }

//   Future<void> submitCategory() async {
//     if (selectedSubCategoryId == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Please select a subcategory")));
//       return;
//     }

//     final response = await http.post(
//       Uri.parse(
//         "$baseUrl/vehicles/add/drivervehiclecategory",
//       ), // 🔁 Replace with your endpoint
//       headers: {"Content-Type": "application/json"},
//       body: jsonEncode({
//         "firebaseId": firebaseId,
//         "vehicleId": widget.vehicleId,
//         "vehicleCategoryId": widget.vehicleCategoryId,
//         "vehicleSubCategoryId": selectedSubCategoryId,
//       }),
//     );

//     if (response.statusCode == 201 || response.statusCode == 200) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Category added successfully")));
//       Navigator.pop(context); // go back to previous screen
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Failed to submit: ${response.body}")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Add Vehicle Category")),
//       body:
//           isLoading
//               ? Center(child: CircularProgressIndicator())
//               : Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "Select Vehicle SubCategory:",
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 8),
//                     DropdownButtonFormField<int>(
//                       isExpanded: true,
//                       value: selectedSubCategoryId,
//                       decoration: InputDecoration(border: OutlineInputBorder()),
//                       items:
//                           subCategories.map((sub) {
//                             return DropdownMenuItem<int>(
//                               value: sub['id'],
//                               child: Text(sub['name']),
//                             );
//                           }).toList(),
//                       onChanged: (value) {
//                         setState(() {
//                           selectedSubCategoryId = value;
//                         });
//                       },
//                       hint: Text("Select subcategory"),
//                     ),
//                     SizedBox(height: 20),
//                     ElevatedButton(
//                       onPressed: submitCategory,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.grey[800],
//                         foregroundColor: Colors.white,
//                       ),
//                       child: Text("Submit"),
//                     ),
//                   ],
//                 ),
//               ),
//     );
//   }
// }
