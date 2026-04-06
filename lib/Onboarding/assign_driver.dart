import 'dart:convert';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/vehicle_category.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AssignDriverScreen extends StatefulWidget {
  final VoidCallback? onCompleted;
  final int vehicleId;
  final int? Category;

  const AssignDriverScreen({
    super.key,
    this.onCompleted,
    required this.vehicleId,
    this.Category,
  });

  @override
  State<AssignDriverScreen> createState() => _AssignDriverScreenState();
}

class _AssignDriverScreenState extends State<AssignDriverScreen> {
  String? selectedDriver;
  bool isLoading = false;
  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> filteredDrivers = [];

  String searchQuery = '';
  //String? selectedCategory;

  @override
  void initState() {
    super.initState();
    fetchDrivers();
  }

  Future<void> fetchDrivers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/vehicles/unassigned-drivers/${widget.Category}"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          drivers = List<Map<String, dynamic>>.from(data);
          filteredDrivers = List.from(drivers);
        });
      } else {
        showSnackBar("Failed to fetch drivers");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // void filterDrivers() {
  //   setState(() {
  //     filteredDrivers =
  //         drivers.where((driver) {
  //           final matchesSearch =
  //               driver['fullName'].toLowerCase().contains(
  //                 searchQuery.toLowerCase(),
  //               ) ||
  //               driver['email'].toLowerCase().contains(
  //                 searchQuery.toLowerCase(),
  //               ) ||
  //               driver['mobile']?.toString().contains(searchQuery) == true;
  //         }).toList();
  //   });
  // }

  Future<void> assignDriver() async {
    if (selectedDriver == null) {
      showSnackBar("Please select a driver.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles/assign-driver'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vehicleId": widget.vehicleId,
          "firebaseId": selectedDriver,
        }),
      );

      if (response.statusCode == 200) {
        showSnackBar("Driver assigned successfully", color: Colors.green);
        Navigator.pop(context, true); // ✅ Go back to previous screen
      } else {
        showSnackBar("Failed to assign driver");
      }
    } catch (e) {
      showSnackBar("Error assigning driver: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Driver"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Search Field
                    // TextField(
                    //   decoration: const InputDecoration(
                    //     labelText: "Search by name, email, or mobile",
                    //     border: OutlineInputBorder(),
                    //     prefixIcon: Icon(Icons.search),
                    //   ),
                    //   onChanged: (value) {
                    //     setState(() {
                    //       searchQuery = value.toLowerCase();
                    //       filteredDrivers =
                    //           drivers.where((driver) {
                    //             final name =
                    //                 (driver['fullName'] ?? '')
                    //                     .toString()
                    //                     .toLowerCase();
                    //             final email =
                    //                 (driver['email'] ?? '')
                    //                     .toString()
                    //                     .toLowerCase();
                    //             final mobile =
                    //                 (driver['mobile'] ?? '').toString();
                    //             return name.contains(searchQuery) ||
                    //                 email.contains(searchQuery) ||
                    //                 mobile.contains(searchQuery);
                    //           }).toList();
                    //     });
                    //   },
                    // ),
                    const SizedBox(height: 16),

                    // Category Filter
                    // DropdownButtonFormField<String>(
                    //   decoration: const InputDecoration(
                    //     labelText: "Filter by Category",
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   value: selectedCategory,
                    //   items: [
                    //     const DropdownMenuItem(value: null, child: Text("All")),
                    //     ...drivers
                    //         .map((d) => d['category']?.toString())
                    //         .toSet()
                    //         .map(
                    //           (cat) => DropdownMenuItem(
                    //             value: cat,
                    //             child: Text(cat ?? 'Unknown'),
                    //           ),
                    //         )
                    //         .toList(),
                    //   ],
                    //   onChanged: (value) {
                    //     selectedCategory = value;
                    //     filterDrivers();
                    //   },
                    // ),
                    // const SizedBox(height: 16),
                    // Replace DropdownButtonFormField with this Autocomplete widget
                    Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        return drivers.where((driver) {
                          final name =
                              (driver['fullName'] ?? '')
                                  .toString()
                                  .toLowerCase();
                          final email =
                              (driver['email'] ?? '').toString().toLowerCase();
                          final mobile = (driver['mobile'] ?? '').toString();
                          final query = textEditingValue.text.toLowerCase();
                          return name.contains(query) ||
                              email.contains(query) ||
                              mobile.contains(query);
                        });
                      },
                      displayStringForOption:
                          (driver) =>
                              "${driver['fullName']} | ${driver['email']} | ${driver['mobile'] ?? ''}",
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: "Search & Select Driver",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Material(
                          elevation: 4,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children:
                                options.map((driver) {
                                  return ListTile(
                                    title: Text(driver['fullName'] ?? ''),
                                    subtitle: Text(
                                      "${driver['email']} | ${driver['mobile'] ?? ''}",
                                    ),
                                    onTap: () {
                                      onSelected(driver);
                                    },
                                  );
                                }).toList(),
                          ),
                        );
                      },
                      onSelected: (driver) {
                        setState(() {
                          selectedDriver = driver['firebaseId'].toString();
                        });
                      },
                    ),

                    // Driver Dropdown
                    // DropdownButtonFormField<String>(
                    //   decoration: const InputDecoration(
                    //     labelText: 'Select Driver',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   value: selectedDriver,
                    //   isExpanded: true, // Important to prevent overflow
                    //   items:
                    //       filteredDrivers.map((driver) {
                    //         return DropdownMenuItem<String>(
                    //           value: driver['firebaseId'].toString(),
                    //           child: Row(
                    //             children: [
                    //               Expanded(
                    //                 child: Text(
                    //                   driver['fullName'] ?? '',
                    //                   overflow: TextOverflow.ellipsis,
                    //                 ),
                    //               ),
                    //               const SizedBox(width: 8),
                    //               Expanded(
                    //                 child: Text(
                    //                   "${driver['email']} | ${driver['mobile'] ?? ''}",
                    //                   style: const TextStyle(
                    //                     fontSize: 12,
                    //                     color: Colors.grey,
                    //                   ),
                    //                   overflow: TextOverflow.ellipsis,
                    //                 ),
                    //               ),
                    //             ],
                    //           ),
                    //         );
                    //       }).toList(),
                    //   onChanged: (value) {
                    //     setState(() => selectedDriver = value);
                    //   },
                    // ),

                    // DropdownButtonFormField<String>(
                    //   decoration: const InputDecoration(
                    //     labelText: 'Select Driver',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   value: selectedDriver,
                    //   items:
                    //       filteredDrivers.map((driver) {
                    //         return DropdownMenuItem<String>(
                    //           value: driver['firebaseId'].toString(),
                    //           child: Column(
                    //             crossAxisAlignment: CrossAxisAlignment.start,
                    //             children: [
                    //               Text(
                    //                 driver['fullName'],
                    //                 overflow: TextOverflow.ellipsis,
                    //               ),
                    //               Text(
                    //                 "${driver['email']} | ${driver['mobile']}",
                    //                 style: const TextStyle(
                    //                   fontSize: 12,
                    //                   color: Colors.grey,
                    //                 ),
                    //                 overflow: TextOverflow.ellipsis,
                    //               ),
                    //             ],
                    //           ),
                    //         );
                    //       }).toList(),
                    //   onChanged: (value) {
                    //     setState(() {
                    //       selectedDriver = value;
                    //     });
                    //   },
                    // ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: assignDriver,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text('Assign Driver'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

