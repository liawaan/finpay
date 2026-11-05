/// Aturan validasi input untuk alur autentikasi.
///
/// Semua fungsi mengembalikan `null` kalau input valid, atau pesan error
/// (bahasa Indonesia) kalau tidak. Dipisah dari UI supaya mudah dites.
abstract final class AuthValidators {
  /// "0812-3456-7890", "+62 812 3456 7890", "6281234567890"
  /// semuanya jadi "81234567890".
  static String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits;
  }

  static String? phone(String input) {
    final digits = normalizePhone(input);
    if (digits.isEmpty) return 'Nomor HP wajib diisi';
    if (!digits.startsWith('8')) {
      return 'Nomor HP harus diawali 8 (contoh 812-3456-7890)';
    }
    if (digits.length < 9 || digits.length > 12) {
      return 'Nomor HP harus 9–12 digit';
    }
    return null;
  }

  static String? email(String input) {
    final value = input.trim();
    if (value.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  static String? name(String input) {
    final value = input.trim();
    if (value.length < 3) return 'Isi nama lengkap sesuai KTP';
    if (!RegExp(r"^[\p{L} .'\-]+$", unicode: true).hasMatch(value)) {
      return 'Nama hanya boleh huruf';
    }
    return null;
  }

  /// Usia minimal 17 tahun.
  static String? birthDate(DateTime? date, {DateTime? now}) {
    if (date == null) return 'Pilih tanggal lahir';
    final today = now ?? DateTime.now();
    var age = today.year - date.year;
    if (today.month < date.month ||
        (today.month == date.month && today.day < date.day)) {
      age--;
    }
    if (age < 17) return 'Usia minimal 17 tahun';
    return null;
  }

  /// Kode referral opsional. Format: FINPAY-XXXX (4–8 huruf/angka).
  static String? referral(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^FINPAY-[A-Z0-9]{4,8}$').hasMatch(value)) {
      return 'Format kode tidak dikenali';
    }
    return null;
  }

  static bool isValidReferral(String input) =>
      input.trim().isNotEmpty && referral(input) == null;

  /// Alasan kenapa PIN dianggap lemah, atau `null` kalau PIN cukup kuat.
  static String? pinProblem(String pin, {DateTime? birthDate}) {
    if (pin.split('').toSet().length == 1) {
      return 'PIN tidak boleh angka yang sama semua.';
    }
    if ('0123456789'.contains(pin) || '9876543210'.contains(pin)) {
      return 'PIN tidak boleh angka berurutan.';
    }
    if (RegExp(r'^(\d\d)\1\1$').hasMatch(pin)) {
      return 'PIN tidak boleh pola yang berulang.';
    }
    if (birthDate != null) {
      String two(int v) => v.toString().padLeft(2, '0');
      final dd = two(birthDate.day);
      final mm = two(birthDate.month);
      final yy = two(birthDate.year % 100);
      if (<String>{'$dd$mm$yy', '$yy$mm$dd', '$mm$dd$yy'}.contains(pin)) {
        return 'PIN tidak boleh memakai tanggal lahirmu.';
      }
    }
    return null;
  }
}
