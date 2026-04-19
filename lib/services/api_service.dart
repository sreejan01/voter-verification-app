class ApiService {
  // 👇 Change this one line only
  static const bool _isEmulator = true; // true = emulator, false = real device

  static String get baseUrl => _isEmulator
      ? "http://10.0.2.2:5000" // emulator
      : "http://10.71.21.217:5000"; // real device

  static String get login => "$baseUrl/login";
  static String get verifyOtp => "$baseUrl/verify-otp";
  static String get resendOtp => "$baseUrl/resend-otp";
  static String get verifyVoter => "$baseUrl/verify-voter";
  static String get verificationHistory => "$baseUrl/verification-history";
  static String get searchVoter => "$baseUrl/search-voter";
  static String get dashboardStats => "$baseUrl/dashboard-stats";
}
