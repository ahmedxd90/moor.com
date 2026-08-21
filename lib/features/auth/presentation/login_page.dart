import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
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
  late final VideoPlayerController _videoController;
  late final Future<void> _videoInitialization;
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'assets/videos/saki-login-background.mp4',
    );
    _videoInitialization = _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.setVolume(0);
      await _videoController.play();
    } catch (_) {
      // يبقى التدرج الداكن ظاهرًا إذا تعذر تشغيل الفيديو على جهاز قديم.
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController.dispose();
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
        final response = await _auth.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
        if (mounted) {
          _show(
            response.session == null
                ? 'تم إنشاء الحساب. تحقق من بريدك الإلكتروني ثم سجّل الدخول.'
                : 'تم إنشاء الحساب، أكمل معلوماتك للمتابعة.',
          );
        }
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
    } catch (error) {
      if (mounted) {
        if (_isExistingUserError(error)) {
          _showExistingAccountMessage();
        } else {
          _show(_friendlyError(error), error: true);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    try {
      await _auth.signInWithGoogle();
    } catch (error) {
      if (mounted) _show(_friendlyError(error), error: true);
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

  bool _isExistingUserError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('user_already_exists') ||
        normalized.contains('user already registered');
  }

  void _showExistingAccountMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'هذا البريد الإلكتروني مسجل مسبقًا. استخدم تسجيل الدخول أو استعادة كلمة المرور.',
        ),
        backgroundColor: AppColors.danger,
        action: SnackBarAction(
          label: 'تسجيل الدخول',
          textColor: Colors.white,
          onPressed: () => setState(() => _register = false),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولًا ثم حاول تسجيل الدخول.';
    }
    if (normalized.contains('password should be at least')) {
      return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.';
    }
    if (normalized.contains('email rate limit')) {
      return 'تم تجاوز عدد المحاولات. حاول بعد قليل.';
    }
    return raw
        .replaceFirst('AuthException: ', '')
        .replaceFirst('AuthApiException: ', '');
  }

  Future<void> _showResetDialog() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة كلمة المرور'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('إرسال الرابط'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await _auth.sendPasswordReset(email: email);
      if (mounted) _show('تم إرسال رابط استعادة كلمة المرور إلى بريدك.');
    } catch (error) {
      if (mounted) _show(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16121F),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _buildVideoBackground()),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: .60)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minimumHeight = constraints.maxHeight - 48;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 440,
                      minHeight: minimumHeight > 620 ? minimumHeight : 620,
                    ),
                    child: Column(
                      children: [
                        _buildBrandHeader(),
                        const SizedBox(height: 34),
                        _buildLoginForm(),
                        const SizedBox(height: 22),
                        _buildSignupFooter(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground() {
    return FutureBuilder<void>(
      future: _videoInitialization,
      builder: (context, snapshot) {
        if (_videoController.value.isInitialized) {
          final videoSize = _videoController.value.size;
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: videoSize.width,
                height: videoSize.height,
                child: VideoPlayer(_videoController),
              ),
            ),
          );
        }
        return Container(color: const Color(0xFF16121F));
      },
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .20)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .30),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.mic_none_rounded,
            color: Colors.white,
            size: 52,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Saki',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: const Text(
            'غرف الدردشة الصوتية',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_register) ...[
            TextFormField(
              controller: _name,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hint: 'الاسم',
                icon: Icons.person_outline,
              ),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'أدخل اسمًا صحيحًا'
                  : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _email,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
            ),
            validator: (value) => value == null || !value.contains('@')
                ? 'أدخل بريدًا إلكترونيًا صحيحًا'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            style: const TextStyle(color: Colors.white),
            obscureText: _obscure,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              hint: 'كلمة المرور',
              icon: Icons.lock_outline,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                color: Colors.white70,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value == null || value.length < 6
                ? 'كلمة المرور ستة أحرف على الأقل'
                : null,
          ),
          if (!_register)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _busy ? null : _showResetDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'نسيت كلمة المرور؟',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: .55,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 10,
                shadowColor: AppColors.primary.withValues(alpha: .38),
              ),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _register ? 'إنشاء الحساب' : 'تسجيل الدخول',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          if (AppConfig.isConfigured) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: .22)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'أو',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: .22)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _googleSignIn,
                icon: const Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                label: const Text('تسجيل الدخول باستخدام جوجل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF374151),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 8,
                ),
              ),
            ),
          ],
          if (widget.demoMode) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onDemoEnter,
              child: const Text(
                'الدخول للمعاينة بدون حساب',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: .22)),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .10),
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: suffix,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildSignupFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'ليس لديك حساب؟ ',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _register = !_register),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _register ? 'العودة لتسجيل الدخول' : 'إنشاء حساب جديد',
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
