import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/auth_repository.dart';
import '../data/countries.dart';
import 'country_picker_page.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({
    super.key,
    required this.onCompleted,
    this.existingProfile,
  });

  final VoidCallback onCompleted;
  final Map<String, dynamic>? existingProfile;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _auth = const AuthRepository();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userName;
  String _gender = 'male';
  String _countryCode = 'SA';
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final data = _auth.profileData(widget.existingProfile);
    _userName = TextEditingController(
      text: data['userName'] as String? ?? data['nickname'] as String? ?? '',
    );
    _gender = _normalizeGender(data['gender'] as String?);
    _countryCode = data['countryCode'] as String? ?? _countryCode;
    _avatarUrl = data['avatarUrl'] as String? ?? data['avatar_url'] as String?;
  }

  String _normalizeGender(String? value) => switch (value) {
    'singleOtherWomen' || 'marriedStraightWomen' || 'female' => 'female',
    _ => 'male',
  };

  CountryOption get _selectedCountry => worldCountries.firstWhere(
    (country) => country.code == _countryCode,
    orElse: () => const CountryOption('SA', 'السعودية'),
  );

  @override
  void dispose() {
    _userName.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 86,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _chooseCountry() async {
    final selected = await Navigator.of(context).push<CountryOption>(
      MaterialPageRoute(
        builder: (_) => CountryPickerPage(initialCode: _countryCode),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _countryCode = selected.code);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      var avatarUrl = _avatarUrl;
      if (_avatarBytes != null) {
        avatarUrl = await _auth.uploadAvatar(
          _avatarBytes!,
          fileName: 'avatar-${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
      await _auth.saveMyProfile(
        fullName: _userName.text,
        nickname: _userName.text,
        userName: _userName.text,
        gender: _gender,
        countryCode: _countryCode,
        about: '',
        interests: const [],
        avatarUrl: avatarUrl,
      );
      if (mounted) widget.onCompleted();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('AuthException: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'أكمل معلوماتك',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(38, 18, 38, 28),
            children: [
              _buildAvatarPicker(),
              const SizedBox(height: 28),
              _buildLabel('اسم المستخدم'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _userName,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'أدخل اسم المستخدم',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.length < 3 || username.contains(' ')) {
                    return 'استخدم 3 أحرف على الأقل بدون مسافات';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              _buildLabel('الجنس'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _genderChoice('male', 'ذكر', Icons.male)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _genderChoice('female', 'أنثى', Icons.female),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildLabel('الدولة'),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _chooseCountry,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.public),
                    suffixIcon: Icon(Icons.chevron_left),
                  ),
                  child: Text(
                    _selectedCountry.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SakiGradientButton(
                label: 'حفظ ومتابعة',
                icon: Icons.arrow_back,
                onPressed: _save,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.w800,
      fontSize: 14,
    ),
  );

  Widget _genderChoice(String value, String label, IconData icon) {
    final selected = _gender == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.white : AppColors.primaryDark,
              size: 21,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    final child = _avatarBytes == null && _avatarUrl == null
        ? const Icon(Icons.person, size: 48, color: AppColors.secondary)
        : ClipOval(
            child: _avatarBytes != null
                ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                : Image.network(_avatarUrl!, fit: BoxFit.cover),
          );
    return Center(
      child: GestureDetector(
        onTap: _busy ? null : _pickAvatar,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 126,
              height: 126,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: child,
            ),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
