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
  late final TextEditingController _fullName;
  late final TextEditingController _nickname;
  late final TextEditingController _userName;
  late final TextEditingController _about;
  String _gender = 'male';
  String _countryCode = 'SA';
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _busy = false;
  final _interests = <String>{};
  final _availableInterests = const [
    'music',
    'technology',
    'games',
    'travel',
    'photography',
    'sports',
    'books',
    'art',
  ];

  @override
  void initState() {
    super.initState();
    final data = _auth.profileData(widget.existingProfile);
    _fullName = TextEditingController(text: data['fullName'] as String? ?? '');
    _nickname = TextEditingController(text: data['nickname'] as String? ?? '');
    _userName = TextEditingController(text: data['userName'] as String? ?? '');
    _about = TextEditingController(text: data['about'] as String? ?? '');
    _gender = _normalizeGender(data['gender'] as String?);
    _countryCode = data['countryCode'] as String? ?? _countryCode;
    _avatarUrl = data['avatarUrl'] as String?;
    final savedInterests = data['interests'];
    if (savedInterests is List) {
      _interests.addAll(savedInterests.whereType<String>());
    }
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
    _fullName.dispose();
    _nickname.dispose();
    _userName.dispose();
    _about.dispose();
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
      final sakiId = await _auth.saveMyProfile(
        fullName: _fullName.text,
        nickname: _nickname.text,
        userName: _userName.text,
        gender: _gender,
        countryCode: _countryCode,
        about: _about.text,
        interests: _interests.toList(),
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ ملفك. Saki ID الخاص بك: $sakiId'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onCompleted();
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _buildAvatarCard(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B1D68), Color(0xFF1E2145)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.secondary,
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'خطوة واحدة وتصبح جاهزًا لاكتشاف غرف Saki Chat والتواصل مع المجتمع.',
                        style: TextStyle(
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'المعلومات الأساسية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'أدخل اسمك الكامل'
                    : null,
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _nickname,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'الاسم الظاهر',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'أدخل اسمًا ظاهرًا'
                    : null,
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _userName,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  hintText: 'saki_user',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  return v.length < 3 || v.contains(' ')
                      ? 'استخدم 3 أحرف على الأقل بدون مسافات'
                      : null;
                },
              ),
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'الجنس',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('ذكر')),
                  DropdownMenuItem(value: 'female', child: Text('أنثى')),
                ],
                onChanged: (value) =>
                    setState(() => _gender = value ?? _gender),
              ),
              const SizedBox(height: 13),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _chooseCountry,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'الدولة',
                    prefixIcon: Icon(Icons.public),
                    suffixIcon: Icon(Icons.chevron_left),
                  ),
                  child: Text(
                    _selectedCountry.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _about,
                maxLines: 3,
                maxLength: 180,
                decoration: const InputDecoration(
                  labelText: 'نبذة عنك (اختياري)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'اهتماماتك',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableInterests
                    .map(
                      (interest) => FilterChip(
                        label: Text(_interestLabel(interest)),
                        selected: _interests.contains(interest),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _interests.add(interest)
                              : _interests.remove(interest),
                        ),
                        selectedColor: AppColors.primary,
                        checkmarkColor: AppColors.white,
                        labelStyle: TextStyle(
                          color: _interests.contains(interest)
                              ? AppColors.white
                              : AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'سيتم إنشاء Saki ID فريد من 9 أرقام وحفظه تلقائيًا عند الحفظ.',
                style: TextStyle(
                  color: AppColors.mutedText.withValues(alpha: .9),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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

  Widget _buildAvatarCard() {
    final image = _avatarBytes == null && _avatarUrl == null
        ? const Icon(Icons.person, size: 42, color: AppColors.mutedText)
        : ClipOval(
            child: _avatarBytes != null
                ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                : Image.network(_avatarUrl!, fit: BoxFit.cover),
          );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .14),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: .55),
                width: 2,
              ),
            ),
            child: image,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'صورة المستخدم',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 5),
                const Text(
                  'أضف صورة تظهر لأصدقائك داخل Saki Chat.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickAvatar,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('اختيار صورة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _interestLabel(String value) => switch (value) {
    'music' => 'موسيقى',
    'technology' => 'تقنية',
    'games' => 'ألعاب',
    'travel' => 'سفر',
    'photography' => 'تصوير',
    'sports' => 'رياضة',
    'books' => 'كتب',
    'art' => 'فن',
    _ => value,
  };
}
