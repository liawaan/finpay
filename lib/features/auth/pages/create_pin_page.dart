import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/services/auth_service.dart';
import '../data/auth_flow_args.dart';
import '../data/auth_repository.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/pin_pad.dart';
import '../widgets/shake.dart';
import 'auth_success_page.dart';

/// Langkah 3: membuat PIN 6 digit (buat -> konfirmasi). Menolak PIN yang
/// lemah (angka sama, berurutan, berulang, atau memakai tanggal lahir).
/// Dipakai untuk pendaftaran akun baru maupun pemulihan PIN.
class CreatePinPage extends StatefulWidget {
  const CreatePinPage({super.key, required this.args});

  final AuthFlowArgs args;

  @override
  State<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
  static const int _length = 6;

  int _stage = 0; // 0 = buat PIN, 1 = konfirmasi PIN
  String _input = '';
  String _firstPin = '';
  String? _error;
  int _shake = 0;
  bool _saving = false;

  bool get _isReset => widget.args.purpose == AuthPurpose.resetPin;

  void _onDigit(String digit) {
    if (_saving || _input.length >= _length) return;
    setState(() {
      _input += digit;
      _error = null;
    });
    if (_input.length == _length) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _submit();
      });
    }
  }

  void _onBackspace() {
    if (_saving || _input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _fail(String message, {bool restart = false}) {
    HapticFeedback.heavyImpact();
    setState(() {
      _input = '';
      _error = message;
      _shake++;
      if (restart) {
        _firstPin = '';
        _stage = 0;
      }
    });
  }

  void _submit() {
    if (_stage == 0) {
      final problem = AuthValidators.pinProblem(
        _input,
        birthDate: widget.args.birthDate,
      );
      if (problem != null) {
        _fail(problem);
        return;
      }
      setState(() {
        _firstPin = _input;
        _input = '';
        _stage = 1;
      });
      return;
    }

    if (_input != _firstPin) {
      _fail('PIN tidak cocok. Ulangi dari awal.', restart: true);
      return;
    }

    _complete();
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);

    final args = widget.args;

    if (_isReset) {
      final ok = authRepository.resetPin(phone: args.phone, newPin: _firstPin);
      await AuthService.instance.resetPinByPhone(
        phone: args.phone,
        newPin: _firstPin,
      );
      if (!mounted) return;
      if (!ok) {
        // Tetap izinkan lanjut jika nomor ada di Firestore, atau tampilkan pesan bila gagal lokal.
        setState(() => _saving = false);
      }
    } else {
      try {
        await AuthService.instance.register(
          fullName: args.name ?? '',
          nik: args.nik,
          birthDate: args.birthDate != null
              ? AuthService.formatDeviceDate(args.birthDate!)
              : null,
          address: args.address,
          email: args.email ?? '',
          phoneNumber: '0${args.phone}',
          password: (args.password != null && args.password!.isNotEmpty)
              ? args.password!
              : _firstPin,
          pin: _firstPin,
          usedReferralCode: args.referral,
          initialCash: 0,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        _fail(e.toString().replaceFirst('Exception: ', ''), restart: true);
        return;
      }

      try {
        authRepository.register(
          name: args.name ?? '',
          phone: args.phone,
          email: args.email ?? '',
          pin: _firstPin,
          birthDate: args.birthDate,
        );
      } on StateError {
        // Nomor sudah ada di cache memori lokal; sesi utama tetap aktif di AuthService.
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).push(authRoute<void>(AuthSuccessPage(args: args)));
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;

    return AuthHeroScaffold(
      title: _stage == 0
          ? (_isReset ? 'Buat PIN baru' : 'Buat PIN FinPay')
          : 'Konfirmasi PIN',
      subtitle: _stage == 0
          ? 'PIN 6 digit ini dipakai untuk masuk dan mengonfirmasi transaksi. Jangan bagikan ke siapa pun.'
          : 'Masukkan ulang PIN yang barusan kamu buat.',
      children: [
        Shake(
          trigger: _shake,
          child: PinDots(
            length: _length,
            filled: _input.length,
            hasError: hasError,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 36,
          child: Center(
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PinKeypad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          enabled: !_saving,
        ),
      ],
    );
  }
}
