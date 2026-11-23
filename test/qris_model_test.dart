import 'package:finpay/core/theme/app_theme.dart';
import 'package:finpay/data/dummy/dummy_data.dart';
import 'package:finpay/data/models/qris_model.dart';
import 'package:finpay/data/services/account_service.dart';
import 'package:finpay/data/services/auth_service.dart';
import 'package:finpay/data/services/qris_service.dart';
import 'package:finpay/data/services/transaction_service.dart';
import 'package:finpay/data/services/wallet_service.dart';
import 'package:finpay/features/pay/pay_page.dart';
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
  const merchant = QrisPayload(
    merchantName: 'Kopi Kenangan Sudirman',
    merchantCity: 'Jakarta',
    nmid: 'ID1020023912901',
  );

  group('QrisCrc', () {
    test('menghasilkan CRC16/CCITT-FALSE standar', () {
      expect(QrisCrc.crc16('123456789'), '29B1');
    });
  });

  group('QrisPayload.encode', () {
    test('QRIS statis memakai point of initiation 11 dan tanpa nominal', () {
      final qr = merchant.encode();
      expect(qr.startsWith('000201010211'), isTrue);
      expect(qr.contains('5303360'), isTrue);
      expect(qr.contains('5802ID'), isTrue);
      expect(merchant.isDynamic, isFalse);
    });

    test('QRIS dinamis memakai 12 dan menyimpan nominal', () {
      final qr = merchant.copyWith(amount: 45000).encode();
      expect(qr.startsWith('000201010212'), isTrue);
      expect(qr.contains('540545000'), isTrue);
    });

    test('diakhiri tag CRC 6304 + 4 digit heksa', () {
      final qr = merchant.encode();
      expect(RegExp(r'6304[0-9A-F]{4}$').hasMatch(qr), isTrue);
    });
  });

  group('QrisPayload.parse', () {
    test('round-trip QRIS dinamis mengembalikan data yang sama', () {
      final qr = merchant
          .copyWith(
            amount: 125000,
            referenceLabel: 'INV-0001',
            terminalLabel: 'KASIR01',
          )
          .encode();
      final parsed = QrisPayload.parse(qr);

      expect(parsed.merchantName, 'Kopi Kenangan Sudirman');
      expect(parsed.merchantCity, 'Jakarta');
      expect(parsed.nmid, 'ID1020023912901');
      expect(parsed.amount, 125000);
      expect(parsed.isDynamic, isTrue);
      expect(parsed.referenceLabel, 'INV-0001');
      expect(parsed.terminalLabel, 'KASIR01');
    });

    test('round-trip QRIS statis tidak memiliki nominal', () {
      final parsed = QrisPayload.parse(merchant.encode());
      expect(parsed.amount, isNull);
      expect(parsed.isDynamic, isFalse);
    });

    test('menolak string yang bukan QRIS', () {
      expect(
        () => QrisPayload.parse('https://example.com'),
        throwsA(isA<QrisFormatException>()),
      );
    });

    test('menolak QRIS dengan checksum yang salah', () {
      final qr = merchant.encode();
      final tampered = '${qr.substring(0, qr.length - 4)}0000';
      expect(
        () => QrisPayload.parse(tampered),
        throwsA(isA<QrisFormatException>()),
      );
    });

    test('menolak QRIS yang nominalnya dimodifikasi', () {
      final qr = merchant.copyWith(amount: 10000).encode();
      final tampered = qr.replaceFirst('540510000', '540599999');
      expect(
        () => QrisPayload.parse(tampered),
        throwsA(isA<QrisFormatException>()),
      );
    });
  });

  group('PayPage Scan QRIS UI & Flow Tests', () {
    testWidgets(
      'PayPage menampilkan Scan QRIS, QRIS SUPPORTED, Metode QRIS Lainnya (Bayar & Transfer tanpa Tap)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const PayPage(),
          ),
        );
        await tester.pump();

        expect(find.text('Scan QRIS'), findsOneWidget);
        expect(find.text('SUPPORTED'), findsOneWidget);
        expect(find.text('Metode QRIS Lainnya'), findsOneWidget);
        expect(find.text('Bayar'), findsOneWidget);
        expect(find.text('Transfer'), findsOneWidget);
        expect(find.text('Tap'), findsNothing);
      },
    );

    testWidgets(
      'Ketuk Bayar meminta PIN 6 digit lalu menampilkan Kode QRIS Bayar (CPM)',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const PayPage(),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Bayar'));
        await tester.pumpAndSettle();

        expect(find.text('Masukkan PIN FinPay'), findsOneWidget);

        // Masukkan PIN default 123456
        for (final digit in ['1', '2', '3', '4', '5', '6']) {
          await tester.tap(find.text(digit));
          await tester.pump();
        }
        await tester.pumpAndSettle();

        expect(find.text('Kode QRIS Bayar (CPM)'), findsOneWidget);
        expect(find.text('PIN Terverifikasi'), findsOneWidget);
      },
    );

    testWidgets(
      'Ketuk Transfer langsung menampilkan halaman QRIS Saya milik pengguna',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const PayPage(),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Transfer'));
        await tester.pumpAndSettle();

        expect(find.text('QRIS Saya'), findsOneWidget);
      },
    );

    test(
      'QRIS Ali Akbar dapat di-scan oleh Reza Pratama untuk transfer dan saldo Ali bertambah',
      () async {
        // 1. Ali Akbar login dan membuat QRIS miliknya (nominal Rp 75.000)
        await AuthService.instance.login(
          email: 'ali.akbar@email.com',
          password: 'password123',
        );
        final aliInitialCash = DummyData.cashBalance;
        final aliPublishedQris = await QrisService.instance
            .publishActiveUserQris(amount: 75000);

        expect(aliPublishedQris.userName, 'Ali Akbar');
        expect(aliPublishedQris.userId, 'finpay_user_ali');

        // 2. Reza Pratama login lalu memindai (scan) kode QRIS milik Ali Akbar
        await AuthService.instance.login(
          email: 'reza.pratama@email.com',
          password: 'password123',
        );
        final rezaInitialCash = DummyData.cashBalance;

        final scannedPayload =
            QrisService.instance.scan(aliPublishedQris.qrisString);
        expect(scannedPayload.merchantName, 'Ali Akbar');
        expect(scannedPayload.isFinPayUser, isTrue);
        expect(scannedPayload.recipientUserId, 'finpay_user_ali');
        expect(scannedPayload.amount, 75000);

        // 3. Reza menyelesaikan pembayaran/transfer QRIS ke Ali
        final resolvedAmount = QrisService.instance.resolveAmount(
          scannedPayload,
        );
        final trx = await WalletService.instance.payWithQris(
          merchantName: scannedPayload.merchantName,
          merchantCity: scannedPayload.merchantCity,
          nmid: scannedPayload.nmid,
          recipientUserId: scannedPayload.recipientUserId,
          isPeerTransfer: scannedPayload.isFinPayUser,
          amount: resolvedAmount,
          timeFormatted: '12:45',
        );

        expect(trx.title, 'Transfer QRIS ke Ali Akbar');
        expect(DummyData.cashBalance, rezaInitialCash - 75000);

        // 4. Ketika Ali Akbar login kembali, saldo Ali bertambah Rp 75.000 & ada riwayat Terima QRIS dari Reza
        await AuthService.instance.login(
          email: 'ali.akbar@email.com',
          password: 'password123',
        );
        expect(DummyData.cashBalance, aliInitialCash + 75000);
        expect(
          DummyData.transactions.first.title,
          'Terima QRIS dari Reza Pratama',
        );

        // Kembalikan sesi ke Reza
        await AuthService.instance.login(
          email: 'reza.pratama@email.com',
          password: 'password123',
        );
      },
    );

    test(
      'Login sebagai Ali Akbar via Nomor HP atau Email tidak tertimpa profil Reza Pratama',
      () async {
        // Mulai dari sesi Reza Pratama
        await AuthService.instance.loginWithIdentifier(
          identifier: 'reza.pratama@email.com',
          secret: '123456',
        );
        expect(AccountService.instance.currentUser.fullName, 'Reza Pratama');

        // Login sebagai Ali Akbar menggunakan nomor HP 813-8899-7766
        final aliUser = await AuthService.instance.loginWithIdentifier(
          identifier: '81388997766',
          secret: '123456',
        );
        expect(aliUser, isNotNull);
        expect(aliUser!.userId, 'finpay_user_ali');
        expect(aliUser.fullName, 'Ali Akbar');
        expect(AccountService.instance.currentUser.fullName, 'Ali Akbar');
        expect(AuthService.instance.currentUser.fullName, 'Ali Akbar');
        expect(DummyData.userName, 'Ali Akbar');

        // Kembalikan sesi ke Reza
        await AuthService.instance.loginWithIdentifier(
          identifier: 'reza.pratama@email.com',
          secret: '123456',
        );
      },
    );
  });
}
