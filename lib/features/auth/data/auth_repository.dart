import '../utils/auth_validators.dart';

/// Akun pengguna FinPay.
///
/// CATATAN KEAMANAN: di sini PIN disimpan apa adanya hanya karena ini data
/// demo di memori. Di aplikasi sungguhan PIN TIDAK pernah disimpan di klien;
/// verifikasi dilakukan di server terhadap hash (mis. Argon2/bcrypt).
class Account {
  const Account({
    required this.name,
    required this.phone,
    required this.email,
    required this.pin,
    this.birthDate,
  });

  final String name;

  /// Sudah dinormalisasi: tanpa 0 / 62 di depan, mis. "81234567890".
  final String phone;
  final String email;
  final String pin;
  final DateTime? birthDate;

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? name : parts.first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final second = parts.length > 1 ? parts[1][0] : '';
    return (parts.first[0] + second).toUpperCase();
  }

  /// "+62 812-••••-90"
  String get maskedPhone {
    if (phone.length < 6) return '+62 $phone';
    return '+62 ${phone.substring(0, 3)}-••••-${phone.substring(phone.length - 2)}';
  }

  Account copyWith({String? pin}) => Account(
        name: name,
        phone: phone,
        email: email,
        pin: pin ?? this.pin,
        birthDate: birthDate,
      );
}

enum LoginStatus { success, wrongCredentials, notFound, locked }

/// Hasil percobaan login.
class LoginResult {
  const LoginResult._(
    this.status, {
    this.account,
    this.attemptsLeft = 0,
    this.lockRemaining = Duration.zero,
  });

  const LoginResult.success(Account account)
      : this._(LoginStatus.success, account: account);

  const LoginResult.wrong(int attemptsLeft)
      : this._(LoginStatus.wrongCredentials, attemptsLeft: attemptsLeft);

  const LoginResult.notFound() : this._(LoginStatus.notFound);

  const LoginResult.locked(Duration remaining)
      : this._(LoginStatus.locked, lockRemaining: remaining);

  final LoginStatus status;
  final Account? account;
  final int attemptsLeft;
  final Duration lockRemaining;

  bool get isSuccess => status == LoginStatus.success;
}

/// Kontrak akses data akun. UI hanya bergantung ke interface ini, jadi
/// saat backend siap cukup tulis implementasi baru (mis. `ApiAuthRepository`)
/// tanpa mengubah halaman-halamannya.
abstract interface class AuthRepository {
  /// Akun yang sedang login (null kalau belum / sudah logout).
  Account? get currentAccount;

  /// Akun yang "diingat" di perangkat ini (untuk login cepat pakai PIN).
  Account? get rememberedAccount;

  bool phoneExists(String phone);

  /// Sisa waktu terkunci untuk nomor ini, atau null kalau tidak terkunci.
  Duration? lockRemainingFor(String phone);

  LoginResult login({
    required String identifier,
    required String secret,
    bool remember = false,
  });

  /// Login cepat untuk akun yang diingat, memakai PIN.
  LoginResult loginRemembered(String pin);

  /// Masuk ke akun yang diingat tanpa PIN (setelah biometrik berhasil).
  Account? signInRemembered();

  /// Mendaftarkan akun baru dan langsung masuk. Melempar [StateError]
  /// kalau nomor sudah terdaftar.
  Account register({
    required String name,
    required String phone,
    required String email,
    required String pin,
    DateTime? birthDate,
  });

  /// Mengganti PIN. Mengembalikan false kalau nomor tidak terdaftar.
  bool resetPin({required String phone, required String newPin});

  void logout();

  void forgetRememberedAccount();
}

