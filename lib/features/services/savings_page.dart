import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/dummy/dummy_data.dart';
import '../../data/models/wallet_model.dart';
import '../../data/models/wealth_models.dart';
import '../../data/services/wallet_service.dart';
import '../../data/services/wealth_service.dart';
import '../../shared/dialogs/widgets/finpay_receipt_dialog.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/pill_badge.dart';
import '../../shared/widgets/rounded_progress_bar.dart';
import '../pay/widgets/qris_pin_sheet.dart';

/// Halaman Penuh 3: Target Menabung terintegrasi [WealthService] & koleksi `saving_goals` (Bagian Tugas Pidi).
class SavingsPage extends StatefulWidget {
  const SavingsPage({super.key});

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  Future<void> _setorTabungan(SavingGoalModel goal) async {
    if (WalletService.instance.walletNotifier.value.cashBalance <
        goal.monthlyDebit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo FinPay Cash kamu tidak mencukupi untuk setor tabungan.'),
        ),
      );
      return;
    }

    final pinVerified = await showQrisPinSheet(
      context,
      title: 'Masukkan PIN FinPay',
      subtitle:
          'Setor ${CurrencyFormatter.rupiah(goal.monthlyDebit)} ke "${goal.title}" (saldo cash langsung terpotong)',
    );
    if (!pinVerified || !mounted) return;

    final timeFormatted = TimeOfDay.now().format(context);
    try {
      final trx = await WealthService.instance.depositToGoal(
        goalId: goal.id,
        amount: goal.monthlyDebit,
        timeFormatted: timeFormatted,
      );
      if (!mounted) return;
      await showFinPayReceiptDialog(
        context,
        title: 'Setoran Tabungan Berhasil! 🐷',
        amountText: CurrencyFormatter.rupiah(goal.monthlyDebit),
        amountColor: AppColors.primary,
        referenceNumber: trx.referenceNumber,
        details: [
          {'label': 'No. Referensi', 'value': trx.referenceNumber},
          {'label': 'Target Impian', 'value': goal.title},
          {
            'label': 'Total Tabungan',
            'value': CurrencyFormatter.rupiah(DummyData.savingBalance),
          },
          {
            'label': 'Sisa Saldo Cash',
            'value': CurrencyFormatter.rupiah(DummyData.cashBalance),
          },
        ],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _tarikTabunganModal(SavingGoalModel goal) async {
    final amountController = TextEditingController(
      text: (goal.currentAmount >= 250000 ? 250000 : goal.currentAmount)
          .toString(),
    );

    final requestedAmount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
              const SizedBox(height: AppSpacing.md),
              Text('Tarik Dana Tabungan', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Target: ${goal.title} • Tersedia: ${CurrencyFormatter.rupiah(goal.currentAmount)}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Tarik ke Saldo Cash (Rp)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final parsed = int.tryParse(
                          amountController.text
                              .replaceAll('.', '')
                              .replaceAll('Rp', '')
                              .trim(),
                        ) ??
                        0;
                    Navigator.pop(sheetContext, parsed);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Cairkan ke FinPay Cash',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (requestedAmount == null || requestedAmount <= 0 || !mounted) return;

    final pinVerified = await showQrisPinSheet(
      context,
      title: 'Masukkan PIN FinPay',
      subtitle:
          'Konfirmasi penarikan ${CurrencyFormatter.rupiah(requestedAmount)} dari "${goal.title}" ke Saldo Cash',
    );
    if (!pinVerified || !mounted) return;

    final timeFormatted = TimeOfDay.now().format(context);
    try {
      final trx = await WealthService.instance.withdrawFromGoal(
        goalId: goal.id,
        amount: requestedAmount,
        timeFormatted: timeFormatted,
      );
      if (!mounted) return;
      await showFinPayReceiptDialog(
        context,
        title: 'Penarikan Tabungan Berhasil! 💸',
        amountText: CurrencyFormatter.rupiah(requestedAmount, withSign: true),
        amountColor: AppColors.success,
        referenceNumber: trx.referenceNumber,
        details: [
          {'label': 'No. Referensi', 'value': trx.referenceNumber},
          {'label': 'Sumber Tabungan', 'value': goal.title},
          {
            'label': 'Saldo Cash Sekarang',
            'value': CurrencyFormatter.rupiah(DummyData.cashBalance),
          },
        ],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _buatTargetBaruModal() {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '5000000');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
              const SizedBox(height: AppSpacing.md),
              Text('Buat Target Menabung Baru', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Nama Target (Mis. Beli Kamera Baru)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Nominal (Rp)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final target = int.tryParse(
                          targetController.text
                              .replaceAll('.', '')
                              .replaceAll('Rp', '')
                              .trim(),
                        ) ??
                        0;
                    try {
                      final created =
                          await WealthService.instance.createSavingGoal(
                        title: title,
                        targetAmount: target,
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Target "${created.title}" berhasil dibuat & disimpan ke Firebase! 🎉',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Simpan Target Baru',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WalletModel>(
      valueListenable: WalletService.instance.walletNotifier,
      builder: (context, wallet, _) {
        return ValueListenableBuilder<List<SavingGoalModel>>(
          valueListenable: WealthService.instance.savingGoalsNotifier,
          builder: (context, goals, __) {
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
                title: Text('Target Menabung', style: AppTextStyles.h2),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Buat Target Baru',
                    onPressed: _buatTargetBaruModal,
                  ),
                ],
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.maxContentWidth,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.page),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Ringkasan Total Tabungan Terkumpul
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            gradient: AppColors.balanceGradient,
                            borderRadius: AppRadius.xlAll,
                            boxShadow: AppShadows.glow(AppColors.primary),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOTAL TABUNGAN TERKUMPUL',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white70,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const PillBadge(
                                    label: 'Bunga 3.5%/thn',
                                    backgroundColor: Colors.white24,
                                    foregroundColor: Colors.white,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                CurrencyFormatter.rupiah(wallet.savingBalance),
                                style: AppTextStyles.displayLarge.copyWith(
                                  color: Colors.white,
                                  fontSize: 30,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Saldo Cash Tersedia: ${CurrencyFormatter.rupiah(wallet.cashBalance)} • Dijamin LPS',
                                style: AppTextStyles.caption
                                    .copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.section),

                        // Heading & Create Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daftar Impian Kamu (${goals.length})',
                              style: AppTextStyles.h3,
                            ),
                            ElevatedButton.icon(
                              onPressed: _buatTargetBaruModal,
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Target Baru',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        for (final goal in goals) ...[
                          _GoalCardFull(
                            goal: goal,
                            onSetorTap: () => _setorTabungan(goal),
                            onTarikTap: () => _tarikTabunganModal(goal),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GoalCardFull extends StatelessWidget {
  const _GoalCardFull({
    required this.goal,
    required this.onSetorTap,
    required this.onTarikTap,
  });

  final SavingGoalModel goal;
  final VoidCallback onSetorTap;
  final VoidCallback onTarikTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(goal.title, style: AppTextStyles.h3)),
              PillBadge(
                label: '${goal.percentage}%',
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Setoran rutin: ${CurrencyFormatter.rupiah(goal.monthlyDebit)}/bulan • Estimasi: ${WealthService.calculateSavingGoalEta(currentAmount: goal.currentAmount, targetAmount: goal.targetAmount, monthlyDebit: goal.monthlyDebit)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          RoundedProgressBar(
            value: goal.progress,
            color: goal.color,
            height: 8,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.rupiah(goal.currentAmount),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Target: ${CurrencyFormatter.rupiah(goal.targetAmount)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: goal.currentAmount > 0 ? onTarikTap : null,
                icon: const Icon(Icons.arrow_downward_rounded, size: 14),
                label: const Text(
                  'Tarik Dana',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onSetorTap,
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: Text(
                  'Setor ${CurrencyFormatter.rupiah(goal.monthlyDebit)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
