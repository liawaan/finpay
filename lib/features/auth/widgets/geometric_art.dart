import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Bentuk dasar
// ---------------------------------------------------------------------------

/// Setengah lingkaran (sisi datar di bawah).
class _HalfDiscPainter extends CustomPainter {
  const _HalfDiscPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final path = Path()
      ..moveTo(0, size.height)
      ..arcTo(
        Rect.fromCircle(center: Offset(radius, size.height), radius: radius),
        math.pi, // mulai dari titik kiri
        math.pi, // sapu setengah lingkaran lewat atas
        false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HalfDiscPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Setengah lingkaran yang diputar [angle] radian, opsional dengan ikon.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.radius,
    required this.color,
    this.angle = 0,
    this.glyph,
  });

  final double radius;
  final Color color;
  final double angle;
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: radius * 2,
        height: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _HalfDiscPainter(color)),
            ),
            if (glyph != null)
              Align(alignment: const Alignment(0, 0.35), child: glyph),
          ],
        ),
      ),
    );
  }
}

/// Lingkaran penuh (titik hiasan atau bentuk lembut).
class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Data komposisi: tiap slide onboarding punya susunan bentuk sendiri
// ---------------------------------------------------------------------------

class _DiscSpec {
  const _DiscSpec({
    required this.left,
    required this.top,
    required this.radius,
    required this.color,
    this.angle = 0,
    this.glyph,
    this.phase = 0,
    this.amplitude = 6,
  });

  final double left;
  final double top;
  final double radius;
  final Color color;
  final double angle;
  final Widget? glyph;

  /// Selisih fase animasi melayang (0..1) supaya tiap bentuk tidak serempak.
  final double phase;
  final double amplitude;
}

class _DotSpec {
  const _DotSpec({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
    this.phase = 0,
  });

  final double left;
  final double top;
  final double size;
  final Color color;
  final double phase;
}

class _ArtSpec {
  const _ArtSpec({required this.discs, required this.dots});

  final List<_DiscSpec> discs;
  final List<_DotSpec> dots;
}

// ---------------------------------------------------------------------------
// Hero onboarding
// ---------------------------------------------------------------------------

/// Ilustrasi hero onboarding: setengah lingkaran bertumpuk berwarna FinPay
/// yang melayang pelan. [variant] (0..2) memilih susunan bentuk, ikon, dan
/// warna, jadi tiap slide punya gambar yang berbeda.
///
/// Digambar murni dengan kode (tanpa file gambar), jadi tajam di semua ukuran.
class GeometricArt extends StatefulWidget {
  const GeometricArt({super.key, this.variant = 0});

  static const double width = 320;
  static const double height = 360;
  static const int variantCount = 3;

  final int variant;

  @override
  State<GeometricArt> createState() => _GeometricArtState();
}

