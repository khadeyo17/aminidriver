import 'dart:convert';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/assign_driver.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/Onboarding/vehicle_addition_screen.dart';
import 'package:aminidriver/Onboarding/vehicle_category.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/add_driver_vehicle_category.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DriverVehiclesScreen extends StatefulWidget {
  const DriverVehiclesScreen({super.key});

  @override
  State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
}

class _DriverVehiclesScreenState extends State<DriverVehiclesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> approvedVehicles = [];
  List<Map<String, dynamic>> unapprovedVehicles = [];
  List<Map<String, dynamic>> allVehicles = [];
  String role = "";
  Set<int> expandedCardIds = {};
  //VehicleCategory? category;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchVehicles();
  }

  Future<void> fetchVehicles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/my-vehicles'),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List ownedData = data['ownedVehicles'] ?? [];
        final List drivenData = data['drivenVehicles'] ?? [];
        final String fetchedRole = data['role'] ?? '';

        final allFetched = [
          ...ownedData.map((v) => Map<String, dynamic>.from(v)),
          ...drivenData.map((v) => Map<String, dynamic>.from(v)),
        ];

        setState(() {
          allVehicles = allFetched;
          role = fetchedRole;
          approvedVehicles =
              allFetched.where((v) => v['isApproved'] == true).toList();
          unapprovedVehicles =
              allFetched.where((v) => v['isApproved'] == false).toList();
        });
      } else {
        throw Exception("Failed to fetch vehicles: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching vehicles: $e");
    }
  }

  Future<void> deleteSubCategory(int vehicleId, int subCategoryId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles/delete/drivervehiclecategory'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vehicleId": vehicleId,
          "subCategory": subCategoryId,
        }),
      );

      if (response.statusCode == 200) {
        fetchVehicles(); // only refresh that vehicle list
      } else {
        throw Exception('Failed to delete subcategory');
      }
    } catch (e) {
      debugPrint("Error deleting subcategory: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting subcategory: $e")));
    }
  }

  void assignDriver(int vehicleId, int category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                AssignDriverScreen(vehicleId: vehicleId, Category: category),
      ),
    ).then((result) {
      if (result == true) fetchVehicles();
    });
  }

  void removeDriver(int vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Remove Driver"),
            content: const Text("Are you sure you want to remove this driver?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Remove"),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final response = await http.post(
        Uri.parse("$baseUrl/vehicles/remove-driver"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'vehicleId': vehicleId}),
      );

      if (response.statusCode == 200) {
        showSnack("Driver removed successfully");
        fetchVehicles();
      } else {
        showSnack("Failed: ${response.body}", isError: true);
      }
    }
  }

  void showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // void goToAddVehicle() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder:
  //           (_) => DriverOnboardingScreen(
  //             role: UserRole.owner,
  //             vehicleId: null, // ✅ New vehicle, no ID yet
  //           ),
  //     ),
  //   ).then((_) => fetchVehicles());
  // }
  void goToAddVehicle() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => VehicleScreen(
              role: UserRole.owner,
              vehicleId: null, // ✅ New vehicle, no ID yet
            ),
      ),
    ).then((_) => fetchVehicles());
  }

  Widget buildVehicleList(List<Map<String, dynamic>> vehicleList) {
    if (vehicleList.isEmpty) {
      return const Center(child: Text("No vehicles found"));
    }

    return ListView.builder(
      itemCount: vehicleList.length,
      itemBuilder: (context, index) {
        final v = vehicleList[index];
        final vehicleId = v['id'];
        final isExpanded = expandedCardIds.contains(vehicleId);
        final categoryIndex = v['category'] ?? -1;
        //category = v['category'] ?? -1;
        final categoryName =
            parseVehicleCategory(categoryIndex)?.displayName ?? 'Unknown';
        final isAssigned = v['driverId'] != null;
        final bool isOwner = role == "owner" || role == "ownerdriver";
        final bool isApproved = v['isApproved'] == true;

        return GestureDetector(
          onTap: () {
            // ✅ Only unapproved vehicles should be tappable
            if (!isApproved) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => VehicleScreen(
                        role: UserRole.owner,
                        vehicleId: vehicleId, // ✅ Open for edit
                      ),
                ),
              ).then((_) => fetchVehicles());
            }
          },
          child: Card(
            margin: const EdgeInsets.all(10),
            elevation: 4,
            color:
                isApproved
                    ? Colors.blue[100]
                    : Colors.orange[50], // Optional visual cue
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Class: $categoryName",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      "${v['vehicleMake'] ?? 'Unknown'} ${v['vehicleModel'] ?? ''}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      "Reg: ${v['registrationNumber']} | Year: ${v['year']}",
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () {
                        setState(() {
                          if (isExpanded) {
                            expandedCardIds.remove(vehicleId);
                          } else {
                            expandedCardIds.add(vehicleId);
                          }
                        });
                      },
                    ),
                  ),
                  if (isExpanded) ...[
                    const Divider(),
                    const Text(
                      "Categories",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          // Filter subcategories by vehicleId
                          ((v['subCategories'] as List<dynamic>? ?? [])
                              .where(
                                (cat) => cat['vehicleId'] == vehicleId,
                              ) // ✅ Only this vehicle
                              .map((cat) {
                                final int subCategoryId = cat['id'];
                                final String subCategoryName = cat['name'];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text("- $subCategoryName"),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () async {
                                          final confirmed = await showDialog<
                                            bool
                                          >(
                                            context: context,
                                            builder:
                                                (context) => AlertDialog(
                                                  title: const Text(
                                                    "Confirm Delete",
                                                  ),
                                                  content: Text(
                                                    "Delete '$subCategoryName' from this vehicle?",
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        "Cancel",
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        "Delete",
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );

                                          if (confirmed == true) {
                                            await deleteSubCategory(
                                              vehicleId,
                                              subCategoryId,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList()),
                    ),
                    const SizedBox(height: 8),

                    if (isExpanded && isApproved) ...[
                      // SizedBox(
                      //   width: double.infinity,
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Color(
                      //       0xFF1E88E5,
                      //     ), // Example color (Blue)
                      //     foregroundColor: Colors.white, // Text and icon color
                      //     padding: const EdgeInsets.symmetric(vertical: 14),
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(12),
                      //     ),
                      //   ),
                      //   child: ElevatedButton.icon(
                      //     // backgoundcolour:Color(value)
                      //     icon: const Icon(Icons.add),
                      //     label: const Text("Add Category"),

                      //     onPressed: () {
                      //       Navigator.push(
                      //         context,
                      //         MaterialPageRoute(
                      //           builder:
                      //               (_) => AddVehicleDriverCategoryScreen(
                      //                 vehicleId: vehicleId,
                      //                 vehicleCategoryId: categoryIndex,
                      //               ),
                      //         ),
                      //       ).then((_) => fetchVehicles());
                      //     },
                      //   ),
                      // ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            //backgroundColor: createTicker(ol) // Example color (Blue)
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.grey[700], // Text and icon color
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            "Add Category",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => AddVehicleDriverCategoryScreen(
                                      vehicleId: vehicleId,
                                      vehicleCategoryId: categoryIndex,
                                    ),
                              ),
                            ).then((_) => fetchVehicles());
                          },
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  // if (isExpanded) ...[
                  //   const Divider(),
                  //   const Text(
                  //     "Categories",
                  //     style: TextStyle(
                  //       fontSize: 16,
                  //       fontWeight: FontWeight.bold,
                  //     ),
                  //   ),
                  //   const SizedBox(height: 8),
                  //   Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children:
                  //         (v['subCategories'] as List<dynamic>? ?? []).map((
                  //           cat,
                  //         ) {
                  //           final int subCategoryId = cat['id'];
                  //           final String subCategoryName = cat['name'];
                  //           return Padding(
                  //             padding: const EdgeInsets.only(bottom: 4.0),
                  //             child: Row(
                  //               mainAxisAlignment:
                  //                   MainAxisAlignment.spaceBetween,
                  //               children: [
                  //                 Expanded(child: Text("- $subCategoryName")),
                  //                 IconButton(
                  //                   icon: const Icon(
                  //                     Icons.delete,
                  //                     color: Colors.grey,
                  //                   ),
                  //                   onPressed: () async {
                  //                     final confirmed = await showDialog<bool>(
                  //                       context: context,
                  //                       builder:
                  //                           (context) => AlertDialog(
                  //                             title: const Text(
                  //                               "Confirm Delete",
                  //                             ),
                  //                             content: Text(
                  //                               "Delete '$subCategoryName' from this vehicle?",
                  //                             ),
                  //                             actions: [
                  //                               TextButton(
                  //                                 onPressed:
                  //                                     () => Navigator.pop(
                  //                                       context,
                  //                                       false,
                  //                                     ),
                  //                                 child: const Text("Cancel"),
                  //                               ),
                  //                               TextButton(
                  //                                 onPressed:
                  //                                     () => Navigator.pop(
                  //                                       context,
                  //                                       true,
                  //                                     ),
                  //                                 child: const Text(
                  //                                   "Delete",
                  //                                   style: TextStyle(
                  //                                     color: Colors.red,
                  //                                   ),
                  //                                 ),
                  //                               ),
                  //                             ],
                  //                           ),
                  //                     );
                  //                     if (confirmed == true) {
                  //                       await deleteSubCategory(
                  //                         vehicleId,
                  //                         subCategoryId,
                  //                       );
                  //                     }
                  //                   },
                  //                 ),
                  //               ],
                  //             ),
                  //           );
                  //         }).toList(),
                  //   ),
                  //   const SizedBox(height: 8),

                  //   // SizedBox(
                  //   //   width: double.infinity,
                  //   //   child: ElevatedButton.icon(
                  //   //     icon: const Icon(Icons.add),
                  //   //     label: const Text("Add Category"),
                  //   //     onPressed: () {
                  //   //       Navigator.push(
                  //   //         context,
                  //   //         MaterialPageRoute(
                  //   //           builder:
                  //   //               (_) => AddVehicleDriverCategoryScreen(
                  //   //                 vehicleId: vehicleId,
                  //   //                 vehicleCategoryId: categoryIndex,
                  //   //               ),
                  //   //         ),
                  //   //       ).then((_) => fetchVehicles());
                  //   //     },
                  //   //   ),
                  //   // ),
                  //   if (isExpanded && isApproved) ...[
                  //     SizedBox(
                  //       width: double.infinity,
                  //       child: ElevatedButton.icon(
                  //         icon: const Icon(Icons.add),
                  //         label: const Text("Add Category"),
                  //         onPressed: () {
                  //           Navigator.push(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder:
                  //                   (_) => AddVehicleDriverCategoryScreen(
                  //                     vehicleId: vehicleId,
                  //                     vehicleCategoryId: categoryIndex,
                  //                   ),
                  //             ),
                  //           ).then((_) => fetchVehicles());
                  //         },
                  //       ),
                  //     ),
                  //   ],
                  // ],
                  if (isOwner && isApproved) ...[
                    if (isAssigned) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "Driver: ${v['driverName'] ?? 'Unknown'}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                    // isAssigned
                    //     ? TextButton(
                    //       onPressed: () => removeDriver(vehicleId),
                    //       child: const Text("Remove Driver"),
                    //     )
                    //     : ElevatedButton(
                    //       onPressed: () => assignDriver(vehicleId),
                    //       child: const Text("Assign Driver"),
                    //     ),
                    SizedBox(
                      width: double.infinity,
                      child:
                          isAssigned
                              ? TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => removeDriver(vehicleId),
                                child: const Text(
                                  "Remove Driver",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                              : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed:
                                    () =>
                                        assignDriver(vehicleId, categoryIndex),
                                child: const Text(
                                  "Assign Driver",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                    ),
                  ],

                  // if (isOwner)
                  //   isAssigned
                  //       ? TextButton(
                  //         onPressed: () => removeDriver(vehicleId),
                  //         child: const Text("Remove Driver"),
                  //       )
                  //       : ElevatedButton(
                  //         onPressed: () => assignDriver(vehicleId),
                  //         child: const Text("Assign Driver"),
                  //       ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showTabs = role == "owner";
    final bool isOwner = role == "owner";

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Vehicles"),
        centerTitle: true,
        //backgroundColor: Colors.black,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom:
            showTabs
                ? TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: "Approved"), Tab(text: "Unapproved")],
                )
                : null,
      ),
      body:
          showTabs
              ? TabBarView(
                controller: _tabController,
                children: [
                  buildVehicleList(approvedVehicles),
                  buildVehicleList(unapprovedVehicles),
                ],
              )
              : buildVehicleList(allVehicles),

      // ✅ Show active Add (+) button only for owners
      floatingActionButton:
          isOwner
              ? FloatingActionButton(
                onPressed: goToAddVehicle,
                backgroundColor: Colors.green, // make it visibly active
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null, // Hide button completely for other roles
    );
  }
}

  // void goToAddVehicle() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => DriverOnboardingScreen(role: UserRole.owner,vehicleId: ,),
  //     ),
  //   );
  //   // GoRouter.of(context).goNamed(Routes().driverConfig);
  // }

  // Widget buildVehicleList(List<Map<String, dynamic>> vehicleList) {
  //   if (vehicleList.isEmpty) {
  //     return const Center(child: Text("No vehicles found"));
  //   }

  //   return ListView.builder(
  //     itemCount: vehicleList.length,
  //     itemBuilder: (context, index) {
  //       final v = vehicleList[index];
  //       final vehicleId = v['id'];
  //       final isExpanded = expandedCardIds.contains(vehicleId);
  //       final categoryIndex = v['category'] ?? -1;
  //       final categoryName =
  //           parseVehicleCategory(categoryIndex)?.displayName ?? 'Unknown';
  //       final isAssigned = v['driverId'] != null;
  //       final bool isOwner = role == "owner" || role == "ownerdriver";

  //       return Card(
  //         margin: const EdgeInsets.all(10),
  //         elevation: 4,
  //         child: Padding(
  //           padding: const EdgeInsets.all(12),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 "Class: $categoryName",
  //                 style: const TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               ListTile(
  //                 contentPadding: EdgeInsets.zero,
  //                 title: Text(
  //                   "${v['vehicleMake'] ?? 'Unknown'} ${v['vehicleModel'] ?? ''}",
  //                   style: const TextStyle(
  //                     fontWeight: FontWeight.bold,
  //                     fontSize: 18,
  //                   ),
  //                 ),
  //                 subtitle: Text(
  //                   "Reg: ${v['registrationNumber']} | Year: ${v['year']}",
  //                 ),
  //                 trailing: IconButton(
  //                   icon: Icon(
  //                     isExpanded ? Icons.expand_less : Icons.expand_more,
  //                   ),
  //                   onPressed: () {
  //                     setState(() {
  //                       if (isExpanded) {
  //                         expandedCardIds.remove(vehicleId);
  //                       } else {
  //                         expandedCardIds.add(vehicleId);
  //                       }
  //                     });
  //                   },
  //                 ),
  //               ),
  //               if (isExpanded) ...[
  //                 const Divider(),
  //                 const Text(
  //                   "Categories",
  //                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //                 ),
  //                 const SizedBox(height: 8),
  //                 Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children:
  //                       (v['subCategories'] as List<dynamic>? ?? []).map((cat) {
  //                         final int subCategoryId = cat['id'];
  //                         final String subCategoryName = cat['name'];
  //                         return Padding(
  //                           padding: const EdgeInsets.only(bottom: 4.0),
  //                           child: Row(
  //                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                             children: [
  //                               Expanded(child: Text("- $subCategoryName")),
  //                               IconButton(
  //                                 icon: const Icon(
  //                                   Icons.delete,
  //                                   color: Colors.grey,
  //                                 ),
  //                                 onPressed: () async {
  //                                   final confirmed = await showDialog<bool>(
  //                                     context: context,
  //                                     builder:
  //                                         (context) => AlertDialog(
  //                                           title: const Text("Confirm Delete"),
  //                                           content: Text(
  //                                             "Delete '$subCategoryName' from this vehicle?",
  //                                           ),
  //                                           actions: [
  //                                             TextButton(
  //                                               onPressed:
  //                                                   () => Navigator.pop(
  //                                                     context,
  //                                                     false,
  //                                                   ),
  //                                               child: const Text("Cancel"),
  //                                             ),
  //                                             TextButton(
  //                                               onPressed:
  //                                                   () => Navigator.pop(
  //                                                     context,
  //                                                     true,
  //                                                   ),
  //                                               child: const Text(
  //                                                 "Delete",
  //                                                 style: TextStyle(
  //                                                   color: Colors.red,
  //                                                 ),
  //                                               ),
  //                                             ),
  //                                           ],
  //                                         ),
  //                                   );
  //                                   if (confirmed == true) {
  //                                     await deleteSubCategory(
  //                                       vehicleId,
  //                                       subCategoryId,
  //                                     );
  //                                   }
  //                                 },
  //                               ),
  //                             ],
  //                           ),
  //                         );
  //                       }).toList(),
  //                 ),
  //                 const SizedBox(height: 8),
  //                 SizedBox(
  //                   width: double.infinity,
  //                   child: ElevatedButton.icon(
  //                     icon: const Icon(Icons.add),
  //                     label: const Text("Add Category"),
  //                     onPressed: () {
  //                       Navigator.push(
  //                         context,
  //                         MaterialPageRoute(
  //                           builder:
  //                               (_) => AddVehicleDriverCategoryScreen(
  //                                 vehicleId: vehicleId,
  //                                 vehicleCategoryId: categoryIndex,
  //                               ),
  //                         ),
  //                       ).then((_) => fetchVehicles());
  //                     },
  //                   ),
  //                 ),
  //               ],
  //               if (isOwner)
  //                 isAssigned
  //                     ? TextButton(
  //                       onPressed: () => removeDriver(vehicleId),
  //                       child: const Text("Remove Driver"),
  //                     )
  //                     : ElevatedButton(
  //                       onPressed: () => assignDriver(vehicleId),
  //                       child: const Text("Assign Driver"),
  //                     ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

//   @override
//   Widget build(BuildContext context) {
//     final bool showTabs = role == "owner";

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("My Vehicles"),
//         centerTitle: true,
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//         bottom:
//             showTabs
//                 ? TabBar(
//                   controller: _tabController,
//                   tabs: const [Tab(text: "Approved"), Tab(text: "Unapproved")],
//                 )
//                 : null,
//       ),
//       body:
//           showTabs
//               ? TabBarView(
//                 controller: _tabController,
//                 children: [
//                   buildVehicleList(approvedVehicles),
//                   buildVehicleList(unapprovedVehicles),
//                 ],
//               )
//               : buildVehicleList(allVehicles),
//       floatingActionButton: FloatingActionButton(
//         onPressed: goToAddVehicle,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
// import 'dart:convert';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/assign_driver.dart';
// import 'package:aminidriver/Onboarding/vehicle_category.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/add_driver_vehicle_category.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:http/http.dart' as http;

// class DriverVehiclesScreen extends StatefulWidget {
//   const DriverVehiclesScreen({super.key});

//   @override
//   State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
// }

// class _DriverVehiclesScreenState extends State<DriverVehiclesScreen> {
//   List<Map<String, dynamic>> vehicles = [];
//   String driverId = "";
//   String role = "";
//   //VehicleCategory? category;
//   Set<int> expandedCardIds = {}; // Track which cards are expanded

//   @override
//   void initState() {
//     super.initState();
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       driverId = user.uid;
//       fetchVehicles();
//     }
//   }

//   Future<void> deleteSubCategory(int vehicleId, int subCategoryId) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/vehicles/delete/drivervehiclecategory'),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "vehicleId": vehicleId,
//           "subCategory": subCategoryId,
//         }),
//       );

//       if (response.statusCode == 200) {
//         // Success
//       } else {
//         throw Exception('Failed to delete subcategory');
//       }
//     } catch (e) {
//       print("Error deleting subcategory: $e");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error deleting subcategory: $e")));
//     }
//   }

//   Future<void> fetchVehicles() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       final idToken = await user?.getIdToken();

//       final response = await http.get(
//         Uri.parse('$baseUrl/vehicles/my-vehicles'),
//         headers: {
//           "Authorization": "Bearer $idToken",
//           "Content-Type": "application/json",
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         final List ownedData = data['ownedVehicles'] ?? [];
//         final List drivenData = data['drivenVehicles'] ?? [];
//         final String fetchedRole = data['role'] ?? '';

//         setState(() {
//           vehicles = [
//             ...ownedData.map((v) => Map<String, dynamic>.from(v)),
//             ...drivenData.map((v) => Map<String, dynamic>.from(v)),
//           ];
//           role = fetchedRole;
//         });
//       } else {
//         throw Exception("Failed to fetch vehicles: ${response.body}");
//       }
//     } catch (e) {
//       print("Error fetching vehicles: $e");
//     }
//   }

//   void goToAddVehicle() {
//     GoRouter.of(context).goNamed(Routes().driverConfig);
//   }

//   // void assignDriver(int vehicleId) async {
//   //   final TextEditingController emailController = TextEditingController();

//   //   showDialog(
//   //     context: context,
//   //     builder:
//   //         (context) => AlertDialog(
//   //           title: const Text("Assign Driver"),
//   //           content: TextField(
//   //             controller: emailController,
//   //             decoration: const InputDecoration(
//   //               labelText: "Driver's Email",
//   //               prefixIcon: Icon(Icons.email),
//   //             ),
//   //           ),
//   //           actions: [
//   //             TextButton(
//   //               onPressed: () => Navigator.of(context).pop(),
//   //               child: const Text("Cancel"),
//   //             ),
//   //             ElevatedButton(
//   //               onPressed: () async {
//   //                 final email = emailController.text.trim();
//   //                 Navigator.of(context).pop();
//   //                 final response = await http.post(
//   //                   Uri.parse(
//   //                     "$baseUrl/driver-vehicles/assign-driver-by-email",
//   //                   ),
//   //                   headers: {'Content-Type': 'application/json'},
//   //                   body: jsonEncode({'email': email, 'vehicleId': vehicleId}),
//   //                 );
//   //                 if (response.statusCode == 200) {
//   //                   showSnack("Driver assigned successfully");
//   //                   fetchVehicles();
//   //                 } else {
//   //                   showSnack("Failed: ${response.body}", isError: true);
//   //                 }
//   //               },
//   //               child: const Text("Assign"),
//   //             ),
//   //           ],
//   //         ),
//   //   );
//   // }
//   void assignDriver(int vehicleId) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => AssignDriverScreen(vehicleId: vehicleId),
//       ),
//     ).then((result) {
//       if (result == true) {
//         fetchVehicles(); // Refresh list after returning from screen
//       }
//     });
//   }

//   void removeDriver(int vehicleId) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text("Remove Driver"),
//             content: const Text("Are you sure?"),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(false),
//                 child: const Text("Cancel"),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(true),
//                 child: Text(
//                   "Remove",
//                   style: TextStyle(color: Colors.grey[700]),
//                 ),
//               ),
//             ],
//           ),
//     );

//     if (confirm == true) {
//       final response = await http.post(
//         Uri.parse("$baseUrl/driver-vehicles/remove-driver"),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'vehicleId': vehicleId}),
//       );
//       if (response.statusCode == 200) {
//         showSnack("Driver removed successfully");
//         fetchVehicles();
//       } else {
//         showSnack("Failed: ${response.body}", isError: true);
//       }
//     }
//   }

//   void showSnack(String msg, {bool isError = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: isError ? Colors.red : Colors.green,
//       ),
//     );
//   }

//   bool get isOwnerOrOwnerDriver => role == "owner" || role == "ownerdriver";

//   List<String> getDummyCategories(int id) {
//     // You can replace this with a real call to backend per vehicle
//     return ['Insurance', 'Maintenance', 'Fuel', 'Permit'];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("My Vehicles"),
//         centerTitle: true,
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,

//         //title: const Text("My Vehicles"),
//         // actions: [
//         //   IconButton(icon: const Icon(Icons.add), onPressed: goToAddVehicle),
//         // ],
//       ),
//       body:
//           vehicles.isEmpty
//               ? const Center(child: Text("No vehicles found"))
//               : ListView.builder(
//                 itemCount: vehicles.length,
//                 itemBuilder: (context, index) {
//                   final v = vehicles[index];
//                   final vehicleId = v['id'];
//                   final isAssigned = v['driverId'] != null;
//                   final isExpanded = expandedCardIds.contains(vehicleId);

//                   final int indexx = v['category'] ?? -1;
//                   final category =
//                       parseVehicleCategory(indexx)?.displayName ?? 'Unknown';
//                   //category = v['category'] ?? 'Unknown';
//                   //final categoryName = v['categoryName'] ?? 'Unknown';

//                   return Card(
//                     margin: const EdgeInsets.all(10),
//                     elevation: 4,
//                     child: Padding(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Class: $category",
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.grey[700], // ✅ Updated color
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,

//                             title: Text(
//                               "${v['vehicleMake'] ?? 'Unknown'} ${v['vehicleModel'] ?? ''}",
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 18,
//                               ),
//                             ),
//                             subtitle: Text(
//                               "Reg: ${v['registrationNumber']} | Year: ${v['year']}",
//                             ),
//                             trailing: IconButton(
//                               icon: Icon(
//                                 isExpanded
//                                     ? Icons.expand_less
//                                     : Icons.expand_more,
//                               ),
//                               onPressed: () {
//                                 setState(() {
//                                   if (isExpanded) {
//                                     expandedCardIds.remove(vehicleId);
//                                   } else {
//                                     expandedCardIds.add(vehicleId);
//                                   }
//                                 });
//                               },
//                             ),
//                           ),
//                           if (isExpanded) ...[
//                             const Divider(),
//                             Text(
//                               "Categories",
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey[700],
//                               ),
//                             ),
//                             const SizedBox(height: 8),

//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children:
//                                   (v['subCategories'] as List<dynamic>? ?? []).map((
//                                     cat,
//                                   ) {
//                                     final int subCategoryId =
//                                         cat['id']; // ✅ extract ID
//                                     final String subCategoryName =
//                                         cat['name']; // for display

//                                     return Padding(
//                                       padding: const EdgeInsets.only(
//                                         bottom: 4.0,
//                                       ),
//                                       child: Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Expanded(
//                                             child: Text("- $subCategoryName"),
//                                           ),
//                                           IconButton(
//                                             icon: Icon(
//                                               Icons.delete,
//                                               color: Colors.grey[700],
//                                             ),
//                                             onPressed: () async {
//                                               final confirmed = await showDialog<
//                                                 bool
//                                               >(
//                                                 context: context,
//                                                 builder:
//                                                     (context) => AlertDialog(
//                                                       title: const Text(
//                                                         "Confirm Delete",
//                                                       ),
//                                                       content: Text(
//                                                         "Are you sure you want to remove '$subCategoryName'?",
//                                                       ),
//                                                       actions: [
//                                                         TextButton(
//                                                           onPressed:
//                                                               () =>
//                                                                   Navigator.pop(
//                                                                     context,
//                                                                     false,
//                                                                   ),
//                                                           child: const Text(
//                                                             "Cancel",
//                                                           ),
//                                                         ),
//                                                         TextButton(
//                                                           onPressed:
//                                                               () =>
//                                                                   Navigator.pop(
//                                                                     context,
//                                                                     true,
//                                                                   ),
//                                                           child: const Text(
//                                                             "Delete",
//                                                             style: TextStyle(
//                                                               color: Colors.red,
//                                                             ),
//                                                           ),
//                                                         ),
//                                                       ],
//                                                     ),
//                                               );

//                                               if (confirmed == true) {
//                                                 await deleteSubCategory(
//                                                   vehicleId,
//                                                   subCategoryId,
//                                                 ); // 🔁 pass only the ID
//                                                 fetchVehicles(); // refresh list
//                                               }
//                                             },
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   }).toList(),
//                             ),

//                             const SizedBox(height: 8),
//                             SizedBox(
//                               width: double.infinity, // ✅ Full width
//                               child: ElevatedButton.icon(
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor:
//                                       Colors.grey[700], // ✅ Grey background
//                                   foregroundColor:
//                                       Colors.white, // ✅ White text/icon
//                                 ),
//                                 onPressed: () async {
//                                   final user =
//                                       FirebaseAuth.instance.currentUser;
//                                   final int? categoryIndex = v['category'];

//                                   if (user != null && categoryIndex != null) {
//                                     final vehicleCategory =
//                                         parseVehicleCategory(categoryIndex);
//                                     //   final result = await Navigator.push(
//                                     //     context,
//                                     //     MaterialPageRoute(
//                                     //       builder:
//                                     //           (context) =>
//                                     //               AddVehicleDriverCategoryScreen(
//                                     //                 vehicleId: vehicleId,
//                                     //                 vehicleCategoryId:
//                                     //                     categoryIndex,
//                                     //               ),
//                                     //     ),
//                                     //   );

//                                     //   if (result == true) {
//                                     //     fetchVehicles(); // ✅ refresh your vehicle list
//                                     //   }
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder:
//                                             (
//                                               context,
//                                             ) => AddVehicleDriverCategoryScreen(
//                                               // firebaseId: user.uid,
//                                               vehicleId: vehicleId,
//                                               vehicleCategoryId: categoryIndex,
//                                               // v['category'], // 🟢 Ensure this exists in backend response
//                                             ),
//                                       ),
//                                     );
//                                     //fetchVehicles();
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                         content: Text(
//                                           "Missing Firebase user or category ID",
//                                         ),
//                                       ),
//                                     );
//                                   }
//                                 },
//                                 icon: const Icon(Icons.add),
//                                 label: const Text("Add Category"),
//                               ),
//                             ),
//                           ],

//                           if (isOwnerOrOwnerDriver) ...[
//                             if (isAssigned)
//                               TextButton(
//                                 onPressed: () => removeDriver(vehicleId),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor:
//                                       Colors.grey[700], // ✅ Grey background
//                                   foregroundColor: Colors.white, // ✅ White text
//                                 ),
//                                 child: Text(
//                                   "Remove Driver",
//                                   // style: TextStyle(color: Colors.grey[700]),
//                                 ),
//                               )
//                             else
//                               ElevatedButton(
//                                 onPressed: () => assignDriver(vehicleId),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor:
//                                       Colors.grey[700], // ✅ Grey background
//                                   foregroundColor: Colors.white, // ✅ White text
//                                 ),
//                                 child: Text(
//                                   "Assign Driver",

//                                   //style: TextStyle(color: Colors.grey[700]),
//                                 ),
//                               ),
//                           ],

//                           // if (isAssigned) ...[
//                           //   TextButton(
//                           //     onPressed: () => removeDriver(vehicleId),
//                           //     child: Text(
//                           //       "Remove Driver",
//                           //       style: TextStyle(color: Colors.grey[700]),
//                           //     ),
//                           //   ),
//                           // ] else if (role == 'ownerdriver') ...[
//                           //   ElevatedButton(
//                           //     onPressed: () => assignDriver(vehicleId),
//                           //     child: Text(
//                           //       "Assign Driver",
//                           //       style: TextStyle(color: Colors.grey[700]),
//                           //     ),
//                           //   ),
//                           // ],
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: goToAddVehicle,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

// // class DriverVehiclesScreen extends StatefulWidget {
// //   const DriverVehiclesScreen({super.key});

// //   @override
// //   State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
// // }

// // class _DriverVehiclesScreenState extends State<DriverVehiclesScreen> {
// //   List<Map<String, dynamic>> vehicles = [];
// //   String driverId = "";
// //   String role = "";

// //   @override
// //   void initState() {
// //     super.initState();
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user != null) {
// //       driverId = user.uid;
// //       fetchVehicles();
// //     }
// //   }

// //   Future<void> fetchVehicles() async {
// //     try {
// //       final user = FirebaseAuth.instance.currentUser;
// //       final idToken = await user?.getIdToken();

// //       final response = await http.get(
// //         Uri.parse('$baseUrl/vehicles/my-vehicles'),
// //         headers: {
// //           "Authorization": "Bearer $idToken",
// //           "Content-Type": "application/json",
// //         },
// //       );

// //       if (response.statusCode == 200) {
// //         final Map<String, dynamic> data = json.decode(response.body);

// //         final List ownedData = data['ownedVehicles'] ?? [];
// //         final List drivenData = data['drivenVehicles'] ?? [];
// //         final String fetchedRole = data['role'] ?? '';

// //         setState(() {
// //           vehicles = [
// //             ...ownedData.map((v) => Map<String, dynamic>.from(v)),
// //             ...drivenData.map((v) => Map<String, dynamic>.from(v)),
// //           ];
// //           role = fetchedRole; // store role in state
// //         });
// //       } else {
// //         throw Exception("Failed to fetch vehicles: ${response.body}");
// //       }
// //     } catch (e) {
// //       print("Error fetching vehicles: $e");
// //     }
// //   }

// //   // Future<void> _getUserRoleAndVehicles() async {
// //   //   try {
// //   //     final user = FirebaseAuth.instance.currentUser;
// //   //     final idTokenResult = await user?.getIdTokenResult();
// //   //     final claims = idTokenResult?.claims;

// //   //     setState(() {
// //   //       userRole = claims?['role'] ?? '';
// //   //     });

// //   //     await fetchVehicles();
// //   //   } catch (e) {
// //   //     print("Error fetching user role: $e");
// //   //   }
// //   // }

// //   // Future<void> fetchVehicles() async {
// //   //   try {
// //   //     final user = FirebaseAuth.instance.currentUser;
// //   //     final idToken = await user?.getIdToken();

// //   //     final response = await http.get(
// //   //       Uri.parse('$baseUrl/vehicles/my-vehicles'),
// //   //       headers: {
// //   //         "Authorization": "Bearer $idToken",
// //   //         "Content-Type": "application/json",
// //   //       },
// //   //     );

// //   //     if (response.statusCode == 200) {
// //   //       final Map<String, dynamic> data = json.decode(response.body);

// //   //       final List ownedData = data['ownedVehicles'] ?? [];
// //   //       final List drivenData = data['drivenVehicles'] ?? [];

// //   //       setState(() {
// //   //         vehicles = [
// //   //           ...ownedData.map((v) => Map<String, dynamic>.from(v)),
// //   //           ...drivenData.map((v) => Map<String, dynamic>.from(v)),
// //   //         ];
// //   //       });
// //   //     } else {
// //   //       throw Exception("Failed to fetch vehicles: ${response.body}");
// //   //     }
// //   //   } catch (e) {
// //   //     print("Error fetching vehicles: $e");
// //   //   }
// //   // }

// //   void goToAddVehicle() {
// //     GoRouter.of(context).goNamed(Routes().driverConfig);
// //   }

// //   void assignDriver(int vehicleId) async {
// //     final TextEditingController emailController = TextEditingController();

// //     showDialog(
// //       context: context,
// //       builder:
// //           (context) => AlertDialog(
// //             title: const Text("Assign Driver"),
// //             content: TextField(
// //               controller: emailController,
// //               decoration: const InputDecoration(
// //                 labelText: "Driver's Email",
// //                 prefixIcon: Icon(Icons.email, color: Colors.blue),
// //               ),
// //             ),
// //             actions: [
// //               TextButton(
// //                 onPressed: () => Navigator.of(context).pop(),
// //                 child: const Text(
// //                   "Cancel",
// //                   style: TextStyle(color: Colors.grey),
// //                 ),
// //               ),
// //               ElevatedButton(
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: Colors.blue,
// //                   foregroundColor: Colors.white,
// //                 ),
// //                 onPressed: () async {
// //                   final email = emailController.text.trim();
// //                   Navigator.of(context).pop();

// //                   final response = await http.post(
// //                     Uri.parse(
// //                       "$baseUrl/driver-vehicles/assign-driver-by-email",
// //                     ),
// //                     headers: {'Content-Type': 'application/json'},
// //                     body: jsonEncode({'email': email, 'vehicleId': vehicleId}),
// //                   );

// //                   if (response.statusCode == 200) {
// //                     showSnack("Driver assigned successfully");
// //                     fetchVehicles();
// //                   } else {
// //                     showSnack(
// //                       "Failed to assign driver: ${response.body}",
// //                       isError: true,
// //                     );
// //                   }
// //                 },
// //                 child: const Text("Assign"),
// //               ),
// //             ],
// //           ),
// //     );
// //   }

// //   void removeDriver(int vehicleId) async {
// //     final confirm = await showDialog<bool>(
// //       context: context,
// //       builder:
// //           (context) => AlertDialog(
// //             title: const Text("Remove Driver"),
// //             content: const Text(
// //               "Are you sure you want to unassign the driver?",
// //             ),
// //             actions: [
// //               TextButton(
// //                 onPressed: () => Navigator.of(context).pop(false),
// //                 child: const Text("Cancel"),
// //               ),
// //               TextButton(
// //                 onPressed: () => Navigator.of(context).pop(true),
// //                 child: const Text(
// //                   "Remove",
// //                   style: TextStyle(color: Colors.red),
// //                 ),
// //               ),
// //             ],
// //           ),
// //     );

// //     if (confirm == true) {
// //       final response = await http.post(
// //         Uri.parse("$baseUrl/driver-vehicles/remove-driver"),
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({'vehicleId': vehicleId}),
// //       );

// //       if (response.statusCode == 200) {
// //         showSnack("Driver removed successfully");
// //         fetchVehicles();
// //       } else {
// //         showSnack("Failed to remove driver: ${response.body}", isError: true);
// //       }
// //     }
// //   }

// //   void showSnack(String message, {bool isError = false}) {
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(
// //         content: Text(message),
// //         backgroundColor: isError ? Colors.red : Colors.blue,
// //       ),
// //     );
// //   }

// //   bool get isOwnerOrOwnerDriver => role == "owner" || role == "ownerdriver";
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("My Vehicles"),
// //         backgroundColor: Colors.blue,
// //         foregroundColor: Colors.white,
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.add),
// //             onPressed: goToAddVehicle,
// //             color: Colors.white,
// //           ),
// //         ],
// //       ),
// //       body:
// //           vehicles.isEmpty
// //               ? const Center(child: Text("No vehicles found"))
// //               : ListView.builder(
// //                 itemCount: vehicles.length,
// //                 itemBuilder: (context, index) {
// //                   final v = vehicles[index];
// //                   final isAssigned = v['driverId'] != null;

// //                   return Card(
// //                     margin: const EdgeInsets.all(10),
// //                     elevation: 4,
// //                     child: ListTile(
// //                       title: Text(
// //                         "${v['vehicleMake'] ?? 'Unknown'} ${v['vehicleModel'] ?? ''}",
// //                       ),
// //                       subtitle: Text(
// //                         "Reg: ${v['registrationNumber'] ?? ''} | Year: ${v['year'] ?? ''}",
// //                       ),
// //                       trailing: Column(
// //                         mainAxisAlignment: MainAxisAlignment.center,
// //                         crossAxisAlignment: CrossAxisAlignment.end,
// //                         children: [
// //                           if (isAssigned) ...[
// //                             Container(
// //                               padding: const EdgeInsets.symmetric(
// //                                 horizontal: 8,
// //                                 vertical: 4,
// //                               ),
// //                               decoration: BoxDecoration(
// //                                 color: Colors.yellow,
// //                                 borderRadius: BorderRadius.circular(8),
// //                               ),
// //                               child: const Text(
// //                                 "Driver Assigned",
// //                                 style: TextStyle(
// //                                   color: Colors.black,
// //                                   fontWeight: FontWeight.bold,
// //                                 ),
// //                               ),
// //                             ),
// //                             const SizedBox(height: 5),
// //                             if (role == 'ownerdriver')
// //                               TextButton(
// //                                 onPressed: () => removeDriver(v['id']),
// //                                 style: TextButton.styleFrom(
// //                                   foregroundColor: Colors.red,
// //                                 ),
// //                                 child: const Text("Remove Driver"),
// //                               ),
// //                           ] else if (role == 'ownerdriver') ...[
// //                             ElevatedButton(
// //                               onPressed: () => assignDriver(v['id']),
// //                               style: ElevatedButton.styleFrom(
// //                                 backgroundColor: Colors.blue,
// //                                 foregroundColor: Colors.white,
// //                               ),
// //                               child: const Text("Assign Driver"),
// //                             ),
// //                           ],
// //                         ],
// //                       ),
// //                     ),
// //                   );
// //                 },
// //               ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: goToAddVehicle,
// //         backgroundColor: Colors.yellow,
// //         child: const Icon(Icons.add, color: Colors.black),
// //       ),
// //     );
// //   }
// // }
// import 'dart:convert';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/assign_driver.dart';
// import 'package:aminidriver/Onboarding/vehicle_category.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/add_driver_vehicle_category.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:http/http.dart' as http;

// class DriverVehiclesScreen extends StatefulWidget {
//   const DriverVehiclesScreen({super.key});

//   @override
//   State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
// }

// class _DriverVehiclesScreenState extends State<DriverVehiclesScreen> {
//   List<Map<String, dynamic>> vehicles = [];
//   String driverId = "";
//   String role = "";
//   //VehicleCategory? category;
//   Set<int> expandedCardIds = {}; // Track which cards are expanded

//   @override
//   void initState() {
//     super.initState();
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       driverId = user.uid;
//       fetchVehicles();
//     }
//   }

//   Future<void> deleteSubCategory(int vehicleId, int subCategoryId) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/vehicles/delete/drivervehiclecategory'),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "vehicleId": vehicleId,
//           "subCategory": subCategoryId,
//         }),
//       );

//       if (response.statusCode == 200) {
//         // Success
//       } else {
//         throw Exception('Failed to delete subcategory');
//       }
//     } catch (e) {
//       print("Error deleting subcategory: $e");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error deleting subcategory: $e")));
//     }
//   }

//   Future<void> fetchVehicles() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       final idToken = await user?.getIdToken();

//       final response = await http.get(
//         Uri.parse('$baseUrl/vehicles/my-vehicles'),
//         headers: {
//           "Authorization": "Bearer $idToken",
//           "Content-Type": "application/json",
//         },
//       );

//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         final List ownedData = data['ownedVehicles'] ?? [];
//         final List drivenData = data['drivenVehicles'] ?? [];
//         final String fetchedRole = data['role'] ?? '';

//         setState(() {
//           vehicles = [
//             ...ownedData.map((v) => Map<String, dynamic>.from(v)),
//             ...drivenData.map((v) => Map<String, dynamic>.from(v)),
//           ];
//           role = fetchedRole;
//         });
//       } else {
//         throw Exception("Failed to fetch vehicles: ${response.body}");
//       }
//     } catch (e) {
//       print("Error fetching vehicles: $e");
//     }
//   }

//   void goToAddVehicle() {
//     GoRouter.of(context).goNamed(Routes().driverConfig);
//   }

//   // void assignDriver(int vehicleId) async {
//   //   final TextEditingController emailController = TextEditingController();

//   //   showDialog(
//   //     context: context,
//   //     builder:
//   //         (context) => AlertDialog(
//   //           title: const Text("Assign Driver"),
//   //           content: TextField(
//   //             controller: emailController,
//   //             decoration: const InputDecoration(
//   //               labelText: "Driver's Email",
//   //               prefixIcon: Icon(Icons.email),
//   //             ),
//   //           ),
//   //           actions: [
//   //             TextButton(
//   //               onPressed: () => Navigator.of(context).pop(),
//   //               child: const Text("Cancel"),
//   //             ),
//   //             ElevatedButton(
//   //               onPressed: () async {
//   //                 final email = emailController.text.trim();
//   //                 Navigator.of(context).pop();
//   //                 final response = await http.post(
//   //                   Uri.parse(
//   //                     "$baseUrl/driver-vehicles/assign-driver-by-email",
//   //                   ),
//   //                   headers: {'Content-Type': 'application/json'},
//   //                   body: jsonEncode({'email': email, 'vehicleId': vehicleId}),
//   //                 );
//   //                 if (response.statusCode == 200) {
//   //                   showSnack("Driver assigned successfully");
//   //                   fetchVehicles();
//   //                 } else {
//   //                   showSnack("Failed: ${response.body}", isError: true);
//   //                 }
//   //               },
//   //               child: const Text("Assign"),
//   //             ),
//   //           ],
//   //         ),
//   //   );
//   // }
//   void assignDriver(int vehicleId) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => AssignDriverScreen(vehicleId: vehicleId),
//       ),
//     ).then((result) {
//       if (result == true) {
//         fetchVehicles(); // Refresh list after returning from screen
//       }
//     });
//   }

//   void removeDriver(int vehicleId) async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text("Remove Driver"),
//             content: const Text("Are you sure?"),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(false),
//                 child: const Text("Cancel"),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(true),
//                 child: Text(
//                   "Remove",
//                   style: TextStyle(color: Colors.grey[700]),
//                 ),
//               ),
//             ],
//           ),
//     );

//     if (confirm == true) {
//       final response = await http.post(
//         Uri.parse("$baseUrl/driver-vehicles/remove-driver"),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'vehicleId': vehicleId}),
//       );
//       if (response.statusCode == 200) {
//         showSnack("Driver removed successfully");
//         fetchVehicles();
//       } else {
//         showSnack("Failed: ${response.body}", isError: true);
//       }
//     }
//   }

//   void showSnack(String msg, {bool isError = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: isError ? Colors.red : Colors.green,
//       ),
//     );
//   }

//   bool get isOwnerOrOwnerDriver => role == "owner" || role == "ownerdriver";

//   List<String> getDummyCategories(int id) {
//     // You can replace this with a real call to backend per vehicle
//     return ['Insurance', 'Maintenance', 'Fuel', 'Permit'];
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("My Vehicles"),
//         centerTitle: true,
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,

//         //title: const Text("My Vehicles"),
//         // actions: [
//         //   IconButton(icon: const Icon(Icons.add), onPressed: goToAddVehicle),
//         // ],
//       ),
//       body:
//           vehicles.isEmpty
//               ? const Center(child: Text("No vehicles found"))
//               : ListView.builder(
//                 itemCount: vehicles.length,
//                 itemBuilder: (context, index) {
//                   final v = vehicles[index];
//                   final vehicleId = v['id'];
//                   final isAssigned = v['driverId'] != null;
//                   final isExpanded = expandedCardIds.contains(vehicleId);

//                   final int indexx = v['category'] ?? -1;
//                   final category =
//                       parseVehicleCategory(indexx)?.displayName ?? 'Unknown';
//                   //category = v['category'] ?? 'Unknown';
//                   //final categoryName = v['categoryName'] ?? 'Unknown';

//                   return Card(
//                     margin: const EdgeInsets.all(10),
//                     elevation: 4,
//                     child: Padding(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Class: $category",
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.grey[700], // ✅ Updated color
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,

//                             title: Text(
//                               "${v['vehicleMake'] ?? 'Unknown'} ${v['vehicleModel'] ?? ''}",
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 18,
//                               ),
//                             ),
//                             subtitle: Text(
//                               "Reg: ${v['registrationNumber']} | Year: ${v['year']}",
//                             ),
//                             trailing: IconButton(
//                               icon: Icon(
//                                 isExpanded
//                                     ? Icons.expand_less
//                                     : Icons.expand_more,
//                               ),
//                               onPressed: () {
//                                 setState(() {
//                                   if (isExpanded) {
//                                     expandedCardIds.remove(vehicleId);
//                                   } else {
//                                     expandedCardIds.add(vehicleId);
//                                   }
//                                 });
//                               },
//                             ),
//                           ),
//                           if (isExpanded) ...[
//                             const Divider(),
//                             Text(
//                               "Categories",
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey[700],
//                               ),
//                             ),
//                             const SizedBox(height: 8),

//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children:
//                                   (v['subCategories'] as List<dynamic>? ?? []).map((
//                                     cat,
//                                   ) {
//                                     final int subCategoryId =
//                                         cat['id']; // ✅ extract ID
//                                     final String subCategoryName =
//                                         cat['name']; // for display

//                                     return Padding(
//                                       padding: const EdgeInsets.only(
//                                         bottom: 4.0,
//                                       ),
//                                       child: Row(
//                                         mainAxisAlignment:
//                                             MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Expanded(
//                                             child: Text("- $subCategoryName"),
//                                           ),
//                                           IconButton(
//                                             icon: Icon(
//                                               Icons.delete,
//                                               color: Colors.grey[700],
//                                             ),
//                                             onPressed: () async {
//                                               final confirmed = await showDialog<
//                                                 bool
//                                               >(
//                                                 context: context,
//                                                 builder:
//                                                     (context) => AlertDialog(
//                                                       title: const Text(
//                                                         "Confirm Delete",
//                                                       ),
//                                                       content: Text(
//                                                         "Are you sure you want to remove '$subCategoryName'?",
//                                                       ),
//                                                       actions: [
//                                                         TextButton(
//                                                           onPressed:
//                                                               () =>
//                                                                   Navigator.pop(
//                                                                     context,
//                                                                     false,
//                                                                   ),
//                                                           child: const Text(
//                                                             "Cancel",
//                                                           ),
//                                                         ),
//                                                         TextButton(
//                                                           onPressed:
//                                                               () =>
//                                                                   Navigator.pop(
//                                                                     context,
//                                                                     true,
//                                                                   ),
//                                                           child: const Text(
//                                                             "Delete",
//                                                             style: TextStyle(
//                                                               color: Colors.red,
//                                                             ),
//                                                           ),
//                                                         ),
//                                                       ],
//                                                     ),
//                                               );

//                                               if (confirmed == true) {
//                                                 await deleteSubCategory(
//                                                   vehicleId,
//                                                   subCategoryId,
//                                                 ); // 🔁 pass only the ID
//                                                 fetchVehicles(); // refresh list
//                                               }
//                                             },
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   }).toList(),
//                             ),

