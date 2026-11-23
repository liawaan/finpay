import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../dummy/dummy_data.dart';
import '../models/transaction_model.dart';

/// Konfigurasi koneksi Firebase Cloud Firestore untuk bagian Backend Ali.
///
/// Isi [projectId] dengan Project ID dari Firebase Console kamu
/// (contoh: `'finpay-kelompok6'`).
abstract final class FirebaseFirestoreConfig {
  static String projectId = 'finpay-app-4026a';
  static String defaultUserId = 'finpay_user_01';

  static bool get isConfigured => projectId.trim().isNotEmpty;

  static String get baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
}

/// Service Backend Riwayat Transaksi (Bagian Tugas Ali).
///
/// Mengelola koleksi `transactions` di Firebase Firestore sekaligus menjaga
/// sinkronisasi state lokal agar UI langsung ter-update secara reaktif.
class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  final ValueNotifier<List<TransactionModel>> transactionsNotifier =
      ValueNotifier<List<TransactionModel>>(
    List<TransactionModel>.from(DummyData.transactions),
  );

  /// Mengambil daftar transaksi yang sudah difilter berdasarkan tipe dan kata kunci pencarian.
  List<TransactionModel> getTransactions({
    TransactionFilter filter = TransactionFilter.all,
    String searchQuery = '',
  }) {
    final query = searchQuery.trim().toLowerCase();
    return DummyData.transactions.where((trx) {
      if (!filter.matches(trx)) return false;
      if (query.isEmpty) return true;

      return trx.title.toLowerCase().contains(query) ||
          trx.channel.toLowerCase().contains(query) ||
          trx.category.toLowerCase().contains(query) ||
          trx.referenceNumber.toLowerCase().contains(query);
    }).toList();
  }

  /// Mencari detail satu transaksi berdasarkan nomor referensi (`FPX-...`).
  TransactionModel? getTransactionByRef(String referenceNumber) {
    for (final trx in DummyData.transactions) {
      if (trx.referenceNumber == referenceNumber) return trx;
    }
    return null;
  }

  /// Menyimpan transaksi baru ke daftar riwayat & menyinkronkannya ke koleksi `transactions` di Firebase.
  ///
  /// Fungsi ini juga dapat dipanggil oleh modul Pidi (Tabungan, Pinjaman, dll).
  Future<void> addTransaction(TransactionModel transaction) async {
    DummyData.transactions.insert(0, transaction);
    transactionsNotifier.value =
        List<TransactionModel>.from(DummyData.transactions);

    if (!FirebaseFirestoreConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/transactions/${transaction.referenceNumber}',
      );
      final firestorePayload = {
        'fields': _toFirestoreFields(transaction.toMap()),
      };
      await http
          .patch(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(firestorePayload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Tetap aman menggunakan state lokal apabila jaringan sedang offline.
    }
  }

  /// Mengambil riwayat transaksi dari koleksi `transactions` di Firebase Firestore.
  Future<List<TransactionModel>> fetchTransactionsFromFirebase({
    String? userId,
  }) async {
    if (!FirebaseFirestoreConfig.isConfigured) {
      return DummyData.transactions;
    }

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/transactions?pageSize=200',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = (decoded['documents'] as List<dynamic>?) ?? [];
        if (documents.isNotEmpty) {
          final fetched = documents.map((doc) {
            final fields =
                (doc as Map<String, dynamic>)['fields'] as Map<String, dynamic>;
            return TransactionModel.fromMap(_fromFirestoreFields(fields));
          }).toList();

          DummyData.transactions
            ..clear()
            ..addAll(fetched);
          transactionsNotifier.value =
              List<TransactionModel>.from(DummyData.transactions);
        }
      }
    } catch (_) {
      // Fallback ke data lokal jika gagal terhubung.
    }

    return DummyData.transactions;
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

  Map<String, dynamic> _fromFirestoreFields(Map<String, dynamic> fields) {
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
