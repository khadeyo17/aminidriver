// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/History_Screen/history_screen.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
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
//             destinations: const [
//               NavigationDestination(
//                 icon: Icon(Icons.home_outlined),
//                 label: "",
//                 selectedIcon: Icon(Icons.home),
//               ),
//               NavigationDestination(
//                 icon: Icon(Icons.currency_bitcoin_outlined),
//                 label: "",
//                 selectedIcon: Icon(Icons.currency_bitcoin),
//               ),
//               NavigationDestination(
//                 icon: Icon(Icons.history_edu_outlined),
//                 label: "",
//                 selectedIcon: Icon(Icons.history_edu),
//               ),
//               NavigationDestination(
//                 icon: Icon(Icons.person_2_outlined),
//                 label: "",
//                 selectedIcon: Icon(Icons.person),
//               ),
//             ],
//             onDestinationSelected: (int selection) {
//               ref
//                   .watch(navigationStateProvider.notifier)
//                   .update((state) => selection);
//             },
//             backgroundColor: Colors.black38,
//             labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
//             selectedIndex: ref.watch(navigationStateProvider),
//           ),
//         );
//       },
//     );
//   }
// }
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
//import 'package:aminidriver/View/Screens/Main_Screens/map_screen';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aminidriver/View/Screens/Main_Screens/History_Screen/history_screen.dart';
//import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Payment_Screen/payment_screen.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Profile_Screen/profile_screen.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_providers.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  List<Widget> screens = [
    const HomeScreen(),
    //const MapScreen(),
    const PaymentScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return Scaffold(
          body: screens[ref.watch(navigationStateProvider)],
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Colors.yellow),
                label: "",
                selectedIcon: Icon(Icons.home, color: Colors.yellow),
              ),
              NavigationDestination(
                icon: Icon(Icons.wallet, color: Colors.yellow),
                label: "",
                selectedIcon: Icon(
                  Icons.currency_bitcoin,
                  color: Colors.yellow,
                ),
              ),
              NavigationDestination(
                icon: Icon(Icons.event, color: Colors.yellow),
                label: "",
                selectedIcon: Icon(Icons.history_edu, color: Colors.yellow),
              ),
              NavigationDestination(
                icon: Icon(Icons.person_2_outlined, color: Colors.yellow),
                label: "",
                selectedIcon: Icon(Icons.person, color: Colors.yellow),
              ),
            ],
            onDestinationSelected: (int selection) {
              ref
                  .watch(navigationStateProvider.notifier)
                  .update((state) => selection);
            },
            backgroundColor:
                Colors.blue, // Blue background for the navigation bar
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: ref.watch(navigationStateProvider),
          ),
        );
      },
    );
  }
}
