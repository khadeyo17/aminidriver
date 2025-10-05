import 'dart:convert';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:http/http.dart' as http;

class ApprovalService {
  //final String baseUrl = "http://your-api-url.com/api"; // 🔗 update with your backend URL

  Future<String?> checkApprovalStatus(String firebaseId) async {
    final url = Uri.parse(
      "$baseUrl/vehicles/documents/approval-status/$firebaseId",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['approved']; // "yes" or "no"
      } else {
        return null; // error case
      }
    } catch (e) {
      print("Error fetching approval status: $e");
      return null;
    }
  }
}
