import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../dummy/dummy_data.dart';
import '../models/support_chat_model.dart';
import 'transaction_service.dart';

/// Service Komunikasi & Live Chat Customer Support (User ↔ Admin).
/// Mengelola pesan bantuan secara real-time dan menyinkronkannya ke koleksi `support_chats` di Firebase Firestore.
class SupportChatService {
  SupportChatService._() {
    _initDefaultMessages();
  }
  static final SupportChatService instance = SupportChatService._();

  final ValueNotifier<List<SupportMessageModel>> messagesNotifier =
      ValueNotifier<List<SupportMessageModel>>([]);

  void _initDefaultMessages() {
    final now = DateTime.now();
    messagesNotifier.value = [
      SupportMessageModel(
        id: 'msg_01',
        userId: 'finpay_user_01',
        userName: DummyData.userName,
        text: 'Halo! Saya mengalami kendala top up saldo via BCA Virtual Account belum masuk.',
        isFromAdmin: false,
        timestamp: now.subtract(const Duration(minutes: 25)),
        isRead: true,
      ),
      SupportMessageModel(
        id: 'msg_02',
        userId: 'finpay_user_01',
        userName: 'Admin FinPay',
        text: 'Halo Kak Reza! Baik, boleh kami minta nomor referensi transaksi (FPX) dan bukti transfernya untuk kami verifikasi?',
        isFromAdmin: true,
        timestamp: now.subtract(const Duration(minutes: 20)),
        isRead: true,
      ),
      SupportMessageModel(
        id: 'msg_03',
        userId: 'finpay_user_01',
        userName: DummyData.userName,
        text: 'Nomor referensinya FPX-90821231 nominal Rp 500.000.',
        isFromAdmin: false,
        timestamp: now.subtract(const Duration(minutes: 15)),
        isRead: true,
      ),
      SupportMessageModel(
        id: 'msg_04',
        userId: 'finpay_user_01',
        userName: 'Admin FinPay',
        text: 'Terima kasih Kak. Transaksi sudah kami sinkronkan dan saldo kas sebesar Rp 500.000 sudah masuk ke dompet Kakak. Ada hal lain yang bisa kami bantu?',
        isFromAdmin: true,
        timestamp: now.subtract(const Duration(minutes: 10)),
        isRead: true,
      ),
    ];
  }

