import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/menu_item_data.dart';
import '../models/transaction_model.dart';

/// Data dummy untuk tampilan Beranda, Riwayat, dan Keuangan.
/// Ganti dengan data dari API / repository saat integrasi backend.
abstract class DummyData {
  // ---------- Profil & Saldo ----------
  static String userName = '';
  static const String membership = 'FinPay Reguler';
  static const int finPoin = 0;
  static String phoneNumber = '';

  static int totalBalance = 0;
  static int cashBalance = 0;
  static int savingBalance = 0;

  static int get totalWealth => cashBalance + savingBalance;

  // ---------- Quick Actions ----------
  static const List<MenuItemData> quickActions = [
    MenuItemData(
      label: 'Top Up',
      icon: Icons.add_circle_outline_rounded,
      badge: MenuBadge.text('QRIS', color: AppColors.textPrimary),
    ),
    MenuItemData(
      label: 'Transfer',
      icon: Icons.swap_horiz_rounded,
      backgroundColor: AppColors.mintLight,
      iconColor: Color(0xFF0F766E),
    ),
    MenuItemData(label: 'Tarik Tunai', icon: Icons.payments_outlined),
    MenuItemData(
      label: 'QRIS Pay',
      icon: Icons.qr_code_scanner_rounded,
      backgroundColor: AppColors.primary,
      iconColor: Colors.white,
    ),
  ];

  // ---------- Layanan Keuangan ----------
  static const List<MenuItemData> services = [
    MenuItemData(
        label: 'Isi Saldo', icon: Icons.account_balance_wallet_outlined),
    MenuItemData(label: 'Kirim Uang', icon: Icons.send_to_mobile_outlined),
    MenuItemData(
      label: 'Menabung',
      icon: Icons.savings_outlined,
      badge: MenuBadge.dot(color: AppColors.success),
    ),
    MenuItemData(label: 'Cash Flow', icon: Icons.donut_large_rounded),
    MenuItemData(label: 'Promo Fin', icon: Icons.redeem_outlined),
  ];

  // ---------- Sorotan Keuangan ----------
  static const String highlightPeriod = 'Bulan Oktober 2024';
  static const int monthlyIncome = 8500000;
  static const int monthlyExpense = 3650000;
  static const String incomeGrowth = '+14% dr bln lalu';
  static const String expenseNote = '42% batas aman';

  // ---------- Target Menabung ----------
  static const String savingGoalTitle = 'Target Menabung: Liburan ke Jepang';
  static const int savingGoalMonthly = 500000;
  static const int savingGoalCurrent = 7500000;
  static const int savingGoalTarget = 15000000;
  static const String savingGoalEta = 'Mei 2025';

  static const String emergencyFundTitle = 'Dana Darurat 6 Bulan';
  static const int emergencyFundCurrent = 8000000;
  static const int emergencyFundTarget = 10000000;

  // ---------- Pinjaman Instan ----------
  static const int loanMaxAmount = 25000000;
  static const int loanMinInstallment = 350000;
  static const String loanInterest = 'Bunga 0.9%/bln';

  // ---------- Riwayat Transaksi ----------
  static final List<TransactionModel> transactions = [];
}
