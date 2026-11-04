import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/dummy/dummy_data.dart';
import '../../../data/services/wallet_service.dart';
import '../widgets/finpay_receipt_dialog.dart';

/// Bottom Sheet Tarik Tunai Tanpa Kartu terhubung ke [WalletService.createCashoutCode].
class CashoutActionSheet extends StatefulWidget {
  const CashoutActionSheet({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  State<CashoutActionSheet> createState() => _CashoutActionSheetState();
}

class _CashoutActionSheetState extends State<CashoutActionSheet> {
  int _amount = 200000;
  String _channel = 'Kasir Indomaret / Alfamart';
  bool _isProcessing = false;

  final List<String> _channels = const [
    'Kasir Indomaret / Alfamart',
    'ATM BCA Tanpa Kartu',
    'ATM Mandiri / BRI',
  ];

  Future<void> _processCashout() async {
    if (_isProcessing) return;
    final timeFormatted = TimeOfDay.now().format(context);
    final nav = Navigator.of(context);
    final rootContext = nav.context;

    setState(() => _isProcessing = true);
    try {
      final result = await WalletService.instance.createCashoutCode(
        amount: _amount,
        channelName: _channel,
        timeFormatted: timeFormatted,
      );
      widget.onSuccess?.call();
      if (!mounted) return;
      nav.pop();
      if (!rootContext.mounted) return;
      await showFinPayReceiptDialog(
        rootContext,
        title: 'Kode Tarik Tunai Dibuat! 🏪',
        amountText: CurrencyFormatter.rupiah(-_amount, withSign: true),
        amountColor: AppColors.danger,
        referenceNumber: result['referenceNumber'],
        details: [
          {'label': 'No. Referensi', 'value': result['referenceNumber'] ?? '-'},
          {'label': 'Lokasi Penarikan', 'value': _channel},
          {'label': 'Kode Token Penarikan', 'value': result['tokenCode'] ?? '-'},
          {'label': 'Masa Berlaku Kode', 'value': '30 Menit'},
          {
            'label': 'Sisa Saldo Cash',
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
                  Text('Tarik Tunai Tanpa Kartu', style: AppTextStyles.h2),
                  Text(
                    'Tarik saldo cash di Indomaret/Alfamart atau ATM terdekat',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Pilih Kanal Penarikan', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  for (final ch in _channels)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _channel == ch
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                        borderRadius: AppRadius.mdAll,
                        color: _channel == ch
                            ? AppColors.primarySoft
                            : AppColors.surface,
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          _channel == ch
                              ? Icons.check_circle_rounded
                              : Icons.atm_rounded,
                          color: _channel == ch
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          ch,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        onTap: () => setState(() => _channel = ch),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Pilih Nominal Penarikan', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [100000, 200000, 500000, 1000000].map((amt) {
                      return ChoiceChip(
                        label: Text(CurrencyFormatter.rupiah(amt)),
                        selected: _amount == amt,
                        onSelected: (sel) {
                          if (sel) setState(() => _amount = amt);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _amount == amt
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
                      onPressed: _isProcessing ? null : _processCashout,
                      icon: const Icon(
                        Icons.payments_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isProcessing
                            ? 'Membuat Kode Tarik...'
                            : 'Buat Kode Tarik ${CurrencyFormatter.rupiah(_amount)}',
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
