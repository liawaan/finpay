import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/dummy/dummy_data.dart';
import '../../../data/services/wallet_service.dart';
import '../widgets/finpay_receipt_dialog.dart';

/// Bottom Sheet Setor Tabungan Impian terhubung ke [WalletService.depositToSaving].
class SavingActionSheet extends StatefulWidget {
  const SavingActionSheet({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  State<SavingActionSheet> createState() => _SavingActionSheetState();
}

class _SavingActionSheetState extends State<SavingActionSheet> {
  int _selectedAmount = 250000;
  String _selectedGoal = 'Liburan ke Jepang ✈️';
  bool _isProcessing = false;

  final List<String> _goals = const [
    'Liburan ke Jepang ✈️',
    'Dana Darurat 🛡️',
    'Gadget Impian 💻',
  ];

  Future<void> _processSaving() async {
    if (_isProcessing) return;
    final timeFormatted = TimeOfDay.now().format(context);
    final nav = Navigator.of(context);
    final rootContext = nav.context;

    setState(() => _isProcessing = true);
    try {
      final trx = await WalletService.instance.depositToSaving(
        amount: _selectedAmount,
        goalTitle: _selectedGoal,
        timeFormatted: timeFormatted,
      );
      widget.onSuccess?.call();
      if (!mounted) return;
      nav.pop();
      if (!rootContext.mounted) return;
      await showFinPayReceiptDialog(
        rootContext,
        title: 'Setoran Tabungan Berhasil! 🐷',
        amountText: CurrencyFormatter.rupiah(-_selectedAmount, withSign: true),
        amountColor: AppColors.primary,
        referenceNumber: trx.referenceNumber,
        details: [
          {'label': 'No. Referensi', 'value': trx.referenceNumber},
          {'label': 'Target Impian', 'value': _selectedGoal},
          {
            'label': 'Total Tabungan Terkumpul',
            'value': CurrencyFormatter.rupiah(DummyData.savingBalance),
          },
          {
            'label': 'Sisa Saldo Cash',
            'value': CurrencyFormatter.rupiah(DummyData.cashBalance),
          },
          {'label': 'Bunga Tabungan', 'value': '3.5% / tahun'},
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
                  Text('Menabung & Setor Impian', style: AppTextStyles.h2),
                  Text(
                    'Alokasikan dana ke tabungan impian & sinkron ke Firestore',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.savings_outlined,
                          size: 36,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target: $_selectedGoal',
                                style: AppTextStyles.h3,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Terkumpul: ${CurrencyFormatter.rupiah(DummyData.savingBalance)} / Rp 15.000.000',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Pilih Target Tabungan', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: _goals.map((g) {
                      return ChoiceChip(
                        label: Text(g),
                        selected: _selectedGoal == g,
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedGoal = g);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedGoal == g
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Pilih Nominal Setoran', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [100000, 250000, 500000, 1000000].map((amt) {
                      return ChoiceChip(
                        label: Text(CurrencyFormatter.rupiah(amt)),
                        selected: _selectedAmount == amt,
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedAmount = amt);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _selectedAmount == amt
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processSaving,
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isProcessing
                            ? 'Memproses Setoran...'
                            : 'Setor ${CurrencyFormatter.rupiah(_selectedAmount)} Sekarang',
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
