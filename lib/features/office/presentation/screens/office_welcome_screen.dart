import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../data/models/office_model.dart';
import '../controllers/office_providers.dart';

class OfficeWelcomeScreen extends ConsumerWidget {
  final OfficeModel office;
  const OfficeWelcomeScreen({super.key, required this.office});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Office logo or initials ──────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: office.logo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.network(
                          office.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _OfficeLetter(name: office.name, cs: cs),
                        ),
                      )
                    : _OfficeLetter(name: office.name, cs: cs),
              ),

              const SizedBox(height: 32),

              // ── Welcome text ─────────────────────────────────────────
              Text(
                'Welcome to',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                office.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  office.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'You are now connected to your office.\nSign in to continue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.75),
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 2),

              // ── Get Started button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => _getStarted(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cs.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getStarted(BuildContext context, WidgetRef ref) async {
    // Mark office setup as complete — won't show again
    await ref.read(selectedOfficeProvider.notifier).completeSetup();

    if (context.mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }
}

class _OfficeLetter extends StatelessWidget {
  final String name;
  final ColorScheme cs;
  const _OfficeLetter({required this.name, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }
}