/// Implementasi sementara: semua data disimpan di memori dan hilang saat
/// app dimuat ulang. Sudah ada anti brute-force: 5 kali salah = terkunci.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    // Akun demo supaya fitur login bisa dicoba tanpa daftar dulu.
    // PIN-nya sama dengan "PIN lama" di Akun > Ubah PIN.
    const demo = Account(
      name: 'Reza Pratama',
      phone: '81234567890',
      email: 'reza.pratama@email.com',
      pin: '123456',
    );
    _accounts[demo.phone] = demo;
  }

  static const int maxAttempts = 5;

  /// Dipendekkan jadi 30 detik supaya enak didemokan.
  /// Di produksi biasanya 15–30 menit dengan jeda yang makin panjang.
  static const Duration lockDuration = Duration(seconds: 30);

  final DateTime Function() _clock;
  final Map<String, Account> _accounts = {};
  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockedUntil = {};

  Account? _current;
  String? _rememberedPhone;

  @override
  Account? get currentAccount => _current;

  @override
  Account? get rememberedAccount {
    final phone = _rememberedPhone;
    return phone == null ? null : _accounts[phone];
  }

  @override
  bool phoneExists(String phone) =>
      _accounts.containsKey(AuthValidators.normalizePhone(phone));

  @override
  Duration? lockRemainingFor(String phone) {
    final key = AuthValidators.normalizePhone(phone);
    final until = _lockedUntil[key];
    if (until == null) return null;

    final remaining = until.difference(_clock());
    if (remaining <= Duration.zero) {
      _lockedUntil.remove(key);
      _failedAttempts[key] = 0;
      return null;
    }
    return remaining;
  }

  Account? _find(String identifier) {
    final id = identifier.trim();
    if (id.contains('@')) {
      final lower = id.toLowerCase();
      for (final account in _accounts.values) {
        if (account.email.toLowerCase() == lower) return account;
      }
      return null;
    }
    return _accounts[AuthValidators.normalizePhone(id)];
  }

  LoginResult _attempt(
    Account account,
    String secret, {
    required bool remember,
  }) {
    final locked = lockRemainingFor(account.phone);
    if (locked != null) return LoginResult.locked(locked);

    if (account.pin == secret) {
      _failedAttempts[account.phone] = 0;
      _current = account;
      if (remember) _rememberedPhone = account.phone;
      return LoginResult.success(account);
    }

    final failed = (_failedAttempts[account.phone] ?? 0) + 1;
    _failedAttempts[account.phone] = failed;

    if (failed >= maxAttempts) {
      _lockedUntil[account.phone] = _clock().add(lockDuration);
      return const LoginResult.locked(lockDuration);
    }
    return LoginResult.wrong(maxAttempts - failed);
  }

  @override
  LoginResult login({
    required String identifier,
    required String secret,
    bool remember = false,
  }) {
    final account = _find(identifier);
    if (account == null) return const LoginResult.notFound();
    return _attempt(account, secret, remember: remember);
  }

  @override
  LoginResult loginRemembered(String pin) {
    final account = rememberedAccount;
    if (account == null) return const LoginResult.notFound();
    return _attempt(account, pin, remember: true);
  }

  @override
  Account? signInRemembered() {
    final account = rememberedAccount;
    if (account != null) _current = account;
    return account;
  }

  @override
  Account register({
    required String name,
    required String phone,
    required String email,
    required String pin,
    DateTime? birthDate,
  }) {
    final normalized = AuthValidators.normalizePhone(phone);
    if (_accounts.containsKey(normalized)) {
      throw StateError('Nomor sudah terdaftar');
    }
    final account = Account(
      name: name.trim(),
      phone: normalized,
      email: email.trim(),
      pin: pin,
      birthDate: birthDate,
    );
    _accounts[normalized] = account;
    _current = account;
    _rememberedPhone = normalized;
    return account;
  }

  @override
  bool resetPin({required String phone, required String newPin}) {
    final key = AuthValidators.normalizePhone(phone);
    final account = _accounts[key];
    if (account == null) return false;

    _accounts[key] = account.copyWith(pin: newPin);
    _failedAttempts[key] = 0;
    _lockedUntil.remove(key);
    return true;
  }

  @override
  void logout() => _current = null;

  @override
  void forgetRememberedAccount() => _rememberedPhone = null;
}

/// Instance yang dipakai seluruh app. Ganti ke implementasi API nanti.
final AuthRepository authRepository = InMemoryAuthRepository();