  /// Mengambil seluruh pesan untuk satu user tertentu.
  List<SupportMessageModel> getMessagesForUser(String userId) {
    final list = messagesNotifier.value
        .where((m) => m.userId == userId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  /// Mengambil riwayat pesan CS dari koleksi `support_chats` di Firebase Firestore.
  Future<List<SupportMessageModel>> fetchMessagesFromFirebase({
    String? userId,
  }) async {
    if (!FirebaseFirestoreConfig.isConfigured) {
      return userId == null
          ? messagesNotifier.value
          : getMessagesForUser(userId);
    }

    try {
      final url = Uri.parse(
        '${FirebaseFirestoreConfig.baseUrl}/support_chats?pageSize=200',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = (decoded['documents'] as List<dynamic>?) ?? [];
        if (documents.isNotEmpty) {
          final byId = <String, SupportMessageModel>{
            for (final existing in messagesNotifier.value)
              existing.id: existing,
          };

          for (final doc in documents) {
            final docMap = doc as Map<String, dynamic>;
            final fields = docMap['fields'] as Map<String, dynamic>?;
            if (fields == null) continue;
            final docName = (docMap['name'] as String?) ?? '';
            final docId =
                docName.contains('/') ? docName.split('/').last : null;
            final parsed = SupportMessageModel.fromFirestoreFields(
              fields,
              docId: docId,
            );
            byId[parsed.id] = parsed;
          }

          final merged = byId.values.toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          messagesNotifier.value = merged;
        }
      }
    } catch (_) {
      // Tetap gunakan daftar pesan lokal jika sedang offline.
    }

    return userId == null
        ? messagesNotifier.value
        : getMessagesForUser(userId);
  }

  /// Mengirim pesan baru (bisa dari User HP atau Admin Web).
  Future<void> sendMessage({
    required String userId,
    required String userName,
    required String text,
    required bool isFromAdmin,
  }) async {
    final msg = SupportMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      text: text,
      isFromAdmin: isFromAdmin,
      timestamp: DateTime.now(),
      isRead: false,
    );

    final current = List<SupportMessageModel>.from(messagesNotifier.value)..add(msg);
    messagesNotifier.value = current;

    // Sync ke Firebase Firestore menggunakan package:http (kompatibel Web Chrome, Android, & Desktop)
    if (FirebaseFirestoreConfig.isConfigured) {
      try {
        final url = Uri.parse(
          '${FirebaseFirestoreConfig.baseUrl}/support_chats/${msg.id}',
        );
        final payload = {
          'fields': msg.toFirestoreFields(),
        };

        await http
            .patch(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        // Tetap aman menggunakan state lokal jika jaringan sedang offline.
      }
    }
  }

  /// Menambahkan pesan sapaan pembuka CS otomatis untuk user baru yang belum punya riwayat chat.
  void ensureWelcomeMessageForUser({
    required String userId,
    required String userName,
  }) {
    final existing = messagesNotifier.value.any((m) => m.userId == userId);
    if (existing) return;

    final firstName = userName.trim().isEmpty
        ? 'Kak'
        : userName.trim().split(' ').first;
    final welcome = SupportMessageModel(
      id: 'msg_welcome_$userId',
      userId: userId,
      userName: 'Admin FinPay',
      text:
          'Halo Kak $firstName! 👋 Selamat datang di Layanan Live CS FinPay 24 Jam. Ada kendala Top Up, QRIS, Transfer, atau Akun yang bisa kami bantu?',
      isFromAdmin: true,
      timestamp: DateTime.now(),
      isRead: true,
    );

    messagesNotifier.value = [
      ...messagesNotifier.value,
      welcome,
    ];
  }

  /// Menghitung jumlah pesan yang belum dibaca untuk user tertentu.
  /// - [forAdmin] = `true`: menghitung pesan dari user yang belum dibaca Admin.
  /// - [forAdmin] = `false`: menghitung pesan dari Admin yang belum dibaca user.
  int unreadCountForUser(String userId, {bool forAdmin = false}) {
    return messagesNotifier.value.where((msg) {
      if (msg.userId != userId || msg.isRead) return false;
      return forAdmin ? !msg.isFromAdmin : msg.isFromAdmin;
    }).length;
  }

  /// Membuat balasan cerdas CS berdasarkan topik pertanyaan pengguna.
  String buildSmartAdminReply(String userText, {String? userName}) {
    final lower = userText.toLowerCase();
    final firstName = (userName == null || userName.trim().isEmpty)
        ? 'Kak'
        : userName.trim().split(' ').first;

    if (lower.contains('top up') || lower.contains('isi saldo')) {
      return 'Halo Kak $firstName! Untuk kendala Top Up Virtual Account / QRIS Midtrans, mohon lampirkan Order ID (FPX-...) agar tim kami segera menyinkronkan saldo kas Kakak.';
    }
    if (lower.contains('qris')) {
      return 'Halo Kak $firstName! Pembayaran & Top Up QRIS FinPay diproses instan dengan standar EMVCo Bank Indonesia. Jika status masih pending, mohon kirimkan nomor referensi FPX-QR... ya.';
    }
    if (lower.contains('transfer') || lower.contains('bank')) {
      return 'Halo Kak $firstName! Transfer sesama FinPay masuk detik itu juga, sedangkan transfer antar bank diproses real-time. Boleh infokan nomor referensi FPX-... transaksi Kakak?';
    }
    if (lower.contains('pin') || lower.contains('lupa')) {
      return 'Halo Kak $firstName! Jika lupa PIN 6 digit, Kakak dapat melakukan reset PIN melalui menu Akun > Ubah PIN atau tombol Lupa PIN di halaman masuk.';
    }
    if (lower.contains('limit') || lower.contains('kyc')) {
      return 'Halo Kak $firstName! Limit transaksi harian mengikuti tier akun dan status verifikasi KTP (KYC). Upgrade KYC ke Terverifikasi untuk limit hingga Rp 50.000.000/hari.';
    }
    return 'Terima kasih Kak $firstName, pesan Kakak sudah diterima oleh tim Live CS FinPay dan sedang kami tindak lanjuti.';
  }

  /// Mengirimkan balasan otomatis CS FinPay setelah pengguna mengirim pertanyaan.
  Future<SupportMessageModel> sendAutoReplyForUserMessage({
    required String userId,
    required String userName,
    required String userText,
  }) async {
    final replyText = buildSmartAdminReply(userText, userName: userName);
    final replyMsg = SupportMessageModel(
      id: 'msg_auto_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: 'Admin FinPay',
      text: replyText,
      isFromAdmin: true,
      timestamp: DateTime.now(),
      isRead: false,
    );

    final current = List<SupportMessageModel>.from(messagesNotifier.value)
      ..add(replyMsg);
    messagesNotifier.value = current;

    if (FirebaseFirestoreConfig.isConfigured) {
      try {
        final url = Uri.parse(
          '${FirebaseFirestoreConfig.baseUrl}/support_chats/${replyMsg.id}',
        );
        await http
            .patch(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'fields': replyMsg.toFirestoreFields()}),
            )
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }

    return replyMsg;
  }

  /// Menandai semua pesan untuk user tertentu sebagai sudah dibaca (read).
  void markMessagesAsRead(String userId, {bool readByAdmin = true}) {
    final updated = messagesNotifier.value.map((msg) {
      final shouldMark = readByAdmin ? !msg.isFromAdmin : msg.isFromAdmin;
      if (msg.userId == userId && shouldMark && !msg.isRead) {
        return msg.copyWith(isRead: true);
      }
      return msg;
    }).toList();

    messagesNotifier.value = updated;
  }
}
