import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/dummy/dummy_data.dart';
import '../../data/models/linked_account_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/services/account_service.dart';
import '../../data/services/transaction_service.dart';
import '../../data/services/wallet_service.dart';
import '../../shared/dialogs/widgets/finpay_receipt_dialog.dart';
import '../../shared/widgets/app_card.dart';
import '../pay/widgets/qris_pin_sheet.dart';

/// Model tujuan transfer (baik sesama FinPay maupun rekening bank).
class _TransferTarget {
  const _TransferTarget({
    required this.name,
    required this.identifier,
    required this.isBank,
    required this.channelLabel,
    this.bankName,
  });

  final String name;
  final String identifier; // No. HP atau No. Rekening
  final bool isBank;
  final String channelLabel;
  final String? bankName;

  String get key => '${isBank ? 'bank' : 'finpay'}:${name.toLowerCase()}';

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

/// Formatter angka ribuan dengan pemisah titik setiap 3 digit (mis. 1.000.000).
class _ThousandsDotFormatter extends TextInputFormatter {
  const _ThousandsDotFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Halaman Utama Transfer:
/// - Judul "Transfer"
/// - 2 kotak tombol ikon: "Ke Sesama FinPay" & "Ke Rekening Bank"
/// - 2 bilah tab di bawahnya: "Recent" & "Favorites" (berdasarkan bintang menyala)
class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage>
    with SingleTickerProviderStateMixin {
  /// Menyimpan key kontak yang bintang favoritnya dinyalakan di sesi aktif.
  static final Set<String> _starredKeys = <String>{};

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _extractNameFromTitle(String title) {
    final trimmed = title.trim();
    for (final prefix in const ['Transfer ke ', 'Transfer QRIS ke ']) {
      if (trimmed.toLowerCase().startsWith(prefix.toLowerCase())) {
        return trimmed.substring(prefix.length).trim();
      }
    }
    return '';
  }

  String _extractIdentifierFromNote(String? note) {
    if (note == null || note.isEmpty) return '';
    final match = RegExp(r'\(([^)]+)\)').firstMatch(note);
    return match?.group(1)?.trim() ?? '';
  }

  List<_TransferTarget> _buildRecentContacts(List<TransactionModel> txList) {
    final seen = <String>{};
    final result = <_TransferTarget>[];

    for (final tx in txList) {
      if (tx.isIncoming) continue;
      final name = _extractNameFromTitle(tx.title);
      if (name.isEmpty) continue;

      final isBank = tx.channel.toLowerCase().contains('bank');
      final identifier = _extractIdentifierFromNote(tx.note);
      final target = _TransferTarget(
        name: name,
        identifier: identifier.isNotEmpty ? identifier : tx.channel,
        isBank: isBank,
        channelLabel: isBank ? 'Rekening Bank' : 'Sesama FinPay',
      );

      if (seen.add(target.key)) {
        result.add(target);
      }
    }
    return result;
  }

  Future<void> _openSearchPage({required bool isBank}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _TransferSearchPage(isBank: isBank),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openAmountPage(_TransferTarget target) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _TransferAmountPage(target: target),
      ),
    );
    if (mounted) setState(() {});
  }