//                             const SizedBox(height: 8),
//                             SizedBox(
//                               width: double.infinity, // ✅ Full width
//                               child: ElevatedButton.icon(
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor:
//                                       Colors.grey[700], // ✅ Grey background
//                                   foregroundColor:
//                                       Colors.white, // ✅ White text/icon
//                                 ),
//                                 onPressed: () async {
//                                   final user =
//                                       FirebaseAuth.instance.currentUser;
//                                   final int? categoryIndex = v['category'];

//                                   if (user != null && categoryIndex != null) {
//                                     final vehicleCategory =
//                                         parseVehicleCategory(categoryIndex);
//                                     //   final result = await Navigator.push(
//                                     //     context,
//                                     //     MaterialPageRoute(
//                                     //       builder:
//                                     //           (context) =>
//                                     //               AddVehicleDriverCategoryScreen(
//                                     //                 vehicleId: vehicleId,
//                                     //                 vehicleCategoryId:
//                                     //                     categoryIndex,
//                                     //               ),
//                                     //     ),
//                                     //   );

//                                     //   if (result == true) {
//                                     //     fetchVehicles(); // ✅ refresh your vehicle list
//                                     //   }
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder:
//                                             (
//                                               context,
//                                             ) => AddVehicleDriverCategoryScreen(
//                                               // firebaseId: user.uid,
//                                               vehicleId: vehicleId,
//                                               vehicleCategoryId: categoryIndex,
//                                               // v['category'], // 🟢 Ensure this exists in backend response
//                                             ),
//                                       ),
//                                     );
//                                     //fetchVehicles();
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                         content: Text(
//                                           "Missing Firebase user or category ID",
//                                         ),
//                                       ),
//                                     );
//                                   }
//                                 },
//                                 icon: const Icon(Icons.add),
//                                 label: const Text("Add Category"),
//                               ),
//                             ),
//                           ],

//                           if (isOwnerOrOwnerDriver) ...[
//                             if (isAssigned)
//                               TextButton(
//                                 onPressed: () => removeDriver(vehicleId),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor:
//                                       Colors.grey[700], // ✅ Grey background
//                                   foregroundColor: Colors.white, // ✅ White text
//                                 ),
//                                 child: Text(
//                                   "Remove Driver",
//                                   // style: TextStyle(color: Colors.grey[700]),
//                                 ),
//                               )
//                             else
//                               ElevatedButton(
//                                 onPressed: () => assignDriver(vehicleId),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor:
//                                       Colors.grey[700], // ✅ Grey background
//                                   foregroundColor: Colors.white, // ✅ White text
//                                 ),
//                                 child: Text(
//                                   "Assign Driver",

//                                   //style: TextStyle(color: Colors.grey[700]),
//                                 ),
//                               ),
//                           ],

//                           // if (isAssigned) ...[
//                           //   TextButton(
//                           //     onPressed: () => removeDriver(vehicleId),
//                           //     child: Text(
//                           //       "Remove Driver",
//                           //       style: TextStyle(color: Colors.grey[700]),
//                           //     ),
//                           //   ),
//                           // ] else if (role == 'ownerdriver') ...[
//                           //   ElevatedButton(
//                           //     onPressed: () => assignDriver(vehicleId),
//                           //     child: Text(
//                           //       "Assign Driver",
//                           //       style: TextStyle(color: Colors.grey[700]),
//                           //     ),
//                           //   ),
//                           // ],
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: goToAddVehicle,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

// // class DriverVehiclesScreen extends StatefulWidget {
// //   const DriverVehiclesScreen({super.key});

// //   @override
// //   State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
// // }

// // class _DriverVehiclesScreenState extends State<DriverVehiclesScreen> {
// //   List<Map<String, dynamic>> vehicles = [];
// //   String driverId = "";
// //   String role = "";

// //   @override
// //   void initState() {
// //     super.initState();
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user != null) {
// //       driverId = user.uid;
// //       fetchVehicles();
// //     }
// //   }

// //   Future<void> fetchVehicles() async {
// //     try {
// //       final user = FirebaseAuth.instance.currentUser;
// //       final idToken = await user?.getIdToken();

// //       final response = await http.get(
// //         Uri.parse('$baseUrl/vehicles/my-vehicles'),
// //         headers: {
// //           "Authorization": "Bearer $idToken",
// //           "Content-Type": "application/json",
// //         },
// //       );

// //       if (response.statusCode == 200) {
// //         final Map<String, dynamic> data = json.decode(response.body);

// //         final List ownedData = data['ownedVehicles'] ?? [];
// //         final List drivenData = data['drivenVehicles'] ?? [];
// //         final String fetchedRole = data['role'] ?? '';

// //         setState(() {
// //           vehicles = [
// //             ...ownedData.map((v) => Map<String, dynamic>.from(v)),
// //             ...drivenData.map((v) => Map<String, dynamic>.from(v)),
// //           ];
// //           role = fetchedRole; // store role in state
// //         });
// //       } else {
// //         throw Exception("Failed to fetch vehicles: ${response.body}");
// //       }
// //     } catch (e) {
// //       print("Error fetching vehicles: $e");
// //     }
// //   }

// //   // Future<void> _getUserRoleAndVehicles() async {
// //   //   try {
// //   //     final user = FirebaseAuth.instance.currentUser;
// //   //     final idTokenResult = await user?.getIdTokenResult();
// //   //     final claims = idTokenResult?.claims;

// //   //     setState(() {
// //   //       userRole = claims?['role'] ?? '';
// //   //     });

// //   //     await fetchVehicles();
// //   //   } catch (e) {
// //   //     print("Error fetching user role: $e");
// //   //   }
// //   // }

// //   // Future<void> fetchVehicles() async {
// //   //   try {
// //   //     final user = FirebaseAuth.instance.currentUser;
// //   //     final idToken = await user?.getIdToken();

// //   //     final response = await http.get(
// //   //       Uri.parse('$baseUrl/vehicles/my-vehicles'),
// //   //       headers: {
// //   //         "Authorization": "Bearer $idToken",
// //   //         "Content-Type": "application/json",
// //   //       },
// //   //     );

// //   //     if (response.statusCode == 200) {
// //   //       final Map<String, dynamic> data = json.decode(response.body);

// //   //       final List ownedData = data['ownedVehicles'] ?? [];
// //   //       final List drivenData = data['drivenVehicles'] ?? [];

// //   //       setState(() {
// //   //         vehicles = [
// //   //           ...ownedData.map((v) => Map<String, dynamic>.from(v)),
// //   //           ...drivenData.map((v) => Map<String, dynamic>.from(v)),
// //   //         ];
// //   //       });
// //   //     } else {
// //   //       throw Exception("Failed to fetch vehicles: ${response.body}");
// //   //     }
// //   //   } catch (e) {
// //   //     print("Error fetching vehicles: $e");
// //   //   }
// //   // }

// //   void goToAddVehicle() {
// //     GoRouter.of(context).goNamed(Routes().driverConfig);
// //   }

// //   void assignDriver(int vehicleId) async {
// //     final TextEditingController emailController = TextEditingController();

// //     showDialog(
// //       context: context,
// //       builder:
// //           (context) => AlertDialog(
// //             title: const Text("Assign Driver"),
// //             content: TextField(
// //               controller: emailController,
// //               decoration: const InputDecoration(
// //                 labelText: "Driver's Email",
// //                 prefixIcon: Icon(Icons.email, color: Colors.blue),
// //               ),
// //             ),
// //             actions: [
// //               TextButton(
// //                 onPressed: () => Navigator.of(context).pop(),
// //                 child: const Text(
// //                   "Cancel",
// //                   style: TextStyle(color: Colors.grey),
// //                 ),
// //               ),
// //               ElevatedButton(
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: Colors.blue,
// //                   foregroundColor: Colors.white,
// //                 ),
// //                 onPressed: () async {
// //                   final email = emailController.text.trim();
// //                   Navigator.of(context).pop();

// //                   final response = await http.post(
// //                     Uri.parse(
// //                       "$baseUrl/driver-vehicles/assign-driver-by-email",
// //                     ),
// //                     headers: {'Content-Type': 'application/json'},
// //                     body: jsonEncode({'email': email, 'vehicleId': vehicleId}),
// //                   );

// //                   if (response.statusCode == 200) {
// //                     showSnack("Driver assigned successfully");
// //                     fetchVehicles();
// //                   } else {
// //                     showSnack(
// //                       "Failed to assign driver: ${response.body}",
// //                       isError: true,
// //                     );
// //                   }
// //                 },
// //                 child: const Text("Assign"),
// //               ),
// //             ],
// //           ),
// //     );
// //   }

// //   void removeDriver(int vehicleId) async {
// //     final confirm = await showDialog<bool>(
// //       context: context,
// //       builder:
// //           (context) => AlertDialog(
// //             title: const Text("Remove Driver"),
// //             content: const Text(
// //               "Are you sure you want to unassign the driver?",
// //             ),
// //             actions: [
// //               TextButton(
// //                 onPressed: () => Navigator.of(context).pop(false),
// //                 child: const Text("Cancel"),
// //               ),
// //               TextButton(
// //                 onPressed: () => Navigator.of(context).pop(true),
// //                 child: const Text(
// //                   "Remove",
// //                   style: TextStyle(color: Colors.red),
// //                 ),
// //               ),
// //             ],
// //           ),
// //     );

// //     if (confirm == true) {
// //       final response = await http.post(
// //         Uri.parse("$baseUrl/driver-vehicles/remove-driver"),
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({'vehicleId': vehicleId}),
// //       );

// //       if (response.statusCode == 200) {
// //         showSnack("Driver removed successfully");
// //         fetchVehicles();
// //       } else {
// //         showSnack("Failed to remove driver: ${response.body}", isError: true);
// //       }
// //     }
// //   }

// //   void showSnack(String message, {bool isError = false}) {
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(
// //         content: Text(message),
// //         backgroundColor: isError ? Colors.red : Colors.blue,
// //       ),
// //     );
// //   }

// //   bool get isOwnerOrOwnerDriver => role == "owner" || role == "ownerdriver";
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("My Vehicles"),
// //         backgroundColor: Colors.blue,
// //         foregroundColor: Colors.white,
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.add),
// //             onPressed: goToAddVehicle,
// //             color: Colors.white,
// //           ),
// //         ],
// //       ),
// //       body:
// //           vehicles.isEmpty
// //               ? const Center(child: Text("No vehicles found"))
// //               : ListView.builder(
// //                 itemCount: vehicles.length,
// //                 itemBuilder: (context, index) {
// //                   final v = vehicles[index];
// //                   final isAssigned = v['driverId'] != null;

// //                   return Card(
// //                     margin: const EdgeInsets.all(10),
// //                     elevation: 4,
// //                     child: ListTile(
// //                       title: Text(
// //                         "${v['vehicleMake'] ?? 'Unknown'} ${v['vehicleModel'] ?? ''}",
// //                       ),
// //                       subtitle: Text(
// //                         "Reg: ${v['registrationNumber'] ?? ''} | Year: ${v['year'] ?? ''}",
// //                       ),
// //                       trailing: Column(
// //                         mainAxisAlignment: MainAxisAlignment.center,
// //                         crossAxisAlignment: CrossAxisAlignment.end,
// //                         children: [
// //                           if (isAssigned) ...[
// //                             Container(
// //                               padding: const EdgeInsets.symmetric(
// //                                 horizontal: 8,
// //                                 vertical: 4,
// //                               ),
// //                               decoration: BoxDecoration(
// //                                 color: Colors.yellow,
// //                                 borderRadius: BorderRadius.circular(8),
// //                               ),
// //                               child: const Text(
// //                                 "Driver Assigned",
// //                                 style: TextStyle(
// //                                   color: Colors.black,
// //                                   fontWeight: FontWeight.bold,
// //                                 ),
// //                               ),
// //                             ),
// //                             const SizedBox(height: 5),
// //                             if (role == 'ownerdriver')
// //                               TextButton(
// //                                 onPressed: () => removeDriver(v['id']),
// //                                 style: TextButton.styleFrom(
// //                                   foregroundColor: Colors.red,
// //                                 ),
// //                                 child: const Text("Remove Driver"),
// //                               ),
// //                           ] else if (role == 'ownerdriver') ...[
// //                             ElevatedButton(
// //                               onPressed: () => assignDriver(v['id']),
// //                               style: ElevatedButton.styleFrom(
// //                                 backgroundColor: Colors.blue,
// //                                 foregroundColor: Colors.white,
// //                               ),
// //                               child: const Text("Assign Driver"),
// //                             ),
// //                           ],
// //                         ],
// //                       ),
// //                     ),
// //                   );
// //                 },
// //               ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: goToAddVehicle,
// //         backgroundColor: Colors.yellow,
// //         child: const Icon(Icons.add, color: Colors.black),
// //       ),
// //     );
// //   }
// // }
