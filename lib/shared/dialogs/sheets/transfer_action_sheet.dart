import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/dummy/dummy_data.dart';
import '../../../data/services/wallet_service.dart';
import '../widgets/finpay_receipt_dialog.dart';

/// Bottom Sheet Kirim Uang / Transfer terhubung langsung ke [WalletService.transferMoney].
class TransferActionSheet extends StatefulWidget {
  const TransferActionSheet({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  State<TransferActionSheet> createState() => _TransferActionSheetState();
}

class _TransferActionSheetState extends State<TransferActionSheet> {
  final TextEditingController _recipientController = TextEditingController(
    text: '0812-9988-7766 (Budi Santoso)',
  );
  final TextEditingController _amountController = TextEditingController(
    text: '150000',
  );
  final TextEditingController _noteController = TextEditingController(
    text: 'Patungan makan malam',
  );
  bool _isBankTransfer = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _processTransfer() async {
    if (_isProcessing) return;
    final amount = int.tryParse(
          _amountController.text
              .replaceAll('.', '')
              .replaceAll('Rp', '')
              .trim(),
        ) ??
        0;
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor HP atau rekening tujuan!')),
      );
      return;
    }

    final timeFormatted = TimeOfDay.now().format(context);
    final nav = Navigator.of(context);
    final rootContext = nav.context;

    setState(() => _isProcessing = true);
    try {
      final trx = await WalletService.instance.transferMoney(
        recipient: recipient,
        amount: amount,
        isBankTransfer: _isBankTransfer,
        timeFormatted: timeFormatted,
        note: _noteController.text,
      );
      widget.onSuccess?.call();
      if (!mounted) return;
      nav.pop();
      if (!rootContext.mounted) return;
      await showFinPayReceiptDialog(
        rootContext,
        title: 'Transfer Berhasil! 💸',
        amountText: CurrencyFormatter.rupiah(-amount, withSign: true),
        amountColor: AppColors.danger,
        referenceNumber: trx.referenceNumber,
        details: [
          {'label': 'No. Referensi', 'value': trx.referenceNumber},
          {'label': 'Penerima', 'value': recipient},
          {
            'label': 'Kanal',
            'value': _isBankTransfer
                ? 'Transfer Bank BI-FAST (Gratis)'
                : 'Sesama FinPay (Bebas Biaya)',
          },
          {'label': 'Catatan', 'value': trx.note ?? '-'},
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
                  Text('Kirim Uang / Transfer', style: AppTextStyles.h2),
                  Text(
                    'Gratis biaya transfer sesama FinPay & Bank BI-FAST',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Sesama FinPay'),
                          selected: !_isBankTransfer,
                          onSelected: (_) =>
                              setState(() => _isBankTransfer = false),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: !_isBankTransfer
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Rekening Bank'),
                          selected: _isBankTransfer,
                          onSelected: (_) =>
                              setState(() => _isBankTransfer = true),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _isBankTransfer
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _recipientController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: _isBankTransfer
                          ? 'Rekening Bank Tujuan'
                          : 'Nomor HP FinPay Tujuan',
                      prefixIcon: const Icon(
                        Icons.person_pin_rounded,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.h3,
                    decoration: InputDecoration(
                      labelText: 'Nominal Transfer (Rp)',
                      prefixIcon: const Icon(
                        Icons.payments_rounded,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _noteController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      labelText: 'Catatan Transfer (Opsional)',
                      prefixIcon: const Icon(
                        Icons.note_alt_rounded,
                        color: AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sumber Dana: FinPay Cash',
                          style: AppTextStyles.caption,
                        ),
                        Text(
                          CurrencyFormatter.rupiah(DummyData.cashBalance),
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
                      onPressed: _isProcessing ? null : _processTransfer,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(
                        _isProcessing
                            ? 'Memproses Transfer...'
                            : 'Konfirmasi Transfer Sekarang',
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
