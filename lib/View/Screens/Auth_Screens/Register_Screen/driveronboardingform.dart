// import 'package:flutter/material.dart';
// import 'driveronboardingcontroller.dart';
// import 'vehicleonboardingcontroller.dart';

// class DriverVehicleOnboardingForm extends StatefulWidget {
//   @override
//   _DriverVehicleOnboardingFormState createState() => _DriverVehicleOnboardingFormState();
// }

// class _DriverVehicleOnboardingFormState extends State<DriverVehicleOnboardingForm> {
//   final DriverOnboardingController driverController = DriverOnboardingController();
//   final VehicleOnboardingController vehicleController = VehicleOnboardingController();

//   @override
//   void dispose() {
//     driverController.dispose();
//     vehicleController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Driver & Vehicle Onboarding')),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: driverController.formKey,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 ExpansionTile(
//                   title: const Text("Driver Information", style: TextStyle(fontWeight: FontWeight.bold)),
//                   children: [
//                     TextFormField(
//                       controller: driverController.firstNameController,
//                       decoration: const InputDecoration(labelText: 'First Name'),
//                     ),
//                     TextFormField(
//                       controller: driverController.middleNameController,
//                       decoration: const InputDecoration(labelText: 'Middle Name'),
//                     ),
//                     TextFormField(
//                       controller: driverController.lastNameController,
//                       decoration: const InputDecoration(labelText: 'Last Name'),
//                     ),
//                     DropdownButtonFormField<String>(
//                       value: driverController.selectedIdType,
//                       items: driverController.idTypes.map((type) {
//                         return DropdownMenuItem(value: type, child: Text(type));
//                       }).toList(),
//                       onChanged: (value) {
//                         setState(() {
//                           driverController.selectedIdType = value;
//                         });
//                       },
//                       decoration: const InputDecoration(labelText: 'ID Type'),
//                     ),
//                     TextFormField(
//                       controller: driverController.idNumberController,
//                       decoration: const InputDecoration(labelText: 'ID Number'),
//                     ),
//                     TextFormField(
//                       controller: driverController.paymentMobileController,
//                       decoration: const InputDecoration(labelText: 'Payment Mobile'),
//                     ),
//                     TextFormField(
//                       controller: driverController.referralCodeController,
//                       decoration: const InputDecoration(labelText: 'Referral Code'),
//                     ),
//                     TextFormField(
//                       controller: driverController.licenseExpiryController,
//                       decoration: const InputDecoration(labelText: 'License Expiry'),
//                     ),
//                     const SizedBox(height: 10),
//                     Text("Upload Documents", style: TextStyle(fontWeight: FontWeight.bold)),
//                     ...driverController.docLabels.entries.map((entry) {
//                       return ListTile(
//                         title: Text(entry.value),
//                         trailing: Icon(
//                           driverController.documents[entry.key] != null
//                               ? Icons.check_circle
//                               : Icons.upload_file,
//                           color: driverController.documents[entry.key] != null
//                               ? Colors.green
//                               : null,
//                         ),
//                         onTap: () => driverController.pickFile(context, entry.key, () {
//                           setState(() {});
//                         }),
//                       );
//                     }),
//                   ],
//                 ),
//                 ExpansionTile(
//                   title: const Text("Vehicle Information", style: TextStyle(fontWeight: FontWeight.bold)),
//                   children: [
//                     DropdownButtonFormField<String>(
//                       value: vehicleController.selectedMake,
//                       items: vehicleController.vehicleMakes.map((make) {
//                         return DropdownMenuItem(value: make, child: Text(make));
//                       }).toList(),
//                       onChanged: (value) {
//                         setState(() {
//                           vehicleController.selectedMake = value;
//                           vehicleController.selectedModel = null;
//                         });
//                       },
//                       decoration: const InputDecoration(labelText: 'Vehicle Make'),
//                     ),
//                     DropdownButtonFormField<String>(
//                       value: vehicleController.selectedModel,
//                       items: vehicleController.vehicleModels[vehicleController.selectedMake]?.map((model) {
//                         return DropdownMenuItem(value: model, child: Text(model));
//                       }).toList(),
//                       onChanged: (value) {
//                         setState(() {
//                           vehicleController.selectedModel = value;
//                         });
//                       },
//                       decoration: const InputDecoration(labelText: 'Vehicle Model'),
//                     ),
//                     DropdownButtonFormField<String>(
//                       value: vehicleController.selectedCategory,
//                       items: vehicleController.vehicleCategories.map((cat) {
//                         return DropdownMenuItem(value: cat, child: Text(cat));
//                       }).toList(),
//                       onChanged: (value) {
//                         setState(() {
//                           vehicleController.selectedCategory = value;
//                         });
//                       },
//                       decoration: const InputDecoration(labelText: 'Vehicle Category'),
//                     ),
//                     TextFormField(
//                       controller: vehicleController.registrationNumberController,
//                       decoration: const InputDecoration(labelText: 'Registration Number'),
//                     ),
//                     TextFormField(
//                       controller: vehicleController.yearController,
//                       decoration: const InputDecoration(labelText: 'Year'),
//                     ),
//                     const SizedBox(height: 10),
//                     Text("Upload Vehicle Documents", style: TextStyle(fontWeight: FontWeight.bold)),
//                     ...vehicleController.docLabels.entries.map((entry) {
//                       return ListTile(
//                         title: Text(entry.value),
//                         trailing: Icon(
//                           vehicleController.documents[entry.key] != null
//                               ? Icons.check_circle
//                               : Icons.upload_file,
//                           color: vehicleController.documents[entry.key] != null
//                               ? Colors.green
//                               : null,
//                         ),
//                         onTap: () => vehicleController.pickFile(context, entry.key, () {
//                           setState(() {});
//                         }),
//                       );
//                     }),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: () {
//                     if (driverController.formKey.currentState!.validate()) {
//                       final driverData = driverController.collectData();
//                       final vehicleData = vehicleController.collectData();
//                       print("Driver Data: $driverData");
//                       print("Vehicle Data: $vehicleData");
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Data collected successfully!')),
//                       );
//                     }
//                   },
//                   child: const Text("Submit"),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
