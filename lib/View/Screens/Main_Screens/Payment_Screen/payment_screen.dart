import 'dart:convert';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  double walletBalance = 0.0;
  double weeklyEarnings = 0.0;
  List<Map<String, dynamic>> payouts = [];
  double depositAmount = 0.0;

  String driverId = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverId = user.uid;
      fetchPayments();
    }
  }

  Future<void> fetchPayments() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/Payments/$driverId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // walletBalance = data['walletBalance'] ?? 0.0;
          // weeklyEarnings = data['weeklyEarnings'] ?? 0.0;
          walletBalance = (data['walletBalance']?.toDouble() ?? 0.0);
          weeklyEarnings = (data['weeklyEarnings']?.toDouble() ?? 0.0);

          payouts = List<Map<String, dynamic>>.from(data['payouts'] ?? []);
        });
      } else {
        showSnack('Failed to fetch payment data');
      }
    } catch (e) {
      showSnack('Something went wrong: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> withdrawFunds() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/withdraw/$driverId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'driverId': driverId, 'amount': walletBalance}),
      );

      if (response.statusCode == 200) {
        showSnack('Withdrawal successful!');
        fetchPayments();
      } else {
        showSnack('Withdrawal failed.');
      }
    } catch (e) {
      showSnack('Error: $e');
    }
  }

  Future<void> depositFunds() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Payments/deposit/$driverId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'driverId': driverId, 'amount': depositAmount}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          walletBalance = data['updatedBalance'] ?? walletBalance;
        });
        showSnack(data['message'] ?? 'Deposit successful!');
      } else {
        showSnack('Deposit failed.');
      }
    } catch (e) {
      showSnack('Error: $e');
    }
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Earnings & Wallet"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Card
                    _buildCard(
                      title: "Wallet Balance",
                      value: "KES ${walletBalance.toStringAsFixed(2)}",
                      icon: Icons.account_balance_wallet,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),

                    // Weekly Earnings
                    _buildCard(
                      title: "Weekly Earnings",
                      value: "KES ${weeklyEarnings.toStringAsFixed(2)}",
                      icon: Icons.calendar_today,
                      color: Colors.blueAccent,
                      subtitle: "Trips: 34 | Hours: 29",
                    ),
                    const SizedBox(height: 24),

                    // Deposit Field
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Amount to Deposit',
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged:
                          (val) => setState(
                            () => depositAmount = double.tryParse(val) ?? 0.0,
                          ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: depositAmount > 0 ? depositFunds : null,
                            icon: const Icon(Icons.add),
                            label: const Text("Deposit"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: walletBalance > 0 ? withdrawFunds : null,
                            icon: const Icon(Icons.arrow_downward),
                            label: const Text("Withdraw"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Recent Payouts
                    const Text(
                      "Recent Payouts",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(),
                    ...payouts.map(
                      (p) => ListTile(
                        leading: const Icon(Icons.attach_money),
                        title: Text("KES ${p['amount']}"),
                        subtitle: Text(p['date']),
                        trailing: Text(
                          p['status'],
                          style: TextStyle(
                            color:
                                p['status'].toLowerCase() == 'completed'
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//   // Widget buildChart() {
//   //   return BarChart(
//   //     BarChartData(
//   //       alignment: BarChartAlignment.spaceAround,
//   //       titlesData: FlTitlesData(
//   //         leftTitles: SideTitles(showTitles: true),
//   //         bottomTitles: SideTitles(
//   //           showTitles: true,
//   //           getTitles: (value) {
//   //             const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//   //             return days[value.toInt()];
//   //           },
//   //         ),
//   //       ),
//   //       barGroups: [
//   //         for (int i = 0; i < 7; i++)
//   //           BarChartGroupData(
//   //             x: i,
//   //             barRods: [
//   //               BarChartRodData(
//   //                 y: earnings[i].toDouble(), // Your data here
//   //                 colors: [Colors.blueAccent],
//   //               ),
//   //             ],
//   //           ),
//   //       ],
//   //     ),
//   //   );
//   // }
// }
// // Navigator.push(
// //   context,
// //   PageRouteBuilder(
// //     transitionDuration: const Duration(milliseconds: 500),
// //     pageBuilder: (_, __, ___) => PayoutDetailsScreen(),
// //     transitionsBuilder: (_, animation, __, child) {
// //       return FadeTransition(opacity: animation, child: child);
// //     },
// //   ),
// // );

// // import 'dart:convert';
// // import 'package:aminidriver/Container/utils/api_constant.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;

// // class PaymentScreen extends StatefulWidget {
// //   const PaymentScreen({super.key});

// //   @override
// //   State<PaymentScreen> createState() => _PaymentScreenState();
// // }

// // class _PaymentScreenState extends State<PaymentScreen> {
// //   double walletBalance = 0.0;
// //   double weeklyEarnings = 0.0;
// //   List<Map<String, dynamic>> payouts = [];
// //   double depositAmount = 0.0;

// //   String driverId = ""; // replace dynamically

// //   @override
// //   void initState() {
// //     super.initState();
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user != null) {
// //       driverId = user.uid;
// //     }
// //     fetchPayments();
// //   }

// //   // Fetch Payment Data
// //   Future<void> fetchPayments() async {
// //     try {
// //       final response = await http.get(Uri.parse('$baseUrl/Payments/$driverId'));
// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         setState(() {
// //           walletBalance = data['walletBalance'];
// //           weeklyEarnings = data['weeklyEarnings'];
// //           payouts = List<Map<String, dynamic>>.from(data['payouts']);
// //         });
// //       } else {
// //         debugPrint('Failed to fetch payments: ${response.body}');
// //       }
// //     } catch (e) {
// //       debugPrint('Error fetching payment data: $e');
// //     }
// //   }

// //   // Withdraw Funds
// //   Future<void> withdrawFunds() async {
// //     try {
// //       final response = await http.post(
// //         Uri.parse('$baseUrl/Payments/withdraw/$driverId'),
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({'driverId': driverId, 'amount': walletBalance}),
// //       );

// //       if (response.statusCode == 200) {
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(const SnackBar(content: Text('Withdrawal successful!')));
// //         fetchPayments(); // Refresh data
// //       } else {
// //         debugPrint('Withdrawal failed: ${response.body}');
// //       }
// //     } catch (e) {
// //       debugPrint('Error withdrawing funds: $e');
// //     }
// //   }

// //   // Deposit Funds
// //   Future<void> depositFunds() async {
// //     try {
// //       final response = await http.post(
// //         Uri.parse('$baseUrl/Payments/deposit/$driverId'),
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({'driverId': driverId, 'amount': depositAmount}),
// //       );

// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         setState(() {
// //           walletBalance = data['updatedBalance'];
// //         });
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(SnackBar(content: Text(data['message'])));
// //       } else {
// //         debugPrint('Deposit failed: ${response.body}');
// //       }
// //     } catch (e) {
// //       debugPrint('Error depositing funds: $e');
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final Size size = MediaQuery.sizeOf(context);
// //     final isDark = Theme.of(context).brightness == Brightness.dark;

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("Payments"),
// //         //backgroundColor: Colors.blue,
// //         foregroundColor: Colors.black,
// //         elevation: 0,
// //       ),
// //       body: SafeArea(
// //         child: SingleChildScrollView(
// //           child: Container(
// //             width: size.width,
// //             padding: const EdgeInsets.all(16.0),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 // Wallet Summary
// //                 Container(
// //                   padding: const EdgeInsets.all(16),
// //                   decoration: BoxDecoration(
// //                     color: Colors.grey[700],
// //                     borderRadius: BorderRadius.circular(16),
// //                   ),
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text(
// //                         "Wallet Balance",
// //                         style: TextStyle(fontSize: 16, color: Colors.white),
// //                       ),
// //                       const SizedBox(height: 8),
// //                       Text(
// //                         "KES ${walletBalance.toStringAsFixed(2)}",
// //                         style: TextStyle(
// //                           fontSize: 32,
// //                           fontWeight: FontWeight.bold,
// //                           color: isDark ? Colors.white : Colors.black,
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //                 const SizedBox(height: 20),

// //                 // Weekly Earnings Summary
// //                 Text(
// //                   "Earnings Summary",
// //                   //style: Theme.of(context).textTheme.s,
// //                 ),
// //                 const SizedBox(height: 10),
// //                 Card(
// //                   color: Colors.grey[700],
// //                   elevation: 2,
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(12),
// //                   ),
// //                   child: ListTile(
// //                     leading: const Icon(
// //                       Icons.calendar_today,
// //                       color: Colors.white,
// //                     ),
// //                     title: const Text("This Week"),
// //                     subtitle: const Text("Trips: 34 | Hours: 29"),
// //                     trailing: Text(
// //                       "KES ${weeklyEarnings.toStringAsFixed(2)}",
// //                       style: const TextStyle(
// //                         fontWeight: FontWeight.bold,
// //                         color: Colors.white,
// //                       ),
// //                     ),
// //                   ),
// //                 ),

// //                 const SizedBox(height: 20),

// //                 // Deposit Input
// //                 TextField(
// //                   decoration: const InputDecoration(
// //                     labelText: 'Amount to Deposit',
// //                     labelStyle: TextStyle(
// //                       fontWeight: FontWeight.bold,
// //                       color: Colors.black,
// //                     ),
// //                     prefixIcon: Icon(Icons.money),
// //                   ),
// //                   keyboardType: TextInputType.number,
// //                   onChanged: (value) {
// //                     setState(() {
// //                       depositAmount = double.tryParse(value) ?? 0.0;
// //                     });
// //                   },
// //                 ),
// //                 const SizedBox(height: 20),

// //                 // Deposit Button
// //                 Center(
// //                   child: ElevatedButton.icon(
// //                     onPressed:
// //                         depositAmount > 0
// //                             ? depositFunds
// //                             : null, // Disabled if depositAmount is <= 0
// //                     icon: const Icon(
// //                       Icons.account_balance_wallet_outlined,
// //                       color: Colors.white,
// //                     ),
// //                     label: const Text("Deposit Funds"),
// //                     style: ElevatedButton.styleFrom(
// //                       foregroundColor: Colors.white,
// //                       backgroundColor: Colors.grey[700],
// //                       padding: const EdgeInsets.symmetric(
// //                         vertical: 12,
// //                         horizontal: 24,
// //                       ),
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(12),
// //                       ),
// //                     ),
// //                   ),
// //                 ),

// //                 const SizedBox(height: 20),

// //                 // Withdraw Button
// //                 Center(
// //                   child: ElevatedButton.icon(
// //                     onPressed:
// //                         walletBalance > 0
// //                             ? withdrawFunds
// //                             : null, // Disabled if walletBalance is <= 0
// //                     icon: const Icon(
// //                       Icons.account_balance_wallet_outlined,
// //                       color: Colors.white,
// //                     ),
// //                     label: const Text("Withdraw Funds"),
// //                     style: ElevatedButton.styleFrom(
// //                       foregroundColor: Colors.white,
// //                       backgroundColor: Colors.grey[700],
// //                       padding: const EdgeInsets.symmetric(
// //                         vertical: 12,
// //                         horizontal: 24,
// //                       ),
// //                       shape: RoundedRectangleBorder(
// //                         borderRadius: BorderRadius.circular(12),
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }


// // // import 'dart:convert';
// // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:http/http.dart' as http;

// // // class PaymentScreen extends StatefulWidget {
// // //   const PaymentScreen({super.key});

// // //   @override
// // //   State<PaymentScreen> createState() => _PaymentScreenState();
// // // }

// // // class _PaymentScreenState extends State<PaymentScreen> {
// // //   double walletBalance = 0.0;
// // //   double weeklyEarnings = 0.0;
// // //   List<Map<String, dynamic>> payouts = [];
// // //   double depositAmount = 0.0;

// // //   String driverId = ""; // replace dynamically

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     final user = FirebaseAuth.instance.currentUser;
// // //     if (user != null) {
// // //       driverId = user.uid;
// // //     }
// // //     fetchPayments();
// // //   }

// // //   // Fetch Payment Data
// // //   Future<void> fetchPayments() async {
// // //     try {
// // //       final response = await http.get(Uri.parse('$baseUrl/Payments/$driverId'));
// // //       if (response.statusCode == 200) {
// // //         final data = jsonDecode(response.body);
// // //         setState(() {
// // //           walletBalance = data['walletBalance'];
// // //           weeklyEarnings = data['weeklyEarnings'];
// // //           payouts = List<Map<String, dynamic>>.from(data['payouts']);
// // //         });
// // //       } else {
// // //         debugPrint('Failed to fetch payments: ${response.body}');
// // //       }
// // //     } catch (e) {
// // //       debugPrint('Error fetching payment data: $e');
// // //     }
// // //   }

// // //   // Withdraw Funds
// // //   Future<void> withdrawFunds() async {
// // //     try {
// // //       final response = await http.post(
// // //         Uri.parse('$baseUrl/Payments/withdraw/$driverId'),
// // //         headers: {'Content-Type': 'application/json'},
// // //         body: jsonEncode({'driverId': driverId, 'amount': walletBalance}),
// // //       );

// // //       if (response.statusCode == 200) {
// // //         ScaffoldMessenger.of(
// // //           context,
// // //         ).showSnackBar(const SnackBar(content: Text('Withdrawal successful!')));
// // //         fetchPayments(); // Refresh data
// // //       } else {
// // //         debugPrint('Withdrawal failed: ${response.body}');
// // //       }
// // //     } catch (e) {
// // //       debugPrint('Error withdrawing funds: $e');
// // //     }
// // //   }

// // //   // Deposit Funds
// // //   Future<void> depositFunds() async {
// // //     try {
// // //       final response = await http.post(
// // //         Uri.parse('$baseUrl/Payments/deposit/$driverId'),
// // //         headers: {'Content-Type': 'application/json'},
// // //         body: jsonEncode({'driverId': driverId, 'amount': depositAmount}),
// // //       );

// // //       if (response.statusCode == 200) {
// // //         final data = jsonDecode(response.body);
// // //         setState(() {
// // //           walletBalance = data['updatedBalance'];
// // //         });
// // //         ScaffoldMessenger.of(
// // //           context,
// // //         ).showSnackBar(SnackBar(content: Text(data['message'])));
// // //       } else {
// // //         debugPrint('Deposit failed: ${response.body}');
// // //       }
// // //     } catch (e) {
// // //       debugPrint('Error depositing funds: $e');
// // //     }
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final Size size = MediaQuery.sizeOf(context);
// // //     final isDark = Theme.of(context).brightness == Brightness.dark;

// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         title: const Text("Payments"),
// // //         backgroundColor: Colors.blue,
// // //         foregroundColor: Colors.white,
// // //         elevation: 0,
// // //       ),
// // //       body: SafeArea(
// // //         child: SingleChildScrollView(
// // //           child: Container(
// // //             width: size.width,
// // //             padding: const EdgeInsets.all(16.0),
// // //             child: Column(
// // //               crossAxisAlignment: CrossAxisAlignment.start,
// // //               children: [
// // //                 // Wallet Summary
// // //                 Container(
// // //                   padding: const EdgeInsets.all(16),
// // //                   decoration: BoxDecoration(
// // //                     color: isDark ? Colors.grey[900] : Colors.grey[200],
// // //                     borderRadius: BorderRadius.circular(16),
// // //                   ),
// // //                   child: Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     children: [
// // //                       Text(
// // //                         "Wallet Balance",
// // //                         style: TextStyle(
// // //                           fontSize: 16,
// // //                           color: isDark ? Colors.white70 : Colors.black87,
// // //                         ),
// // //                       ),
// // //                       const SizedBox(height: 8),
// // //                       Text(
// // //                         "KES ${walletBalance.toStringAsFixed(2)}",
// // //                         style: TextStyle(
// // //                           fontSize: 32,
// // //                           fontWeight: FontWeight.bold,
// // //                           color: isDark ? Colors.white : Colors.black,
// // //                         ),
// // //                       ),
// // //                     ],
// // //                   ),
// // //                 ),
// // //                 const SizedBox(height: 20),

// // //                 // Weekly Earnings Summary
// // //                 Text(
// // //                   "Earnings Summary",
// // //                   style: Theme.of(context).textTheme.titleMedium,
// // //                 ),
// // //                 const SizedBox(height: 10),
// // //                 Card(
// // //                   color: isDark ? Colors.grey[850] : Colors.white,
// // //                   elevation: 2,
// // //                   shape: RoundedRectangleBorder(
// // //                     borderRadius: BorderRadius.circular(12),
// // //                   ),
// // //                   child: ListTile(
// // //                     leading: const Icon(
// // //                       Icons.calendar_today,
// // //                       color: Colors.amber,
// // //                     ),
// // //                     title: const Text("This Week"),
// // //                     subtitle: const Text("Trips: 34 | Hours: 29"),
// // //                     trailing: Text(
// // //                       "KES ${weeklyEarnings.toStringAsFixed(2)}",
// // //                       style: const TextStyle(fontWeight: FontWeight.bold),
// // //                     ),
// // //                   ),
// // //                 ),

// // //                 const SizedBox(height: 20),

// // //                 // Deposit Input
// // //                 TextField(
// // //                   decoration: const InputDecoration(
// // //                     labelText: 'Amount to Deposit',
// // //                     prefixIcon: Icon(Icons.money),
// // //                   ),
// // //                   keyboardType: TextInputType.number,
// // //                   onChanged: (value) {
// // //                     setState(() {
// // //                       depositAmount = double.tryParse(value) ?? 0.0;
// // //                     });
// // //                   },
// // //                 ),
// // //                 const SizedBox(height: 20),

// // //                 // Deposit Button
// // //                 Center(
// // //                   child: ElevatedButton.icon(
// // //                     onPressed: depositFunds,
// // //                     icon: const Icon(
// // //                       Icons.account_balance_wallet_outlined,
// // //                       color: Colors.white,
// // //                     ),
// // //                     label: const Text("Deposit Funds"),
// // //                     style: ElevatedButton.styleFrom(
// // //                       foregroundColor: Colors.black,
// // //                       backgroundColor: Colors.green,
// // //                       padding: const EdgeInsets.symmetric(
// // //                         vertical: 12,
// // //                         horizontal: 24,
// // //                       ),
// // //                       shape: RoundedRectangleBorder(
// // //                         borderRadius: BorderRadius.circular(12),
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ),

// // //                 const SizedBox(height: 20),

// // //                 // Withdraw Button
// // //                 Center(
// // //                   child: ElevatedButton.icon(
// // //                     onPressed: withdrawFunds,
// // //                     icon: const Icon(
// // //                       Icons.account_balance_wallet_outlined,
// // //                       color: Colors.white,
// // //                     ),
// // //                     label: const Text("Withdraw Funds"),
// // //                     style: ElevatedButton.styleFrom(
// // //                       foregroundColor: Colors.black,
// // //                       backgroundColor: Colors.yellow,
// // //                       padding: const EdgeInsets.symmetric(
// // //                         vertical: 12,
// // //                         horizontal: 24,
// // //                       ),
// // //                       shape: RoundedRectangleBorder(
// // //                         borderRadius: BorderRadius.circular(12),
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ),
// // //               ],
// // //             ),
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }



// // // import 'dart:convert';
// // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:http/http.dart' as http;

// // // class PaymentScreen extends StatefulWidget {
// // //   const PaymentScreen({super.key});

// // //   @override
// // //   State<PaymentScreen> createState() => _PaymentScreenState();
// // // }

// // // class _PaymentScreenState extends State<PaymentScreen> {
// // //   double walletBalance = 0.0;
// // //   double weeklyEarnings = 0.0;
// // //   List<Map<String, dynamic>> payouts = [];

// // //   String driverId = ""; // replace dynamically
// // //   //final String apiBase = "https://yourapi.com/api";

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     final user = FirebaseAuth.instance.currentUser;
// // //     if (user != null) {
// // //       driverId = user.uid;
// // //       //email = user.email ?? '';
// // //     }
// // //     fetchPayments();
// // //   }

// // //   Future<void> fetchPayments() async {
// // //     try {
// // //       final response = await http.get(Uri.parse('$baseUrl/Payments/$driverId'));
// // //       if (response.statusCode == 200) {
// // //         final data = jsonDecode(response.body);
// // //         setState(() {
// // //           walletBalance = data['walletBalance'];
// // //           weeklyEarnings = data['weeklyEarnings'];
// // //           payouts = List<Map<String, dynamic>>.from(data['payouts']);
// // //         });
// // //       } else {
// // //         debugPrint('Failed to fetch payments: ${response.body}');
// // //       }
// // //     } catch (e) {
// // //       debugPrint('Error fetching payment data: $e');
// // //     }
// // //   }

// // //   Future<void> withdrawFunds() async {
// // //     try {
// // //       final response = await http.post(
// // //         Uri.parse('$apiBase/Payments/withdraw/$driverId'),
// // //         headers: {'Content-Type': 'application/json'},
// // //         body: jsonEncode({'driverId': driverId, 'amount': walletBalance}),
// // //       );

// // //       if (response.statusCode == 200) {
// // //         ScaffoldMessenger.of(context).showSnackBar(
// // //           const SnackBar(content: Text('Withdrawal successful!')),
// // //         );
// // //         fetchPayments(); // Refresh data
// // //       } else {
// // //         debugPrint('Withdrawal failed: ${response.body}');
// // //       }
// // //     } catch (e) {
// // //       debugPrint('Error withdrawing funds: $e');
// // //     }
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final Size size = MediaQuery.sizeOf(context);
// // //     final isDark = Theme.of(context).brightness == Brightness.dark;

// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         title: const Text("Payments"),
// // //         backgroundColor: Colors.blue,
// // //         foregroundColor: Colors.white,
// // //         elevation: 0,
// // //       ),
// // //       body: SafeArea(
// // //         child: SingleChildScrollView(
// // //           child: Container(
// // //             width: size.width,
// // //             padding: const EdgeInsets.all(16.0),
// // //             child: Column(
// // //               crossAxisAlignment: CrossAxisAlignment.start,
// // //               children: [
// // //                 // Wallet Summary
// // //                 Container(
// // //                   padding: const EdgeInsets.all(16),
// // //                   decoration: BoxDecoration(
// // //                     color: isDark ? Colors.grey[900] : Colors.grey[200],
// // //                     borderRadius: BorderRadius.circular(16),
// // //                   ),
// // //                   child: Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     children: [
// // //                       Text(
// // //                         "Wallet Balance",
// // //                         style: TextStyle(
// // //                           fontSize: 16,
// // //                           color: isDark ? Colors.white70 : Colors.black87,
// // //                         ),
// // //                       ),
// // //                       const SizedBox(height: 8),
// // //                       Text(
// // //                         "KES ${walletBalance.toStringAsFixed(2)}",
// // //                         style: TextStyle(
// // //                           fontSize: 32,
// // //                           fontWeight: FontWeight.bold,
// // //                           color: isDark ? Colors.white : Colors.black,
// // //                         ),
// // //                       ),
// // //                     ],
// // //                   ),
// // //                 ),
// // //                 const SizedBox(height: 20),

// // //                 // Weekly Earnings Summary
// // //                 Text(
// // //                   "Earnings Summary",
// // //                   style: Theme.of(context).textTheme.titleMedium,
// // //                 ),
// // //                 const SizedBox(height: 10),
// // //                 Card(
// // //                   color: isDark ? Colors.grey[850] : Colors.white,
// // //                   elevation: 2,
// // //                   shape: RoundedRectangleBorder(
// // //                     borderRadius: BorderRadius.circular(12),
// // //                   ),
// // //                   child: ListTile(
// // //                     leading: const Icon(Icons.calendar_today, color: Colors.amber),
// // //                     title: const Text("This Week"),
// // //                     subtitle: const Text("Trips: 34 | Hours: 29"), // optional details
// // //                     trailing: Text(
// // //                       "KES ${weeklyEarnings.toStringAsFixed(2)}",
// // //                       style: const TextStyle(fontWeight: FontWeight.bold),
// // //                     ),
// // //                   ),
// // //                 ),

// // //                 const SizedBox(height: 20),

// // //                 // Payment History
// // //                 Text(
// // //                   "Recent Payouts",
// // //                   style: Theme.of(context).textTheme.titleMedium,
// // //                 ),
// // //                 const SizedBox(height: 10),
// // //                 ...payouts.map((payout) {
// // //                   return Card(
// // //                     color: isDark ? Colors.grey[850] : Colors.white,
// // //                     child: ListTile(
// // //                       leading: const Icon(Icons.payments_outlined, color: Colors.blue),
// // //                       title: Text(payout['title'] ?? "Payout to M-PESA"),
// // //                       subtitle: Text(payout['date']),
// // //                       trailing: Text("KES ${payout['amount']}"),
// // //                     ),
// // //                   );
// // //                 }).toList(),

// // //                 const SizedBox(height: 20),

// // //                 // Withdraw Button
// // //                 Center(
// // //                   child: ElevatedButton.icon(
// // //                     onPressed: withdrawFunds,
// // //                     icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white),
// // //                     label: const Text("Withdraw Funds"),
// // //                     style: ElevatedButton.styleFrom(
// // //                       foregroundColor: Colors.black,
// // //                       backgroundColor: Colors.yellow,
// // //                       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
// // //                       shape: RoundedRectangleBorder(
// // //                         borderRadius: BorderRadius.circular(12),
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ),
// // //               ],
// // //             ),
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }



// // // // import 'package:flutter/material.dart';

// // // // class PaymentScreen extends StatefulWidget {
// // // //   const PaymentScreen({super.key});

// // // //   @override
// // // //   State<PaymentScreen> createState() => _PaymentScreenState();
// // // // }

// // // // class _PaymentScreenState extends State<PaymentScreen> {
// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //       Size size = MediaQuery.sizeOf(context);
// // // //     return Scaffold(
// // // //       body: SafeArea(
// // // //         child: SizedBox(
// // // //          width:size.width,
// // // //          height:size.height,
// // // //           child:const Column(
// // // //             children: [],
// // // //         ),
// // // //        )
// // // //       ),
// // // //     );
// // // //   }
// // // // }

// // // import 'package:flutter/material.dart';
// // // import 'dart:convert';
// // // import 'package:http/http.dart' as http;

// // // class PaymentScreen extends StatefulWidget {
// // //   const PaymentScreen({super.key});

// // //   @override
// // //   State<PaymentScreen> createState() => _PaymentScreenState();
// // // }

// // // class _PaymentScreenState extends State<PaymentScreen> {
// // //   List<Map<String, dynamic>> _payouts = [];
// // //   bool _isLoading = true;

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     fetchPayments();
// // //   }

// // //   Future<void> fetchPayments() async {
// // //     try {
// // //       // Replace this with your real API endpoint
// // //       final response = await http.get(Uri.parse('https://example.com/api/payments'));

// // //       if (response.statusCode == 200) {
// // //         final List<dynamic> data = jsonDecode(response.body);
// // //         setState(() {
// // //           _payouts = data.map((e) => e as Map<String, dynamic>).toList();
// // //           _isLoading = false;
// // //         });
// // //       } else {
// // //         throw Exception("Failed to load payments");
// // //       }
// // //     } catch (e) {
// // //       debugPrint("Error fetching payments: $e");
// // //       setState(() {
// // //         _isLoading = false;
// // //       });
// // //     }
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final Size size = MediaQuery.sizeOf(context);
// // //     final isDark = Theme.of(context).brightness == Brightness.dark;

// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         title: const Text("Payments"),
// // //         backgroundColor: Colors.blue, // Blue AppBar
// // //         foregroundColor: Colors.white,
// // //         elevation: 0,
// // //       ),
// // //       body: SafeArea(
// // //         child: SingleChildScrollView(
// // //           child: Container(
// // //             width: size.width,
// // //             padding: const EdgeInsets.all(16.0),
// // //             child: Column(
// // //               crossAxisAlignment: CrossAxisAlignment.start,
// // //               children: [
// // //                 // Wallet Summary
// // //                 Container(
// // //                   padding: const EdgeInsets.all(16),
// // //                   decoration: BoxDecoration(
// // //                     color: Colors.blue,
// // //                     borderRadius: BorderRadius.circular(16),
// // //                   ),
// // //                   child: Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     children: [
// // //                       const Text(
// // //                         "Wallet Balance",
// // //                         style: TextStyle(
// // //                           fontSize: 16,
// // //                           color: Colors.white,
// // //                         ),
// // //                       ),
// // //                       const SizedBox(height: 8),
// // //                       const Text(
// // //                         "KES 5,200.00",
// // //                         style: TextStyle(
// // //                           fontSize: 32,
// // //                           fontWeight: FontWeight.bold,
// // //                           color: Colors.white,
// // //                         ),
// // //                       ),
// // //                     ],
// // //                   ),
// // //                 ),
// // //                 const SizedBox(height: 20),

// // //                 // Weekly Earnings Summary
// // //                 Text(
// // //                   "Earnings Summary",
// // //                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
// // //                         color: isDark ? Colors.white : Colors.black,
// // //                       ),
// // //                 ),
// // //                 const SizedBox(height: 10),
// // //                 Card(
// // //                   color: Colors.blue,
// // //                   elevation: 2,
// // //                   shape: RoundedRectangleBorder(
// // //                     borderRadius: BorderRadius.circular(12),
// // //                   ),
// // //                   child: ListTile(
// // //                     leading: const Icon(
// // //                       Icons.calendar_today,
// // //                       color: Colors.yellow,
// // //                     ),
// // //                     title: const Text(
// // //                       "This Week",
// // //                       style: TextStyle(color: Colors.white),
// // //                     ),
// // //                     subtitle: const Text(
// // //                       "Trips: 34 | Hours: 29",
// // //                       style: TextStyle(color: Colors.white70),
// // //                     ),
// // //                     trailing: const Text(
// // //                       "KES 15,700",
// // //                       style: TextStyle(
// // //                           fontWeight: FontWeight.bold, color: Colors.white),
// // //                     ),
// // //                   ),
// // //                 ),
// // //                 const SizedBox(height: 20),

// // //                 // Payment History
// // //                 Text(
// // //                   "Recent Payouts",
// // //                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
// // //                         color: isDark ? Colors.white : Colors.black,
// // //                       ),
// // //                 ),
// // //                 const SizedBox(height: 10),
// // //                 _isLoading
// // //                     ? const Center(child: CircularProgressIndicator())
// // //                     : Column(
// // //                         children: _payouts
// // //                             .map((payout) => Card(
// // //                                   color: isDark ? Colors.grey[850] : Colors.white,
// // //                                   child: ListTile(
// // //                                     leading: const Icon(
// // //                                       Icons.payments_outlined,
// // //                                       color: Colors.blue,
// // //                                     ),
// // //                                     title: Text("Payout to ${payout['method']}"),
// // //                                     subtitle: Text(payout['date']),
// // //                                     trailing:
// // //                                         Text("KES ${payout['amount'].toString()}"),
// // //                                   ),
// // //                                 ))
// // //                             .toList(),
// // //                       ),
// // //                 const SizedBox(height: 20),

// // //                 // Withdraw Button
// // //                 Center(
// // //                   child: ElevatedButton.icon(
// // //                     onPressed: () {
// // //                       // TODO: Implement withdrawal logic
// // //                     },
// // //                     icon: const Icon(
// // //                       Icons.account_balance_wallet_outlined,
// // //                       color: Colors.white,
// // //                     ),
// // //                     label: const Text("Withdraw Funds"),
// // //                     style: ElevatedButton.styleFrom(
// // //                       foregroundColor: Colors.black, // Black font
// // //                       backgroundColor: Colors.yellow, // Yellow button
// // //                       padding: const EdgeInsets.symmetric(
// // //                         vertical: 12,
// // //                         horizontal: 24,
// // //                       ),
// // //                       shape: RoundedRectangleBorder(
// // //                         borderRadius: BorderRadius.circular(12),
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ),
// // //               ],
// // //             ),
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
