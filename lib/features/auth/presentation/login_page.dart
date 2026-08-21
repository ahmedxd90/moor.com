import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.demoMode = false, this.onDemoEnter});

  final bool demoMode;
  final VoidCallback? onDemoEnter;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = const AuthRepository();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        await _auth.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
        if (mounted) {
          _show(
            'تم إنشاء الحساب. تحقق من بريدك الإلكتروني إذا طلب التطبيق ذلك.',
          );
        }
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
    } catch (error) {
      if (mounted) {
        _show(
          error.toString().replaceFirst('AuthException: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/saki-login-background.png',
              fit: BoxFit.cover,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xD90F0A24),
                    Color(0xB30F0A24),
                    Color(0xE60F0A24),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .35),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/saki-icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Saki Chat',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _register
                              ? 'أنشئ حسابك وابدأ التواصل'
                              : 'غرف صوتية، أصدقاء، ولحظات لا تنسى',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            height: 1.5,
                          ),
                        ),
                        if (widget.demoMode) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.secondary.withValues(
                                  alpha: .35,
                                ),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.secondary,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'المشروع يعمل الآن بوضع المعاينة. أضف بيانات Supabase لتفعيل الحسابات والبيانات الحقيقية.',
                                    style: TextStyle(
                                      color: AppColors.secondary,
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'الاسم',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().length < 2
                                ? 'أدخل اسمًا صحيحًا'
                                : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'كلمة المرور ستة أحرف على الأقل'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        SakiGradientButton(
                          label: _register ? 'إنشاء الحساب' : 'تسجيل الدخول',
                          icon: _register
                              ? Icons.person_add_alt_1
                              : Icons.login,
                          onPressed: _submit,
                          busy: _busy,
                        ),
                        if (widget.demoMode) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: widget.onDemoEnter,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('الدخول للمعاينة بدون حساب'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              foregroundColor: AppColors.secondary,
                              side: const BorderSide(
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () =>
                              setState(() => _register = !_register),
                          child: Text(
                            _register
                                ? 'لديك حساب؟ تسجيل الدخول'
                                : 'ليس لديك حساب؟ إنشاء حساب',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (AppConfig.isConfigured) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await _auth.signInWithGoogle();
                              } catch (error) {
                                if (mounted) {
                                  _show(error.toString(), error: true);
                                }
                              }
                            },
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('المتابعة باستخدام Google'),
                          ),
                        ],
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
