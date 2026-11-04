import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../dummy/dummy_data.dart';
import '../models/qris_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import 'midtrans_service.dart';
import 'qris_service.dart';
import 'transaction_service.dart';

/// Service Backend Dompet & Pembayaran (Bagian Tugas Ali).
///
/// Mengelola:
/// 1. Koleksi `wallets` & `midtrans_orders` di Firebase Firestore
/// 2. Top Up Saldo via Midtrans Sandbox
/// 3. Transfer Sesama FinPay & Antar Bank
/// 4. Pembayaran QRIS & Pembuatan Kode Tarik Tunai ATM
class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  final ValueNotifier<WalletModel> walletNotifier = ValueNotifier<WalletModel>(
    WalletModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      cashBalance: DummyData.cashBalance,
      savingBalance: DummyData.savingBalance,
      updatedAt: DateTime.now(),
    ),
  );

  /// Mengambil kondisi dompet pengguna saat ini.
  WalletModel get currentWallet => WalletModel(
        userId: FirebaseFirestoreConfig.defaultUserId,
        cashBalance: DummyData.cashBalance,
        savingBalance: DummyData.savingBalance,
        updatedAt: DateTime.now(),
      );

  /// Inisialisasi dokumen saldo awal untuk user baru (dapat dipanggil oleh AuthService milik Pidi).
  Future<void> initWallet(String userId, {int initialCash = 0}) async {
    final wallet = WalletModel(
      userId: userId,
      cashBalance: initialCash,
      savingBalance: 0,
      updatedAt: DateTime.now(),
    );
    await _syncWalletToFirestore(wallet);
  }

  /// Update saldo utama / saldo tabungan dan sinkronkan ke Firebase Firestore.
  Future<WalletModel> updateBalance({
    int? cashDelta,
    int? savingDelta,
  }) async {
    if (cashDelta != null) {
      DummyData.cashBalance += cashDelta;
      DummyData.totalBalance = DummyData.cashBalance + DummyData.savingBalance;
    }
    if (savingDelta != null) {
      DummyData.savingBalance += savingDelta;
      DummyData.totalBalance = DummyData.cashBalance + DummyData.savingBalance;
    }

    final updated = currentWallet;
    walletNotifier.value = updated;
    await _syncWalletToFirestore(updated);
    return updated;
  }

  /// Proses Top Up Saldo terintegrasi dengan Midtrans Sandbox + pencatatan Firestore.
  Future<MidtransOrderResult> topUpWithMidtrans({
    required int amount,
    required String paymentMethod,
    required String timeFormatted,
  }) async {
    // 1. Buat transaksi Snap di Midtrans Sandbox
    final order = await MidtransService.instance.createSnapTransaction(
      userId: FirebaseFirestoreConfig.defaultUserId,
      customerName: DummyData.userName,
      customerPhone: DummyData.phoneNumber,
      amount: amount,
      paymentMethod: paymentMethod,
    );

    // 2. Simpan log order Midtrans ke koleksi `midtrans_orders` di Firestore
    await _saveMidtransOrderToFirestore(order);

    // 3. Cek status pembayaran Midtrans Sandbox
    final paymentStatus =
        await MidtransService.instance.checkPaymentStatus(order.orderId);

    if (paymentStatus == 'settlement' || paymentStatus == 'capture') {
      await updateBalance(cashDelta: amount);

      final trx = TransactionModel(
        userId: FirebaseFirestoreConfig.defaultUserId,
        title: 'Isi Saldo $paymentMethod',
        dateTime: 'Hari Ini, $timeFormatted',
        channel: paymentMethod,
        amount: amount,
        icon: Icons.add_circle_outline_rounded,
        type: TransactionType.income,
        referenceNumber: order.orderId,
        category: 'Isi Saldo',
        dateGroup: 'Hari Ini',
        note: 'Top Up Midtrans Sandbox (${order.snapToken})',
      );

      await TransactionService.instance.addTransaction(trx);
    }

    return order;
  }

  /// Proses Transfer Uang (Sesama FinPay / Rekening Bank).
  Future<TransactionModel> transferMoney({
    required String recipient,
    required int amount,
    required bool isBankTransfer,
    required String timeFormatted,
    String? note,
  }) async {
    if (amount <= 0) {
      throw Exception('Nominal transfer harus lebih dari Rp 0.');
    }
    if (amount > DummyData.cashBalance) {
      throw Exception('Saldo FinPay Cash kamu tidak mencukupi!');
    }

    await updateBalance(cashDelta: -amount);

    final referenceNumber =
        'FPX-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final trx = TransactionModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      title: 'Transfer ke $recipient',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: isBankTransfer ? 'Transfer Bank' : 'Antar FinPay',
      amount: -amount,
      icon: Icons.person_outline_rounded,
      type: TransactionType.expense,
      referenceNumber: referenceNumber,
      category: 'Transfer',
      dateGroup: 'Hari Ini',
      note: (note == null || note.trim().isEmpty) ? 'Transfer dana' : note,
    );

    await TransactionService.instance.addTransaction(trx);
    return trx;
  }

  /// Proses Pembayaran Scan QRIS Merchant.
  ///
  /// [nmid] & [merchantCity] opsional agar pemanggil lama tetap kompatibel.
  Future<TransactionModel> payWithQris({
    required String merchantName,
    required int amount,
    required String timeFormatted,
    String? nmid,
    String? merchantCity,
    int adminFee = 0,
  }) async {
    if (amount <= 0) {
      throw Exception('Nominal pembayaran QRIS harus lebih dari Rp 0.');
    }
    final total = amount + adminFee;
    if (total > DummyData.cashBalance) {
      throw Exception('Saldo FinPay Cash kamu tidak mencukupi!');
    }

    await updateBalance(cashDelta: -total);

    final referenceNumber =
        'FPX-QR${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final location = (merchantCity == null || merchantCity.isEmpty)
        ? ''
        : ' ($merchantCity)';
    final nmidNote = (nmid == null || nmid.isEmpty) ? '' : ' • NMID $nmid';
    final trx = TransactionModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      title: 'Belanja QRIS $merchantName',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: 'QRIS Pay',
      amount: -total,
      icon: Icons.qr_code_scanner_rounded,
      type: TransactionType.expense,
      referenceNumber: referenceNumber,
      category: 'Pembayaran QRIS',
      adminFee: adminFee,
      dateGroup: 'Hari Ini',
      note: 'Pembayaran QRIS di $merchantName$location$nmidNote',
    );

    await TransactionService.instance.addTransaction(trx);
    return trx;
  }

  /// Menerima uang masuk dari pembayaran ke QRIS milik pengguna.
  Future<TransactionModel> receiveQris({
    required String payerName,
    required int amount,
    required String timeFormatted,
    String? payerApp,
  }) async {
    QrisService.instance.validateAmount(amount);

    await updateBalance(cashDelta: amount);

    final referenceNumber =
        'FPX-QR${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final trx = TransactionModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      title: 'Terima QRIS dari $payerName',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: 'QRIS Terima',
      amount: amount,
      icon: Icons.qr_code_2_rounded,
      type: TransactionType.income,
      referenceNumber: referenceNumber,
      category: 'Terima QRIS',
      dateGroup: 'Hari Ini',
      note: payerApp == null
          ? 'Pembayaran masuk via QRIS FinPay'
          : 'Pembayaran masuk via QRIS FinPay dari $payerApp',
    );

    await TransactionService.instance.addTransaction(trx);
    return trx;
  }

  final Set<String> _creditedQrisOrders = <String>{};

  /// Langkah 1 Top Up QRIS: buat tagihan di Midtrans Sandbox dan
  /// kembalikan QRIS dinamis (nominal terkunci) untuk dibayar dari aplikasi bank lain.
  Future<({MidtransOrderResult order, String qrisString})> createQrisTopUp({
    required int amount,
  }) async {
    QrisService.instance.validateAmount(amount);

    final order = await MidtransService.instance.createSnapTransaction(
      userId: FirebaseFirestoreConfig.defaultUserId,
      customerName: DummyData.userName,
      customerPhone: DummyData.phoneNumber,
      amount: amount,
      paymentMethod: 'QRIS',
    );
    await _saveMidtransOrderToFirestore(order);

    final payload = QrisPayload(
      merchantName: 'FinPay Top Up ${DummyData.userName}',
      merchantCity: 'Jakarta',
      nmid: QrisService.instance.myNmid,
      merchantCategoryCode: '6012',
      amount: amount,
      referenceLabel: order.orderId,
      terminalLabel: 'TOPUPQRIS',
    );

    return (order: order, qrisString: payload.encode());
  }

  /// Langkah 2 Top Up QRIS: cek status di Midtrans, lalu kredit saldo sekali saja.
  Future<TransactionModel> confirmQrisTopUp({
    required MidtransOrderResult order,
    required String timeFormatted,
  }) async {
    if (_creditedQrisOrders.contains(order.orderId)) {
      throw Exception('Top up ${order.orderId} sudah pernah dikreditkan.');
    }

    final status = await MidtransService.instance.checkPaymentStatus(
      order.orderId,
    );
    if (status != 'settlement' && status != 'capture') {
      throw Exception(
        'Pembayaran QRIS belum diterima (status: ${status.toUpperCase()}).',
      );
    }

    _creditedQrisOrders.add(order.orderId);
    await updateBalance(cashDelta: order.amount);

    final trx = TransactionModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      title: 'Isi Saldo via QRIS',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: 'QRIS',
      amount: order.amount,
      icon: Icons.add_circle_outline_rounded,
      type: TransactionType.income,
      referenceNumber: order.orderId,
      category: 'Isi Saldo',
      dateGroup: 'Hari Ini',
      note: 'Top Up QRIS Midtrans Sandbox (${order.snapToken})',
    );

    await TransactionService.instance.addTransaction(trx);
    return trx;
  }

  /// Membuat Kode Tarik Tunai ATM / Minimarket & memotong saldo utama.
  Future<Map<String, String>> createCashoutCode({
    required int amount,
    required String channelName,
    required String timeFormatted,
  }) async {
    if (amount > DummyData.cashBalance) {
      throw Exception('Saldo FinPay Cash kamu tidak mencukupi!');
    }

    await updateBalance(cashDelta: -amount);

    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    final referenceNumber = 'FPX-${millis.substring(5)}';
    final tokenCode =
        '${millis.substring(millis.length - 4)}-${millis.substring(millis.length - 8, millis.length - 4)}-4819';

    final trx = TransactionModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      title: 'Tarik Tunai $channelName',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: 'Tarik Tunai',
      amount: -amount,
      icon: Icons.payments_outlined,
      type: TransactionType.expense,
      referenceNumber: referenceNumber,
      category: 'Tarik Tunai',
      dateGroup: 'Hari Ini',
      note: 'Kode Penarikan: $tokenCode',
    );

    await TransactionService.instance.addTransaction(trx);
    return {
      'tokenCode': tokenCode,
      'referenceNumber': referenceNumber,
    };
  }

  /// Proses Setor Tabungan Impian: memindahkan dana dari Saldo Cash ke Saldo Tabungan
  /// dan mencatat mutasi ke koleksi `transactions` & `wallets` di Firestore.
  Future<TransactionModel> depositToSaving({
    required int amount,
    required String goalTitle,
    required String timeFormatted,
  }) async {
    if (amount <= 0) {
      throw Exception('Nominal setoran tabungan harus lebih dari Rp 0.');
    }
    if (amount > DummyData.cashBalance) {
      throw Exception('Saldo FinPay Cash kamu tidak mencukupi!');
    }

    await updateBalance(cashDelta: -amount, savingDelta: amount);

    final referenceNumber =
        'FPX-SV${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final trx = TransactionModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      title: 'Setor Tabungan: $goalTitle',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: 'Tabungan FinPay',
      amount: -amount,
      icon: Icons.savings_outlined,
      type: TransactionType.saving,
      referenceNumber: referenceNumber,
      category: 'Tabungan',
      dateGroup: 'Hari Ini',
      note: 'Alokasi tabungan impian ($goalTitle)',
    );

    await TransactionService.instance.addTransaction(trx);
    return trx;
  }

  /// Proses Pencairan Pinjaman Instan FinPay Loan ke Saldo Cash
  /// beserta perhitungan cicilan bulanan (bunga 0.9% / bulan).
  Future<({TransactionModel transaction, int monthlyInstallment})> disburseLoan({
    required int amount,
    required int tenorMonths,
    required String timeFormatted,
  }) async {
    if (amount < 1000000) {
      throw Exception('Nominal pengajuan pinjaman minimal Rp 1.000.000.');
    }
    if (tenorMonths <= 0) {
      throw Exception('Tenor cicilan tidak valid.');
    }

    await updateBalance(cashDelta: amount);

    // Bunga flat 0.9% per bulan
    final totalWithInterest = amount * (1 + (0.009 * tenorMonths));
    final monthlyInstallment = (totalWithInterest / tenorMonths).round();

    final referenceNumber =
        'FPX-LN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final trx = TransactionModel(
      userId: FirebaseFirestoreConfig.defaultUserId,
      title: 'Pencairan Pinjaman FinPay Loan',
      dateTime: 'Hari Ini, $timeFormatted',
      channel: 'FinPay Loan OJK',
      amount: amount,
      icon: Icons.account_balance_wallet_outlined,
      type: TransactionType.income,
      referenceNumber: referenceNumber,
      category: 'Pinjaman',
      dateGroup: 'Hari Ini',
      note: 'Tenor $tenorMonths bulan • Cicilan Rp $monthlyInstallment/bln',
    );

    await TransactionService.instance.addTransaction(trx);
    return (transaction: trx, monthlyInstallment: monthlyInstallment);
  }

  Future<void> _syncWalletToFirestore(WalletModel wallet) async {
    if (!FirebaseFirestoreConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/wallets/${wallet.userId}',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final request = await client.patchUrl(url);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final payload = {
        'fields': {
          'userId': {'stringValue': wallet.userId},
          'cashBalance': {'integerValue': wallet.cashBalance.toString()},
          'savingBalance': {'integerValue': wallet.savingBalance.toString()},
          'totalWealth': {'integerValue': wallet.totalWealth.toString()},
          'updatedAt': {
            'stringValue':
                (wallet.updatedAt ?? DateTime.now()).toIso8601String(),
          },
        },
      };

      request.write(jsonEncode(payload));
      final response = await request.close();
      await response.drain<void>();
      client.close();
    } catch (_) {
      // Tetap aman secara lokal jika belum ada koneksi internet.
    }
  }

  Future<void> _saveMidtransOrderToFirestore(MidtransOrderResult order) async {
    if (!FirebaseFirestoreConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/midtrans_orders?documentId=${order.orderId}',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final request = await client.postUrl(url);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      final payload = {
        'fields': {
          'orderId': {'stringValue': order.orderId},
          'userId': {'stringValue': order.userId},
          'amount': {'integerValue': order.amount.toString()},
          'paymentType': {'stringValue': order.paymentMethod},
          'snapToken': {'stringValue': order.snapToken},
          'redirectUrl': {'stringValue': order.redirectUrl},
          'vaNumber': {'stringValue': order.vaNumber},
          'status': {'stringValue': order.status},
          'createdAt': {'stringValue': order.createdAt.toIso8601String()},
        },
      };

      request.write(jsonEncode(payload));
      final response = await request.close();
      await response.drain<void>();
      client.close();
    } catch (_) {}
  }
}