class _GeometricArtState extends State<GeometricArt>
    with SingleTickerProviderStateMixin {
  /// 0 = Bayar, 1 = Nabung, 2 = Aman.
  static final List<_ArtSpec> _variants = [
    // 0 — Bayar apa aja, di mana aja
    _ArtSpec(
      discs: const [
        _DiscSpec(
          left: 8, top: 44, radius: 54,
          color: AppColors.primaryLight, angle: -0.6, phase: 0.10, amplitude: 5,
        ),
        _DiscSpec(
          left: 10, top: 170, radius: 120,
          color: AppColors.primary, angle: -0.30, phase: 0.40, amplitude: 7,
          glyph: Icon(Icons.qr_code_2_rounded, size: 46, color: Colors.white),
        ),
        _DiscSpec(
          left: 140, top: 52, radius: 84,
          color: AppColors.navy, angle: 0.50, phase: 0.70, amplitude: 8,
          glyph: Icon(
            Icons.account_balance_wallet_rounded,
            size: 34,
            color: Colors.white,
          ),
        ),
        _DiscSpec(
          left: 150, top: 180, radius: 64,
          color: AppColors.primaryDark, angle: -0.95, phase: 0.25,
        ),
        _DiscSpec(
          left: 26, top: 270, radius: 70,
          color: AppColors.mint, angle: 0.35, phase: 0.85,
          glyph: Icon(Icons.north_east_rounded, size: 30, color: AppColors.navy),
        ),
      ],
      dots: [
        const _DotSpec(
          left: 270, top: 18, size: 18, color: AppColors.mint, phase: 0.55,
        ),
        const _DotSpec(
          left: 4, top: 140, size: 14, color: AppColors.goldLight, phase: 0.95,
        ),
        const _DotSpec(
          left: 282, top: 252, size: 20,
          color: AppColors.primaryLight, phase: 0.30,
        ),
        _DotSpec(
          left: 218, top: 322, size: 12,
          color: AppColors.primary.withValues(alpha: 0.5), phase: 0.65,
        ),
      ],
    ),

    // 1 — Nabung dan atur uang lebih pintar
    _ArtSpec(
      discs: const [
        _DiscSpec(
          left: 206, top: 36, radius: 52,
          color: AppColors.primaryLight, angle: 0.7, phase: 0.20, amplitude: 5,
        ),
        _DiscSpec(
          left: 14, top: 64, radius: 86,
          color: AppColors.primary, angle: -0.50, phase: 0.55, amplitude: 7,
          glyph: Icon(Icons.trending_up_rounded, size: 36, color: Colors.white),
        ),
        _DiscSpec(
          left: 64, top: 160, radius: 120,
          color: AppColors.mint, angle: 0.28, phase: 0.05, amplitude: 8,
          glyph: Icon(Icons.savings_rounded, size: 50, color: AppColors.navy),
        ),
        _DiscSpec(
          left: 176, top: 196, radius: 62,
          color: AppColors.navy, angle: 0.90, phase: 0.75,
        ),
        _DiscSpec(
          left: 170, top: 280, radius: 66,
          color: AppColors.primaryDark, angle: -0.30, phase: 0.40, amplitude: 5,
          glyph: Icon(Icons.flag_rounded, size: 28, color: Colors.white),
        ),
      ],
      dots: [
        const _DotSpec(
          left: 8, top: 22, size: 16, color: AppColors.goldLight, phase: 0.35,
        ),
        const _DotSpec(
          left: 288, top: 170, size: 16, color: AppColors.mint, phase: 0.80,
        ),
        const _DotSpec(
          left: 20, top: 310, size: 20,
          color: AppColors.primaryLight, phase: 0.15,
        ),
        _DotSpec(
          left: 110, top: 332, size: 12,
          color: AppColors.navy.withValues(alpha: 0.5), phase: 0.60,
        ),
      ],
    ),

    // 2 — Aman, resmi, dan terjamin
    _ArtSpec(
      discs: const [
        _DiscSpec(
          left: 122, top: 18, radius: 90,
          color: AppColors.navy, angle: -0.15, phase: 0.30, amplitude: 7,
          glyph: Icon(Icons.verified_user_rounded, size: 38, color: Colors.white),
        ),
        _DiscSpec(
          left: 0, top: 146, radius: 100,
          color: AppColors.primary, angle: 0.45, phase: 0.65, amplitude: 7,
          glyph: Icon(Icons.lock_rounded, size: 40, color: Colors.white),
        ),
        _DiscSpec(
          left: 124, top: 190, radius: 106,
          color: AppColors.mint, angle: -0.40, phase: 0.10, amplitude: 8,
          glyph: Icon(Icons.fingerprint_rounded, size: 46, color: AppColors.navy),
        ),
        _DiscSpec(
          left: 206, top: 288, radius: 52,
          color: AppColors.primaryLight, angle: 0.5, phase: 0.85, amplitude: 4,
        ),
        _DiscSpec(
          left: 28, top: 286, radius: 52,
          color: AppColors.primaryDark, angle: -0.6, phase: 0.45, amplitude: 5,
        ),
      ],
      dots: [
        const _DotSpec(
          left: 24, top: 54, size: 18, color: AppColors.mint, phase: 0.50,
        ),
        const _DotSpec(
          left: 292, top: 90, size: 14,
          color: AppColors.primaryLight, phase: 0.20,
        ),
        const _DotSpec(
          left: 290, top: 236, size: 16, color: AppColors.goldLight, phase: 0.75,
        ),
        _DotSpec(
          left: 134, top: 338, size: 12,
          color: AppColors.primary.withValues(alpha: 0.5), phase: 0.05,
        ),
      ],
    ),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Menggeser [child] naik-turun mengikuti gelombang sinus.
  Widget _bob(double t, double phase, double amplitude, Widget child) {
    final dy = math.sin((t + phase) * math.pi * 2) * amplitude;
    return Transform.translate(offset: Offset(0, dy), child: child);
  }

  @override
  Widget build(BuildContext context) {
    final spec = _variants[widget.variant % _variants.length];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: GeometricArt.width,
          height: GeometricArt.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final disc in spec.discs)
                Positioned(
                  left: disc.left,
                  top: disc.top,
                  child: _bob(
                    t,
                    disc.phase,
                    disc.amplitude,
                    _Disc(
                      radius: disc.radius,
                      color: disc.color,
                      angle: disc.angle,
                      glyph: disc.glyph,
                    ),
                  ),
                ),
              for (final dot in spec.dots)
                Positioned(
                  left: dot.left,
                  top: dot.top,
                  child: _bob(
                    t,
                    dot.phase,
                    5,
                    _Dot(size: dot.size, color: dot.color),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hiasan header halaman form
// ---------------------------------------------------------------------------

/// Hiasan lembut di pojok kanan atas header halaman form: hanya lingkaran
/// translusen (tanpa sudut lancip). Taruh di dalam widget yang memotong area
/// luarnya, mis. `ClipRRect`.
class GeometricCorner extends StatelessWidget {
  const GeometricCorner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 50,
            top: 30,
            child: _Dot(size: 150, color: Colors.white.withValues(alpha: 0.10)),
          ),
          Positioned(
            left: 112,
            top: 6,
            child: _Dot(size: 92, color: AppColors.navy.withValues(alpha: 0.40)),
          ),
          Positioned(
            left: 178,
            top: 116,
            child: _Dot(size: 14, color: Colors.white.withValues(alpha: 0.40)),
          ),
        ],
      ),
    );
  }
}
