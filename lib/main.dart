import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'features/office/presentation/controllers/office_providers.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'features/office/presentation/screens/enter_office_code_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. Initialize Firebase (مهم جدًا)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ 2. Initialize Supabase
  await Supabase.initialize(
    url: 'https://efjbcwmbvuhqeouybbbp.supabase.co',
    anonKey: 'sb_publishable_RLRBugv6UKMD41b01_S81w_PiE8paQ1',
  );

  // ✅ 3. Run app with Riverpod
  runApp(const ProviderScope(child: MangProjectsApp()));
}

class MangProjectsApp extends StatelessWidget {
  const MangProjectsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mang Projects',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
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
        final user = FirebaseAuth.instance.currentUser;

        if (office == null) {
          return const EnterOfficeCodeScreen();
        }

        if (user == null) {
          return const LoginScreen();
        }

        return const HomeScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text(e.toString()))),
    );
  }
}
