import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/qris_model.dart';
import '../models/user_profile_model.dart';
import 'account_service.dart';
import 'transaction_service.dart';

/// Data QRIS milik pengguna FinPay yang dipublikasikan untuk transfer antar pengguna.
class PublishedUserQris {
  const PublishedUserQris({
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.nmid,
    required this.qrisString,
    this.amount,
    required this.updatedAt,
  });

  final String userId;
  final String userName;
  final String phoneNumber;
  final String nmid;
  final String qrisString;
  final int? amount;
  final DateTime updatedAt;

  bool get isDynamic => amount != null && amount! > 0;
}

/// Service logika QRIS FinPay (Bagian Tugas Ali).
///
/// Bertugas membuat QRIS milik pengguna, mempublikasikan QRIS untuk transfer
/// antar pengguna (misal Ali ↔ Reza), membaca hasil scan, dan memvalidasi nominal
/// sebelum diteruskan ke [WalletService].
class QrisService {
  QrisService._() {
    _seedDefaultUserQrisRegistry();
  }
  static final QrisService instance = QrisService._();

  /// Nominal minimum & maksimum per transaksi QRIS.
  static const int minAmount = 1000;
  static const int maxAmount = 10000000;

  final Map<String, PublishedUserQris> _userQrisMap = {};

  /// Daftar QRIS pengguna FinPay yang siap dipindai untuk transfer antar pengguna.
  final ValueNotifier<List<PublishedUserQris>> publishedUserQrisNotifier =
      ValueNotifier<List<PublishedUserQris>>([]);

  UserProfileModel get _activeUser => AccountService.instance.currentUser;

