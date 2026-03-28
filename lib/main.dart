import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/office/presentation/controllers/office_providers.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'features/office/presentation/screens/enter_office_code_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ CRITICAL FIX: Disable Firestore offline persistence on Web.
  // Web persistence causes stale cached data after logout/login,
  // resulting in permission-denied errors for the new user's token.
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  await Supabase.initialize(
    url: 'https://efjbcwmbvuhqeouybbbp.supabase.co',
    anonKey: 'sb_publishable_RLRBugv6UKMD41b01_S81w_PiE8paQ1',
  );

  runApp(const ProviderScope(child: MangProjectsApp()));
}

class MangProjectsApp extends StatelessWidget {
  const MangProjectsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mang Projects',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(sharedPreferencesProvider);

    return prefsAsync.when(
      data: (prefs) {
        final office = ref.watch(selectedOfficeProvider);

        if (office == null) {
          return const EnterOfficeCodeScreen();
        }

        // ✅ FIX: Use StreamBuilder on authStateChanges instead of
        // FirebaseAuth.instance.currentUser (synchronous, stale after logout).
        // authStateChanges fires reliably when auth state changes,
        // ensuring Firestore queries use a fresh, valid token.
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Still waiting for auth state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppColors.slate900,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.cyan500),
                ),
              );
            }

            final user = snapshot.data;

            if (user == null) {
              return const LoginScreen();
            }

            // With persistence disabled, no stale cache issues.
            // authStateChanges already guarantees a valid auth state here.
            return const HomeScreen();
          },
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.slate900,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.cyan500),
        ),
      ),
      error: (e, s) => Scaffold(
        body: Center(child: Text(e.toString())),
      ),
    );
  }
}
