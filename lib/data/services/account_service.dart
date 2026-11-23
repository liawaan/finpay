import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../dummy/dummy_data.dart';
import '../models/linked_account_model.dart';
import '../models/transaction_model.dart';
import '../models/user_profile_model.dart';
import 'auth_service.dart';
import 'transaction_service.dart';
import 'wallet_service.dart';

/// Service Backend Manajemen Akun, Profil, Limit, & Rekening Terhubung (Bagian Tugas Pidi).
///
/// Mengelola koleksi:
/// 1. `users` (Profil, FinPoin, Referral, PIN, KYC, Limit Harian, Preferensi Keamanan)
/// 2. `linked_accounts` (Rekening bank & kartu tersimpan)
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  final ValueNotifier<UserProfileModel> userNotifier =
      ValueNotifier<UserProfileModel>(
    UserProfileModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      fullName: DummyData.userName,
      email: 'reza.pratama@email.com',
      phoneNumber: DummyData.phoneNumber,
    ),
  );

  final ValueNotifier<List<LinkedAccountModel>> linkedAccountsNotifier =
      ValueNotifier<List<LinkedAccountModel>>([
    const LinkedAccountModel(
      id: 'acc_bca_01',
      userId: 'finpay_user_01',
      bankName: 'BCA',
      accountNumber: '8801204821',
      holderName: 'Reza Pratama',
      isPrimary: true,
    ),
    const LinkedAccountModel(
      id: 'acc_mandiri_02',
      userId: 'finpay_user_01',
      bankName: 'Mandiri',
      accountNumber: '1300097733',
      holderName: 'Reza Pratama',
      isPrimary: false,
    ),
  ]);

  UserProfileModel get currentUser => userNotifier.value;
  List<LinkedAccountModel> get linkedAccounts => linkedAccountsNotifier.value;

  /// Menghitung total pemakaian transaksi keluar (transfer/pembayaran) hari ini.
  int get usedTodayAmount {
    final outgoing = DummyData.transactions.where(
      (t) => !t.isIncoming && t.dateGroup.toLowerCase().contains('hari ini'),
    );
    final sum = outgoing.fold<int>(0, (acc, item) => acc + item.amount.abs());
    return sum > 0 ? sum : 3650000;
  }

  /// Update data kontak profil pengguna (Nama, Email, Nomor HP, Alamat) & sinkronkan ke koleksi `users`.
  Future<UserProfileModel> updateProfile({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? address,
  }) async {
    final updated = currentUser.copyWith(
      fullName: fullName?.trim().isNotEmpty == true ? fullName!.trim() : null,
      email: email?.trim().isNotEmpty == true ? email!.trim() : null,
      phoneNumber:
          phoneNumber?.trim().isNotEmpty == true ? phoneNumber!.trim() : null,
      address: address?.trim().isNotEmpty == true ? address!.trim() : null,
      updatedAt: DateTime.now(),
    );

    DummyData.userName = updated.fullName;
    DummyData.phoneNumber = updated.phoneNumber;
    _applyProfileUpdate(updated);
    await syncUserProfileToFirestore(updated);
    return updated;
  }

  /// Mengatur batas limit transfer harian pengguna di koleksi `users`.
  Future<UserProfileModel> updateDailyLimit(int newLimit) async {
    if (newLimit < 1000000) {
      throw Exception('Limit transfer harian minimal Rp 1.000.000.');
    }
    if (newLimit > currentUser.maxDailyLimit) {
      throw Exception(
        'Limit melebihi batas maksimum akun (${currentUser.maxDailyLimit}).',
      );
    }

    final updated = currentUser.copyWith(
      dailyLimit: newLimit,
      updatedAt: DateTime.now(),
    );
    _applyProfileUpdate(updated);
    await syncUserProfileToFirestore(updated);
    return updated;
  }

  /// Mengubah pengaturan keamanan & preferensi (Biometrik, Notifikasi, Bahasa, Kartu Virtual).
  Future<UserProfileModel> updatePreferences({
    bool? biometricEnabled,
    bool? notificationEnabled,
    String? language,
    bool? virtualCardFrozen,
    bool? virtualCardOnlineEnabled,
  }) async {
    final updated = currentUser.copyWith(
      biometricEnabled: biometricEnabled,
      notificationEnabled: notificationEnabled,
      language: language,
      virtualCardFrozen: virtualCardFrozen,
      virtualCardOnlineEnabled: virtualCardOnlineEnabled,
      updatedAt: DateTime.now(),
    );
    _applyProfileUpdate(updated);
    await syncUserProfileToFirestore(updated);
    return updated;
  }

  /// Menambah FinPoin pengguna dan otomatis menaikkan tier membership jika memenuhi syarat.
  Future<UserProfileModel> addFinPoin(int pointsDelta) async {
    if (pointsDelta <= 0) return currentUser;
    final newPoints = currentUser.finPoin + pointsDelta;
    final updated = currentUser.copyWith(
      finPoin: newPoints,
      membership: UserProfileModel.resolveMembershipTier(newPoints),
      updatedAt: DateTime.now(),
    );
    _applyProfileUpdate(updated);
    await syncUserProfileToFirestore(updated);
    return updated;
  }

  /// Menukar (Redeem) FinPoin pengguna menjadi Saldo FinPay Cash (1 FinPoin = Rp 100)
  /// serta mencatat mutasinya ke Riwayat Transaksi & Firebase Firestore.
  Future<({TransactionModel transaction, int cashAdded})> redeemFinPoin({
    required int pointsToRedeem,
    required String timeFormatted,
  }) async {
    if (pointsToRedeem <= 0) {
      throw Exception('Masukkan jumlah FinPoin yang ingin ditukar.');
    }
    if (pointsToRedeem < 100) {
      throw Exception('Minimal penukaran adalah 100 FinPoin (Rp 10.000).');
    }
    if (pointsToRedeem > currentUser.finPoin) {
      throw Exception(
        'FinPoin kamu tidak mencukupi (Tersedia: ${currentUser.finPoin} Poin).',
      );
    }

    // Konversi: 1 FinPoin = Rp 100
    final cashAdded = pointsToRedeem * 100;
    final remainingPoints = currentUser.finPoin - pointsToRedeem;

    final updatedUser = currentUser.copyWith(
      finPoin: remainingPoints,
      updatedAt: DateTime.now(),
    );
    _applyProfileUpdate(updatedUser);
    await syncUserProfileToFirestore(updatedUser);

    await WalletService.instance.updateBalance(cashDelta: cashAdded);

    final referenceNumber =
        'FPX-PT${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final trx = TransactionModel(
      userId: currentUser.userId,
      title: 'Tukar $pointsToRedeem FinPoin ke Saldo Cash',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: 'FinPay Rewards',
      amount: cashAdded,
      icon: Icons.redeem_rounded,
      type: TransactionType.income,
      referenceNumber: referenceNumber,
      category: 'Reward FinPoin',
      dateGroup: 'Hari Ini',
      note: 'Redeem $pointsToRedeem FinPoin (1 Poin = Rp 100)',
    );

    await TransactionService.instance.addTransaction(trx);
    return (transaction: trx, cashAdded: cashAdded);
  }

  /// Mencari pengguna pemilik kode referral di koleksi `users` Firebase Firestore.
  Future<UserProfileModel?> findUserByReferralCodeFromFirestore(
    String referralCode,
  ) async {
    if (!FirebaseFirestoreConfig.isConfigured) return null;
    final cleanCode = referralCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    try {
      final url = Uri.parse('${FirebaseFirestoreConfig.baseUrl}/users');
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (decoded['documents'] as List<dynamic>?) ?? [];
        for (final doc in docs) {
          final docMap = doc as Map<String, dynamic>;
          final fields = docMap['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;

          final parsedMap = fromFirestoreFields(fields);
          final docCode = (parsedMap['referralCode']?.toString() ?? '')
              .trim()
              .toUpperCase();
          if (docCode == cleanCode) {
            final namePath = (docMap['name'] as String?) ?? '';
            final docId = namePath.contains('/')
                ? namePath.split('/').last
                : (parsedMap['userId']?.toString() ?? 'finpay_user_01');
            return UserProfileModel.fromMap(parsedMap, docId: docId);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Menambahkan rekening bank baru ke koleksi `linked_accounts` di Firebase Firestore.
  Future<LinkedAccountModel> addLinkedAccount({
    required String bankName,
    required String accountNumber,
    bool setAsPrimary = false,
  }) async {
    final cleanNumber = accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length < 10) {
      throw Exception('Nomor rekening minimal 10 digit angka.');
    }

    final newAccount = LinkedAccountModel(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUser.userId,
      bankName: bankName.trim(),
      accountNumber: cleanNumber,
      holderName: currentUser.fullName,
      isPrimary: setAsPrimary || linkedAccounts.isEmpty,
      createdAt: DateTime.now(),
    );

    final currentList = List<LinkedAccountModel>.from(linkedAccounts);
    if (newAccount.isPrimary) {
      for (var i = 0; i < currentList.length; i++) {
        currentList[i] = currentList[i].copyWith(isPrimary: false);
      }
    }
    currentList.add(newAccount);
    linkedAccountsNotifier.value = currentList;

    await _syncLinkedAccountToFirestore(newAccount);
    return newAccount;
  }

  /// Menjadikan salah satu rekening bank sebagai rekening utama.
  Future<void> setPrimaryLinkedAccount(String accountId) async {
    final updatedList = linkedAccounts.map((acc) {
      return acc.copyWith(isPrimary: acc.id == accountId);
    }).toList();

    linkedAccountsNotifier.value = updatedList;
    final primary = updatedList.where((a) => a.id == accountId).firstOrNull;
    if (primary != null) {
      await _syncLinkedAccountToFirestore(primary);
    }
  }

  /// Menghapus rekening bank dari koleksi `linked_accounts`.
  Future<void> removeLinkedAccount(String accountId) async {
    if (linkedAccounts.length <= 1) {
      throw Exception('Minimal harus ada satu rekening terhubung.');
    }

    final updatedList =
        linkedAccounts.where((acc) => acc.id != accountId).toList();
    if (!updatedList.any((acc) => acc.isPrimary) && updatedList.isNotEmpty) {
      updatedList[0] = updatedList[0].copyWith(isPrimary: true);
    }
    linkedAccountsNotifier.value = updatedList;

    await _deleteLinkedAccountFromFirestore(accountId);
  }

  void _applyProfileUpdate(UserProfileModel updated) {
    userNotifier.value = updated;
    AuthService.instance.currentUserNotifier.value = updated;
  }

  /// Menyinkronkan data awal koleksi `users` dan `linked_accounts` ke Firestore agar langsung muncul di Firebase Console.
  Future<void> seedInitialAccountDataToFirestore() async {
    await syncUserProfileToFirestore(currentUser);
    for (final acc in linkedAccounts) {
      await _syncLinkedAccountToFirestore(acc);
    }
  }

  /// Mengambil dokumen profil dari koleksi `users/{uid}` di Firebase Firestore.
  ///
  /// Jika dokumen belum ada di Firestore (404) atau sedang offline,
  /// mengembalikan [fallback] agar tidak menimpa sesi user baru (misal Ali)
  /// dengan profil `currentUser` sebelumnya (misal Reza).
  Future<UserProfileModel> fetchUserProfile(
    String userId, {
    UserProfileModel? fallback,
  }) async {
    final safeFallback = fallback ??
        (currentUser.userId == userId
            ? currentUser
            : UserProfileModel(
                userId: userId,
                fullName: userId == 'finpay_user_ali'
                    ? 'Ali Akbar'
                    : 'Pengguna FinPay',
                email: userId == 'finpay_user_ali'
                    ? 'ali.akbar@email.com'
                    : '',
                phoneNumber: userId == 'finpay_user_ali'
                    ? '0813-8899-7766'
                    : '',
              ));

    if (!FirebaseFirestoreConfig.isConfigured) return safeFallback;

    try {
      final url = Uri.parse('${FirebaseFirestoreConfig.baseUrl}/users/$userId');
      final response =
          await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final fields = decoded['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final loaded = UserProfileModel.fromMap(
            fromFirestoreFields(fields),
            docId: userId,
          );
          if (loaded.userId == userId && loaded.fullName.trim().isNotEmpty) {
            _applyProfileUpdate(loaded);
            return loaded;
          }
        }
      }
    } catch (_) {}

    return safeFallback;
  }

  /// Mencari pengguna berdasarkan alamat email di koleksi `users` pada Firebase Firestore.
  Future<UserProfileModel?> findUserByEmailFromFirestore(String email) async {
    if (!FirebaseFirestoreConfig.isConfigured) return null;
    final cleanEmail = email.trim().toLowerCase();

    try {
      final url = Uri.parse('${FirebaseFirestoreConfig.baseUrl}/users');
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (decoded['documents'] as List<dynamic>?) ?? [];
        for (final doc in docs) {
          final docMap = doc as Map<String, dynamic>;
          final fields = docMap['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;

          final parsedMap = fromFirestoreFields(fields);
          final docEmail =
              (parsedMap['email']?.toString() ?? '').trim().toLowerCase();
          if (docEmail == cleanEmail) {
            final namePath = (docMap['name'] as String?) ?? '';
            final docId = namePath.contains('/')
                ? namePath.split('/').last
                : (parsedMap['userId']?.toString() ?? 'finpay_user_01');
            return UserProfileModel.fromMap(parsedMap, docId: docId);
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Mencari pengguna berdasarkan Nomor HP (ternormalisasi) di koleksi `users` pada Firebase Firestore.
  Future<UserProfileModel?> findUserByPhoneFromFirestore(String phone) async {
    if (!FirebaseFirestoreConfig.isConfigured) return null;
    final normalizedTarget = _normalizePhoneDigits(phone);
    if (normalizedTarget.isEmpty) return null;

    try {
      final url = Uri.parse('${FirebaseFirestoreConfig.baseUrl}/users');
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (decoded['documents'] as List<dynamic>?) ?? [];
        for (final doc in docs) {
          final docMap = doc as Map<String, dynamic>;
          final fields = docMap['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;

          final parsedMap = fromFirestoreFields(fields);
          final docPhone = _normalizePhoneDigits(
            parsedMap['phoneNumber']?.toString() ?? '',
          );
          if (docPhone == normalizedTarget) {
            final namePath = (docMap['name'] as String?) ?? '';
            final docId = namePath.contains('/')
                ? namePath.split('/').last
                : (parsedMap['userId']?.toString() ?? 'finpay_user_01');
            return UserProfileModel.fromMap(parsedMap, docId: docId);
          }
        }
      }
    } catch (_) {}

    return null;
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

  /// Mengambil daftar rekening bank milik `userId` dari koleksi `linked_accounts` di Firestore.
  Future<List<LinkedAccountModel>?> fetchLinkedAccountsForUser(
    String userId,
  ) async {
    if (!FirebaseFirestoreConfig.isConfigured) return null;

    try {
      final url =
          Uri.parse('${FirebaseFirestoreConfig.baseUrl}/linked_accounts');
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (decoded['documents'] as List<dynamic>?) ?? [];
        final userAccounts = <LinkedAccountModel>[];
        for (final doc in docs) {
          final docMap = doc as Map<String, dynamic>;
          final fields = docMap['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;

          final parsedMap = fromFirestoreFields(fields);
          if (parsedMap['userId']?.toString() == userId) {
            userAccounts.add(LinkedAccountModel.fromMap(parsedMap));
          }
        }
        return userAccounts;
      }
    } catch (_) {}

    return null;
  }

  /// Menyinkronkan dokumen profil pengguna ke koleksi `users/{uid}` di Firebase Firestore.
  Future<void> syncUserProfileToFirestore(UserProfileModel user) async {
    if (!FirebaseFirestoreConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/users/${user.userId}',
      );
      final payload = {
        'fields': _toFirestoreFields(user.toMap()),
      };
      await http
          .patch(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<void> _syncLinkedAccountToFirestore(LinkedAccountModel account) async {
    if (!FirebaseFirestoreConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/linked_accounts/${account.id}',
      );
      final payload = {
        'fields': _toFirestoreFields(account.toMap()),
      };
      await http
          .patch(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<void> _deleteLinkedAccountFromFirestore(String accountId) async {
    if (!FirebaseFirestoreConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/linked_accounts/$accountId',
      );
      await http.delete(url).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Map<String, dynamic> _toFirestoreFields(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) return;
      if (value is int) {
        result[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        result[key] = {'doubleValue': value};
      } else if (value is bool) {
        result[key] = {'booleanValue': value};
      } else {
        result[key] = {'stringValue': value.toString()};
      }
    });
    return result;
  }

  Map<String, dynamic> fromFirestoreFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    fields.forEach((key, value) {
      final fieldMap = value as Map<String, dynamic>;
      if (fieldMap.containsKey('integerValue')) {
        result[key] = int.tryParse(fieldMap['integerValue'].toString()) ?? 0;
      } else if (fieldMap.containsKey('doubleValue')) {
        result[key] = (fieldMap['doubleValue'] as num).toDouble();
      } else if (fieldMap.containsKey('booleanValue')) {
        result[key] = fieldMap['booleanValue'] as bool;
      } else if (fieldMap.containsKey('stringValue')) {
        result[key] = fieldMap['stringValue'].toString();
      }
    });
    return result;
  }
}
