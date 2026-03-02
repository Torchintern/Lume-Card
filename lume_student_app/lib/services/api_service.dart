import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = "http://192.168.0.3:5000"; 

  // SEND OTP
  static Future sendOtp(String phone) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/send-otp"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone}),
    );
    return jsonDecode(res.body);
  }

  // VERIFY OTP
  static Future verifyOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/verify-otp"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "otp": otp}),
    );
    return jsonDecode(res.body);
  }

  // SET PIN
  static Future setPin(String phone, String pin) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/set-pin"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "pin": pin}),
    );
    return jsonDecode(res.body);
  }

  // LOGIN PIN
  static Future loginPin(String phone, String pin) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/login-pin"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "pin": pin}),
    );
    return jsonDecode(res.body);
  }
  // GET PROFILE
  static Future getProfile(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/auth/profile"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    return jsonDecode(res.body);
  }

  // UPLOAD PROFILE IMAGE
  static Future uploadProfileImage(String token, String filePath) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/auth/upload-profile-image"),
    );
    request.headers["Authorization"] = "Bearer $token";
    request.files.add(await http.MultipartFile.fromPath('image', filePath));
    
    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    return jsonDecode(res.body);
  }

  static Future removeProfileImage(String token) async {
    final res = await http.post(
      Uri.parse("$baseUrl/auth/remove-profile-image"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    return jsonDecode(res.body);
  }


 // Scholar data
  static Future<bool> submitScholarApplication(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse("$baseUrl/scholar/apply"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      return res["success"] == true;
    }
    return false;
  }

// GET SCHOLAR APPLICATION STATUS
static Future<Map<String, dynamic>> getScholarApplicationStatus(int regId) async {
  final response = await http.get(
    Uri.parse("$baseUrl/scholar/status/$regId"),
    headers: {
      "Content-Type": "application/json",
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }

  return {
    "hasApplication": false,
    "status": null
  };
}

}