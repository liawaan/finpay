import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/dummy/dummy_data.dart';
import '../../data/services/qris_service.dart';
import '../../data/services/wallet_service.dart';
import '../../features/pay/widgets/qris_confirm_sheet.dart';
import '../../features/pay/widgets/qris_merchant_picker_sheet.dart';
import '../../features/pay/widgets/qris_receipt_sheet.dart';
import '../widgets/pill_badge.dart';
import 'sheets/cashout_action_sheet.dart';
import 'sheets/loan_action_sheet.dart';
import 'sheets/saving_action_sheet.dart';
import 'sheets/top_up_action_sheet.dart';
import 'sheets/transfer_action_sheet.dart';

/// Helper terpusat untuk memproses semua transaksi & aksi Keuangan
/// dengan Bottom Sheet berukuran 85% Viewport yang terhubung penuh ke [WalletService].
abstract class FinancialActionSheets {
  static void openAction(
    BuildContext context,
    String actionLabel, {
    VoidCallback? onStateChanged,
  }) {
    final lower = actionLabel.toLowerCase();
    if (lower.contains('isi saldo') || lower.contains('top up')) {
      showTopUp(context, onStateChanged: onStateChanged);
    } else if (lower.contains('kirim') || lower.contains('transfer')) {
      showTransfer(context, onStateChanged: onStateChanged);
    } else if (lower.contains('menabung') ||
        lower.contains('tabungan') ||
        lower.contains('setor')) {
      showSaving(context, onStateChanged: onStateChanged);
    } else if (lower.contains('pinjam') || lower.contains('loan')) {
      showLoan(context, onStateChanged: onStateChanged);
    } else if (lower.contains('tarik')) {
      showCashout(context, onStateChanged: onStateChanged);
    } else if (lower.contains('qris')) {
      showQrisPay(context, onStateChanged: onStateChanged);
    } else if (lower.contains('cash flow')) {
      showCashFlowDetail(context);
    } else if (lower.contains('promo')) {
      showPromoList(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Membuka layanan $actionLabel...')),
      );
    }
  }

  static void showTopUp(BuildContext context, {VoidCallback? onStateChanged}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopUpActionSheet(onSuccess: onStateChanged),
    );
  }

  static void showTransfer(
    BuildContext context, {
    VoidCallback? onStateChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferActionSheet(onSuccess: onStateChanged),
    );
  }

  static void showSaving(BuildContext context, {VoidCallback? onStateChanged}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SavingActionSheet(onSuccess: onStateChanged),
    );
  }

  static void showLoan(BuildContext context, {VoidCallback? onStateChanged}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoanActionSheet(onSuccess: onStateChanged),
    );
  }

  static void showCashout(
    BuildContext context, {
    VoidCallback? onStateChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CashoutActionSheet(onSuccess: onStateChanged),
    );
  }

  static Future<void> showQrisPay(
    BuildContext context, {
    VoidCallback? onStateChanged,
  }) async {
    final merchant = await showQrisMerchantPicker(context);
    if (merchant == null || !context.mounted) return;

    final payload = QrisService.instance.scan(merchant.qrisString);
    final approvedAmount = await showQrisConfirmSheet(context, payload);
    if (approvedAmount == null || !context.mounted) return;

    final timeFormatted = TimeOfDay.now().format(context);
    try {
      final fee = QrisService.instance.adminFee(approvedAmount);
      final trx = await WalletService.instance.payWithQris(
        merchantName: payload.merchantName,
        merchantCity: payload.merchantCity,
        nmid: payload.nmid,
        amount: approvedAmount,
        adminFee: fee,
        timeFormatted: timeFormatted,
      );
      onStateChanged?.call();
      if (!context.mounted) return;
      await showQrisReceipt(
        context,
        transaction: trx,
        payload: payload,
      );
      onStateChanged?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  static void showCashFlowDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.donut_large_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Laporan Arus Kas FinPay', style: AppTextStyles.h2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Periode Bulan Oktober 2024',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: 'Total Pemasukan',
                            value: CurrencyFormatter.rupiah(
                              DummyData.monthlyIncome,
                            ),
                            color: AppColors.success,
                          ),
                          const Divider(height: 20),
                          _SummaryRow(
                            label: 'Total Pengeluaran',
                            value: CurrencyFormatter.rupiah(
                              DummyData.monthlyExpense,
                            ),
                            color: AppColors.danger,
                          ),
                          const Divider(height: 20),
                          _SummaryRow(
                            label: 'Surplus Bersih',
                            value: CurrencyFormatter.rupiah(
                              DummyData.monthlyIncome -
                                  DummyData.monthlyExpense,
                              withSign: true,
                            ),
                            color: AppColors.primary,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Tutup Laporan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showPromoList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Promo & Cashback FinPay 🎉',
                          style: AppTextStyles.h2,
                        ),
                        const PillBadge(
                          label: '2 Voucher Aktif',
                          backgroundColor: AppColors.goldLight,
                          foregroundColor: Color(0xFFB45309),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _PromoCardTile(
                      title: 'Cashback 50% QRIS Indomaret',
                      subtitle: 'Maks. Rp 10.000 • Berlaku s.d 31 Okt',
                      code: 'FINQRIS50',
                      icon: Icons.qr_code_2_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _PromoCardTile(
                      title: 'Cashback Transfer Antar Bank',
                      subtitle: 'Min. transaksi Rp 100.000 • s.d 15 Nov',
                      code: 'FREEADMIN',
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)
              : AppTextStyles.caption,
        ),
        Text(
          value,
          style: isBold
              ? AppTextStyles.h3.copyWith(color: color)
              : AppTextStyles.body.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
        ),
      ],
    );
  }
}

class _PromoCardTile extends StatelessWidget {
  const _PromoCardTile({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.icon,
    required this.color,
  });
  final String title;
  final String subtitle;
  final String code;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kode promo "$code" berhasil disalin!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Pakai', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
