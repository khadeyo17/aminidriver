import 'package:aminidriver/View/Screens/Other_Screens/driver_vehicle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
import 'package:aminidriver/View/Screens/Main_Screens/History_Screen/history_screen.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Profile_Screen/profile_screen.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_providers.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  List<Widget> screens = const [
    HomeScreen(),
    DriverVehiclesScreen(),
    //PaymentScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final currentIndex = ref.watch(navigationStateProvider);

        return Scaffold(
          backgroundColor: Colors.white,
          body: screens[currentIndex],
          bottomNavigationBar: NavigationBar(
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home, color: Colors.grey[700]),
                selectedIcon: Icon(Icons.home, color: Colors.black),
                label: "Home",
              ),
              NavigationDestination(
                icon: Icon(Icons.car_rental, color: Colors.grey[700]),
                selectedIcon: Icon(Icons.car_rental, color: Colors.black),
                label: "Vehicle",
              ),
              NavigationDestination(
                icon: Icon(Icons.history, color: Colors.grey[700]),
                selectedIcon: Icon(Icons.history, color: Colors.black),
                label: "History",
              ),
              NavigationDestination(
                icon: Icon(Icons.person, color: Colors.grey[700]),
                selectedIcon: Icon(Icons.person, color: Colors.black),
                label: "Profile",
              ),
            ],
            onDestinationSelected: (int index) {
              ref.read(navigationStateProvider.notifier).state = index;
            },
            backgroundColor: Colors.white,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: ref.watch(navigationStateProvider),
          ),
        );
      },
    );
  }
}

// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// //import 'package:aminidriver/View/Screens/Main_Screens/map_screen';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/History_Screen/history_screen.dart';
// //import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Payment_Screen/payment_screen.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Profile_Screen/profile_screen.dart';
// import 'package:aminidriver/View/Screens/Nav_Screens/navigation_providers.dart';

// class NavigationScreen extends StatefulWidget {
//   const NavigationScreen({super.key});

//   @override
//   State<NavigationScreen> createState() => _NavigationScreenState();
// }

// class _NavigationScreenState extends State<NavigationScreen> {
//   List<Widget> screens = [
//     const HomeScreen(),
//     //const MapScreen(),
//     const PaymentScreen(),
//     const HistoryScreen(),
//     const ProfileScreen(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Consumer(
//       builder: (context, ref, child) {
//         return Scaffold(
//           body: screens[ref.watch(navigationStateProvider)],
//           bottomNavigationBar: NavigationBar(
//             destinations:  [
//               NavigationDestination(
//                icon: Icon(Icons.home_outlined, color: Colors.yellow),
//                 // label: "",
//                 // selectedIcon: Icon(Icons.home, color: Colors.yellow),
//               ),
//               NavigationDestination(
//                 icon: Icon(Icons.wallet, color: Colors.yellow),
//                 // label: "",
//                 // selectedIcon: Icon(
//                 //   Icons.currency_bitcoin,
//                 //   color: Colors.yellow,
//                 // ),
//               ),
//               NavigationDestination(
//                 icon: Icon(Icons.event, color: Colors.yellow),
//                 // label: "",
//                 // selectedIcon: Icon(Icons.history_edu, color: Colors.yellow),
//               ),
//               NavigationDestination(
//                 //icon: Icon(Icons.person_2_outlined, color: Colors.yellow),
//                 label: "",
//                 selectedIcon: Icon(Icons.person, color: Colors.yellow),
//               ),
//             ],
//             onDestinationSelected: (int selection) {
//               ref
//                   .watch(navigationStateProvider.notifier)
//                   .update((state) => selection);
//             },
//             backgroundColor:
//                 Colors.grey[300], // Blue background for the navigation bar
//             labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
//             selectedIndex: ref.watch(navigationStateProvider),
//           ),
//         );
//       },
//     );
//   }
// }
