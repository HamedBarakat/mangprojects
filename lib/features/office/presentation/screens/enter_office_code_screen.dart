import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/office_providers.dart';
import 'office_logo_screen.dart';

class EnterOfficeCodeScreen extends ConsumerStatefulWidget {
  const EnterOfficeCodeScreen({super.key});

  @override
  ConsumerState<EnterOfficeCodeScreen> createState() =>
      _EnterOfficeCodeScreenState();
}

class _EnterOfficeCodeScreenState extends ConsumerState<EnterOfficeCodeScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _floatCtrl;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _bgRotate;
  late Animation<double> _pulse;
  late Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _bgRotate = Tween<double>(begin: 0, end: 2 * math.pi).animate(_bgCtrl);
    _pulse = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _float = Tween<double>(
      begin: -12,
      end: 12,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _entryCtrl.dispose();
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final code = _codeController.text.trim().toUpperCase();
      final office = await ref.read(officeRepositoryProvider).findByCode(code);
      if (office == null) {
        setState(
          () => _errorMessage = 'Invalid code. Please check and try again.',
        );
        return;
      }
      await ref.read(selectedOfficeProvider.notifier).setOffice(office);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => OfficeLogoScreen(office: office),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('OFFICE LOGIN ERROR: $e');
      debugPrintStack(stackTrace: st);
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0E00),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_bgCtrl, _pulseCtrl]),
              builder: (_, _) => CustomPaint(
                painter: _OrangeBgPainter(
                  rotation: _bgRotate.value,
                  pulse: _pulse.value,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, _) => Positioned(
              top: -100,
              left: size.width * 0.2,
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF6D00).withOpacity(0.28 * _pulse.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, _) => Positioned.fill(
              child: CustomPaint(
                painter: _FloatingParticlesPainter(offset: _float.value),
              ),
            ),
          ),
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
                        Center(
                          child: Column(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseCtrl,
                                builder: (_, child) => Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(26),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF8C00),
                                        Color(0xFFE65100),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF6D00,
                                        ).withOpacity(0.55 * _pulse.value),
                                        blurRadius: 32,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: child,
                                ),
                                child: const Icon(
                                  Icons.architecture_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFF8C00,
                                    ).withOpacity(0.5),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  color: const Color(
                                    0xFFFF6D00,
                                  ).withOpacity(0.1),
                                ),
                                child: const Text(
                                  'PROJECT MANAGEMENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 2.5,
                                    color: Color(0xFFFFB74D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFFCC02), Color(0xFFFF8C00)],
                            ).createShader(bounds),
                            child: Text(
                              'Enter Office Code',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Enter the code provided by your office\nadministrator to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ),
                        const SizedBox(height: 52),
                        Text(
                          'Office Code',
                          style: TextStyle(
                            color: const Color(0xFFFFB74D).withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          onChanged: (_) =>
                              setState(() => _errorMessage = null),
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
                              color: Colors.white.withOpacity(0.22),
                            ),
                            prefixIcon: Icon(
                              Icons.tag_rounded,
                              color: const Color(0xFFFF8C00).withOpacity(0.8),
                            ),
                            filled: true,
                            fillColor: const Color(
                              0xFFFF6D00,
                            ).withOpacity(0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: const Color(0xFFFF8C00).withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: const Color(0xFFFF8C00).withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF8C00),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.5,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                                width: 2,
                              ),
                            ),
                            errorStyle: const TextStyle(
                              color: Colors.redAccent,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Please enter your office code';
                            if (v.trim().length < 4)
                              return 'Code must be at least 4 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, child) => Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF6D00,
                                  ).withOpacity(0.4 * _pulse.value),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: child,
                          ),
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              disabledBackgroundColor: const Color(
                                0xFFE65100,
                              ).withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: size.height * 0.07),
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

// ════════════════════════════════════════════════════════════
// ORANGE BG PAINTER
// ════════════════════════════════════════════════════════════

