import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
  runApp(const ProviderScope(child: SakiChatApp(demoMode: demoMode)));
}

class SakiChatApp extends StatelessWidget {
  const SakiChatApp({super.key, this.demoMode = false});
  final bool demoMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConfig.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    locale: const Locale('ar'),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: AuthGate(demoMode: demoMode),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.demoMode = false});
  final bool demoMode;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = const AuthRepository();
  StreamSubscription<AuthState>? _authSubscription;
  bool _demoEntered = false;
  bool _loading = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    if (!widget.demoMode && AppConfig.isConfigured) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
        authState,
      ) {
        if (!mounted) return;
        setState(() {
          _signedIn = authState.session != null;
          _loading = false;
        });
      });
    }
    _checkSession();
  }

  Future<void> _checkSession() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      _loading = false;
      return;
    }
    final token = await _auth.sessionToken;
    if (!mounted) return;
    setState(() {
      _signedIn = token?.isNotEmpty == true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.demoMode || _demoEntered) {
      return const HomeShell(demoMode: true);
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_signedIn) {
      return LoginPage(onDemoEnter: () => setState(() => _demoEntered = true));
    }
    return const ProfileGate();
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
    _profile = await _auth.getMyProfile();
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
