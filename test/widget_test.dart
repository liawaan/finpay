import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:finpay/data/services/auth_service.dart';
import 'package:finpay/main.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    AuthService.instance.isLoggedInNotifier.value = true;
  });

  testWidgets(
      'Splash muncul saat belum login lalu lanjut Onboarding -> Login -> Beranda',
      (tester) async {
    AuthService.instance.isLoggedInNotifier.value = false;

    await tester.pumpWidget(const FinPayApp());
    await tester.pump();

    // SplashPage tampil terlebih dahulu
    expect(find.text('FinPay'), findsOneWidget);

    // Tunggu transisi otomatis SplashPage (1800ms) menuju OnboardingPage
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Saya sudah punya akun'), findsOneWidget);
    await tester.tap(find.text('Saya sudah punya akun'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang kembali'), findsOneWidget);

    // Pindah ke tab Email lalu login sebagai Reza Pratama
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'reza.pratama@email.com');
    await tester.enterText(textFields.at(1), 'password123');
    await tester.ensureVisible(find.text('Masuk'));
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Halo, Reza Pratama'), findsOneWidget);
  });

  testWidgets('Beranda menampilkan sapaan dan saldo', (tester) async {
    await tester.pumpWidget(const FinPayApp());
    await tester.pump();

    expect(find.textContaining('Halo, Reza Pratama'), findsOneWidget);
    expect(find.text('Rp 14.850.000'), findsOneWidget);
  });

  // Surface dibuat sangat tinggi agar seluruh section ter-render,
  // sehingga overflow di bagian mana pun akan terdeteksi.
  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
    testWidgets('Tidak ada overflow pada lebar $width', (tester) async {
      tester.view.physicalSize = Size(width, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const FinPayApp());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Keamanan Terjamin FinPay'), findsOneWidget);
    });
  }

  testWidgets('Tab Riwayat menampilkan halaman lengkap beserta kartu ringkasan arus kas Rp 0 untuk user baru', (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await AuthService.instance.register(
      fullName: 'User Baru Test',
      nik: '3174123456780099',
      birthDate: '1 Januari 2001',
      address: 'Jakarta',
      email: 'userbaru@email.com',
      phoneNumber: '081200001111',
      password: 'password123',
      pin: '654321',
    );

    await tester.pumpWidget(const FinPayApp());
    await tester.pump();

    // Tap tab Riwayat di bottom navigation bar
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Riwayat Transaksi'), findsOneWidget);
    expect(find.text('e-Statement'), findsOneWidget);
    expect(find.text('Belum Ada Aktivitas Arus Kas'), findsOneWidget);

    // Kembalikan ke akun Reza untuk test berikutnya
    await AuthService.instance.login(
      email: 'reza.pratama@email.com',
      password: 'password123',
    );
    await tester.pump();
  });

  testWidgets('Filter transaksi bekerja', (tester) async {
    tester.view.physicalSize = const Size(390, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FinPayApp());
    await tester.pump();

    expect(find.text('Transfer ke Budi Santoso'), findsOneWidget);

    await tester.tap(find.text('Pemasukan').last);
    await tester.pumpAndSettle();

    expect(find.text('Transfer ke Budi Santoso'), findsNothing);
    expect(find.text('Top Up QRIS Admin'), findsOneWidget);
  });
}
