import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/office_model.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class OfficeLogoScreen extends ConsumerStatefulWidget {
  final OfficeModel office;
  const OfficeLogoScreen({super.key, required this.office});

  @override
  ConsumerState<OfficeLogoScreen> createState() => _OfficeLogoScreenState();
}

class _OfficeLogoScreenState extends ConsumerState<OfficeLogoScreen>
    with TickerProviderStateMixin {

  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late AnimationController _floatCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _bgRotate;
  late Animation<double> _pulse;
  late Animation<double> _orbit;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.09), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _bgRotate  = Tween<double>(begin: 0, end: 2 * math.pi).animate(_bgCtrl);
    _pulse     = Tween<double>(begin: 0.65, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _orbit     = Tween<double>(begin: 0, end: 2 * math.pi).animate(_orbitCtrl);
    _float     = Tween<double>(begin: -10, end: 10).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => const LoginScreen(),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hasLogo = widget.office.logo.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF020E1A),
      body: Stack(
        children: [
          // ── Animated sky background ─────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_bgCtrl, _pulseCtrl]),
              builder: (_, __) => CustomPaint(
                painter: _SkyBgPainter(rotation: _bgRotate.value, pulse: _pulse.value),
              ),
            ),
          ),

          // ── Radial glow center ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Center(
              child: Container(
                width: size.width * 0.85,
                height: size.width * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF0288D1).withOpacity(0.18 * _pulse.value),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),

          // ── Orbiting rings around logo ──────────────────────────────────
          AnimatedBuilder(
            animation: _orbitCtrl,
            builder: (_, __) => Positioned.fill(
              child: CustomPaint(
                painter: _OrbitRingsPainter(
                  angle: _orbit.value,
                  center: Offset(size.width / 2, size.height * 0.44),
                ),
              ),
            ),
          ),

          // ── Floating particles ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, __) => Positioned.fill(
              child: CustomPaint(painter: _SkyParticlesPainter(offset: _float.value)),
            ),
          ),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: size.height * 0.06),

                      // ── Welcome badge ───────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF29B6F6).withOpacity(0.45)),
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF0288D1).withOpacity(0.1),
                        ),
                        child: const Text(
                          'WELCOME TO',
                          style: TextStyle(fontSize: 9, letterSpacing: 3.5, color: Color(0xFF81D4FA), fontWeight: FontWeight.w600),
                        ),
                      ),

                      SizedBox(height: size.height * 0.05),

                      // ── Logo with glow ──────────────────────────────────
                      AnimatedBuilder(
                        animation: Listenable.merge([_pulseCtrl, _entryCtrl]),
                        builder: (_, child) => Transform.scale(
                          scale: _scaleAnim.value,
                          child: Container(
                            width: 148, height: 148,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              color: const Color(0xFF041624),
                              border: Border.all(color: const Color(0xFF0288D1).withOpacity(0.35), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF29B6F6).withOpacity(0.35 * _pulse.value),
                                  blurRadius: 40, spreadRadius: 6,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20, offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: hasLogo
                              ? (widget.office.logo.startsWith('data:image')
                                    ? Image.memory(base64Decode(widget.office.logo.split(',').last), fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => _SkyDefaultLogo(name: widget.office.name))
                                    : Image.network(widget.office.logo, fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => _SkyDefaultLogo(name: widget.office.name)))
                              : _SkyDefaultLogo(name: widget.office.name),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ── Office name ─────────────────────────────────────
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFE1F5FE), Color(0xFF81D4FA)],
                        ).createShader(bounds),
                        child: Text(
                          widget.office.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold,
                            letterSpacing: -0.5, height: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Code badge ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0277BD).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF29B6F6).withOpacity(0.3)),
                        ),
                        child: Text(
                          '#${widget.office.code}',
                          style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.8),
                        ),
                      ),

                      SizedBox(height: size.height * 0.07),

                      // ── Continue button ─────────────────────────────────
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Container(
                          width: double.infinity, height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0288D1).withOpacity(0.45 * _pulse.value),
                                blurRadius: 26, spreadRadius: 2, offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0277BD),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Continue to Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.06),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sky Blue default logo ────────────────────────────────────────────────────

