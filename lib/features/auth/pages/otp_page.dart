import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../auth_config.dart';
import '../data/auth_flow_args.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/pin_pad.dart';
import '../widgets/shake.dart';
import 'create_pin_page.dart';

enum _Channel { sms, whatsapp }

/// Langkah 2: verifikasi kode OTP 4 digit. Bisa dikirim lewat SMS atau
/// WhatsApp, ada hitung mundur kirim ulang, dan setelah 3 kali salah
/// pengguna harus meminta kode baru.
///
/// DEMO: kode OTP yang benar adalah `AuthConfig.demoOtp` (1234).
class OtpPage extends StatefulWidget {
  const OtpPage({super.key, required this.args});

  final AuthFlowArgs args;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  static const int _length = 4;
  static const int _resendSeconds = 30;
  static const int _maxWrong = 3;

  String _code = '';
  String? _error;
  int _wrong = 0;
  int _shake = 0;
  int _seconds = _resendSeconds;
  _Channel _channel = _Channel.sms;
  Timer? _timer;

  bool get _blocked => _wrong >= _maxWrong;
  bool get _isReset => widget.args.purpose == AuthPurpose.resetPin;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) timer.cancel();
    });
  }

  /// "81234567890" -> "+62 812-••••-90"
  String get _maskedPhone {
    final digits = widget.args.phone;
    if (digits.length < 6) return '+62 $digits';
    return '+62 ${digits.substring(0, 3)}-••••-${digits.substring(digits.length - 2)}';
  }

  String get _countdown {
    final s = _seconds.toString().padLeft(2, '0');
    return '00:$s';
  }

  String get _channelLabel =>
      _channel == _Channel.sms ? 'SMS' : 'WhatsApp';

  void _onDigit(String digit) {
    if (_code.length >= _length || _blocked) return;
    setState(() {
      _code += digit;
      _error = null;
    });
    if (_code.length == _length) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _verify();
      });
    }
  }

  void _onBackspace() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  void _verify() {
    if (_code != AuthConfig.demoOtp) {
      HapticFeedback.heavyImpact();
      final wrong = _wrong + 1;
      setState(() {
        _wrong = wrong;
        _code = '';
        _shake++;
        _error = wrong >= _maxWrong
            ? 'Terlalu banyak percobaan. Minta kode baru.'
            : 'Kode OTP salah. Sisa percobaan: ${_maxWrong - wrong}x.';
      });
      return;
    }

    // Pemulihan PIN: setelah OTP terbukti benar (pengguna memegang nomor
    // tersebut), baru aman memberi tahu kalau nomornya tidak terdaftar.
    if (_isReset && !authRepository.phoneExists(widget.args.phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor ini belum terdaftar. Silakan daftar dulu.'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    Navigator.of(context).push(authRoute<void>(CreatePinPage(args: widget.args)));
  }

  void _resend() {
    setState(() {
      _code = '';
      _error = null;
      _wrong = 0;
    });
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kode OTP baru dikirim lewat $_channelLabel')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _seconds <= 0 || _blocked;

    return AuthHeroScaffold(
      title: 'Verifikasi nomor HP',
      subtitle:
          'Masukkan 4 digit kode yang dikirim lewat $_channelLabel ke $_maskedPhone',
      children: [
        _buildChannelSwitch(),
        const SizedBox(height: AppSpacing.xxl),
        Shake(trigger: _shake, child: _buildBoxes()),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 24,
          child: Center(
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: canResend
              ? TextButton(
                  onPressed: _resend,
                  child: Text(
                    'Kirim ulang kode',
                    style:
                        AppTextStyles.label.copyWith(color: AppColors.primary),
                  ),
                )
              : Text(
                  'Kirim ulang kode dalam $_countdown',
                  style: AppTextStyles.bodySmall,
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PinKeypad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          enabled: !_blocked,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            'Mode demo: kode OTP adalah ${AuthConfig.demoOtp}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelSwitch() {
    Widget chip(_Channel channel, IconData icon, String label) {
      final selected = _channel == channel;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _channel = channel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: AppRadius.mdAll,
              boxShadow: selected ? AppShadows.card : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: AppSizes.iconMd - 2,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          chip(_Channel.sms, Icons.sms_outlined, 'SMS'),
          chip(_Channel.whatsapp, Icons.chat_outlined, 'WhatsApp'),
        ],
      ),
    );
  }

  Widget _buildBoxes() {
    final hasError = _error != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            width: 58,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: hasError
                    ? AppColors.danger
                    : (i == _code.length
                        ? AppColors.primary
                        : AppColors.border),
                width: i == _code.length ? 1.5 : 1,
              ),
            ),
            child: Text(
              i < _code.length ? _code[i] : '',
              style: AppTextStyles.displayMedium,
            ),
          ),
      ],
    );
  }
}
