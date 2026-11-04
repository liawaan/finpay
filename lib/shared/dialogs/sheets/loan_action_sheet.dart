import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/dummy/dummy_data.dart';
import '../../../data/services/wallet_service.dart';
import '../../widgets/pill_badge.dart';
import '../widgets/finpay_receipt_dialog.dart';

/// Bottom Sheet Pinjaman Instan FinPay Loan terhubung ke [WalletService.disburseLoan].
class LoanActionSheet extends StatefulWidget {
  const LoanActionSheet({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  State<LoanActionSheet> createState() => _LoanActionSheetState();
}

class _LoanActionSheetState extends State<LoanActionSheet> {
  double _loanAmount = 5000000;
  int _tenorMonths = 6;
  bool _isProcessing = false;

  Future<void> _processLoan() async {
    if (_isProcessing) return;
    final amount = _loanAmount.round();
    final timeFormatted = TimeOfDay.now().format(context);
    final nav = Navigator.of(context);
    final rootContext = nav.context;

    setState(() => _isProcessing = true);
    try {
      final result = await WalletService.instance.disburseLoan(
        amount: amount,
        tenorMonths: _tenorMonths,
        timeFormatted: timeFormatted,
      );
      widget.onSuccess?.call();
      if (!mounted) return;
      nav.pop();
      if (!rootContext.mounted) return;
      await showFinPayReceiptDialog(
        rootContext,
        title: 'Pinjaman Cair! 🏦',
        amountText: CurrencyFormatter.rupiah(amount, withSign: true),
        amountColor: AppColors.success,
        referenceNumber: result.transaction.referenceNumber,
        details: [
          {'label': 'No. Referensi', 'value': result.transaction.referenceNumber},
          {'label': 'Penyedia Dana', 'value': 'FinPay Loan (Berizin OJK)'},
          {'label': 'Suku Bunga', 'value': '0.9% / bulan'},
          {'label': 'Tenor Cicilan', 'value': '$_tenorMonths Bulan'},
          {
            'label': 'Cicilan Bulanan',
            'value': CurrencyFormatter.rupiah(result.monthlyInstallment),
          },
          {
            'label': 'Saldo Cash Baru',
            'value': CurrencyFormatter.rupiah(DummyData.cashBalance),
          },
        ],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _loanAmount.round();
    final estimatedInstallment =
        ((amount * (1 + 0.009 * _tenorMonths)) / _tenorMonths).round();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              padding: EdgeInsets.only(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pinjaman Instan FinPay', style: AppTextStyles.h2),
                      const PillBadge(
                        label: 'OJK Verified',
                        backgroundColor: AppColors.dangerLight,
                        foregroundColor: AppColors.danger,
                      ),
                    ],
                  ),
                  Text(
                    'Persetujuan 5 menit cair ke Saldo Cash & tercatat di Firestore',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Jumlah Pengajuan: ${CurrencyFormatter.rupiah(amount)}',
                    style: AppTextStyles.h3,
                  ),
                  Slider(
                    value: _loanAmount,
                    min: 1000000,
                    max: 25000000,
                    divisions: 24,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _loanAmount = val),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rp 1.000.000', style: AppTextStyles.caption),
                      Text('Rp 25.000.000', style: AppTextStyles.caption),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Pilih Tenor Cicilan', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [3, 6, 12].map((m) {
                      return ChoiceChip(
                        label: Text('$m Bulan'),
                        selected: _tenorMonths == m,
                        onSelected: (sel) {
                          if (sel) setState(() => _tenorMonths = m);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _tenorMonths == m
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimasi Cicilan:', style: AppTextStyles.caption),
                        Text(
                          '${CurrencyFormatter.rupiah(estimatedInstallment)} / bulan',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processLoan,
                      icon: const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isProcessing
                            ? 'Mencairkan Pinjaman...'
                            : 'Ajukan Pinjaman Instan',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
