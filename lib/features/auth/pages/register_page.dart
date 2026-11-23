import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/auth_flow_args.dart';
import '../data/auth_repository.dart';
import '../utils/auth_validators.dart';
import '../utils/phone_input_formatter.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_hero_scaffold.dart';
import '../widgets/auth_routes.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/legal_links.dart';
import 'login_page.dart';
import 'otp_page.dart';

/// Langkah 1 pendaftaran: data diri. Field mengikuti desain Figma (nama
/// sesuai KTP, nomor HP, email, kode referral, persetujuan S&K) ditambah
/// tanggal lahir untuk cek usia minimal 17 tahun. Tanggal lahir dan kode
/// referral disusun berdampingan supaya form tidak terlalu panjang.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  final TextEditingController _name = TextEditingController();
  final TextEditingController _nik = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _birth = TextEditingController();
  final TextEditingController _referral = TextEditingController();

  DateTime? _birthDate;
  bool _agree = false;

  String? _nameError;
  String? _nikError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _addressError;
  String? _birthError;
  String? _referralError;

  @override
  void dispose() {
    _name.dispose();
    _nik.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _address.dispose();
    _birth.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _birthDate = picked;
      _birth.text = '${picked.day} ${_months[picked.month - 1]} ${picked.year}';
      _birthError = null;
    });
  }

  bool _validate() {
    final nameError = AuthValidators.name(_name.text);
    final cleanNik = _nik.text.replaceAll(RegExp(r'\D'), '');
    final nikError =
        cleanNik.length != 16 ? 'NIK KTP wajib diisi 16 digit angka.' : null;
    var phoneError = AuthValidators.phone(_phone.text);
    final emailError = AuthValidators.email(_email.text);
    final passwordError = AuthValidators.password(_password.text);
    final confirmPasswordError = AuthValidators.confirmPassword(
      _password.text,
      _confirmPassword.text,
    );
    final addressError = _address.text.trim().isEmpty
        ? 'Alamat / lokasi tempat tinggal wajib diisi.'
        : null;
    final birthError = AuthValidators.birthDate(_birthDate);
    final referralError = AuthValidators.referral(_referral.text);

    if (phoneError == null && authRepository.phoneExists(_phone.text)) {
      phoneError = 'Nomor ini sudah terdaftar. Coba masuk.';
    }

    setState(() {
      _nameError = nameError;
      _nikError = nikError;
      _phoneError = phoneError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
      _addressError = addressError;
      _birthError = birthError;
      _referralError = referralError;
    });

    return nameError == null &&
        nikError == null &&
        phoneError == null &&
        emailError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        addressError == null &&
        birthError == null &&
        referralError == null;
  }

  void _next() {
    if (!_validate()) return;

    final referral = _referral.text.trim();
    Navigator.of(context).push(
      authRoute<void>(
        OtpPage(
          args: AuthFlowArgs(
            purpose: AuthPurpose.register,
            phone: AuthValidators.normalizePhone(_phone.text),
            name: _name.text.trim(),
            nik: _nik.text.replaceAll(RegExp(r'\D'), ''),
            email: _email.text.trim(),
            password: _password.text,
            address: _address.text.trim(),
            birthDate: _birthDate,
            referral: referral.isEmpty ? null : referral,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      title: 'Buka rekening FinPay',
      subtitle: 'Isi data dirimu. Proses ini hanya butuh beberapa menit.',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: AuthButton(
          label: 'Lanjut & Verifikasi OTP',
          onPressed: _agree ? _next : null,
        ),
      ),
      children: [
        AuthTextField(
          label: 'Nama Lengkap (sesuai KTP)',
          hint: 'Contoh: Reza Pratama',
          controller: _name,
          errorText: _nameError,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'NIK KTP (16 Digit)',
          hint: '3201234567890001',
          controller: _nik,
          keyboardType: TextInputType.number,
          maxLength: 16,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _nikError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Nomor HP',
          hint: '812-3456-7890',
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: const [PhoneInputFormatter()],
          errorText: _phoneError,
          prefix: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text('+62', style: AppTextStyles.bodyLarge),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Email',
          hint: 'nama@email.com',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Buat Password',
          hint: 'Minimal 6 karakter',
          controller: _password,
          obscure: true,
          errorText: _passwordError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _passwordError = null),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Konfirmasi Password',
          hint: 'Ulangi password',
          controller: _confirmPassword,
          obscure: true,
          errorText: _confirmPasswordError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _confirmPasswordError = null),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          label: 'Alamat / Lokasi Tempat Tinggal',
          hint: 'Contoh: Jl. Sudirman No. 12, Jakarta',
          controller: _address,
          errorText: _addressError,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        // Tanggal lahir dan kode referral berdampingan dalam satu baris.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AuthTextField(
                label: 'Tanggal Lahir',
                hint: 'Pilih tanggal',
                controller: _birth,
                readOnly: true,
                onTap: _pickBirthDate,
                errorText: _birthError,
                suffix: const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AuthTextField(
                label: 'Kode Referral',
                hint: 'Opsional',
                controller: _referral,
                errorText: _referralError,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _referralError = null),
                suffix: AuthValidators.isValidReferral(_referral.text)
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.success,
                      )
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: LegalLinks(prefix: 'Saya menyetujui', center: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sudah punya akun FinPay?', style: AppTextStyles.bodySmall),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacement(authRoute<void>(const LoginPage())),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'Masuk',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