  void _toggleStar(_TransferTarget target) {
    setState(() {
      if (_starredKeys.contains(target.key)) {
        _starredKeys.remove(target.key);
      } else {
        _starredKeys.add(target.key);
      }
    });
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
        title: Text('Transfer', style: AppTextStyles.h2),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<TransactionModel>>(
        valueListenable: TransactionService.instance.transactionsNotifier,
        builder: (context, txList, _) {
          final recentContacts = _buildRecentContacts(txList);
          final favoriteContacts = recentContacts
              .where((c) => _starredKeys.contains(c.key))
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TransferOptionTile(
                        icon: Icons.send_to_mobile_rounded,
                        title: 'Ke Sesama FinPay',
                        subtitle: 'Cari via No. HP',
                        accentColor: AppColors.primary,
                        backgroundColor: AppColors.primaryLight,
                        onTap: () => _openSearchPage(isBank: false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TransferOptionTile(
                        icon: Icons.account_balance_rounded,
                        title: 'Ke Rekening Bank',
                        subtitle: 'Pilih bank & rekening',
                        accentColor: const Color(0xFF0F766E),
                        backgroundColor: AppColors.mintLight,
                        onTap: () => _openSearchPage(isBank: true),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTextStyles.label,
                  tabs: [
                    Tab(text: 'Recent (${recentContacts.length})'),
                    Tab(text: 'Favorites (${favoriteContacts.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ContactListView(
                      contacts: recentContacts,
                      emptyTitle: 'Belum ada riwayat transfer',
                      emptySubtitle:
                          'Kontak tujuan akan otomatis muncul di sini setelah kamu melakukan transfer.',
                      isStarred: (c) => _starredKeys.contains(c.key),
                      onToggleStar: _toggleStar,
                      onTapContact: _openAmountPage,
                    ),
                    _ContactListView(
                      contacts: favoriteContacts,
                      emptyTitle: 'Belum ada kontak favorit',
                      emptySubtitle:
                          'Ketuk ikon bintang pada kontak di tab Recent untuk menambahkannya ke Favorites.',
                      isStarred: (c) => _starredKeys.contains(c.key),
                      onToggleStar: _toggleStar,
                      onTapContact: _openAmountPage,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransferOptionTile extends StatelessWidget {
  const _TransferOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.xlAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xlAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.xlAll,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactListView extends StatelessWidget {
  const _ContactListView({
    required this.contacts,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.isStarred,
    required this.onToggleStar,
    required this.onTapContact,
  });

  final List<_TransferTarget> contacts;
  final String emptyTitle;
  final String emptySubtitle;
  final bool Function(_TransferTarget) isStarred;
  final ValueChanged<_TransferTarget> onToggleStar;
  final ValueChanged<_TransferTarget> onTapContact;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                emptyTitle,
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                emptySubtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.page),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final starred = isStarred(contact);
        return AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: InkWell(
            onTap: () => onTapContact(contact),
            borderRadius: AppRadius.lgAll,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: contact.isBank
                      ? AppColors.mintLight
                      : AppColors.primaryLight,
                  child: Text(
                    contact.initials,
                    style: AppTextStyles.label.copyWith(
                      color: contact.isBank
                          ? const Color(0xFF0F766E)
                          : AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${contact.channelLabel} • ${contact.identifier}',
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: starred ? 'Hapus dari Favorites' : 'Tambah ke Favorites',
                  onPressed: () => onToggleStar(contact),
                  icon: Icon(
                    starred ? Icons.star_rounded : Icons.star_border_rounded,
                    color: starred ? AppColors.gold : AppColors.textTertiary,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Langkah 2: Pencarian Kontak FinPay (No. HP) atau Rekening Bank (Pilih Bank + No. Rekening).
class _TransferSearchPage extends StatefulWidget {
  const _TransferSearchPage({required this.isBank});

  final bool isBank;

  @override
  State<_TransferSearchPage> createState() => _TransferSearchPageState();
}

class _TransferSearchPageState extends State<_TransferSearchPage> {
  static const List<String> _bankOptions = [
    'BCA',
    'Mandiri',
    'BNI',
    'BRI',
    'BSI',
    'CIMB Niaga',
    'Bank Permata',
    'SeaBank',
  ];

  final TextEditingController _inputController = TextEditingController();
  String? _selectedBank;
  bool _searching = false;
  String? _notFoundNotice;
  _TransferTarget? _foundTarget;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _searchTarget() async {
    FocusScope.of(context).unfocus();
    final digits = _inputController.text.replaceAll(RegExp(r'\D'), '');

    if (widget.isBank) {
      if (_selectedBank == null) {
        setState(() {
          _foundTarget = null;
          _notFoundNotice = 'Pilih bank tujuan terlebih dahulu.';
        });
        return;
      }
      if (digits.length < 10 || digits.length > 16) {
        setState(() {
          _foundTarget = null;
          _notFoundNotice =
              'Nomor rekening tidak ditemukan / salah (wajib 10–16 digit angka).';
        });
        return;
      }

      setState(() {
        _searching = true;
        _notFoundNotice = null;
        _foundTarget = null;
      });

      // Cek apakah nomor rekening cocok dengan rekening terdaftar milik user.
      final matchedLinked = AccountService.instance.linkedAccounts
          .where((acc) => acc.accountNumber.replaceAll(RegExp(r'\D'), '') == digits)
          .firstOrNull;

      final holderName = matchedLinked?.holderName ??
          'Nasabah $_selectedBank (${digits.substring(digits.length - 4)})';

      if (!mounted) return;
      setState(() {
        _searching = false;
        _foundTarget = _TransferTarget(
          name: '$holderName ($_selectedBank)',
          identifier: digits,
          isBank: true,
          channelLabel: 'Bank $_selectedBank',
          bankName: _selectedBank,
        );
      });
      return;
    }

    // Pencarian Sesama FinPay menggunakan No. HP
    if (digits.length < 9 || digits.length > 14) {
      setState(() {
        _foundTarget = null;
        _notFoundNotice = 'No. HP tidak ditemukan / salah.';
      });
      return;
    }

    setState(() {
      _searching = true;
      _notFoundNotice = null;
      _foundTarget = null;
    });

    final currentUserId = AccountService.instance.currentUser.userId;
    final foundUser =
        await AccountService.instance.findUserByPhoneFromFirestore(digits);

    if (!mounted) return;

    if (foundUser == null || foundUser.userId == currentUserId) {
      setState(() {
        _searching = false;
        _foundTarget = null;
        _notFoundNotice = foundUser?.userId == currentUserId
            ? 'Tidak dapat transfer ke nomor HP milik sendiri.'
            : 'No. HP tidak ditemukan / salah. Pastikan nomor sudah terdaftar di FinPay.';
      });
      return;
    }

    setState(() {
      _searching = false;
      _foundTarget = _TransferTarget(
        name: foundUser.fullName,
        identifier: foundUser.phoneNumber,
        isBank: false,
        channelLabel: 'FinPay • ${foundUser.email}',
      );
    });
  }

  void _proceedToAmount() {
    final target = _foundTarget;
    if (target == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _TransferAmountPage(target: target),
      ),
    );
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
        title: Text(
          widget.isBank ? 'Ke Rekening Bank' : 'Ke Sesama FinPay',
          style: AppTextStyles.h2,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isBank) ...[
                    Text('Pilih Bank Tujuan', style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _selectedBank,
                      hint: const Text('Pilih nama bank'),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.account_balance_rounded,
                          color: AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.mdAll,
                        ),
                      ),
                      items: _bankOptions
                          .map(
                            (b) => DropdownMenuItem<String>(
                              value: b,
                              child: Text(b),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedBank = v;
                          _notFoundNotice = null;
                          _foundTarget = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    widget.isBank
                        ? 'Nomor Rekening Tujuan'
                        : 'Cari Kontak dengan Nomor HP',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _inputController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchTarget(),
                    onChanged: (_) {
                      if (_notFoundNotice != null || _foundTarget != null) {
                        setState(() {
                          _notFoundNotice = null;
                          _foundTarget = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText:
                          widget.isBank ? 'Nomor Rekening' : 'Nomor HP FinPay',
                      hintText: widget.isBank
                          ? 'Contoh: 8801204821'
                          : 'Contoh: 081234567890',
                      prefixIcon: Icon(
                        widget.isBank
                            ? Icons.credit_card_rounded
                            : Icons.phone_android_rounded,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _searching ? null : _searchTarget,
                      icon: _searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded, color: Colors.white),
                      label: Text(
                        _searching
                            ? 'Mencari...'
                            : (widget.isBank
                                ? 'Cek Rekening Tujuan'
                                : 'Cari Kontak FinPay'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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

            // Notice jika nomor HP / rekening tidak ditemukan atau salah
            if (_notFoundNotice != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _notFoundNotice!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Kartu Data Kontak / Rekening Ditemukan
            if (_foundTarget != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Kontak Tujuan Ditemukan', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            _foundTarget!.initials,
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundTarget!.name,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _foundTarget!.identifier,
                                style: AppTextStyles.bodySmall,
                              ),
                              Text(
                                _foundTarget!.channelLabel,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _proceedToAmount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Lanjut Masukan Nominal',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Langkah 3: Input Nominal (Rp + separator "." + tombol nominal instan),
/// Payment Method (Saldo FinPay / Rekening terdaftar), Input Message (opsional),
/// Footer (Total + tombol Next biru) -> Input PIN -> Nota Rapi.
class _TransferAmountPage extends StatefulWidget {
  const _TransferAmountPage({required this.target});

  final _TransferTarget target;

  @override
  State<_TransferAmountPage> createState() => _TransferAmountPageState();
}

class _TransferAmountPageState extends State<_TransferAmountPage> {
  static const List<int> _instantAmounts = [
    10000,
    25000,
    50000,
    100000,
    250000,
    500000,
    1000000,
  ];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  /// `'finpay_cash'` atau id dari [LinkedAccountModel].
  String _selectedPaymentMethodId = 'finpay_cash';
  bool _submitting = false;

  int get _parsedAmount =>
      int.tryParse(_amountController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _selectInstantAmount(int amount) {
    final formatted = const _ThousandsDotFormatter()
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: amount.toString()),
        )
        .text;
    setState(() {
      _amountController.text = formatted;
      _amountController.selection =
          TextSelection.collapsed(offset: formatted.length);
    });
  }

  String _formatDotNumber(int value) {
    return const _ThousandsDotFormatter()
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: value.toString()),
        )
        .text;
  }

  Future<void> _onNextPressed(List<LinkedAccountModel> linkedAccounts) async {
    if (_submitting) return;
    final amount = _parsedAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal transfer terlebih dahulu.')),
      );
      return;
    }

    final useLinkedAccount = _selectedPaymentMethodId != 'finpay_cash';
    final selectedAcc = useLinkedAccount
        ? linkedAccounts
            .where((a) => a.id == _selectedPaymentMethodId)
            .firstOrNull
        : null;

    if (!useLinkedAccount &&
        amount > WalletService.instance.walletNotifier.value.cashBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo FinPay Cash kamu tidak mencukupi!')),
      );
      return;
    }

    // Langkah 8: Input PIN terlebih dahulu
    final pinVerified = await showQrisPinSheet(
      context,
      title: 'Masukkan PIN FinPay',
      subtitle:
          'Konfirmasi transfer ${CurrencyFormatter.rupiah(amount)} ke ${widget.target.name}',
    );
    if (!pinVerified || !mounted) return;

    setState(() => _submitting = true);
    final timeFormatted = TimeOfDay.now().format(context);
    final sender = AccountService.instance.currentUser;
    final paymentMethodLabel = useLinkedAccount && selectedAcc != null
        ? '${selectedAcc.bankName} (${selectedAcc.accountNumber})'
        : 'Saldo FinPay Cash';

    try {
      final recipientParam = widget.target.isBank
          ? '${widget.target.name} - ${widget.target.identifier}'
          : widget.target.identifier;

      final trx = await WalletService.instance.transferMoney(
        recipient: recipientParam,
        amount: amount,
        isBankTransfer: widget.target.isBank,
        timeFormatted: timeFormatted,
        note: _messageController.text,
        paymentMethod: paymentMethodLabel,
        useLinkedAccount: useLinkedAccount,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      // Langkah 9: Nota rapi hasil transaksi (dengan tombol Simpan Foto PNG)
      await showFinPayReceiptDialog(
        context,
        title: 'Transfer Berhasil!',
        amountText: CurrencyFormatter.rupiah(amount),
        amountColor: AppColors.primary,
        referenceNumber: trx.referenceNumber,
        details: [
          {'label': 'No. Referensi', 'value': trx.referenceNumber},
          {'label': 'Waktu', 'value': trx.dateTime},
          {'label': 'Pengirim', 'value': '${sender.fullName} (${sender.phoneNumber})'},
          {'label': 'Penerima', 'value': widget.target.name},
          {
            'label': widget.target.isBank ? 'No. Rekening' : 'No. HP Penerima',
            'value': widget.target.identifier,
          },
          {'label': 'Metode Pembayaran', 'value': paymentMethodLabel},
          if (_messageController.text.trim().isNotEmpty)
            {'label': 'Pesan', 'value': _messageController.text.trim()},
          {
            'label': 'Sisa Saldo FinPay',
            'value': CurrencyFormatter.rupiah(DummyData.cashBalance),
          },
        ],
      );

      if (!mounted) return;
      // Kembali ke halaman utama Transfer (Recent langsung ter-update)
      Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/transfer');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WalletModel>(
      valueListenable: WalletService.instance.walletNotifier,
      builder: (context, wallet, _) {
        return ValueListenableBuilder<List<LinkedAccountModel>>(
          valueListenable: AccountService.instance.linkedAccountsNotifier,
          builder: (context, linkedAccounts, __) {
            final amount = _parsedAmount;

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
                title: Text('Masukan Nominal', style: AppTextStyles.h2),
                centerTitle: true,
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.page),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ringkasan Kontak Tujuan
                          AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primaryLight,
                                  child: Text(
                                    widget.target.initials,
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.target.name,
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${widget.target.channelLabel} • ${widget.target.identifier}',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Input Nominal (Rp + pemisah titik ribuan)
                          AppCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nominal Transfer', style: AppTextStyles.h3),
                                const SizedBox(height: AppSpacing.sm),
                                TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: const [
                                    _ThousandsDotFormatter(),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  style: AppTextStyles.displayMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: 'Rp ',
                                    prefixStyle:
                                        AppTextStyles.displayMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    hintText: '0',
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.mdAll,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: _instantAmounts.map((nominal) {
                                    final selected = amount == nominal;
                                    return ChoiceChip(
                                      label: Text(_formatDotNumber(nominal)),
                                      selected: selected,
                                      selectedColor: AppColors.primary,
                                      backgroundColor: AppColors.primarySoft,
                                      labelStyle: AppTextStyles.caption.copyWith(
                                        color: selected
                                            ? Colors.white
                                            : AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      onSelected: (_) =>
                                          _selectInstantAmount(nominal),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Payment Method (Saldo FinPay atau Rekening Terdaftar)
                          AppCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Payment Method', style: AppTextStyles.h3),
                                const SizedBox(height: AppSpacing.sm),
                                _PaymentMethodOption(
                                  icon: Icons.account_balance_wallet_rounded,
                                  title: 'Saldo FinPay Cash',
                                  subtitle:
                                      'Tersedia: ${CurrencyFormatter.rupiah(wallet.cashBalance)}',
                                  selected:
                                      _selectedPaymentMethodId == 'finpay_cash',
                                  onTap: () => setState(
                                    () =>
                                        _selectedPaymentMethodId = 'finpay_cash',
                                  ),
                                ),
                                for (final acc in linkedAccounts) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  _PaymentMethodOption(
                                    icon: Icons.credit_card_rounded,
                                    title: 'Rekening ${acc.bankName}',
                                    subtitle:
                                        '${acc.accountNumber} • ${acc.holderName}',
                                    selected:
                                        _selectedPaymentMethodId == acc.id,
                                    onTap: () => setState(
                                      () => _selectedPaymentMethodId = acc.id,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Input Message (Optional)
                          AppCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Input Message (Optional)',
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextField(
                                  controller: _messageController,
                                  maxLines: 2,
                                  style: AppTextStyles.body,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Tambahkan keterangan transaksi...',
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.mdAll,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer: Total Nominal + Tombol Next Biru
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.md,
                      AppSpacing.page,
                      AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: const Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Total Pembayaran',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.rupiah(amount),
                                  style: AppTextStyles.h2.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          ElevatedButton(
                            onPressed: _submitting || amount <= 0
                                ? null
                                : () => _onNextPressed(linkedAccounts),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Next',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
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
          },
        );
      },
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  const _PaymentMethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.background,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