class _SkyDefaultLogo extends StatelessWidget {
  final String name;
  const _SkyDefaultLogo({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'O';
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(painter: _SkyLogoBgPainter(), size: const Size(148, 148)),
        Container(
          width: 76, height: 76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF29B6F6), Color(0xFF0277BD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: Color(0x6629B6F6), blurRadius: 18)],
          ),
          child: Center(
            child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          ),
        ),
      ],
    );
  }
}

class _SkyLogoBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = const Color(0xFF29B6F6).withOpacity(0.1)..strokeWidth = 0.5..style = PaintingStyle.stroke;
    const step = 14.0;
    for (double x = 0; x <= size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y <= size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    final bp = Paint()..color = const Color(0xFF29B6F6).withOpacity(0.28)..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const b = 16.0;
    canvas.drawLine(const Offset(8, 8 + b), const Offset(8, 8), bp);
    canvas.drawLine(const Offset(8, 8), const Offset(8 + b, 8), bp);
    canvas.drawLine(Offset(size.width - 8, 8 + b), Offset(size.width - 8, 8), bp);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8 - b, 8), bp);
    canvas.drawLine(Offset(8, size.height - 8 - b), Offset(8, size.height - 8), bp);
    canvas.drawLine(Offset(8, size.height - 8), Offset(8 + b, size.height - 8), bp);
    canvas.drawLine(Offset(size.width - 8, size.height - 8 - b), Offset(size.width - 8, size.height - 8), bp);
    canvas.drawLine(Offset(size.width - 8, size.height - 8), Offset(size.width - 8 - b, size.height - 8), bp);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// SKY ANIMATED BACKGROUND PAINTER
// ══════════════════════════════════════════════════════════════════════════════

class _SkyBgPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  const _SkyBgPainter({required this.rotation, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // dot grid
    final dotPaint = Paint()..color = const Color(0xFF29B6F6).withOpacity(0.07)..style = PaintingStyle.fill;
    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // horizontal scan lines
    final scanPaint = Paint()..color = const Color(0xFF0288D1).withOpacity(0.04)..strokeWidth = 0.5..style = PaintingStyle.stroke;
    for (double y = 0; y <= size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // rotating hexagon rings (top-center)
    final cx = size.width * 0.5;
    final cy = size.height * 0.44;
    _drawHex(canvas, Offset(cx, cy), 110, rotation, const Color(0xFF29B6F6), 0.07);
    _drawHex(canvas, Offset(cx, cy), 72,  -rotation * 1.3, const Color(0xFF0288D1), 0.10);
    _drawHex(canvas, Offset(cx, cy), 42,  rotation * 2.0, const Color(0xFF81D4FA), 0.08);

    // concentric arcs top-right
    final arcPaint = Paint()..color = const Color(0xFF0288D1).withOpacity(0.12 * pulse)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    for (double r = 60; r <= 180; r += 40) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(size.width, 0), width: r * 2, height: r * 2),
        math.pi / 2, math.pi / 2, false, arcPaint,
      );
    }

    // circuit lines bottom
    final circPaint = Paint()..color = const Color(0xFF29B6F6).withOpacity(0.1)..strokeWidth = 0.8..style = PaintingStyle.stroke;
    _drawCircuit(canvas, size, circPaint);

    // dimension cross bottom-left
    final dimPaint = Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.15)..strokeWidth = 0.7..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width * 0.06, size.height * 0.72), Offset(size.width * 0.06, size.height * 0.9), dimPaint);
    canvas.drawLine(Offset(size.width * 0.03, size.height * 0.72), Offset(size.width * 0.09, size.height * 0.72), dimPaint);
    canvas.drawLine(Offset(size.width * 0.03, size.height * 0.9), Offset(size.width * 0.09, size.height * 0.9), dimPaint);
  }

  void _drawHex(Canvas canvas, Offset c, double r, double angle, Color color, double opacity) {
    final paint = Paint()..color = color.withOpacity(opacity)..strokeWidth = 1.1..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = angle + i * math.pi / 3;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCircuit(Canvas canvas, Size size, Paint paint) {
    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.75)
      ..lineTo(size.width * 0.25, size.height * 0.75)
      ..lineTo(size.width * 0.25, size.height * 0.82)
      ..lineTo(size.width * 0.42, size.height * 0.82)
      ..moveTo(size.width * 0.15, size.height * 0.88)
      ..lineTo(size.width * 0.35, size.height * 0.88)
      ..lineTo(size.width * 0.35, size.height * 0.82);
    canvas.drawPath(path, paint);
    // nodes
    final nodePaint = Paint()..color = const Color(0xFF29B6F6).withOpacity(0.2)..style = PaintingStyle.fill;
    for (final pt in [
      Offset(size.width * 0.25, size.height * 0.75),
      Offset(size.width * 0.25, size.height * 0.82),
      Offset(size.width * 0.35, size.height * 0.82),
    ]) {
      canvas.drawCircle(pt, 3, nodePaint);
    }
  }

  @override
  bool shouldRepaint(_SkyBgPainter old) => old.rotation != rotation || old.pulse != pulse;
}

