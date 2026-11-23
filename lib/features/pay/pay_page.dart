import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/qris_model.dart';
import '../../data/services/qris_service.dart';
import '../../data/services/wallet_service.dart';
import '../account/pages/my_qr_page.dart';
import 'widgets/qris_bayar_cpm_sheet.dart';
import 'widgets/qris_camera_view.dart';
import 'widgets/qris_confirm_sheet.dart';
import 'widgets/qris_merchant_picker_sheet.dart';
import 'widgets/qris_other_methods_panel.dart';
import 'widgets/qris_pin_sheet.dart';
import 'widgets/qris_receipt_sheet.dart';
import 'widgets/qris_supported_watermark.dart';

/// Halaman Scan QRIS dengan Live Camera Preview, verifikasi PIN pada fitur Bayar,
/// serta akses langsung ke QRIS Saya pada tombol Transfer (Bagian Tugas Ali).
class PayPage extends StatefulWidget {
  const PayPage({super.key, this.onBackTap});

  final VoidCallback? onBackTap;

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  bool _isFlashOn = false;
  bool _isHandlingScan = false;

  /// Alur lengkap pembayaran QRIS dari string EMVCo QRIS:
  /// 1. Parse & validasi CRC16 via [QrisService.scan]
  /// 2. Tampilkan lembar konfirmasi [showQrisConfirmSheet] (termasuk verifikasi PIN 6 digit)
  /// 3. Potong saldo & catat transaksi via [WalletService.payWithQris] (serta kredit saldo penerima bila Transfer QRIS Antar Pengguna)
  /// 4. Tampilkan struk digital [showQrisReceipt]
  Future<void> _handleScannedQrisString(String rawQris) async {
    if (_isHandlingScan) return;
    _isHandlingScan = true;
    try {
      final QrisPayload payload;
      try {
        payload = QrisService.instance.scan(rawQris);
      } on QrisFormatException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      }

      final approvedAmount = await showQrisConfirmSheet(context, payload);
      if (approvedAmount == null || !mounted) return;

      final timeFormatted = TimeOfDay.now().format(context);
      try {
        final fee = QrisService.instance.adminFee(approvedAmount);
        final trx = await WalletService.instance.payWithQris(
          merchantName: payload.merchantName,
          merchantCity: payload.merchantCity,
          nmid: payload.nmid,
          recipientUserId: payload.recipientUserId,
          isPeerTransfer: payload.isFinPayUser,
          amount: approvedAmount,
          adminFee: fee,
          timeFormatted: timeFormatted,
        );
        if (!mounted) return;
        setState(() {});
        await showQrisReceipt(
          context,
          transaction: trx,
          payload: payload,
        );
        if (mounted) setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      _isHandlingScan = false;
    }
  }

  Future<void> _openMerchantPicker() async {
    final rawQris = await showQrisScanSourceSheet(context);
    if (rawQris == null || rawQris.trim().isEmpty || !mounted) return;
    await _handleScannedQrisString(rawQris);
  }

  /// Aksi tombol "Bayar" di Metode QRIS Lainnya:
  /// Wajib memasukkan PIN 6 digit terlebih dahulu sebelum menampilkan QRIS Bayar.
  Future<void> _handleBayarMethodTap() async {
    final pinVerified = await showQrisPinSheet(
      context,
      title: 'Masukkan PIN FinPay',
      subtitle: 'Verifikasi 6 digit PIN untuk menggunakan fitur QRIS Bayar',
    );
    if (!pinVerified || !mounted) return;

    await showQrisBayarCpmSheet(
      context,
      onSelectMerchant: _openMerchantPicker,
    );
  }

  /// Aksi tombol "Transfer" di Metode QRIS Lainnya:
  /// Langsung membuka dan menampilkan kode QRIS milik pengguna (`MyQrPage`).
  Future<void> _handleTransferMethodTap() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const MyQrPage()),
    );
    if (mounted) setState(() {});
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    widget.onBackTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isCameraActive = TickerMode.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1614),
      body: Column(
        children: [
          // Area Kamera Penuh (Full-Bleed Scanner View)
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                QrisCameraView(
                  isActive: isCameraActive,
                  isFlashOn: _isFlashOn,
                  onTapViewport: _openMerchantPicker,
                  onQrDetected: _handleScannedQrisString,
                ),

                // Gradasi halus di bagian atas agar teks & ikon putih tetap kontras di atas kamera
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.52),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Bar Overlay: "< Scan QRIS" di kiri, Galeri QR & Flash di kanan
                SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Kembali',
                            onPressed: _handleBack,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Scan QRIS',
                            style: AppTextStyles.h2.copyWith(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Pilih QRIS dari Galeri / Merchant',
                            onPressed: _openMerchantPicker,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Lampu Flash',
                            onPressed: () =>
                                setState(() => _isFlashOn = !_isFlashOn),
                            icon: Icon(
                              _isFlashOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color:
                                  _isFlashOn ? AppColors.gold : Colors.white,
                              size: 25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Watermark "QRIS SUPPORTED" tepat di atas panel putih bawah
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: IgnorePointer(
                      child: QrisSupportedWatermark(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Panel Putih Bawah: "Metode QRIS Lainnya" (Bayar & Transfer)
          QrisOtherMethodsPanel(
            onBayarTap: _handleBayarMethodTap,
            onTransferTap: _handleTransferMethodTap,
          ),
        ],
      ),
    );
  }
}
