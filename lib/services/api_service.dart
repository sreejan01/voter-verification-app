class ApiService {
  // ✅ Add https:// at the start
  static const String baseUrl =
      "https://voter-verification-backend-vq7k.onrender.com";

  static String get login => "$baseUrl/login";
  static String get verifyOtp => "$baseUrl/verify-otp";
  static String get resendOtp => "$baseUrl/resend-otp";
  static String get verifyVoter => "$baseUrl/verify-voter";
  static String get verificationHistory => "$baseUrl/verification-history";
  static String get dashboardStats => "$baseUrl/dashboard-stats";
  static String get searchVoter => "$baseUrl/search-voter";
}
