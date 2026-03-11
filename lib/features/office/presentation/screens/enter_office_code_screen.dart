import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/office_repository.dart';
import '../controllers/office_providers.dart';
import 'office_logo_screen.dart';

class EnterOfficeCodeScreen extends ConsumerStatefulWidget {
  const EnterOfficeCodeScreen({super.key});

  @override
  ConsumerState<EnterOfficeCodeScreen> createState() =>
      _EnterOfficeCodeScreenState();
}

class _EnterOfficeCodeScreenState
    extends ConsumerState<EnterOfficeCodeScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _formKey        = GlobalKey<FormState>();

  bool    _isLoading    = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final code   = _codeController.text.trim().toUpperCase();
      final office = await ref.read(officeRepositoryProvider).findByCode(code);
      if (office == null) {
        setState(() => _errorMessage = 'Invalid code. Please check and try again.');
        return;
      }
      await ref.read(selectedOfficeProvider.notifier).setOffice(office);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => OfficeLogoScreen(office: office),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1F0F),
      body: Stack(
        children: [
          // ── Geometric engineering background ──────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _EngineeringBgPainter()),
          ),

          // ── Green glow top-right ──────────────────────────────────────
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

          // ── Green glow bottom-left ────────────────────────────────────
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

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: size.height * 0.08),

                        // ── Logo / icon area ─────────────────────────
                        Center(
                          child: Column(children: [
                            Container(
                              width: 88, height: 88,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2E7D32).withOpacity(0.5),
                                    blurRadius: 24, offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.architecture_rounded,
                                  size: 42, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            // small blueprint tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.6)),
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFF2E7D32).withOpacity(0.1),
                              ),
                              child: const Text('PROJECT MANAGEMENT',
                                  style: TextStyle(
                                    fontSize: 9, letterSpacing: 2.5,
                                    color: Color(0xFF81C784), fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 32),

                        // ── Title ────────────────────────────────────
                        Center(
                          child: Text(
                            'Enter Office Code',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Enter the code provided by your office\nadministrator to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14, height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // ── Field label ──────────────────────────────
                        Text(
                          'Office Code',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontWeight: FontWeight.w600, fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Text field ───────────────────────────────
                        TextFormField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          onChanged: (_) => setState(() => _errorMessage = null),
                          style: const TextStyle(
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Company Code',
                            hintStyle: TextStyle(
                              letterSpacing: 1,
                              fontWeight: FontWeight.normal,
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.25),
                            ),
                            prefixIcon: Icon(Icons.tag_rounded,
                                color: const Color(0xFF81C784).withOpacity(0.8)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.07),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.12), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.12), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFF4CAF50), width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                            errorStyle: const TextStyle(color: Colors.redAccent),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your office code';
                            if (v.trim().length < 4) return 'Code must be at least 4 characters';
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // ── Error ────────────────────────────────────
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Button ───────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              disabledBackgroundColor: const Color(0xFF2E7D32).withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Continue',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold,
                                        color: Colors.white, letterSpacing: 0.5)),
                          ),
                        ),

                        SizedBox(height: size.height * 0.06),
                      ],
                    ),
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
// ENGINEERING BACKGROUND PAINTER
// ══════════════════════════════════════════════════════════════════════════════

class _EngineeringBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.08)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // ── Fine grid ─────────────────────────────────────────────────────────
    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── Dot intersections ─────────────────────────────────────────────────
    final dotPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    for (double x = 0; x <= size.width; x += step) {
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // ── Blueprint shapes — structural lines ───────────────────────────────
    final linePaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Building outline top-right
    final buildingPath = Path()
      ..moveTo(size.width * 0.6, size.height * 0.05)
      ..lineTo(size.width * 0.6, size.height * 0.28)
      ..lineTo(size.width * 0.95, size.height * 0.28)
      ..lineTo(size.width * 0.95, size.height * 0.05)
      ..close();
    canvas.drawPath(buildingPath, linePaint);

    // Windows in building
    final winPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.12)
      ..style = PaintingStyle.fill;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 4; col++) {
        final wx = size.width * 0.63 + col * (size.width * 0.07);
        final wy = size.height * 0.08 + row * (size.height * 0.06);
        canvas.drawRect(Rect.fromLTWH(wx, wy, size.width * 0.04, size.height * 0.035), winPaint);
        canvas.drawRect(Rect.fromLTWH(wx, wy, size.width * 0.04, size.height * 0.035), linePaint);
      }
    }

    // ── Gantt-like horizontal bars bottom-left ────────────────────────────
    final ganttPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final ganttBorder = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final barWidths = [0.18, 0.12, 0.22, 0.14, 0.10];
    final barOffsets = [0.0, 0.06, 0.03, 0.10, 0.15];
    for (int i = 0; i < 5; i++) {
      final bx = size.width * 0.04 + size.width * barOffsets[i];
      final by = size.height * 0.72 + i * (size.height * 0.04);
      final bw = size.width * barWidths[i];
      final bh = size.height * 0.022;
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(3));
      canvas.drawRRect(rr, ganttPaint);
      canvas.drawRRect(rr, ganttBorder);
    }

    // ── Arc / compass circle bottom-right ─────────────────────────────────
    final arcPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.13)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.88, size.height * 0.78),
        width: size.width * 0.32, height: size.width * 0.32,
      ),
      -math.pi, math.pi, false, arcPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.88, size.height * 0.78),
        width: size.width * 0.18, height: size.width * 0.18,
      ),
      -math.pi, math.pi, false, arcPaint,
    );
    // crosshair
    canvas.drawLine(
      Offset(size.width * 0.88 - size.width * 0.18, size.height * 0.78),
      Offset(size.width * 0.88 + size.width * 0.18, size.height * 0.78),
      arcPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.88, size.height * 0.78 - size.width * 0.18),
      Offset(size.width * 0.88, size.height * 0.78 + size.width * 0.18),
      arcPaint,
    );

    // ── Dimension lines ───────────────────────────────────────────────────
    final dimPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.18)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    // Vertical dim line left
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.35),
      Offset(size.width * 0.05, size.height * 0.65),
      dimPaint,
    );
    canvas.drawLine(Offset(size.width * 0.03, size.height * 0.35),
        Offset(size.width * 0.07, size.height * 0.35), dimPaint);
    canvas.drawLine(Offset(size.width * 0.03, size.height * 0.65),
        Offset(size.width * 0.07, size.height * 0.65), dimPaint);

    // Horizontal dim line top
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.04),
      Offset(size.width * 0.5, size.height * 0.04),
      dimPaint,
    );
    canvas.drawLine(Offset(size.width * 0.15, size.height * 0.02),
        Offset(size.width * 0.15, size.height * 0.06), dimPaint);
    canvas.drawLine(Offset(size.width * 0.5, size.height * 0.02),
        Offset(size.width * 0.5, size.height * 0.06), dimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
