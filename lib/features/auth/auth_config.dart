/// Pengaturan kecil untuk alur autentikasi (splash, onboarding, login, register).
abstract final class AuthConfig {
  /// Set `true` di laptop sendiri saat mengerjakan screen lain, supaya app
  /// langsung masuk ke Beranda tanpa splash/onboarding/login.
  /// Jangan di-commit dalam keadaan `true`.
  static const bool skipToHome = false;

  /// Kode OTP demo. Ganti dengan verifikasi backend saat integrasi.
  static const String demoOtp = '1234';
}
