import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'core/services/local_storage_service.dart';
import 'features/auth/presentation/controllers/auth_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/office/presentation/controllers/office_providers.dart';
import 'features/office/presentation/screens/enter_office_code_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/developer/presentation/screens/developer_panel_screen.dart';
import 'features/developer/presentation/controllers/developer_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MangProjectsApp(),
    ),
  );
}

class MangProjectsApp extends StatelessWidget {
  const MangProjectsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mang Projects',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A6B3C),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child!,
          ),
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const LoginScreen(),
      data: (user) {
        if (user == null) {
          // ── Not logged in — check office setup ───────────────────────
          final prefs   = ref.watch(sharedPreferencesProvider);
          final storage = LocalStorageService(prefs);
          if (!storage.isOfficeSetupComplete) {
            return const EnterOfficeCodeScreen();
          }
          return const LoginScreen();
        }

        // ── Logged in — check developer FIRST before anything else ─────
        return ref.watch(isDeveloperProvider(user.uid)).when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const LoginScreen(),
          data: (isDev) {
            if (isDev) {
              // Developer → panel directly, skip office setup completely
              return const DeveloperPanelScreen();
            }

            // Regular user — check office setup
            final prefs   = ref.watch(sharedPreferencesProvider);
            final storage = LocalStorageService(prefs);
            if (!storage.isOfficeSetupComplete) {
              return const EnterOfficeCodeScreen();
            }
            _syncOfficeId(ref, user.uid);
            return const HomeScreen();
          },
        );
      },
    );
  }

  void _syncOfficeId(WidgetRef ref, String userId) {
    final office = ref.read(selectedOfficeProvider);
    if (office == null) return;
    ref
        .read(officeRepositoryProvider)
        .assignOfficeToUser(userId: userId, officeId: office.id)
        .catchError((_) {});
  }
}
