/// Tujuan alur verifikasi: daftar akun baru atau pemulihan PIN.
enum AuthPurpose { register, resetPin }

/// Data yang dibawa antar halaman dalam satu alur (data diri -> OTP ->
/// buat PIN -> sukses).
class AuthFlowArgs {
  const AuthFlowArgs({
    required this.purpose,
    required this.phone,
    this.name,
    this.email,
    this.birthDate,
    this.referral,
  });

  final AuthPurpose purpose;

  /// Nomor HP ternormalisasi, mis. "81234567890".
  final String phone;
  final String? name;
  final String? email;
  final DateTime? birthDate;
  final String? referral;
}
