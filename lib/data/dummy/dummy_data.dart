import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/menu_item_data.dart';
import '../models/transaction_model.dart';

/// Data dummy untuk tampilan Beranda, Riwayat, dan Keuangan.
/// Ganti dengan data dari API / repository saat integrasi backend.
abstract class DummyData {
  // ---------- Profil & Saldo ----------
  static String userName = 'Reza Pratama';
  static const String membership = 'FinPay Premier';
  static const int finPoin = 1420;
  static String phoneNumber = '0812-3456-7890';

  static int totalBalance = 14850000;
  static int cashBalance = 12350000;
  static int savingBalance = 2500000;

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
  static final List<TransactionModel> transactions = [
    const TransactionModel(
      title: 'Top Up QRIS Admin',
      dateTime: '24 Okt, 18:20',
      channel: 'BCA Virtual',
      amount: 500000,
      icon: Icons.qr_code_2_rounded,
      type: TransactionType.income,
      referenceNumber: 'FPX-90821231',
      category: 'Isi Saldo',
      dateGroup: 'Hari Ini, 24 Oktober 2024',
      note: 'Top up saldo via Virtual Account BCA',
    ),
    const TransactionModel(
      title: 'Transfer ke Budi Santoso',
      dateTime: '24 Okt, 09:15',
      channel: 'Antar FinPay',
      amount: -250000,
      icon: Icons.person_outline_rounded,
      type: TransactionType.expense,
      referenceNumber: 'FPX-90820012',
      category: 'Transfer',
      dateGroup: 'Hari Ini, 24 Oktober 2024',
      note: 'Pembayaran patungan makan siang',
    ),
    const TransactionModel(
      title: 'Pindah ke Tabungan Impian',
      dateTime: '23 Okt, 18:00',
      channel: 'Auto-debet',
      amount: -1000000,
      icon: Icons.savings_outlined,
      type: TransactionType.saving,
      referenceNumber: 'FPX-90772100',
      category: 'Tabungan',
      dateGroup: 'Kemarin, 23 Oktober 2024',
      note: 'Auto-debit mingguan Tabungan Impian',
    ),
    const TransactionModel(
      title: 'Belanja Indomaret QRIS',
      dateTime: '23 Okt, 12:45',
      channel: 'QRIS Pay',
      amount: -78500,
      icon: Icons.shopping_bag_outlined,
      type: TransactionType.expense,
      referenceNumber: 'FPX-90768912',
      category: 'Pembayaran Merchant',
      dateGroup: 'Kemarin, 23 Oktober 2024',
    ),
    const TransactionModel(
      title: 'Pencairan Dana Instan',
      dateTime: '20 Okt, 11:30',
      channel: 'FinPay Loan',
      amount: 5000000,
      icon: Icons.account_balance_wallet_outlined,
      type: TransactionType.income,
      referenceNumber: 'FPX-90123849',
      category: 'Pinjaman',
      dateGroup: '20 Oktober 2024',
      note: 'Pencairan pinjaman instan FinPay',
    ),
    const TransactionModel(
      title: 'Transfer dari Siska Pertiwi',
      dateTime: '18 Okt, 16:10',
      channel: 'Bank Mandiri',
      amount: 350000,
      icon: Icons.swap_horiz_rounded,
      type: TransactionType.income,
      referenceNumber: 'FPX-89871239',
      category: 'Transfer',
      dateGroup: '18 Oktober 2024',
      note: 'Ganti uang tiket bioskop',
    ),
    const TransactionModel(
      title: 'Tarik Tunai ATM Bersama',
      dateTime: '10 Okt, 19:25',
      channel: 'Tarik Tunai',
      amount: -500000,
      icon: Icons.payments_outlined,
      type: TransactionType.expense,
      referenceNumber: 'FPX-87120392',
      category: 'Tarik Tunai',
      adminFee: 6500,
      dateGroup: '10 Oktober 2024',
    ),
  ];
}
