import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/dummy/dummy_data.dart';
import '../../data/services/midtrans_service.dart';
import '../../data/services/qris_service.dart';
import '../../data/services/wallet_service.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/pill_badge.dart';
import '../../shared/widgets/qris_code_card.dart';

/// Halaman Penuh 1: Isi Saldo FinPay terintegrasi Midtrans Sandbox & WalletService (Bagian Ali).
class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  int _selectedAmount = 100000;
  bool _isProcessing = false;
  final TextEditingController _customAmountController =
      TextEditingController(text: '100000');
  String _expandedMethod = 'QRIS (Semua Bank & E-Wallet)';

  final List<int> _presetAmounts = [50000, 100000, 200000, 500000, 1000000];

  final List<Map<String, String>> _vaMethods = const [
    {
      'name': 'QRIS (Semua Bank & E-Wallet)',
      'code': 'QRIS-MIDTRANS-DYNAMIC',
      'bank': 'QRIS',
      'fee': 'Bebas Biaya • Instan 24 Jam via Midtrans QRIS',
      'steps':
          '1. Klik tombol Konfirmasi Top Up di bawah untuk membuat barcode QRIS\n2. Scan barcode QRIS dari m-BCA, Livin, BRImo, GoPay, OVO, atau DANA\n3. Konfirmasi pembayaran dan saldo FinPay otomatis masuk.'
    },
    {
      'name': 'BCA Virtual Account',
      'code': '88012 0812 3456 7890',
      'bank': 'BCA',
      'fee': 'Bebas Biaya • Midtrans Sandbox',
      'steps':
          '1. Buka m-BCA > m-Transfer > BCA Virtual Account\n2. Masukkan nomor VA 88012 0812 3456 7890\n3. Masukkan nominal top up\n4. Masukkan PIN m-BCA & konfirmasi.'
    },
    {
      'name': 'Mandiri Virtual Account',
      'code': '88013 0812 3456 7890',
      'bank': 'Mandiri',
      'fee': 'Bebas Biaya • Midtrans Sandbox',
      'steps':
          '1. Buka Livin by Mandiri > Bayar > Multipayment\n2. Pilih FinPay Top Up (88013)\n3. Masukkan nomor VA & nominal\n4. Konfirmasi transaksi.'
    },
    {
      'name': 'BRI Virtual Account (BRIVA)',
      'code': '88014 0812 3456 7890',
      'bank': 'BRI',
      'fee': 'Bebas Biaya • Midtrans Sandbox',
      'steps':
          '1. Buka BRImo > Pembayaran > BRIVA\n2. Masukkan nomor BRIVA FinPay\n3. Masukkan nominal & konfirmasi dengan PIN.'
    },
    {
      'name': 'Indomaret / Alfamart',
      'code': 'FINPAY-081234567890',
      'bank': 'Retail',
      'fee': 'Biaya Admin Rp 1.500 • Midtrans Sandbox',
      'steps':
          '1. Tunjukkan nomor HP FinPay ke kasir Indomaret/Alfamart\n2. Sebutkan nominal top up\n3. Kasir akan memproses dan berikan bukti struk.'
    },
  ];

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _confirmTopUp() async {
    if (_isProcessing) return;

    final amount = int.tryParse(
          _customAmountController.text
              .replaceAll('.', '')
              .replaceAll('Rp', '')
              .trim(),
        ) ??
        _selectedAmount;

    final timeFormatted = TimeOfDay.now().format(context);

    setState(() => _isProcessing = true);

    try {
      if (_expandedMethod.toLowerCase().contains('qris')) {
        final created = await WalletService.instance.createQrisTopUp(
          amount: amount,
        );
        if (!mounted) return;
        setState(() => _isProcessing = false);
        await _showQrisTopUpSheet(
          order: created.order,
          qrisString: created.qrisString,
          timeFormatted: timeFormatted,
        );
        return;
      }

      final order = await WalletService.instance.topUpWithMidtrans(
        amount: amount,
        paymentMethod: _expandedMethod,
        timeFormatted: timeFormatted,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 52,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Top Up Midtrans Berhasil! 🎉',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                CurrencyFormatter.rupiah(amount, withSign: true),
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.success,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Column(
                  children: [
                    Text(
                      'Order ID: ${order.orderId}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status Midtrans: ${order.status.toUpperCase()}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Saldo FinPay Cash kamu bertambah menjadi ${CurrencyFormatter.rupiah(DummyData.cashBalance)} via $_expandedMethod.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses Top Up: $e')),
      );
    }
  }

  Future<void> _showQrisTopUpSheet({
    required MidtransOrderResult order,
    required String qrisString,
    required String timeFormatted,
  }) async {
    final settled = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Scan QRIS untuk Isi Saldo', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  'Order Midtrans: ${order.orderId}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                QrisCodeCard(
                  data: qrisString,
                  merchantName: 'FinPay Top Up ${DummyData.userName}',
                  nmid: QrisService.instance.myNmid,
                  amount: order.amount,
                  size: 190,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    icon: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Simulasikan Sudah Bayar (${CurrencyFormatter.rupiah(order.amount)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (settled != true || !mounted) return;
    try {
      await WalletService.instance.confirmQrisTopUp(
        order: order,
        timeFormatted: timeFormatted,
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Top Up QRIS ${CurrencyFormatter.rupiah(order.amount)} berhasil masuk ke saldo FinPay Cash!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Isi Saldo FinPay', style: AppTextStyles.h2),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Membuka riwayat isi saldo...')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Saldo Aktif Hero Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: AppColors.balanceGradient,
                borderRadius: AppRadius.xlAll,
                boxShadow: AppShadows.glow(AppColors.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SALDO CASH AKTIF',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        CurrencyFormatter.rupiah(DummyData.cashBalance),
                        style: AppTextStyles.displayLarge.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                  const PillBadge(
                    label: '● Midtrans Ready',
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),

            // Pilihan Nominal Top Up & Custom Field Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nominal Isi Saldo', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _customAmountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.payments_rounded,
                        color: AppColors.primary,
                      ),
                      labelText: 'Masukkan Nominal (Rp)',
                      border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                      filled: true,
                      fillColor: AppColors.primarySoft,
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null) setState(() => _selectedAmount = n);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final amt in _presetAmounts)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAmount = amt;
                              _customAmountController.text = amt.toString();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
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
                              boxShadow: _selectedAmount == amt
                                  ? AppShadows.glow(AppColors.primary)
                                  : null,
                            ),
                            child: Text(
                              CurrencyFormatter.rupiah(amt),
                              style: AppTextStyles.label.copyWith(
                                color: _selectedAmount == amt
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),

            // Accordion Pilihan Metode Top Up
            Text(
              'Metode Pembayaran (Midtrans Sandbox VA & Retail)',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.sm),

            for (final m in _vaMethods) ...[
              AppCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: Key(m['name']!),
                  initiallyExpanded: _expandedMethod == m['name'],
                  onExpansionChanged: (expanded) {
                    if (expanded) setState(() => _expandedMethod = m['name']!);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    m['name']!,
                    style:
                        AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    m['fee']!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: AppColors.border),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: AppRadius.mdAll,
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NOMOR VIRTUAL ACCOUNT',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      m['code']!,
                                      style: AppTextStyles.h3.copyWith(
                                        color: AppColors.primary,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Nomor VA ${m['code']} berhasil disalin!',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Salin',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Tata Cara Transfer:',
                            style: AppTextStyles.label
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            m['steps']!,
                            style:
                                AppTextStyles.bodySmall.copyWith(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _confirmTopUp,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  _isProcessing
                      ? 'Memproses ke Midtrans Sandbox...'
                      : 'Konfirmasi Top Up ${CurrencyFormatter.rupiah(_selectedAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
