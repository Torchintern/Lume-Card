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

// KYC Status
static Future getKycStatus(int studentId) async {
  final res = await http.get(
    Uri.parse("$baseUrl/kyc/status/$studentId"),
  );

  return jsonDecode(res.body);
}

// KYC Slots
static Future getKycSlots() async {
  final res = await http.get(
    Uri.parse("$baseUrl/kyc/slots"),
  );

  return jsonDecode(res.body);
}

// Book KYC
static Future bookKyc(Map<String,dynamic> data) async {

  final res = await http.post(
    Uri.parse("$baseUrl/kyc/book"),
    headers: {"Content-Type":"application/json"},
    body: jsonEncode(data)
  );

  return jsonDecode(res.body);
}

// GET CARD DETAILS
static Future<Map<String, dynamic>> getCardDetails(String token) async {
  final res = await http.get(
    Uri.parse("$baseUrl/card/details"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token"
    },
  );

  if (res.statusCode == 200) {
    return jsonDecode(res.body);
  }

  return {};
}

// LOCK CARD
static Future lockCard(String token) async {
  final res = await http.post(
    Uri.parse("$baseUrl/card/lock"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token"
    },
  );

  return jsonDecode(res.body);
}

  // UNLOCK CARD
  static Future unlockCard(String token) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/unlock"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    return jsonDecode(res.body);
  }

  // TOGGLE NCMC
  static Future toggleNcmc(String token, bool enabled) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/toggle-ncmc"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({"enabled": enabled}),
    );
    return jsonDecode(res.body);
  }

  // TOGGLE TAP & PAY
  static Future toggleTapPay(String token, bool enabled) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/toggle-tap-pay"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({"enabled": enabled}),
    );
    return jsonDecode(res.body);
  }

  // CARD PIN OTP
  static Future cardSendOtp(String token) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/send-otp"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    return jsonDecode(res.body);
  }

  // CARD PIN VERIFY OTP
  static Future cardVerifyOtp(String token, String otp) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/verify-otp"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({"otp": otp}),
    );
    return jsonDecode(res.body);
  }

  // SET CARD PIN
  static Future setCardPin(String token, String pin) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/set-pin"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({"pin": pin}),
    );
    return jsonDecode(res.body);
  }

  // BLOCK CARD
  static Future blockCard(String token) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/block"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    return jsonDecode(res.body);
  }

  // UPDATE CARD CONTROLS
  static Future updateCardControls(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse("$baseUrl/card/update-controls"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  // GET TRANSACTIONS
  static Future<List<dynamic>> getTransactions(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/card/transactions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }
}