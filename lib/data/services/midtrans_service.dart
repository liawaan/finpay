import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'transaction_service.dart';

/// Model respons dan order pembayaran Midtrans Sandbox untuk koleksi `midtrans_orders`.
class MidtransOrderResult {
  const MidtransOrderResult({
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.snapToken,
    required this.redirectUrl,
    required this.vaNumber,
    required this.status,
    required this.createdAt,
  });

  final String orderId;
  final String userId;
  final int amount;
  final String paymentMethod;
  final String snapToken;
  final String redirectUrl;
  final String vaNumber;
  final String status; // 'pending', 'settlement', 'expire', 'cancel'
  final DateTime createdAt;

  bool get isSettled => status == 'settlement' || status == 'capture';

  MidtransOrderResult copyWith({
    String? orderId,
    String? userId,
    int? amount,
    String? paymentMethod,
    String? snapToken,
    String? redirectUrl,
    String? vaNumber,
    String? status,
    DateTime? createdAt,
  }) {
    return MidtransOrderResult(
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      snapToken: snapToken ?? this.snapToken,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      vaNumber: vaNumber ?? this.vaNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'paymentType': paymentMethod,
      'snapToken': snapToken,
      'redirectUrl': redirectUrl,
      'vaNumber': vaNumber,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreFields() {
    return {
      'orderId': {'stringValue': orderId},
      'userId': {'stringValue': userId},
      'amount': {'integerValue': amount.toString()},
      'paymentType': {'stringValue': paymentMethod},
      'snapToken': {'stringValue': snapToken},
      'redirectUrl': {'stringValue': redirectUrl},
      'vaNumber': {'stringValue': vaNumber},
      'status': {'stringValue': status},
      'createdAt': {'stringValue': createdAt.toIso8601String()},
    };
  }

  factory MidtransOrderResult.fromFirestoreFields(
    Map<String, dynamic> fields, {
    String? docId,
  }) {
    String readStr(String key, [String fallback = '']) {
      final raw = fields[key];
      if (raw is Map<String, dynamic> && raw['stringValue'] != null) {
        return raw['stringValue'].toString();
      }
      return fallback;
    }

    int readInt(String key, [int fallback = 0]) {
      final raw = fields[key];
      if (raw is Map<String, dynamic> && raw['integerValue'] != null) {
        return int.tryParse(raw['integerValue'].toString()) ?? fallback;
      }
      return fallback;
    }

    final parsedOrderId = readStr('orderId', docId ?? 'FPX-00000000');
    return MidtransOrderResult(
      orderId: parsedOrderId,
      userId: readStr('userId', 'finpay_user_01'),
      amount: readInt('amount'),
      paymentMethod: readStr('paymentType', 'BCA Virtual Account'),
      snapToken: readStr(
        'snapToken',
        'sandbox-token-${parsedOrderId.toLowerCase()}',
      ),
      redirectUrl: readStr(
        'redirectUrl',
        'https://app.sandbox.midtrans.com/snap/v2/vtweb/$parsedOrderId',
      ),
      vaNumber: readStr('vaNumber', '88012 081234567890'),
      status: readStr('status', 'settlement'),
      createdAt:
          DateTime.tryParse(readStr('createdAt')) ?? DateTime.now(),
    );
  }
}

/// Service Payment Gateway Midtrans Sandbox (Bagian Tugas Ali).
///
/// Menangani pembuatan Snap Token (`POST /snap/v1/transactions`) dan
/// pengecekan status pembayaran (`GET /v2/{order_id}/status`) di Midtrans Sandbox.
class MidtransService {
  MidtransService._() {
    _seedInitialOrders();
  }
  static final MidtransService instance = MidtransService._();

  /// Kredensial Midtrans Sandbox.
  /// Ganti dengan Server Key & Client Key dari Dashboard Midtrans Sandbox kamu:
  /// https://dashboard.sandbox.midtrans.com/settings/config_info
  static String serverKey = 'SB-Mid-server-FinPaySandboxKey2026';
  static String clientKey = 'SB-Mid-client-FinPaySandboxKey2026';

  static const String _snapSandboxUrl =
      'https://app.sandbox.midtrans.com/snap/v1/transactions';
  static const String _apiSandboxBaseUrl = 'https://api.sandbox.midtrans.com/v2';

  final Map<String, MidtransOrderResult> _ordersCache = {};

  /// Daftar order Midtrans reaktif untuk dipantau dari aplikasi maupun Admin Dashboard.
  final ValueNotifier<List<MidtransOrderResult>> ordersNotifier =
      ValueNotifier<List<MidtransOrderResult>>([]);

  List<MidtransOrderResult> get orders => List<MidtransOrderResult>.unmodifiable(
        ordersNotifier.value,
      );

  void _seedInitialOrders() {
    _publishOrders();
  }

  void _publishOrders() {
    final sorted = _ordersCache.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    ordersNotifier.value = sorted;
  }

  /// Header Basic Auth standar Midtrans: `Basic base64(ServerKey + ":")`.
  String get _basicAuthHeader {
    final bytes = utf8.encode('$serverKey:');
    return 'Basic ${base64Encode(bytes)}';
  }

  /// Membuat transaksi baru ke Midtrans Sandbox dan mengembalikan Snap Token / VA.
  Future<MidtransOrderResult> createSnapTransaction({
    required String userId,
    required String customerName,
    required String customerPhone,
    required int amount,
    required String paymentMethod,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final orderId = 'FPX-${timestamp.substring(timestamp.length - 8)}';
    final vaNumber = _generateVirtualAccount(paymentMethod, customerPhone);

    // Hanya panggil jaringan ke Midtrans Sandbox jika Server Key asli sudah diisi.
    final isRealSandboxKey = !serverKey.contains('FinPaySandboxKey2026') &&
        serverKey.startsWith('SB-Mid-server-');

    if (isRealSandboxKey) {
      try {
        final payload = {
          'transaction_details': {
            'order_id': orderId,
            'gross_amount': amount,
          },
          'customer_details': {
            'first_name': customerName,
            'phone': customerPhone,
          },
          'item_details': [
            {
              'id': 'TOPUP-FINPAY',
              'price': amount,
              'quantity': 1,
              'name': 'Top Up FinPay ($paymentMethod)',
            }
          ],
        };

        final response = await http
            .post(
              Uri.parse(_snapSandboxUrl),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': _basicAuthHeader,
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final result = MidtransOrderResult(
            orderId: orderId,
            userId: userId,
            amount: amount,
            paymentMethod: paymentMethod,
            snapToken: (data['token'] as String?) ?? 'snap-$orderId',
            redirectUrl: (data['redirect_url'] as String?) ??
                'https://app.sandbox.midtrans.com/snap/v2/vtweb/$orderId',
            vaNumber: vaNumber,
            status: 'settlement',
            createdAt: DateTime.now(),
          );
          _ordersCache[orderId] = result;
          _publishOrders();
          return result;
        }
      } catch (_) {
        // Fallback ke simulasi lokal Sandbox jika tidak ada internet / key belum diatur.
      }
    }

    // Fallback Sandbox Simulator agar dapat langsung dites di aplikasi
    final simulatedResult = MidtransOrderResult(
      orderId: orderId,
      userId: userId,
      amount: amount,
      paymentMethod: paymentMethod,
      snapToken: 'sandbox-token-${orderId.toLowerCase()}',
      redirectUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/$orderId',
      vaNumber: vaNumber,
      status: 'settlement',
      createdAt: DateTime.now(),
    );
    _ordersCache[orderId] = simulatedResult;
    _publishOrders();
    return simulatedResult;
  }

  /// Mengecek status pembayaran order dari Midtrans Sandbox API (`GET /v2/{orderId}/status`).
  Future<String> checkPaymentStatus(String orderId) async {
    final isRealSandboxKey = !serverKey.contains('FinPaySandboxKey2026') &&
        serverKey.startsWith('SB-Mid-server-');

    if (isRealSandboxKey) {
      try {
        final response = await http
            .get(
              Uri.parse('$_apiSandboxBaseUrl/$orderId/status'),
              headers: {
                'Accept': 'application/json',
                'Authorization': _basicAuthHeader,
              },
            )
            .timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final resolvedStatus =
              (data['transaction_status'] as String?) ?? 'settlement';
          final existing = _ordersCache[orderId];
          if (existing != null && existing.status != resolvedStatus) {
            _ordersCache[orderId] = existing.copyWith(status: resolvedStatus);
            _publishOrders();
          }
          return resolvedStatus;
        }
      } catch (_) {
        // Gunakan status cache lokal jika offline
      }
    }

    return _ordersCache[orderId]?.status ?? 'settlement';
  }

  /// Mengambil daftar order Midtrans dari koleksi `midtrans_orders` di Firebase Firestore.
  Future<List<MidtransOrderResult>> fetchOrdersFromFirebase({
    String? userId,
  }) async {
    if (!FirebaseFirestoreConfig.isConfigured) {
      return orders;
    }

    try {
      final url =
          Uri.parse('${FirebaseFirestoreConfig.baseUrl}/midtrans_orders');
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = (decoded['documents'] as List<dynamic>?) ?? [];
        for (final doc in documents) {
          final docMap = doc as Map<String, dynamic>;
          final fields = docMap['fields'] as Map<String, dynamic>?;
          if (fields == null) continue;
          final docName = (docMap['name'] as String?) ?? '';
          final docId = docName.contains('/') ? docName.split('/').last : null;
          final parsed = MidtransOrderResult.fromFirestoreFields(
            fields,
            docId: docId,
          );
          if (userId == null || userId.isEmpty || parsed.userId == userId) {
            _ordersCache[parsed.orderId] = parsed;
          }
        }
        _publishOrders();
      }
    } catch (_) {
      // Tetap gunakan cache lokal jika koneksi sedang offline.
    }

    return orders;
  }

  String _generateVirtualAccount(String method, String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final lower = method.toLowerCase();
    if (lower.contains('bca')) return '88012 $cleanPhone';
    if (lower.contains('mandiri')) return '88013 $cleanPhone';
    if (lower.contains('bri')) return '88014 $cleanPhone';
    return 'FINPAY-$cleanPhone';
  }
}