// class _AssignDriverScreenState extends State<AssignDriverScreen> {
//   String? selectedDriver;
//   bool isLoading = false;

//   List<Map<String, dynamic>> drivers = [];

//   //final String baseUrl = "http://your-api-url.com"; // Replace with actual URL

//   @override
//   void initState() {
//     super.initState();
//     fetchDrivers();
//   }

//   Future<void> fetchDrivers() async {
//     setState(() => isLoading = true);
//     try {
//       final response = await http.get(
//         Uri.parse("$baseUrl/vehicles/unassigned-drivers"),
//       );
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() {
//           drivers = List<Map<String, dynamic>>.from(data);
//         });
//       } else {
//         showSnackBar("Failed to fetch drivers");
//       }
//     } catch (e) {
//       showSnackBar("Error: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> assignDriver() async {
//     if (selectedDriver == null) {
//       showSnackBar("Please select a driver.");
//       return;
//     }

//     setState(() => isLoading = true);
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/vehicles/assign-driver'),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "vehicleId": widget.vehicleId,
//           "firebaseId": selectedDriver,
//         }),
//       );

//       if (response.statusCode == 200) {
//         showSnackBar("Driver assigned successfully", color: Colors.green);
//         // widget.onCompleted();
//         // Navigator.pop(context);
//       } else {
//         showSnackBar("Failed to assign driver");
//       }
//     } catch (e) {
//       showSnackBar("Error assigning driver: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   void showSnackBar(String message, {Color color = Colors.red}) {
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Assign Driver"),
//         centerTitle: true,
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//         // title: const Text('Assign Driver'),
//         // backgroundColor: Colors.white,
//       ),
//       body:
//           isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     DropdownButtonFormField<String>(
//                       decoration: const InputDecoration(
//                         labelText: 'Select Driver',
//                         border: OutlineInputBorder(),
//                       ),
//                       value: selectedDriver,
//                       items:
//                           drivers
//                               .map(
//                                 (driver) => DropdownMenuItem<String>(
//                                   value: driver['firebaseId'].toString(),
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Text(driver['fullName']),
//                                       Text(
//                                         driver['email'],
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               )
//                               .toList(),
//                       onChanged: (value) {
//                         setState(() {
//                           selectedDriver = value;
//                         });
//                       },
//                     ),
//                     const SizedBox(height: 30),
//                     SizedBox(
//                       width: double.infinity, // ✅ Stretch to full width
//                       child: ElevatedButton(
//                         onPressed: assignDriver,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.grey[700],
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 30,
//                             vertical: 15,
//                           ),
//                         ),
//                         child: const Text('Assign Driver'),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//     );
//   }
// }