  /// Menghasilkan NMID unik untuk seorang pengguna berdasarkan nomor HP dan userId.
  String nmidForUser({
    required String userId,
    required String phoneNumber,
  }) {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 9) {
      final tail = digits.substring(digits.length - 9);
      return 'ID10$tail';
    }
    final hash = userId.codeUnits
        .fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7FFFFFFF)
        .toString()
        .padLeft(9, '0');
    return 'ID10${hash.substring(hash.length - 9)}';
  }

  /// NMID milik pengguna yang sedang aktif login.
  String get myNmid => nmidForUser(
        userId: _activeUser.userId,
        phoneNumber: _activeUser.phoneNumber,
      );

  /// Membuat payload QRIS untuk pengguna tertentu.
  QrisPayload buildUserQris({
    required String userId,
    required String userName,
    required String phoneNumber,
    int? amount,
    String? referenceLabel,
  }) {
    final effectiveRef = (referenceLabel != null && referenceLabel.isNotEmpty)
        ? referenceLabel
        : 'FPUSER:$userId';
    return QrisPayload(
      merchantName: userName,
      merchantCity: 'Jakarta',
      nmid: nmidForUser(userId: userId, phoneNumber: phoneNumber),
      merchantCategoryCode: '6012',
      amount: (amount != null && amount > 0) ? amount : null,
      referenceLabel: effectiveRef,
      terminalLabel: 'FINPAYUSER',
    );
  }

  /// QRIS milik pengguna yang sedang login untuk menerima uang / transfer QRIS.
  /// - [amount] kosong = QRIS statis, pembayar mengisi nominal sendiri.
  /// - [amount] terisi = QRIS dinamis dengan nominal terkunci.
  QrisPayload myQris({int? amount, String? referenceLabel}) {
    final user = _activeUser;
    return buildUserQris(
      userId: user.userId,
      userName: user.fullName,
      phoneNumber: user.phoneNumber,
      amount: amount,
      referenceLabel: referenceLabel,
    );
  }

  void _seedDefaultUserQrisRegistry() {
    final defaults = [
      (
        userId: 'finpay_user_ali',
        userName: 'Ali Akbar',
        phone: '0813-8899-7766',
        amount: null,
      ),
      (
        userId: 'finpay_user_01',
        userName: 'Reza Pratama',
        phone: '0812-3456-7890',
        amount: null,
      ),
      (
        userId: 'finpay_user_02',
        userName: 'Budi Santoso',
        phone: '0812-9988-7766',
        amount: null,
      ),
      (
        userId: 'finpay_user_03',
        userName: 'Siska Pertiwi',
        phone: '0813-1122-3344',
        amount: null,
      ),
    ];

    for (final item in defaults) {
      final payload = buildUserQris(
        userId: item.userId,
        userName: item.userName,
        phoneNumber: item.phone,
        amount: item.amount,
      );
      _userQrisMap[item.userId] = PublishedUserQris(
        userId: item.userId,
        userName: item.userName,
        phoneNumber: item.phone,
        nmid: payload.nmid,
        qrisString: payload.encode(),
        amount: item.amount,
        updatedAt: DateTime.now(),
      );
    }
    _notifyPublishedList();
  }

  void _notifyPublishedList() {
    publishedUserQrisNotifier.value = _userQrisMap.values.toList();
  }

  /// Mengambil daftar QRIS pengguna lain (tidak termasuk pengguna yang sedang login).
  List<PublishedUserQris> getPeerUserQrisList({String? excludeUserId}) {
    final activeUid = excludeUserId ?? _activeUser.userId;
    return publishedUserQrisNotifier.value
        .where((entry) => entry.userId != activeUid)
        .toList();
  }

  /// Mempublikasikan QRIS milik pengguna aktif (baik statis maupun dinamis) ke registri
  /// lokal dan koleksi `user_qris` di Firebase Firestore agar dapat di-scan oleh pengguna lain.
  Future<PublishedUserQris> publishActiveUserQris({int? amount}) async {
    final user = _activeUser;
    final payload = myQris(amount: amount);
    final encoded = payload.encode();
    final published = PublishedUserQris(
      userId: user.userId,
      userName: user.fullName,
      phoneNumber: user.phoneNumber,
      nmid: payload.nmid,
      qrisString: encoded,
      amount: payload.amount,
      updatedAt: DateTime.now(),
    );

    _userQrisMap[user.userId] = published;
    _notifyPublishedList();

    if (FirebaseFirestoreConfig.isConfigured) {
      try {
        final url = Uri.parse(
          '${FirebaseFirestoreConfig.baseUrl}/user_qris/${user.userId}',
        );
        final body = {
          'fields': {
            'userId': {'stringValue': published.userId},
            'userName': {'stringValue': published.userName},
            'phoneNumber': {'stringValue': published.phoneNumber},
            'nmid': {'stringValue': published.nmid},
            'qrisString': {'stringValue': published.qrisString},
            'amount': {
              'integerValue': (published.amount ?? 0).toString(),
            },
            'updatedAt': {
              'stringValue': published.updatedAt.toIso8601String(),
            },
          },
        };
        await http
            .patch(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }

    return published;
  }

  /// Menarik daftar QRIS pengguna yang dipublikasikan dari koleksi `user_qris` di Firestore.
  Future<List<PublishedUserQris>> fetchPublishedUserQrisFromFirebase() async {
    if (!FirebaseFirestoreConfig.isConfigured) {
      return publishedUserQrisNotifier.value;
    }

    try {
      final url = Uri.parse('${FirebaseFirestoreConfig.baseUrl}/user_qris');
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (decoded['documents'] as List<dynamic>?) ?? [];
        for (final doc in docs) {
          final fields =
              (doc as Map<String, dynamic>)['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;
          String readStr(String k) =>
              (fields[k] as Map<String, dynamic>?)?['stringValue']
                  ?.toString() ??
              '';
          final rawAmt = int.tryParse(
                (fields['amount'] as Map<String, dynamic>?)?['integerValue']
                        ?.toString() ??
                    '0',
              ) ??
              0;
          final uid = readStr('userId');
          final qrisStr = readStr('qrisString');
          if (uid.isEmpty || qrisStr.isEmpty) continue;
          _userQrisMap[uid] = PublishedUserQris(
            userId: uid,
            userName: readStr('userName'),
            phoneNumber: readStr('phoneNumber'),
            nmid: readStr('nmid'),
            qrisString: qrisStr,
            amount: rawAmt > 0 ? rawAmt : null,
            updatedAt:
                DateTime.tryParse(readStr('updatedAt')) ?? DateTime.now(),
          );
        }
        _notifyPublishedList();
      }
    } catch (_) {}

    return publishedUserQrisNotifier.value;
  }

  /// Membaca string hasil scan. Melempar [QrisFormatException] bila tidak valid.
  QrisPayload scan(String raw) {
    final payload = QrisPayload.parse(raw);
    final currentUid = _activeUser.userId;
    final recipientUid = payload.recipientUserId;

    final isSelfByUid = recipientUid != null && recipientUid == currentUid;
    final isSelfByNmid = recipientUid == null && payload.nmid == myNmid;

    if (isSelfByUid || isSelfByNmid) {
      throw const QrisFormatException(
        'Tidak bisa membayar ke QRIS milik sendiri.',
      );
    }
    return payload;
  }

  /// Menentukan nominal akhir yang akan dibayar.
  ///
  /// QRIS dinamis memakai nominal di dalam QR (nominal input diabaikan),
  /// QRIS statis memakai [enteredAmount] dari pengguna.
  int resolveAmount(QrisPayload payload, {int? enteredAmount}) {
    final amount = payload.isDynamic ? payload.amount! : (enteredAmount ?? 0);
    validateAmount(amount);
    return amount;
  }

  void validateAmount(int amount) {
    if (amount < minAmount) {
      throw const QrisFormatException('Nominal minimal pembayaran Rp 1.000.');
    }
    if (amount > maxAmount) {
      throw const QrisFormatException(
        'Nominal melebihi batas QRIS Rp 10.000.000 per transaksi.',
      );
    }
  }

  /// Biaya layanan QRIS untuk pembayar. FinPay menggratiskan seluruh biaya.
  int adminFee(int amount) => 0;
}
