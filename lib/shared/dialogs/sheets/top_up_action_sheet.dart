import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/dummy/dummy_data.dart';
import '../../../data/services/qris_service.dart';
import '../../../data/services/wallet_service.dart';
import '../../widgets/pill_badge.dart';
import '../../widgets/qris_code_card.dart';
import '../widgets/finpay_receipt_dialog.dart';

/// Bottom Sheet Top Up / Isi Saldo terhubung langsung ke [WalletService] & [MidtransService].
class TopUpActionSheet extends StatefulWidget {
  const TopUpActionSheet({super.key, this.onSuccess});
  final VoidCallback? onSuccess;

  @override
  State<TopUpActionSheet> createState() => _TopUpActionSheetState();
}

class _TopUpActionSheetState extends State<TopUpActionSheet> {
  int _selectedAmount = 100000;
  String _selectedMethod = 'QRIS Top Up';
  bool _isProcessing = false;

  final List<int> _amounts = [50000, 100000, 200000, 500000, 1000000];
  final List<Map<String, String>> _methods = const [
    {
      'name': 'QRIS Top Up',
      'desc': 'Scan QRIS dari Mobile Banking / E-Wallet • Instan',
      'code': 'QRIS',
    },
    {
      'name': 'BCA Virtual Account',
      'desc': 'Bebas Biaya Admin • Midtrans Sandbox',
      'code': '88012',
    },
    {
      'name': 'Mandiri Virtual Account',
      'desc': 'Bebas Biaya Admin • Midtrans Sandbox',
      'code': '88013',
    },
    {
      'name': 'Indomaret / Alfamart',
      'desc': 'Biaya Admin Rp 1.500 • Midtrans Sandbox',
      'code': 'RETAIL',
    },
  ];

  Future<void> _processTopUp() async {
    if (_isProcessing) return;
    final timeFormatted = TimeOfDay.now().format(context);
    final nav = Navigator.of(context);
    final rootContext = nav.context;

    setState(() => _isProcessing = true);
    try {
      if (_selectedMethod.toLowerCase().contains('qris')) {
        final created = await WalletService.instance.createQrisTopUp(
          amount: _selectedAmount,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);

        final settled = await showDialog<bool>(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Scan QRIS Isi Saldo', style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text(
                    'Order: ${created.order.orderId}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  QrisCodeCard(
                    data: created.qrisString,
                    merchantName: 'FinPay Top Up ${DummyData.userName}',
                    nmid: QrisService.instance.myNmid,
                    amount: _selectedAmount,
                    size: 170,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(dlgCtx, true),
                      icon: const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Simulasikan Sudah Bayar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dlgCtx, false),
                    child: const Text('Batal'),
                  ),
                ],
              ),
            ),
          ),
        );

        if (settled != true || !mounted) return;
        final trx = await WalletService.instance.confirmQrisTopUp(
          order: created.order,
          timeFormatted: timeFormatted,
        );
        widget.onSuccess?.call();
        if (!mounted) return;
        nav.pop();
        if (!rootContext.mounted) return;
        await showFinPayReceiptDialog(
          rootContext,
          title: 'Top Up QRIS Berhasil! 🎉',
          amountText: CurrencyFormatter.rupiah(_selectedAmount, withSign: true),
          amountColor: AppColors.success,
          referenceNumber: trx.referenceNumber,
          details: [
            {'label': 'Order Midtrans', 'value': created.order.orderId},
            {'label': 'Metode Pembayaran', 'value': _selectedMethod},
            {'label': 'Tanggal & Waktu', 'value': 'Hari Ini, $timeFormatted'},
            {
              'label': 'Saldo FinPay Cash Baru',
              'value': CurrencyFormatter.rupiah(DummyData.cashBalance),
            },
          ],
        );
        return;
      }

      final order = await WalletService.instance.topUpWithMidtrans(
        amount: _selectedAmount,
        paymentMethod: _selectedMethod,
        timeFormatted: timeFormatted,
      );
      widget.onSuccess?.call();
      if (!mounted) return;
      nav.pop();
      if (!rootContext.mounted) return;
      await showFinPayReceiptDialog(
        rootContext,
        title: 'Isi Saldo Berhasil! 🎉',
        amountText: CurrencyFormatter.rupiah(_selectedAmount, withSign: true),
        amountColor: AppColors.success,
        referenceNumber: order.orderId,
        details: [
          {'label': 'Order Midtrans', 'value': order.orderId},
          {'label': 'Metode Pembayaran', 'value': _selectedMethod},
          {'label': 'Virtual Account', 'value': order.vaNumber},
          {'label': 'Tanggal & Waktu', 'value': 'Hari Ini, $timeFormatted'},
          {
            'label': 'Saldo FinPay Cash Baru',
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
                  Text('Isi Saldo FinPay Cash', style: AppTextStyles.h2),
                  Text(
                    'Terhubung ke Midtrans Sandbox & Firebase Firestore',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: AppColors.balanceGradient,
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SALDO CASH SAAT INI',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.rupiah(DummyData.cashBalance),
                              style: AppTextStyles.h2
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                        const PillBadge(
                          label: '+ Top Up',
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Pilih Nominal Top Up', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final amt in _amounts)
                        GestureDetector(
                          onTap: () => setState(() => _selectedAmount = amt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedAmount == amt
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: AppRadius.pillAll,
                              border: Border.all(
                                color: _selectedAmount == amt
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              CurrencyFormatter.rupiah(amt),
                              style: AppTextStyles.label.copyWith(
                                color: _selectedAmount == amt
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Metode Pembayaran', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  for (final m in _methods)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedMethod == m['name']
                              ? AppColors.primary
                              : AppColors.border,
                          width: _selectedMethod == m['name'] ? 1.5 : 1.0,
                        ),
                        borderRadius: AppRadius.mdAll,
                        color: _selectedMethod == m['name']
                            ? AppColors.primarySoft
                            : AppColors.surface,
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          m['name']!,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle:
                            Text(m['desc']!, style: AppTextStyles.caption),
                        leading: Icon(
                          _selectedMethod == m['name']
                              ? Icons.check_circle_rounded
                              : Icons.account_balance_wallet_outlined,
                          color: _selectedMethod == m['name']
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        onTap: () =>
                            setState(() => _selectedMethod = m['name']!),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processTopUp,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isProcessing
                            ? 'Memproses Midtrans...'
                            : 'Top Up ${CurrencyFormatter.rupiah(_selectedAmount)} Sekarang',
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
