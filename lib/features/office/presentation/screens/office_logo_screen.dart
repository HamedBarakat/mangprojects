import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/office_model.dart';
import '../../../auth/presentation/screens/login_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// OFFICE LOGO SCREEN
// Shown after entering office code — displays logo + office name
// ══════════════════════════════════════════════════════════════════════════════

class OfficeLogoScreen extends ConsumerStatefulWidget {
  final OfficeModel office;
  const OfficeLogoScreen({super.key, required this.office});

  @override
  ConsumerState<OfficeLogoScreen> createState() => _OfficeLogoScreenState();
}

class _OfficeLogoScreenState extends ConsumerState<OfficeLogoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hasLogo = widget.office.logo != null && widget.office.logo!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1F0F),
      body: Stack(
        children: [
          // ── Engineering background ──────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _EngineeringBgPainter()),
          ),

          // ── Green glow top-right ────────────────────────────────────────
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF2E7D32).withOpacity(0.35),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Green glow bottom-left ──────────────────────────────────────
          Positioned(
            bottom: -60, left: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF1B5E20).withOpacity(0.3),
                  Colors.transparent,
                ]),
              ),
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

                      // ── Small label ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF2E7D32).withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF2E7D32).withOpacity(0.1),
                        ),
                        child: const Text(
                          'WELCOME TO',
                          style: TextStyle(
                            fontSize: 9, letterSpacing: 3,
                            color: Color(0xFF81C784),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.06),

                      // ── Logo area ────────────────────────────────────
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: _LogoWidget(
                          logoUrl: hasLogo ? widget.office.logo! : null,
                          officeName: widget.office.name,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Office name ──────────────────────────────────
                      Text(
                        widget.office.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Office code badge ────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Text(
                          '#${widget.office.code}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.08),

                      // ── Continue button ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue to Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 18),
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

// ══════════════════════════════════════════════════════════════════════════════
// LOGO WIDGET — shows image URL or default engineering placeholder
// ══════════════════════════════════════════════════════════════════════════════

class _LogoWidget extends StatelessWidget {
  final String? logoUrl;
  final String officeName;
  const _LogoWidget({this.logoUrl, required this.officeName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFF162616),
        border: Border.all(
          color: const Color(0xFF2E7D32).withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: logoUrl != null
            ? (logoUrl!.startsWith('data:image')
                ? Image.memory(
                    base64Decode(logoUrl!.split(',').last),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _DefaultLogo(officeName: officeName),
                  )
                : Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _DefaultLogo(officeName: officeName),
                  ))
            : _DefaultLogo(officeName: officeName),
      ),
    );
  }
}

// ── Default logo — engineering style with office initial ────────────────────

class _DefaultLogo extends StatelessWidget {
  final String officeName;
  const _DefaultLogo({required this.officeName});

  @override
  Widget build(BuildContext context) {
    final initial = officeName.isNotEmpty ? officeName[0].toUpperCase() : 'O';
    return Stack(
      alignment: Alignment.center,
      children: [
        // Blueprint background pattern
        CustomPaint(
          painter: _LogoBlueprintPainter(),
          size: const Size(140, 140),
        ),
        // Letter in the center
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Blueprint painter for default logo background ────────────────────────────

class _LogoBlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.12)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 14.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Corner brackets
    final bracketPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const bSize = 16.0;
    // Top-left
    canvas.drawLine(const Offset(8, 8 + bSize), const Offset(8, 8), bracketPaint);
    canvas.drawLine(const Offset(8, 8), const Offset(8 + bSize, 8), bracketPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - 8, 8 + bSize),
        Offset(size.width - 8, 8), bracketPaint);
    canvas.drawLine(Offset(size.width - 8, 8),
        Offset(size.width - 8 - bSize, 8), bracketPaint);
    // Bottom-left
    canvas.drawLine(Offset(8, size.height - 8 - bSize),
        Offset(8, size.height - 8), bracketPaint);
    canvas.drawLine(Offset(8, size.height - 8),
        Offset(8 + bSize, size.height - 8), bracketPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - 8, size.height - 8 - bSize),
        Offset(size.width - 8, size.height - 8), bracketPaint);
    canvas.drawLine(Offset(size.width - 8, size.height - 8),
        Offset(size.width - 8 - bSize, size.height - 8), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// ENGINEERING BACKGROUND PAINTER  (reused from EnterOfficeCodeScreen)
// ══════════════════════════════════════════════════════════════════════════════

class _EngineeringBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.08)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final dotPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    for (double x = 0; x <= size.width; x += step) {
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final buildingPath = Path()
      ..moveTo(size.width * 0.6, size.height * 0.05)
      ..lineTo(size.width * 0.6, size.height * 0.28)
      ..lineTo(size.width * 0.95, size.height * 0.28)
      ..lineTo(size.width * 0.95, size.height * 0.05)
      ..close();
    canvas.drawPath(buildingPath, linePaint);

    final arcPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.13)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.12, size.height * 0.82),
        width: size.width * 0.28, height: size.width * 0.28,
      ),
      -math.pi, math.pi, false, arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
