import 'package:finpay/core/theme/app_theme.dart';
import 'package:finpay/data/models/support_chat_model.dart';
import 'package:finpay/data/services/midtrans_service.dart';
import 'package:finpay/data/services/support_chat_service.dart';
import 'package:finpay/data/services/transaction_service.dart';
import 'package:finpay/features/admin/admin_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    FirebaseFirestoreConfig.projectId = '';
  });

  tearDown(() {
    FirebaseFirestoreConfig.projectId = 'finpay-app-4026a';
  });

  group('SupportMessageModel & SupportChatService Tests', () {
    test('SupportMessageModel Firestore serializer round-trip dan copyWith', () {
      final original = SupportMessageModel(
        id: 'msg_test_01',
        userId: 'finpay_user_99',
        userName: 'Ali Akbar',
        text: 'Halo CS FinPay, cek status QRIS saya',
        isFromAdmin: false,
        timestamp: DateTime(2026, 11, 21, 13, 5),
        isRead: false,
      );

      expect(original.timeFormatted, '13:05');

      final fields = original.toFirestoreFields();
      final parsed = SupportMessageModel.fromFirestoreFields(fields);

      expect(parsed.id, original.id);
      expect(parsed.userId, 'finpay_user_99');
      expect(parsed.userName, 'Ali Akbar');
      expect(parsed.text, original.text);
      expect(parsed.isFromAdmin, isFalse);
      expect(parsed.isRead, isFalse);

      final updated = parsed.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.id, original.id);
    });

    test('ensureWelcomeMessageForUser, sendMessage, auto-reply, dan markMessagesAsRead', () async {
      const testUid = 'finpay_user_test_cs';
      SupportChatService.instance.ensureWelcomeMessageForUser(
        userId: testUid,
        userName: 'Ali Akbar',
      );

      final afterWelcome =
          SupportChatService.instance.getMessagesForUser(testUid);
      expect(afterWelcome.length, 1);
      expect(afterWelcome.first.isFromAdmin, isTrue);

      await SupportChatService.instance.sendMessage(
        userId: testUid,
        userName: 'Ali Akbar',
        text: 'Top up belum masuk via QRIS',
        isFromAdmin: false,
      );

      expect(
        SupportChatService.instance.unreadCountForUser(testUid, forAdmin: true),
        1,
      );

      SupportChatService.instance.markMessagesAsRead(
        testUid,
        readByAdmin: true,
      );
      expect(
        SupportChatService.instance.unreadCountForUser(testUid, forAdmin: true),
        0,
      );

      final autoReply =
          await SupportChatService.instance.sendAutoReplyForUserMessage(
        userId: testUid,
        userName: 'Ali Akbar',
        userText: 'Top up belum masuk via QRIS',
      );
      expect(autoReply.isFromAdmin, isTrue);
      expect(autoReply.text.toLowerCase(), contains('order id'));
    });
  });

  group('MidtransService & MidtransOrderResult Tests', () {
    test('MidtransOrderResult Firestore serializer round-trip dan copyWith', () {
      final order = MidtransOrderResult(
        orderId: 'FPX-12345678',
        userId: 'finpay_user_01',
        amount: 350000,
        paymentMethod: 'BCA Virtual Account',
        snapToken: 'sandbox-token-fpx-12345678',
        redirectUrl:
            'https://app.sandbox.midtrans.com/snap/v2/vtweb/FPX-12345678',
        vaNumber: '88012 081234567890',
        status: 'pending',
        createdAt: DateTime(2026, 11, 21, 14, 0),
      );

      expect(order.isSettled, isFalse);

      final fields = order.toFirestoreFields();
      final parsed = MidtransOrderResult.fromFirestoreFields(fields);

      expect(parsed.orderId, 'FPX-12345678');
      expect(parsed.amount, 350000);
      expect(parsed.paymentMethod, 'BCA Virtual Account');
      expect(parsed.status, 'pending');

      final settled = parsed.copyWith(status: 'settlement');
      expect(settled.isSettled, isTrue);
    });

    test('createSnapTransaction menambahkan order baru ke ordersNotifier', () async {
      final beforeCount = MidtransService.instance.orders.length;

      final result = await MidtransService.instance.createSnapTransaction(
        userId: 'finpay_user_01',
        customerName: 'Ali Akbar',
        customerPhone: '0812-3456-7890',
        amount: 150000,
        paymentMethod: 'Mandiri Virtual Account',
      );

      expect(result.orderId, startsWith('FPX-'));
      expect(result.vaNumber, startsWith('88013 '));
      expect(result.isSettled, isTrue);
      expect(MidtransService.instance.orders.length, beforeCount + 1);

      final status =
          await MidtransService.instance.checkPaymentStatus(result.orderId);
      expect(status, 'settlement');
    });
  });

  group('AdminDashboardPage Live Integration Tests', () {
    testWidgets(
      'AdminDashboardPage merender tab Midtrans Sandbox live dan menyetujui permohonan KYC',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const AdminDashboardPage(),
          ),
        );
        await tester.pump();

        expect(find.text('FinPay Admin'), findsOneWidget);
        expect(find.text('Sync Firestore'), findsOneWidget);

        // Buka Tab Midtrans Sandbox Gateway
        await tester.tap(find.text('Midtrans Sandbox Gateway'));
        await tester.pump();

        expect(find.text('Audit Transaksi Midtrans Sandbox'), findsOneWidget);
        expect(find.text('FPX-90821231'), findsOneWidget);

        // Buka Tab Verifikasi KYC KTP
        await tester.tap(find.text('Verifikasi KYC KTP'));
        await tester.pump();

        expect(find.text('Pusat Verifikasi KYC (KTP)'), findsOneWidget);
        expect(find.text('Setujui (Approve)'), findsWidgets);

        // Setujui satu permohonan KYC
        await tester.tap(find.text('Setujui (Approve)').first);
        await tester.pump();

        expect(find.textContaining('disetujui'), findsOneWidget);
      },
    );
  });
}