class _OrangeBgPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  const _OrangeBgPainter({required this.rotation, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFFFF8C00).withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const step = 30.0;
    for (double x = 0; x <= size.width; x += step) {
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
      }
    }
    final linePaint = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.05)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (double i = -size.height; i <= size.width + size.height; i += 44) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        linePaint,
      );
    }
    final cx = size.width * 0.5;
    final cy = size.height * 0.14;
    _drawHex(
      canvas,
      Offset(cx, cy),
      88,
      rotation,
      const Color(0xFFFF8C00),
      0.18,
    );
    _drawHex(
      canvas,
      Offset(cx, cy),
      52,
      -rotation * 1.4,
      const Color(0xFFFFCC02),
      0.12,
    );
    _drawHex(
      canvas,
      Offset(cx, cy),
      30,
      rotation * 2.1,
      const Color(0xFFFF8C00),
      0.08,
    );

    final arcPaint = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.13 * pulse)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, size.height),
        width: size.width * 0.9,
        height: size.width * 0.9,
      ),
      -math.pi / 2,
      math.pi / 2,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, size.height),
        width: size.width * 0.54,
        height: size.width * 0.54,
      ),
      -math.pi / 2,
      math.pi / 2,
      false,
      arcPaint,
    );

    final bldPaint = Paint()
      ..color = const Color(0xFFFF8C00).withOpacity(0.1)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    final bldFill = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.04)
      ..style = PaintingStyle.fill;
    final bld = Rect.fromLTWH(
      size.width * 0.64,
      size.height * 0.04,
      size.width * 0.3,
      size.height * 0.22,
    );
    canvas.drawRect(bld, bldFill);
    canvas.drawRect(bld, bldPaint);
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final wx = bld.left + 8 + c * (bld.width / 3);
        final wy = bld.top + 8 + r * (bld.height / 3);
        canvas.drawRect(
          Rect.fromLTWH(wx, wy, bld.width / 3 - 12, bld.height / 3 - 12),
          bldFill,
        );
        canvas.drawRect(
          Rect.fromLTWH(wx, wy, bld.width / 3 - 12, bld.height / 3 - 12),
          bldPaint,
        );
      }
    }
    final dimPaint = Paint()
      ..color = const Color(0xFFFFB74D).withOpacity(0.14)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.38),
      Offset(size.width * 0.05, size.height * 0.62),
      dimPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.38),
      Offset(size.width * 0.08, size.height * 0.38),
      dimPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.62),
      Offset(size.width * 0.08, size.height * 0.62),
      dimPaint,
    );
  }

  void _drawHex(
    Canvas canvas,
    Offset c,
    double r,
    double angle,
    Color color,
    double opacity,
  ) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = angle + i * math.pi / 3;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OrangeBgPainter old) =>
      old.rotation != rotation || old.pulse != pulse;
}

// ════════════════════════════════════════════════════════════
// FLOATING PARTICLES PAINTER
// ════════════════════════════════════════════════════════════

class _FloatingParticlesPainter extends CustomPainter {
  final double offset;
  const _FloatingParticlesPainter({required this.offset});
  static const List<List<double>> _particles = [
    [0.15, 0.45],
    [0.82, 0.30],
    [0.08, 0.72],
    [0.72, 0.65],
    [0.35, 0.18],
    [0.90, 0.82],
    [0.48, 0.88],
    [0.25, 0.60],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final floatY = (i.isEven ? offset : -offset) * 0.6;
      final cx = size.width * p[0];
      final cy = size.height * p[1] + floatY;
      final r = 3.0 + (i % 3) * 2.0;
      paint.color = const Color(0xFFFF8C00).withOpacity(0.15 - i * 0.01);
      if (i % 3 == 0) {
        final path = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r * 0.866, cy + r * 0.5)
          ..lineTo(cx - r * 0.866, cy + r * 0.5)
          ..close();
        canvas.drawPath(path, paint);
      } else if (i % 3 == 1) {
        final path = Path()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r, cy)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FloatingParticlesPainter old) => old.offset != offset;
}
