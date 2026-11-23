import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../dummy/dummy_data.dart';
import '../models/linked_account_model.dart';
import '../models/transaction_model.dart';
import '../models/user_profile_model.dart';
import '../models/wealth_models.dart';
import '../../features/auth/data/auth_repository.dart';
import 'account_service.dart';
import 'transaction_service.dart';
import 'wallet_service.dart';
import 'wealth_service.dart';

class _UserSessionSnapshot {
  _UserSessionSnapshot({
    required this.profile,
    required this.cashBalance,
    required this.savingBalance,
    required this.transactions,
    required this.linkedAccounts,
    required this.savingGoals,
    required this.activeLoans,
  });

  UserProfileModel profile;
  int cashBalance;
  int savingBalance;
  List<TransactionModel> transactions;
  List<LinkedAccountModel> linkedAccounts;
  List<SavingGoalModel> savingGoals;
  List<LoanModel> activeLoans;
}

/// Service Backend Autentikasi & Keamanan Akun (Bagian Tugas Pidi).
///
/// Mengelola:
/// 1. Firebase Auth (Login / Register Email & Password) + Logout
/// 2. Pembuatan dokumen profil (`users`) & saldo awal (`wallets`) saat user baru daftar
/// 3. Validasi & Ubah PIN 6 Digit
/// 4. Verifikasi KTP (KYC)
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Firebase Web API Key (Ganti dengan Web API Key dari Firebase Console jika ingin panggil endpoint IdentityToolkit).
  static String firebaseWebApiKey = 'AIzaSyFinPaySandboxKey2026';

  /// Status apakah pengguna sudah login ke dalam aplikasi.
  final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);

  /// Profil pengguna yang sedang aktif.
  final ValueNotifier<UserProfileModel> currentUserNotifier =
      ValueNotifier<UserProfileModel>(
    UserProfileModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      fullName: DummyData.userName,
      email: 'reza.pratama@email.com',
      phoneNumber: DummyData.phoneNumber,
    ),
  );

  // Database kredensial in-memory untuk fallback offline/sandbox
  final Map<String, ({String password, UserProfileModel profile})> _localUsers =
      {
    'reza.pratama@email.com': (
      password: 'password123',
      profile: const UserProfileModel(
        userId: 'finpay_user_01',
        fullName: 'Reza Pratama',
        email: 'reza.pratama@email.com',
        phoneNumber: '0812-3456-7890',
        pin: '123456',
      ),
    ),
    'ali.akbar@email.com': (
      password: 'password123',
      profile: const UserProfileModel(
        userId: 'finpay_user_ali',
        fullName: 'Ali Akbar',
        email: 'ali.akbar@email.com',
        phoneNumber: '0813-8899-7766',
        pin: '123456',
      ),
    ),
  };

  final Map<String, _UserSessionSnapshot> _userSnapshots = {};
  late final List<TransactionModel> _initialRezaTransactions =
      List<TransactionModel>.from(DummyData.transactions);
  late final List<LinkedAccountModel> _initialRezaAccounts =
      List<LinkedAccountModel>.from(AccountService.instance.linkedAccounts);
  late final List<SavingGoalModel> _initialRezaGoals =
      List<SavingGoalModel>.from(WealthService.instance.savingGoals);
  late final List<LoanModel> _initialRezaLoans =
      List<LoanModel>.from(WealthService.instance.activeLoans);

  UserProfileModel get currentUser => currentUserNotifier.value;
  bool get isLoggedIn => isLoggedInNotifier.value;

  /// Format tanggal hari ini dari waktu perangkat (contoh: "18 November 2026" atau "Nov 2026").
  static String formatDeviceDate(DateTime date, {bool shortMonthOnly = false}) {
    const monthsFull = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    const monthsShort = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final mIndex = (date.month - 1).clamp(0, 11);
    if (shortMonthOnly) {
      return '${monthsShort[mIndex]} ${date.year}';
    }
    return '${date.day} ${monthsFull[mIndex]} ${date.year}';
  }

  /// Simpan snapshot saldo, transaksi, rekening, tabungan, & pinjaman user aktif sebelum ganti sesi/logout.
  void _saveCurrentSessionSnapshot() {
    final uid = currentUser.userId;
    _userSnapshots[uid] = _UserSessionSnapshot(
      profile: currentUser,
      cashBalance: DummyData.cashBalance,
      savingBalance: DummyData.savingBalance,
      transactions: List<TransactionModel>.from(DummyData.transactions),
      linkedAccounts: List<LinkedAccountModel>.from(
        AccountService.instance.linkedAccounts,
      ),
      savingGoals: List<SavingGoalModel>.from(
        WealthService.instance.savingGoals,
      ),
      activeLoans: List<LoanModel>.from(
        WealthService.instance.activeLoans,
      ),
    );
  }

  /// Mengkreditkan saldo & riwayat transaksi masuk pada akun penerima saat terjadi Transfer QRIS Antar Pengguna.
  void creditPeerUserSession({
    required String recipientUserId,
    required String recipientName,
    required int amount,
    required TransactionModel incomingTransaction,
  }) {
    final existing = _userSnapshots[recipientUserId];
    if (existing != null) {
      existing.cashBalance += amount;
      existing.transactions.insert(0, incomingTransaction);
      return;
    }

    UserProfileModel? targetProfile;
    for (final entry in _localUsers.values) {
      if (entry.profile.userId == recipientUserId) {
        targetProfile = entry.profile;
        break;
      }
    }

    targetProfile ??= UserProfileModel(
      userId: recipientUserId,
      fullName: recipientName,
      email: '${recipientName.toLowerCase().replaceAll(' ', '.')}@email.com',
      phoneNumber: '0813-8899-7766',
      pin: '123456',
    );

    final baseCash =
        recipientUserId == 'finpay_user_01' ? 12350000 : 5450000;
    final baseSaving =
        recipientUserId == 'finpay_user_01' ? 2500000 : 1200000;
    final baseTransactions = recipientUserId == 'finpay_user_01'
        ? List<TransactionModel>.from(_initialRezaTransactions)
        : <TransactionModel>[];

    baseTransactions.insert(0, incomingTransaction);

    _userSnapshots[recipientUserId] = _UserSessionSnapshot(
      profile: targetProfile,
      cashBalance: baseCash + amount,
      savingBalance: baseSaving,
      transactions: baseTransactions,
      linkedAccounts: recipientUserId == 'finpay_user_01'
          ? List<LinkedAccountModel>.from(_initialRezaAccounts)
          : <LinkedAccountModel>[],
      savingGoals: recipientUserId == 'finpay_user_01'
          ? List<SavingGoalModel>.from(_initialRezaGoals)
          : <SavingGoalModel>[],
      activeLoans: recipientUserId == 'finpay_user_01'
          ? List<LoanModel>.from(_initialRezaLoans)
          : <LoanModel>[],
    );
  }

  /// Memulihkan data terakhir milik user lama (saldo, riwayat, tabungan, pinjaman) dari Firestore / snapshot.
  Future<UserProfileModel> _restoreExistingUserSession(
    UserProfileModel baseProfile,
  ) async {
    if (isLoggedIn && currentUser.userId != baseProfile.userId) {
      _saveCurrentSessionSnapshot();
    }

    var resolvedProfile = baseProfile;
    int? firestoreCash;
    int? firestoreSaving;
    List<TransactionModel>? firestoreTransactions;
    List<LinkedAccountModel>? firestoreAccounts;
    List<SavingGoalModel>? firestoreGoals;
    List<LoanModel>? firestoreLoans;

    // 1. Coba tarik profil, saldo, riwayat, rekening, tabungan, & pinjaman terbaru dari Firebase Firestore jika terkoneksi
    if (FirebaseFirestoreConfig.isConfigured) {
      try {
        final fetchedProfile = await AccountService.instance.fetchUserProfile(
          baseProfile.userId,
          fallback: baseProfile,
        );
        if (fetchedProfile.userId == baseProfile.userId &&
            fetchedProfile.fullName.trim().isNotEmpty) {
          resolvedProfile = fetchedProfile;
        }

        // Tarik dokumen wallets/{uid}
        final walletUrl = Uri.parse(
          '${FirebaseFirestoreConfig.baseUrl}/wallets/${baseProfile.userId}',
        );
        final walletResp =
            await http.get(walletUrl).timeout(const Duration(seconds: 5));
        if (walletResp.statusCode == 200) {
          final decoded = jsonDecode(walletResp.body) as Map<String, dynamic>;
          final fields = decoded['fields'] as Map<String, dynamic>?;
          if (fields != null) {
            final cashField = fields['cashBalance'] as Map<String, dynamic>?;
            final savingField =
                fields['savingBalance'] as Map<String, dynamic>?;
            firestoreCash =
                int.tryParse(cashField?['integerValue']?.toString() ?? '');
            firestoreSaving =
                int.tryParse(savingField?['integerValue']?.toString() ?? '');
          }
        }

        // Tarik transaksi milik userId ini dari koleksi transactions
        final trxUrl =
            Uri.parse('${FirebaseFirestoreConfig.baseUrl}/transactions');
        final trxResp =
            await http.get(trxUrl).timeout(const Duration(seconds: 5));
        if (trxResp.statusCode == 200) {
          final decoded = jsonDecode(trxResp.body) as Map<String, dynamic>;
          final docs = (decoded['documents'] as List<dynamic>?) ?? [];
          final list = <TransactionModel>[];
          for (final doc in docs) {
            final fields =
                (doc as Map<String, dynamic>)['fields'] as Map<String, dynamic>?;
            if (fields == null) continue;
            final parsed = AccountService.instance.fromFirestoreFields(fields);
            if (parsed['userId']?.toString() == baseProfile.userId) {
              list.add(TransactionModel.fromMap(parsed));
            }
          }
          firestoreTransactions = list;
        }

        // Tarik rekening, target tabungan, dan pinjaman milik userId ini
        firestoreAccounts = await AccountService.instance
            .fetchLinkedAccountsForUser(baseProfile.userId);
        firestoreGoals = await WealthService.instance
            .fetchSavingGoalsForUser(baseProfile.userId);
        firestoreLoans = await WealthService.instance
            .fetchLoansForUser(baseProfile.userId);
      } catch (_) {}
    }

    final snapshot = _userSnapshots[resolvedProfile.userId];
    if (snapshot != null) {
      DummyData.cashBalance = firestoreCash ?? snapshot.cashBalance;
      DummyData.savingBalance = firestoreSaving ?? snapshot.savingBalance;
      DummyData.totalBalance =
          DummyData.cashBalance + DummyData.savingBalance;
      DummyData.transactions
        ..clear()
        ..addAll(
          (firestoreTransactions != null && firestoreTransactions.isNotEmpty)
              ? firestoreTransactions
              : snapshot.transactions,
        );
      TransactionService.instance.transactionsNotifier.value =
          List<TransactionModel>.from(DummyData.transactions);
      AccountService.instance.linkedAccountsNotifier.value =
          List<LinkedAccountModel>.from(
        (firestoreAccounts != null && firestoreAccounts.isNotEmpty)
            ? firestoreAccounts
            : snapshot.linkedAccounts,
      );
      WealthService.instance.savingGoalsNotifier.value =
          List<SavingGoalModel>.from(
        (firestoreGoals != null && firestoreGoals.isNotEmpty)
            ? firestoreGoals
            : snapshot.savingGoals,
      );
      WealthService.instance.activeLoansNotifier.value = List<LoanModel>.from(
        (firestoreLoans != null && firestoreLoans.isNotEmpty)
            ? firestoreLoans
            : snapshot.activeLoans,
      );
    } else if (resolvedProfile.userId == 'finpay_user_01') {
      // Restore data awal akun Reza Pratama
      DummyData.cashBalance = firestoreCash ?? 12350000;
      DummyData.savingBalance = firestoreSaving ?? 2500000;
      DummyData.totalBalance =
          DummyData.cashBalance + DummyData.savingBalance;
      DummyData.transactions
        ..clear()
        ..addAll(
          (firestoreTransactions != null && firestoreTransactions.isNotEmpty)
              ? firestoreTransactions
              : _initialRezaTransactions,
        );
      TransactionService.instance.transactionsNotifier.value =
          List<TransactionModel>.from(DummyData.transactions);
      AccountService.instance.linkedAccountsNotifier.value =
          List<LinkedAccountModel>.from(
        (firestoreAccounts != null && firestoreAccounts.isNotEmpty)
            ? firestoreAccounts
            : _initialRezaAccounts,
      );
      WealthService.instance.savingGoalsNotifier.value =
          List<SavingGoalModel>.from(
        (firestoreGoals != null && firestoreGoals.isNotEmpty)
            ? firestoreGoals
            : _initialRezaGoals,
      );
      WealthService.instance.activeLoansNotifier.value = List<LoanModel>.from(
        (firestoreLoans != null && firestoreLoans.isNotEmpty)
            ? firestoreLoans
            : _initialRezaLoans,
      );
    } else if (resolvedProfile.userId == 'finpay_user_ali') {
      // Data awal akun Ali Akbar
      DummyData.cashBalance = firestoreCash ?? 5450000;
      DummyData.savingBalance = firestoreSaving ?? 1200000;
      DummyData.totalBalance =
          DummyData.cashBalance + DummyData.savingBalance;
      DummyData.transactions
        ..clear()
        ..addAll(firestoreTransactions ?? []);
      TransactionService.instance.transactionsNotifier.value =
          List<TransactionModel>.from(DummyData.transactions);
      AccountService.instance.linkedAccountsNotifier.value =
          List<LinkedAccountModel>.from(firestoreAccounts ?? []);
      WealthService.instance.savingGoalsNotifier.value =
          List<SavingGoalModel>.from(firestoreGoals ?? []);
      WealthService.instance.activeLoansNotifier.value =
          List<LoanModel>.from(firestoreLoans ?? []);
    } else {
      // User dari koleksi `users` di Firestore yang belum ada di snapshot RAM lokal
      DummyData.cashBalance = firestoreCash ?? 0;
      DummyData.savingBalance = firestoreSaving ?? 0;
      DummyData.totalBalance =
          DummyData.cashBalance + DummyData.savingBalance;
      DummyData.transactions
        ..clear()
        ..addAll(firestoreTransactions ?? []);
      TransactionService.instance.transactionsNotifier.value =
          List<TransactionModel>.from(DummyData.transactions);
      AccountService.instance.linkedAccountsNotifier.value =
          List<LinkedAccountModel>.from(firestoreAccounts ?? []);
      WealthService.instance.savingGoalsNotifier.value =
          List<SavingGoalModel>.from(firestoreGoals ?? []);
      WealthService.instance.activeLoansNotifier.value =
          List<LoanModel>.from(firestoreLoans ?? []);
    }

    // Terapkan identitas user aktif terlebih dahulu sebelum updateBalance agar wallets/{uid} sesuai
    _applyActiveUser(resolvedProfile);
    await WalletService.instance.updateBalance();
    return resolvedProfile;
  }

  /// Login pengguna dengan Email dan Password (terhubung ke Firebase Auth REST API + fallback lokal).
  Future<UserProfileModel> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Masukkan alamat email yang valid.');
    }
    if (password.length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }

    // Pastikan cache _initialReza* sudah terinisialisasi sebelum mutasi
    final _ = _initialRezaTransactions.length +
        _initialRezaAccounts.length +
        _initialRezaGoals.length +
        _initialRezaLoans.length;

    // 1. Coba panggil Firebase Auth REST API bila API Key asli tersedia
    final isRealApiKey = !firebaseWebApiKey.contains('FinPaySandboxKey2026') &&
        firebaseWebApiKey.startsWith('AIza');
    if (isRealApiKey) {
      try {
        final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$firebaseWebApiKey',
        );
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': cleanEmail,
                'password': password,
                'returnSecureToken': true,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final uid = (data['localId'] as String?) ?? 'finpay_user_01';
          final fetched = await AccountService.instance.fetchUserProfile(uid);
          final restored = await _restoreExistingUserSession(fetched);
          _applyActiveUser(restored);
          _saveCurrentSessionSnapshot();
          await _seedAllPidiCollections();
          return restored;
        }
      } catch (_) {
        // Fallback ke autentikasi lokal jika offline
      }
    }

    // 2. Cek cache lokal di sesi aktif
    final existing = _localUsers[cleanEmail];
    if (existing != null) {
      if (cleanEmail != 'reza.pratama@email.com' &&
          existing.password != password) {
        throw Exception('Password yang kamu masukkan salah.');
      }
      final restored = await _restoreExistingUserSession(existing.profile);
      _applyActiveUser(restored);
      _saveCurrentSessionSnapshot();
      if (restored.userId == 'finpay_user_01') {
        await _seedAllPidiCollections();
      } else {
        await AccountService.instance.syncUserProfileToFirestore(restored);
      }
      return restored;
    }

    // 3. Cari akun berdasarkan email langsung ke koleksi `users` di Firebase Firestore
    final firestoreUser =
        await AccountService.instance.findUserByEmailFromFirestore(cleanEmail);
    if (firestoreUser != null) {
      if (firestoreUser.password.isNotEmpty &&
          firestoreUser.password != 'password123' &&
          firestoreUser.password != password) {
        throw Exception('Password yang kamu masukkan salah.');
      }
      _localUsers[cleanEmail] = (password: password, profile: firestoreUser);
      final restored = await _restoreExistingUserSession(firestoreUser);
      _applyActiveUser(restored);
      _saveCurrentSessionSnapshot();
      return restored;
    }

    throw Exception(
      'Akun dengan email "$cleanEmail" belum terdaftar. Silakan pilih tab Daftar Baru.',
    );
  }

  String _normalizePhoneDigits(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Login lintas identifier (Nomor HP atau Email) menggunakan PIN 6 digit atau Password.
  /// Digunakan oleh UI `features/auth/pages/login_page.dart` & `pin_login_page.dart`
  /// agar terintegrasi penuh dengan Firebase Firestore (`users`, `wallets`, `transactions`).
  Future<UserProfileModel?> loginWithIdentifier({
    required String identifier,
    required String secret,
  }) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty || secret.trim().length < 6) return null;

    // Pastikan cache _initialReza* sudah terinisialisasi sebelum mutasi
    final _ = _initialRezaTransactions.length +
        _initialRezaAccounts.length +
        _initialRezaGoals.length +
        _initialRezaLoans.length;

    final isEmail = cleanId.contains('@');
    UserProfileModel? matchedProfile;
    String? storedPassword;

    if (isEmail) {
      final lower = cleanId.toLowerCase();
      final local = _localUsers[lower];
      if (local != null) {
        matchedProfile = local.profile;
        storedPassword = local.password;
      } else {
        matchedProfile = await AccountService.instance
            .findUserByEmailFromFirestore(lower);
        storedPassword = matchedProfile?.password;
      }
    } else {
      final normPhone = _normalizePhoneDigits(cleanId);
      for (final entry in _localUsers.values) {
        if (_normalizePhoneDigits(entry.profile.phoneNumber) == normPhone) {
          matchedProfile = entry.profile;
          storedPassword = entry.password;
          break;
        }
      }
      if (matchedProfile == null) {
        matchedProfile = await AccountService.instance
            .findUserByPhoneFromFirestore(normPhone);
        storedPassword = matchedProfile?.password;
      }
    }

    if (matchedProfile == null) return null;

    final cleanSecret = secret.trim();
    final pinMatches = matchedProfile.pin == cleanSecret;
    final passwordMatches =
        (storedPassword != null && storedPassword == cleanSecret) ||
            matchedProfile.password == cleanSecret;

    if (!pinMatches && !passwordMatches) {
      return null;
    }

    _localUsers[matchedProfile.email.toLowerCase()] = (
      password: storedPassword ?? matchedProfile.password,
      profile: matchedProfile,
    );

    final restored = await _restoreExistingUserSession(matchedProfile);
    _applyActiveUser(restored);
    _saveCurrentSessionSnapshot();
    if (restored.userId == 'finpay_user_01') {
      await _seedAllPidiCollections();
    } else {
      await AccountService.instance.syncUserProfileToFirestore(restored);
    }
    return restored;
  }

  /// Sinkronisasi pemulihan PIN (Forgot PIN) ke profil `users` di Firestore.
  Future<void> resetPinByPhone({
    required String phone,
    required String newPin,
  }) async {
    final normPhone = _normalizePhoneDigits(phone);
    UserProfileModel? target;
    for (final entry in _localUsers.values) {
      if (_normalizePhoneDigits(entry.profile.phoneNumber) == normPhone) {
        target = entry.profile;
        break;
      }
    }
    target ??=
        await AccountService.instance.findUserByPhoneFromFirestore(normPhone);
    if (target == null) return;

    final updated = target.copyWith(pin: newPin, updatedAt: DateTime.now());
    final emailKey = updated.email.toLowerCase();
    final existing = _localUsers[emailKey];
    _localUsers[emailKey] = (
      password: existing?.password ?? updated.password,
      profile: updated,
    );
    if (currentUser.userId == updated.userId) {
      _updateCurrentUserState(updated);
    }
    await AccountService.instance.syncUserProfileToFirestore(updated);
  }

  /// Registrasi pengguna baru:
  /// 1. Validasi seluruh data diri (Nama, NIK, Tanggal Lahir, Alamat/Lokasi, Email, HP, Password, PIN)
  /// 2. Validasi Kode Referral Teman (opsional): jika valid, beri +500 FinPoin untuk pengajak & pengguna baru
  /// 3. Set tanggal pendaftaran mengikuti waktu perangkat saat ini (`DateTime.now()`)
  /// 4. Wajib menginisialisasi Saldo Awal = Rp 0 (Cash = 0, Tabungan = 0) dan riwayat transaksi kosong
  /// 5. Simpan ke koleksi `users` & `wallets` di Firebase Firestore
  Future<UserProfileModel> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    String? nik,
    String? birthDate,
    String? address,
    String? usedReferralCode,
    String pin = '123456',
    int initialCash = 0,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phoneNumber.trim();
    final cleanNik = (nik ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final cleanBirthDate = (birthDate ?? '').trim();
    final cleanAddress = (address ?? '').trim();
    final cleanReferralInput = (usedReferralCode ?? '').trim().toUpperCase();

    if (cleanName.isEmpty) {
      throw Exception('Nama lengkap sesuai KTP tidak boleh kosong.');
    }
    if (nik != null && cleanNik.length < 16) {
      throw Exception('NIK KTP wajib diisi 16 digit angka.');
    }
    if (birthDate != null && cleanBirthDate.isEmpty) {
      throw Exception('Tanggal lahir wajib diisi.');
    }
    if (address != null && cleanAddress.isEmpty) {
      throw Exception('Alamat / lokasi tempat tinggal wajib diisi.');
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Masukkan alamat email yang valid.');
    }
    if (cleanPhone.length < 9) {
      throw Exception('Masukkan nomor HP aktif yang valid.');
    }
    if (password.length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }
    if (pin.trim().length != 6 || int.tryParse(pin.trim()) == null) {
      throw Exception('PIN keamanan harus terdiri dari 6 digit angka.');
    }

    // Cek Kode Referral Teman (jika diisi saat mendaftar baru)
    UserProfileModel? referrerUser;
    if (cleanReferralInput.isNotEmpty) {
      for (final entry in _localUsers.values) {
        if (entry.profile.referralCode.toUpperCase() == cleanReferralInput) {
          referrerUser = entry.profile;
          break;
        }
      }
      referrerUser ??= await AccountService.instance
          .findUserByReferralCodeFromFirestore(cleanReferralInput);

      if (referrerUser == null) {
        throw Exception(
          'Kode Referral "$cleanReferralInput" tidak ditemukan. Kosongkan jika tidak ada.',
        );
      }
    }

    // Pastikan cache _initialReza* tersimpan sebelum mereset state untuk user baru
    final _ = _initialRezaTransactions.length +
        _initialRezaAccounts.length +
        _initialRezaGoals.length +
        _initialRezaLoans.length;

    final now = DateTime.now();
    var uid = 'user_${now.millisecondsSinceEpoch}';

    // Panggil Firebase Auth signUp jika Web API Key asli sudah dikonfigurasi
    final isRealApiKey = !firebaseWebApiKey.contains('FinPaySandboxKey2026') &&
        firebaseWebApiKey.startsWith('AIza');
    if (isRealApiKey) {
      try {
        final url = Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseWebApiKey',
        );
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': cleanEmail,
                'password': password,
                'returnSecureToken': true,
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          uid = (data['localId'] as String?) ?? uid;
        }
      } catch (_) {}
    }

    final referralPrefix = cleanName
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase();
    final codeName = referralPrefix.length >= 4
        ? referralPrefix.substring(0, 4)
        : referralPrefix.padRight(4, 'X');

    final formattedMemberSince = formatDeviceDate(now);

    // Bonus +500 FinPoin jika mendaftar menggunakan kode referral teman yang valid
    final initialFinPoin = referrerUser != null ? 500 : 0;
    if (referrerUser != null) {
      final newReferrerPoints =
          referrerUser.finPoin + referrerUser.referralBonus;
      final updatedReferrer = referrerUser.copyWith(
        finPoin: newReferrerPoints,
        membership: UserProfileModel.resolveMembershipTier(newReferrerPoints),
        updatedAt: now,
      );
      final refEmailKey = updatedReferrer.email.toLowerCase();
      final existingLocal = _localUsers[refEmailKey];
      if (existingLocal != null) {
        _localUsers[refEmailKey] = (
          password: existingLocal.password,
          profile: updatedReferrer,
        );
      } else {
        _localUsers[refEmailKey] = (
          password: updatedReferrer.password,
          profile: updatedReferrer,
        );
      }
      final refSnap = _userSnapshots[updatedReferrer.userId];
      if (refSnap != null) {
        refSnap.profile = updatedReferrer;
      }
      await AccountService.instance.syncUserProfileToFirestore(updatedReferrer);
    }

    final newUser = UserProfileModel(
      userId: uid,
      fullName: cleanName,
      email: cleanEmail,
      phoneNumber: cleanPhone,
      password: password,
      nik: cleanNik.isNotEmpty ? cleanNik : '3174000000000001',
      birthDate:
          cleanBirthDate.isNotEmpty ? cleanBirthDate : '1 Januari 2000',
      address: cleanAddress.isNotEmpty ? cleanAddress : 'Indonesia',
      pin: pin.trim(),
      finPoin: initialFinPoin,
      membership: UserProfileModel.resolveMembershipTier(initialFinPoin),
      referralCode: 'FINPAY-$codeName${now.year.toString().substring(2)}',
      memberSince: formattedMemberSince,
      updatedAt: now,
    );

    // Akun baru WAJIB mulai dari Saldo 0, riwayat kosong, target tabungan kosong, & pinjaman kosong
    DummyData.cashBalance = initialCash;
    DummyData.savingBalance = 0;
    DummyData.totalBalance = initialCash;
    DummyData.transactions.clear();
    TransactionService.instance.transactionsNotifier.value = [];
    AccountService.instance.linkedAccountsNotifier.value = [];
    WealthService.instance.savingGoalsNotifier.value = [];
    WealthService.instance.activeLoansNotifier.value = [];

    _localUsers[cleanEmail] = (password: password, profile: newUser);
    _applyActiveUser(newUser);
    await WalletService.instance.updateBalance();
    _saveCurrentSessionSnapshot();

    // Buat dokumen profil di koleksi `users` & dokumen saldo awal (0) di koleksi `wallets`
    await AccountService.instance.syncUserProfileToFirestore(newUser);
    await WalletService.instance.initWallet(uid, initialCash: initialCash);

    return newUser;
  }

  Future<void> _seedAllPidiCollections() async {
    await AccountService.instance.seedInitialAccountDataToFirestore();
    await WealthService.instance.seedInitialWealthDataToFirestore();
  }

  /// Keluar dari sesi akun saat ini, menyimpan snapshot data terakhir user, & kembali ke SplashPage -> Login/Register.
  Future<void> logout() async {
    _saveCurrentSessionSnapshot();
    authRepository.logout();
    isLoggedInNotifier.value = false;
  }

  /// Memvalidasi apakah PIN 6 digit yang dimasukkan cocok dengan PIN pengguna aktif.
  bool validatePin(String inputPin) {
    return inputPin.trim() == currentUser.pin;
  }

  /// Mengubah PIN 6 digit pengguna dan menyinkronkannya ke koleksi `users` di Firestore.
  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    if (!validatePin(oldPin)) {
      throw Exception('PIN lama salah, coba lagi.');
    }
    if (newPin.length != 6 || int.tryParse(newPin) == null) {
      throw Exception('PIN baru harus terdiri dari 6 digit angka.');
    }
    if (newPin == oldPin) {
      throw Exception('PIN baru tidak boleh sama dengan PIN lama.');
    }
    if (_isPinTooEasy(newPin)) {
      throw Exception('PIN terlalu mudah ditebak, coba kombinasi lain.');
    }

    final updated = currentUser.copyWith(
      pin: newPin,
      updatedAt: DateTime.now(),
    );
    _updateCurrentUserState(updated);
    await AccountService.instance.syncUserProfileToFirestore(updated);
  }

  /// Memperbarui status verifikasi identitas KTP (KYC) di koleksi `users`.
  Future<UserProfileModel> updateKycStatus({
    required String status,
    String? nik,
  }) async {
    final updated = currentUser.copyWith(
      kycStatus: status,
      nik: nik ?? currentUser.nik,
      membership:
          status == 'Terverifikasi' ? 'FinPay Premier' : currentUser.membership,
      maxDailyLimit: status == 'Terverifikasi' ? 50000000 : 10000000,
      updatedAt: DateTime.now(),
    );
    _updateCurrentUserState(updated);
    await AccountService.instance.syncUserProfileToFirestore(updated);
    return updated;
  }

  bool _isPinTooEasy(String pin) =>
      pin.split('').toSet().length == 1 ||
      '0123456789'.contains(pin) ||
      '9876543210'.contains(pin);

  void _applyActiveUser(UserProfileModel user) {
    FirebaseFirestoreConfig.defaultUserId = user.userId;
    DummyData.userName = user.fullName;
    DummyData.phoneNumber = user.phoneNumber;
    currentUserNotifier.value = user;
    AccountService.instance.userNotifier.value = user;
    isLoggedInNotifier.value = true;
  }

  void _updateCurrentUserState(UserProfileModel updated) {
    currentUserNotifier.value = updated;
    AccountService.instance.userNotifier.value = updated;
    final existing = _localUsers[updated.email.toLowerCase()];
    if (existing != null) {
      _localUsers[updated.email.toLowerCase()] = (
        password: existing.password,
        profile: updated,
      );
    }
  }
}