// ── Orbiting rings painter ───────────────────────────────────────────────────

class _OrbitRingsPainter extends CustomPainter {
  final double angle;
  final Offset center;
  const _OrbitRingsPainter({required this.angle, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;

    // outer orbit ring
    paint.color = const Color(0xFF29B6F6).withOpacity(0.08);
    canvas.drawCircle(center, 110, paint);

    // orbiting dot on outer ring
    paint.color = const Color(0xFF81D4FA).withOpacity(0.6);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(
      center.dx + 110 * math.cos(angle),
      center.dy + 110 * math.sin(angle),
    ), 3.5, paint);

    // inner orbit ring
    paint.style = PaintingStyle.stroke;
    paint.color = const Color(0xFF0288D1).withOpacity(0.1);
    canvas.drawCircle(center, 78, paint);

    // orbiting dot on inner ring (opposite direction)
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF4FC3F7).withOpacity(0.5);
    canvas.drawCircle(Offset(
      center.dx + 78 * math.cos(-angle * 1.5),
      center.dy + 78 * math.sin(-angle * 1.5),
    ), 2.5, paint);
  }

  @override
  bool shouldRepaint(_OrbitRingsPainter old) => old.angle != angle;
}

// ── Floating sky particles ───────────────────────────────────────────────────

class _SkyParticlesPainter extends CustomPainter {
  final double offset;
  const _SkyParticlesPainter({required this.offset});
  static const _pts = [
    [0.12, 0.22], [0.88, 0.18], [0.05, 0.60], [0.92, 0.55],
    [0.55, 0.92], [0.30, 0.80], [0.75, 0.75], [0.20, 0.40],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.9;
    for (int i = 0; i < _pts.length; i++) {
      final floatY = (i.isEven ? offset : -offset) * 0.55;
      final cx = size.width * _pts[i][0];
      final cy = size.height * _pts[i][1] + floatY;
      final r = 2.5 + (i % 3) * 1.8;
      paint.color = const Color(0xFF29B6F6).withOpacity(0.14 - i * 0.012);
      if (i % 4 == 0) {
        // cross
        canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint);
        canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
      } else if (i % 4 == 1) {
        // diamond
        final path = Path()..moveTo(cx, cy - r)..lineTo(cx + r, cy)..lineTo(cx, cy + r)..lineTo(cx - r, cy)..close();
        canvas.drawPath(path, paint);
      } else if (i % 4 == 2) {
        canvas.drawCircle(Offset(cx, cy), r, paint);
      } else {
        // small hex
        final path = Path();
        for (int j = 0; j < 6; j++) {
          final a = j * math.pi / 3;
          if (j == 0) path.moveTo(cx + r * math.cos(a), cy + r * math.sin(a));
          else path.lineTo(cx + r * math.cos(a), cy + r * math.sin(a));
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(_SkyParticlesPainter old) => old.offset != offset;
}
