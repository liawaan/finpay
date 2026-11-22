import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/dummy/dummy_data.dart';
import '../../data/models/support_chat_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/services/account_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/midtrans_service.dart';
import '../../data/services/support_chat_service.dart';
import '../../data/services/transaction_service.dart';
import '../../data/services/wallet_service.dart';
import '../../shared/widgets/pill_badge.dart';

/// Halaman FinPay Admin Web Portal.
/// Dashboard modern responsif berbasis Web/Desktop untuk:
/// 1. Komunikasi Live Chat dengan Pengguna (Customer Support 2-Arah)
/// 2. Mengetahui Jumlah & Manajemen Pengguna
/// 3. Memantau & Memfilter Seluruh Transaksi Pengguna
/// 4. Audit Payment Gateway Midtrans Sandbox
/// 5. Pusat Verifikasi Identitas (KYC) Pengguna
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, this.onSwitchToMobile});

  final VoidCallback? onSwitchToMobile;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedTabIndex = 0; // 0: Overview, 1: Transaksi, 2: Users, 3: Live CS, 4: Midtrans, 5: KYC
  final TextEditingController _adminReplyController = TextEditingController();
  final TextEditingController _searchTrxController = TextEditingController();
  String _trxFilter = 'Semua';
  String _selectedUserChatId = 'finpay_user_01';
  bool _isSyncingFirestore = false;

  @override
  void initState() {
    super.initState();
    _pullFirestoreDataSilently();
  }

  Future<void> _pullFirestoreDataSilently() async {
    await Future.wait<void>([
      TransactionService.instance.fetchTransactionsFromFirebase(),
      MidtransService.instance.fetchOrdersFromFirebase(),
      SupportChatService.instance.fetchMessagesFromFirebase(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _syncAllFromFirestore() async {
    if (_isSyncingFirestore) return;
    setState(() => _isSyncingFirestore = true);
    await _pullFirestoreDataSilently();
    if (!mounted) return;
    setState(() => _isSyncingFirestore = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Data Transaksi, Order Midtrans, & Live CS berhasil disinkronkan dari Firestore.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Dummy list user untuk manajemen pengguna admin
  final List<Map<String, dynamic>> _userList = [
    {
      'id': 'finpay_user_01',
      'name': DummyData.userName,
      'email': 'reza.pratama@email.com',
      'phone': DummyData.phoneNumber,
      'nik': '3174123456780001',
      'tier': DummyData.membership,
      'kycStatus': 'Terverifikasi',
      'isBlocked': false,
    },
    {
      'id': 'finpay_user_02',
      'name': 'Budi Santoso',
      'email': 'budi.santoso@email.com',
      'phone': '0812-9988-7766',
      'nik': '3171029102910002',
      'tier': 'FinPay Reguler',
      'kycStatus': 'Menunggu Review',
      'isBlocked': false,
    },
    {
      'id': 'finpay_user_03',
      'name': 'Siska Pertiwi',
      'email': 'siska.pertiwi@email.com',
      'phone': '0813-1122-3344',
      'nik': '3173098811220003',
      'tier': 'FinPay Premier',
      'kycStatus': 'Terverifikasi',
      'isBlocked': false,
    },
    {
      'id': 'finpay_user_04',
      'name': 'Eko Kurniawan',
      'email': 'eko.kurniawan@email.com',
      'phone': '0857-4455-6677',
      'nik': '3275012233440004',
      'tier': 'FinPay Reguler',
      'kycStatus': 'Belum Upload',
      'isBlocked': false,
    },
  ];

  /// Menggabungkan direktori pengguna admin dengan akun pengguna yang sedang login aktif di aplikasi.
  List<Map<String, dynamic>> get _mergedUserList {
    final active = AccountService.instance.currentUser;
    final idx = _userList.indexWhere((u) => u['id'] == active.userId);
    final activeEntry = <String, dynamic>{
      'id': active.userId,
      'name': active.fullName,
      'email': active.email,
      'phone': active.phoneNumber,
      'nik': active.nik,
      'tier': active.membership,
      'kycStatus': active.kycStatus,
      'isBlocked': idx >= 0 ? (_userList[idx]['isBlocked'] ?? false) : false,
    };
    if (idx >= 0) {
      _userList[idx] = activeEntry;
    } else if (active.userId.trim().isNotEmpty) {
      _userList.insert(0, activeEntry);
    }
    return _userList;
  }

  int get _pendingKycCount => _mergedUserList
      .where((u) => u['kycStatus'] != 'Terverifikasi')
      .length;

  @override
  void dispose() {
    _adminReplyController.dispose();
    _searchTrxController.dispose();
    super.dispose();
  }

  void _sendAdminReply() {
    final text = _adminReplyController.text.trim();
    if (text.isEmpty) return;

    final targetUser = _userList.firstWhere(
      (u) => u['id'] == _selectedUserChatId,
      orElse: () => _userList.first,
    );

    SupportChatService.instance.sendMessage(
      userId: _selectedUserChatId,
      userName: targetUser['name'] as String,
      text: text,
      isFromAdmin: true,
    );

    _adminReplyController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: Row(
        children: [
          // Sidebar Admin Navigasi Kiri (Lebar Tetap 260px)
          _buildSidebar(),

          // Area Konten Utama
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: _buildCurrentTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SIDEBAR ADMIN ====================
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.balanceGradient,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FinPay Admin',
                      style: AppTextStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Web Management Portal',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Menu Navigasi
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Ringkasan & Metrik',
                  isSelected: _selectedTabIndex == 0,
                  onTap: () => setState(() => _selectedTabIndex = 0),
                ),
                _SidebarItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Monitoring Transaksi',
                  isSelected: _selectedTabIndex == 1,
                  onTap: () => setState(() => _selectedTabIndex = 1),
                ),
                _SidebarItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Manajemen Pengguna',
                  isSelected: _selectedTabIndex == 2,
                  badge: '${_userList.length}',
                  onTap: () => setState(() => _selectedTabIndex = 2),
                ),
                _SidebarItem(
                  icon: Icons.support_agent_rounded,
                  label: 'Live CS & Chat User',
                  isSelected: _selectedTabIndex == 3,
                  badge: 'Online',
                  badgeColor: AppColors.success,
                  onTap: () => setState(() => _selectedTabIndex = 3),
                ),
                _SidebarItem(
                  icon: Icons.account_balance_rounded,
                  label: 'Midtrans Sandbox Gateway',
                  isSelected: _selectedTabIndex == 4,
                  onTap: () => setState(() => _selectedTabIndex = 4),
                ),
                _SidebarItem(
                  icon: Icons.verified_user_rounded,
                  label: 'Verifikasi KYC KTP',
                  isSelected: _selectedTabIndex == 5,
                  badge: '1 Review',
                  badgeColor: AppColors.gold,
                  onTap: () => setState(() => _selectedTabIndex = 5),
                ),
              ],
            ),
          ),

          // Footer Profil Admin Ali
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    'AA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ali Akbar',
                        style: AppTextStyles.label.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Super Admin',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.mint,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TOPBAR ====================
  Widget _buildTopBar() {
    final titles = [
      'Ringkasan & Metrik Eksekutif',
      'Monitoring Seluruh Transaksi Pengguna',
      'Manajemen & Direktori Pengguna',
      'Pusat Komunikasi & Live CS Pengguna',
      'Audit Midtrans Sandbox Payment Gateway',
      'Pusat Verifikasi Identitas (KYC)',
    ];

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                titles[_selectedTabIndex],
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Terhubung langsung ke database Firebase Firestore: finpay-app-4026a',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isSyncingFirestore ? null : _syncAllFromFirestore,
                icon: Icon(
                  Icons.sync_rounded,
                  size: 16,
                  color: _isSyncingFirestore
                      ? AppColors.textTertiary
                      : AppColors.primary,
                ),
                label: Text(
                  _isSyncingFirestore ? 'Menyinkronkan...' : 'Sync Firestore',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Status Firebase Online Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: AppRadius.pillAll,
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Firebase Online',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Tombol Switch Preview Mobile App
              if (widget.onSwitchToMobile != null)
                OutlinedButton.icon(
                  onPressed: widget.onSwitchToMobile,
                  icon: const Icon(Icons.phone_android_rounded, size: 16),
                  label: const Text('Buka Preview Mobile App'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== KONTEN TAB AKTIF ====================
  Widget _buildCurrentTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildTransactionsTab();
      case 2:
        return _buildUsersTab();
      case 3:
        return _buildSupportChatTab();
      case 4:
        return _buildMidtransTab();
      case 5:
        return _buildKycTab();
      default:
        return _buildOverviewTab();
    }
  }

  // 1. OVERVIEW TAB
  Widget _buildOverviewTab() {
    return ValueListenableBuilder<WalletModel>(
      valueListenable: WalletService.instance.walletNotifier,
      builder: (context, wallet, _) {
        return ValueListenableBuilder<List<TransactionModel>>(
          valueListenable: TransactionService.instance.transactionsNotifier,
          builder: (context, transactions, __) {
            return ValueListenableBuilder<List<MidtransOrderResult>>(
              valueListenable: MidtransService.instance.ordersNotifier,
              builder: (context, orders, ___) {
                final users = _mergedUserList;
                final totalTrx = transactions.length;
                final totalVolume = transactions.fold<int>(
                  0,
                  (sum, t) => sum + t.amount.abs(),
                );
                final settledOrders =
                    orders.where((o) => o.isSettled).length;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 4 Kartu KPI Utama
                      Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'TOTAL PENGGUNA',
                              value: '${users.length} Pengguna',
                              subtitle:
                                  '$_pendingKycCount akun menunggu review KYC',
                              icon: Icons.people_outline_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'VOLUME TRANSAKSI (GMV)',
                              value: CurrencyFormatter.rupiah(totalVolume),
                              subtitle: '$totalTrx transaksi tercatat',
                              icon: Icons.trending_up_rounded,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'SALDO CASH BEREDAR',
                              value:
                                  CurrencyFormatter.rupiah(wallet.cashBalance),
                              subtitle:
                                  'Tabungan: ${CurrencyFormatter.rupiah(wallet.savingBalance)}',
                              icon: Icons.account_balance_wallet_outlined,
                              color: const Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'MIDTRANS SANDBOX',
                              value: '${orders.length} Order',
                              subtitle:
                                  '$settledOrders Settlement • Gateway Aktif',
                              icon: Icons.payments_outlined,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tabel Transaksi Terbaru di Dashboard
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.lgAll,
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Aktivitas Transaksi Terbaru (Live)',
                                  style: AppTextStyles.h3,
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _selectedTabIndex = 1),
                                  child:
                                      const Text('Lihat Semua Transaksi →'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTransactionTable(
                              sourceList: transactions,
                              limit: 5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 2. TRANSACTIONS TAB
  Widget _buildTransactionsTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchTrxController,
                  decoration: InputDecoration(
                    hintText: 'Cari Referensi (FPX-...), judul, atau kanal...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _trxFilter,
                items: [
                  'Semua',
                  'Pembayaran QRIS',
                  'Terima QRIS',
                  'Isi Saldo',
                  'Transfer',
                  'Pembayaran Merchant',
                  'Tarik Tunai',
                  'Pinjaman',
                  'Tabungan',
                ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _trxFilter = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tabel Transaksi
          Expanded(
            child: SingleChildScrollView(
              child: _buildTransactionTable(
                filterCategory: _trxFilter == 'Semua' ? null : _trxFilter,
                searchQuery: _searchTrxController.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTable({
    List<TransactionModel>? sourceList,
    int? limit,
    String? filterCategory,
    String? searchQuery,
  }) {
    var list = sourceList ?? TransactionService.instance.transactionsNotifier.value;

    if (filterCategory != null && filterCategory.isNotEmpty) {
      final fc = filterCategory.toLowerCase();
      list = list
          .where(
            (t) =>
                t.category.toLowerCase() == fc ||
                (fc.contains('qris') && t.channel.toLowerCase().contains('qris')),
          )
          .toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((t) =>
        t.referenceNumber.toLowerCase().contains(q) ||
        t.title.toLowerCase().contains(q) ||
        t.channel.toLowerCase().contains(q)
      ).toList();
    }

    if (limit != null && list.length > limit) {
      list = list.sublist(0, limit);
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.0),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.8),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1.2),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      children: [
        // Header Table
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: [
            _tableHeader('Judul & No. Referensi'),
            _tableHeader('Waktu Transaksi'),
            _tableHeader('Kanal / Metode'),
            _tableHeader('Nominal'),
            _tableHeader('Tipe'),
            _tableHeader('Status'),
          ],
        ),

        // Rows
        for (final trx in list)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trx.title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                    Text(trx.referenceNumber, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(trx.dateTime, style: AppTextStyles.bodySmall),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(trx.channel, style: AppTextStyles.bodySmall),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(
                  CurrencyFormatter.rupiah(trx.amount, withSign: true),
                  style: AppTextStyles.label.copyWith(
                    color: trx.isIncoming ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(trx.category, style: AppTextStyles.caption),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: PillBadge(
                  label: trx.status,
                  backgroundColor: AppColors.successLight,
                  foregroundColor: AppColors.success,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 3. USERS MANAGEMENT TAB
  Widget _buildUsersTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daftar Seluruh Pengguna FinPay', style: AppTextStyles.h2),
              PillBadge(
                label: '${_userList.length} Akun Terdaftar',
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.0),
                  1: FlexColumnWidth(1.8),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1.5),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: [
                      _tableHeader('Nama Pengguna'),
                      _tableHeader('Email'),
                      _tableHeader('Nomor HP'),
                      _tableHeader('Membership Tier'),
                      _tableHeader('Status KYC'),
                      _tableHeader('Aksi Admin'),
                    ],
                  ),
                  for (final user in _userList)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  user['name'].toString().substring(0, 1),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(user['name'] as String, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          child: Text(user['email'] as String, style: AppTextStyles.bodySmall),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          child: Text(user['phone'] as String, style: AppTextStyles.bodySmall),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          child: Text(user['tier'] as String, style: AppTextStyles.label.copyWith(color: AppColors.primary)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          child: PillBadge(
                            label: user['kycStatus'] as String,
                            backgroundColor: user['kycStatus'] == 'Terverifikasi' ? AppColors.successLight : AppColors.goldLight,
                            foregroundColor: user['kycStatus'] == 'Terverifikasi' ? AppColors.success : const Color(0xFFB45309),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                                tooltip: 'Kirim Pesan CS',
                                onPressed: () {
                                  setState(() {
                                    _selectedUserChatId = user['id'] as String;
                                    _selectedTabIndex = 3; // Buka tab live chat
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  user['isBlocked'] == true ? Icons.lock_open_rounded : Icons.block_rounded,
                                  color: user['isBlocked'] == true ? AppColors.success : AppColors.danger,
                                  size: 20,
                                ),
                                tooltip: user['isBlocked'] == true ? 'Buka Blokir' : 'Bekukan Akun',
                                onPressed: () {
                                  setState(() {
                                    user['isBlocked'] = !(user['isBlocked'] as bool);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Status akun ${user['name']} diperbarui.')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. LIVE CS CHAT TAB (Komunikasi Admin ↔ User)
  Widget _buildSupportChatTab() {
    return Row(
      children: [
        // Daftar Percakapan Pengguna di Sebelah Kiri
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.lg)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Inbox Pesan Masuk', style: AppTextStyles.h3),
                    const PillBadge(
                      label: 'CS Aktif',
                      backgroundColor: AppColors.successLight,
                      foregroundColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _userList.length,
                  itemBuilder: (context, index) {
                    final u = _userList[index];
                    final isSelected = u['id'] == _selectedUserChatId;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: AppColors.primaryLight,
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade200,
                        child: Text(
                          u['name'].toString().substring(0, 1),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(u['name'] as String, style: AppTextStyles.label),
                      subtitle: Text(u['phone'] as String, style: AppTextStyles.caption),
                      trailing: index == 0
                          ? Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          : null,
                      onTap: () {
                        setState(() => _selectedUserChatId = u['id'] as String);
                        SupportChatService.instance.markMessagesAsRead(u['id'] as String);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Jendela Chat Aktif di Sebelah Kanan
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.lg)),
              border: const Border(
                top: BorderSide(color: AppColors.border),
                right: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: ValueListenableBuilder<List<SupportMessageModel>>(
              valueListenable: SupportChatService.instance.messagesNotifier,
              builder: (context, allMessages, _) {
                final activeChatUser = _userList.firstWhere(
                  (u) => u['id'] == _selectedUserChatId,
                  orElse: () => _userList.first,
                );

                final messages = allMessages
                    .where((m) => m.userId == _selectedUserChatId)
                    .toList();

                return Column(
                  children: [
                    // Chat Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryLight,
                            child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(activeChatUser['name'] as String, style: AppTextStyles.h3),
                              Text('${activeChatUser['email']} • ${activeChatUser['phone']}', style: AppTextStyles.caption),
                            ],
                          ),
                          const Spacer(),
                          const PillBadge(
                            label: 'Terhubung ke HP User',
                            backgroundColor: AppColors.successLight,
                            foregroundColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),

                    // Daftar Balon Pesan
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isAdmin = msg.isFromAdmin;

                          return Align(
                            alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: const BoxConstraints(maxWidth: 520),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isAdmin ? AppColors.primary : Colors.white,
                                borderRadius: AppRadius.lgAll,
                                border: isAdmin ? null : Border.all(color: AppColors.border),
                                boxShadow: AppShadows.card,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAdmin ? 'Admin (Anda)' : msg.userName,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isAdmin ? Colors.white70 : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.text,
                                    style: AppTextStyles.body.copyWith(
                                      color: isAdmin ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    msg.timeFormatted,
                                    style: AppTextStyles.caption.copyWith(
                                      color: isAdmin ? Colors.white60 : AppColors.textTertiary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Input Bar Balasan Admin
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _adminReplyController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendAdminReply(),
                              decoration: InputDecoration(
                                hintText: 'Ketik balasan resmi Admin ke HP ${activeChatUser['name']}...',
                                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _sendAdminReply,
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            label: const Text('Kirim Pesan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // 5. MIDTRANS SANDBOX GATEWAY TAB
  Widget _buildMidtransTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Audit Transaksi Midtrans Sandbox', style: AppTextStyles.h2),
              const PillBadge(
                label: 'Mode: Sandbox Simulator',
                backgroundColor: AppColors.primaryLight,
                foregroundColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Order pembayaran virtual account dan QRIS yang diproses melalui gateway Midtrans',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.8),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(2.0),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.2),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: [
                      _tableHeader('Order ID Midtrans'),
                      _tableHeader('Nominal'),
                      _tableHeader('Kanal Virtual Account'),
                      _tableHeader('Snap Token'),
                      _tableHeader('Status Settlement'),
                    ],
                  ),
                  _midtransRow('FPX-90821231', 500000, 'BCA Virtual Account (88012 081234567890)', 'sandbox-token-fpx-90821231', 'Settlement'),
                  _midtransRow('FPX-90820012', 250000, 'Mandiri Virtual Account (88013 081299887766)', 'sandbox-token-fpx-90820012', 'Settlement'),
                  _midtransRow('FPX-90772100', 1000000, 'BRI Virtual Account (88014 081234567890)', 'sandbox-token-fpx-90772100', 'Settlement'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _midtransRow(String orderId, int amount, String channel, String token, String status) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(orderId, style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(CurrencyFormatter.rupiah(amount), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(channel, style: AppTextStyles.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(token, style: AppTextStyles.caption),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: PillBadge(
            label: status,
            backgroundColor: AppColors.successLight,
            foregroundColor: AppColors.success,
          ),
        ),
      ],
    );
  }

  // 6. KYC VERIFICATION TAB
  Widget _buildKycTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pusat Verifikasi KYC (KTP)', style: AppTextStyles.h2),
              const PillBadge(
                label: '1 Permohonan Menunggu',
                backgroundColor: AppColors.goldLight,
                foregroundColor: Color(0xFFB45309),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: AppRadius.smAll,
                          ),
                          child: const Icon(Icons.badge_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Budi Santoso', style: AppTextStyles.h3),
                              const SizedBox(height: 2),
                              Text('NIK KTP: 3171029102910002 • No HP: 0812-9988-7766', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('KYC Budi Santoso disetujui.')),
                            );
                          },
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          label: const Text('Setujui (Approve)', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Permohonan KYC ditolak.')),
                            );
                          },
                          child: const Text('Tolak'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget Sidebar Nav Item
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white60,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Colors.white24,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: badgeColor != null ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget Kartu KPI
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h1.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
