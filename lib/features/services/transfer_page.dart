import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/dummy/dummy_data.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/services/account_service.dart';
import '../../data/services/transaction_service.dart';
import '../../data/services/wallet_service.dart';
import '../../shared/dialogs/widgets/finpay_receipt_dialog.dart';
import '../../shared/widgets/app_card.dart';
import '../pay/widgets/qris_pin_sheet.dart';

/// Halaman Penuh 2: Kirim Uang / Transfer terintegrasi WalletService (Bagian Ali).
class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _extractNameFromTitle(String title, List<String> prefixes) {
    final trimmed = title.trim();
    for (final prefix in prefixes) {
      if (trimmed.toLowerCase().startsWith(prefix.toLowerCase())) {
        return trimmed.substring(prefix.length).trim();
      }
    }
    return '';
  }

  String _initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  /// Riwayat kontak: hanya muncul dari transaksi transfer yang sudah pernah dilakukan user.
  List<_TransferContact> _buildRecentContacts(List<TransactionModel> txList) {
    final seen = <String>{};
    final contacts = <_TransferContact>[];

    for (final tx in txList) {
      if (tx.isIncoming) continue;
      final name = _extractNameFromTitle(
        tx.title,
        const ['Transfer ke ', 'Transfer QRIS ke '],
      );
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) {
        contacts.add(
          _TransferContact(
            name: name,
            initials: _initialsOf(name),
            channel: tx.channel,
          ),
        );
      }
    }
    return contacts;
  }

  /// Kontak favorit: hanya muncul jika antar user sudah SALING transfer
  /// (pernah mengirim ke kontak tsb DAN pernah menerima transfer dari kontak tsb).
  List<_TransferContact> _buildMutualFavorites(List<TransactionModel> txList) {
    final sentTo = <String, _TransferContact>{};
    final receivedFrom = <String>{};

    for (final tx in txList) {
      if (!tx.isIncoming) {
        final name = _extractNameFromTitle(
          tx.title,
          const ['Transfer ke ', 'Transfer QRIS ke '],
        );
        if (name.isNotEmpty) {
          final key = name.toLowerCase();
          sentTo.putIfAbsent(
            key,
            () => _TransferContact(
              name: name,
              initials: _initialsOf(name),
              channel: tx.channel,
            ),
          );
        }
      } else {
        final name = _extractNameFromTitle(
          tx.title,
          const ['Transfer masuk dari ', 'Terima QRIS dari '],
        );
        if (name.isNotEmpty) {
          receivedFrom.add(name.toLowerCase());
        }
      }
    }

    return sentTo.entries
        .where((e) => receivedFrom.contains(e.key))
        .map((e) => e.value)
        .toList();
  }

  List<_TransferContact> _filterContacts(List<_TransferContact> source) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.channel.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _processTransfer() async {
    final recipient = _recipientController.text.trim();
    final amount = int.tryParse(
          _amountController.text.replaceAll(RegExp(r'\D'), ''),
        ) ??
        0;

    if (recipient.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan penerima transfer terlebih dahulu.')),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal transfer lebih dari Rp 0.')),
      );
      return;
    }
    if (amount > WalletService.instance.walletNotifier.value.cashBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo FinPay Cash kamu tidak mencukupi!')),
      );
      return;
    }

    // Wajib verifikasi PIN 6 digit sebelum memproses transfer.
    final pinVerified = await showQrisPinSheet(
      context,
      title: 'Konfirmasi PIN Transfer',
      subtitle:
          'Kirim ${CurrencyFormatter.rupiah(amount)} ke $recipient',
    );
    if (!pinVerified || !mounted) return;

    final timeFormatted = TimeOfDay.now().format(context);
    final sender = AccountService.instance.currentUser;

    try {
      final trx = await WalletService.instance.transferMoney(
        recipient: recipient,
        amount: amount,
        isBankTransfer: _tabController.index == 1,
        timeFormatted: timeFormatted,
        note: _noteController.text,
      );

      if (!mounted) return;

      await showFinPayReceiptDialog(
        context,
        title: 'Transfer Berhasil! 💸',
        amountText: CurrencyFormatter.rupiah(-amount, withSign: true),
        amountColor: AppColors.danger,
        referenceNumber: trx.referenceNumber,
        details: [
          {'label': 'No. Referensi', 'value': trx.referenceNumber},
          {'label': 'Pengirim', 'value': '${sender.fullName} (${sender.phoneNumber})'},
          {'label': 'Penerima', 'value': trx.title.replaceFirst('Transfer ke ', '')},
          {'label': 'Metode', 'value': trx.channel},
          if (_noteController.text.trim().isNotEmpty)
            {'label': 'Catatan', 'value': _noteController.text.trim()},
          {
            'label': 'Sisa Saldo Cash',
            'value': CurrencyFormatter.rupiah(DummyData.cashBalance),
          },
        ],
      );

      if (mounted) {
        _amountController.clear();
        _noteController.clear();
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
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
        title: Text('Transfer & Kirim Uang', style: AppTextStyles.h2),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.label,
          tabs: const [
            Tab(text: 'Ke Sesama FinPay'),
            Tab(text: 'Ke Rekening Bank'),
          ],
        ),
      ),
      body: ValueListenableBuilder<WalletModel>(
        valueListenable: WalletService.instance.walletNotifier,
        builder: (context, wallet, _) {
          return ValueListenableBuilder<List<TransactionModel>>(
            valueListenable: TransactionService.instance.transactionsNotifier,
            builder: (context, txList, __) {
              final favoriteContacts =
                  _filterContacts(_buildMutualFavorites(txList));
              final recentContacts =
                  _filterContacts(_buildRecentContacts(txList));

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bar Pencarian Kontak
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.pillAll,
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: AppTextStyles.body,
                        decoration: InputDecoration(
                          hintText: 'Cari kontak favorit atau riwayat...',
                          hintStyle: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textTertiary),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),

                    // Kontak Favorit (hanya muncul jika sudah saling transfer)
                    if (favoriteContacts.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Kontak Favorit (Saling Transfer)',
                              style: AppTextStyles.h3),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ContactAvatarRow(
                        contacts: favoriteContacts,
                        badgeColor: AppColors.goldLight,
                        textColor: const Color(0xFF92400E),
                        onSelect: (contact) {
                          setState(() {
                            _recipientController.text = contact.name;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Riwayat Kontak (hanya muncul setelah pernah transfer)
                    if (recentContacts.isNotEmpty) ...[
                      Text('Riwayat Kontak Transfer', style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.sm),
                      _ContactAvatarRow(
                        contacts: recentContacts,
                        badgeColor: AppColors.primaryLight,
                        textColor: AppColors.primary,
                        onSelect: (contact) {
                          setState(() {
                            _recipientController.text = contact.name;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Form Input Transfer Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detail Penerima & Nominal',
                              style: AppTextStyles.h3),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _recipientController,
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Penerima (No. HP / Email / Nama)',
                              hintText: 'Contoh: 081234567890 atau nama akun',
                              prefixIcon: const Icon(
                                Icons.person_pin_rounded,
                                color: AppColors.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.mdAll,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: AppTextStyles.h2
                                .copyWith(color: AppColors.primary),
                            decoration: InputDecoration(
                              labelText: 'Nominal Transfer (Rp)',
                              hintText: 'Contoh: 100000',
                              prefixIcon: const Icon(
                                Icons.payments_rounded,
                                color: AppColors.primary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.mdAll,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _noteController,
                            style: AppTextStyles.body,
                            decoration: InputDecoration(
                              labelText: 'Catatan Transfer (Opsional)',
                              hintText: 'Contoh: Bayar makan siang',
                              prefixIcon: const Icon(
                                Icons.note_alt_rounded,
                                color: AppColors.textSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.mdAll,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Sumber Dana Info Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Sumber Dana: FinPay Cash',
                                style: AppTextStyles.caption
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.rupiah(wallet.cashBalance),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _processTransfer,
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        label: const Text(
                          'Lanjut Transfer Sekarang',
                          style: TextStyle(
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
              );
            },
          );
        },
      ),
    );
  }
}

class _TransferContact {
  const _TransferContact({
    required this.name,
    required this.initials,
    required this.channel,
  });

  final String name;
  final String initials;
  final String channel;
}

class _ContactAvatarRow extends StatelessWidget {
  const _ContactAvatarRow({
    required this.contacts,
    required this.badgeColor,
    required this.textColor,
    required this.onSelect,
  });

  final List<_TransferContact> contacts;
  final Color badgeColor;
  final Color textColor;
  final ValueChanged<_TransferContact> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return GestureDetector(
            onTap: () => onSelect(contact),
            child: Container(
              width: 72,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: badgeColor,
                    child: Text(
                      contact.initials,
                      style: AppTextStyles.label.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contact.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
