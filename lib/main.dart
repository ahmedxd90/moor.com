import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/complete_profile_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: SakiChatApp()));
}

class SakiChatApp extends StatelessWidget {
  const SakiChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = const AuthRepository();
  bool _demoEntered = false;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      if (_demoEntered) return const HomeShell(demoMode: true);
      return LoginPage(
        demoMode: true,
        onDemoEnter: () => setState(() => _demoEntered = true),
      );
    }

    return StreamBuilder(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        final session = SupabaseService.client.auth.currentSession;
        if (session == null) return const LoginPage();
        return const ProfileGate();
      },
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  final _auth = const AuthRepository();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _profile = await _auth.getMyProfile();
    } catch (_) {
      _profile = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_auth.isProfileComplete(_profile)) {
      return CompleteProfilePage(existingProfile: _profile, onCompleted: _load);
    }
    return const HomeShell();
  }
}
