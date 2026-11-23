import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/dummy/dummy_data.dart';
import '../../../data/models/qris_model.dart';
import '../../../data/services/qris_service.dart';
import 'qris_pin_sheet.dart';

/// Menampilkan konfirmasi pembayaran QRIS. Mengembalikan nominal yang
/// disetujui pengguna, atau `null` jika dibatalkan.
Future<int?> showQrisConfirmSheet(BuildContext context, QrisPayload payload) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _QrisConfirmSheet(payload: payload),
  );
}

class _QrisConfirmSheet extends StatefulWidget {
  const _QrisConfirmSheet({required this.payload});

  final QrisPayload payload;

  @override
  State<_QrisConfirmSheet> createState() => _QrisConfirmSheetState();
}

class _QrisConfirmSheetState extends State<_QrisConfirmSheet> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _enteredAmount => int.tryParse(
        _amountController.text.replaceAll('.', '').replaceAll('Rp', '').trim(),
      );

  /// Nominal efektif yang akan dibayar, atau `null` bila belum valid.
  int? get _amount {
    try {
      return QrisService.instance.resolveAmount(
        widget.payload,
        enteredAmount: _enteredAmount,
      );
    } on QrisFormatException {
      return null;
    }
  }

  String? get _errorText {
    if (widget.payload.isDynamic) return null;
    if (_amountController.text.isEmpty) return null;
    try {
      QrisService.instance.resolveAmount(
        widget.payload,
        enteredAmount: _enteredAmount,
      );
      return null;
    } on QrisFormatException catch (e) {
      return e.message;
    }
  }

  Future<void> _confirmWithPin(int amount, int total) async {
    final verified = await showQrisPinSheet(
      context,
      title: 'PIN Pembayaran QRIS',
      subtitle:
          'Konfirmasi pembayaran ${CurrencyFormatter.rupiah(total)} ke ${widget.payload.merchantName}',
    );
    if (!verified || !mounted) return;
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final amount = _amount;
    final fee = amount == null ? 0 : QrisService.instance.adminFee(amount);
    final total = (amount ?? 0) + fee;
    final insufficient = amount != null && total > DummyData.cashBalance;
    final canPay = amount != null && !insufficient;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: AppSpacing.lg),
                Text(
                  payload.isFinPayUser
                      ? 'Konfirmasi Transfer QRIS'
                      : 'Konfirmasi Pembayaran QRIS',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payload.merchantName, style: AppTextStyles.h3),
                      const SizedBox(height: 2),
                      Text(
                        payload.isFinPayUser
                            ? 'Penerima Transfer QRIS FinPay (${payload.merchantCity})'
                            : payload.merchantCity,
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'NMID ${payload.nmid} • MCC ${payload.merchantCategoryCode}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (payload.isDynamic)
                  _InfoRow(
                    label: 'Nominal (terkunci di QRIS)',
                    value: CurrencyFormatter.rupiah(payload.amount!),
                    bold: true,
                  )
                else
                  TextField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Masukkan nominal (Rp)',
                      prefixIcon: const Icon(Icons.payments_rounded),
                      errorText: _errorText,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.border),
                _InfoRow(
                  label: 'Sumber dana',
                  value: 'FinPay Cash (${CurrencyFormatter.rupiah(DummyData.cashBalance)})',
                ),
                _InfoRow(
                  label: 'Biaya layanan',
                  value: fee == 0 ? 'Gratis' : CurrencyFormatter.rupiah(fee),
                ),
                _InfoRow(
                  label: 'Total bayar',
                  value: amount == null ? '-' : CurrencyFormatter.rupiah(total),
                  bold: true,
                ),
                if (insufficient) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Saldo FinPay Cash tidak mencukupi. Isi saldo terlebih dahulu.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: canPay
                            ? () => _confirmWithPin(amount, total)
                            : null,
                        icon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                        ),
                        label: Text(
                          amount == null
                              ? 'Bayar'
                              : 'Bayar ${CurrencyFormatter.rupiah(total)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
