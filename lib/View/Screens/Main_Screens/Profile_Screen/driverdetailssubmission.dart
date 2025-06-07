import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:firebase_storage/firebase_storage.dart';

void handleDriverSubmit(Map<String, dynamic> data, BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Not logged in')));
    return;
  }

  try {
    // Upload files to Firebase Storage and collect URLs
    final Map<String, String> fileUrls = {};
    for (final entry in (data['documents'] as Map<String, File?>).entries) {
      if (entry.value != null) {
        // final storageRef = FirebaseStorage.instance
        //     .ref()
        //     .child('driver_documents/$uid/${entry.key}_${DateTime.now().millisecondsSinceEpoch}');
        //final uploadTask = await storageRef.putFile(entry.value!);
        //final downloadUrl = await uploadTask.ref.getDownloadURL();
        //fileUrls[entry.key] = downloadUrl;
      }
    }

    // Compose API payload
    final payload = {
      "uid": uid,
      "firstName": data['firstName'],
      "middleName": data['middleName'],
      "lastName": data['lastName'],
      "idType": data['idType'],
      "idNumber": data['idNumber'],
      "paymentMobile": data['paymentMobile'],
      "referralCode": data['referralCode'],
      "licenseExpiry": data['licenseExpiry'],
      "documents": fileUrls,
    };

    // Post to your backend
    final response = await http.post(
      Uri.parse('https://yourapi.com/api/driver/onboarding'),
      headers: {
        "Content-Type": "application/json",
        "Authorization":
            "Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver onboarding successful')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backend error: ${response.statusCode}')),
      );
    }
  } catch (e) {
    print("Error: $e");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}
