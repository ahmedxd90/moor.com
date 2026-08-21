import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/auth_repository.dart';

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _nickname;
  late final TextEditingController _userName;
  late final TextEditingController _about;
  String _gender = 'singleOtherMen';
  String _countryCode = 'SA';
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
    _gender = data['gender'] as String? ?? _gender;
    _countryCode = data['countryCode'] as String? ?? _countryCode;
    final savedInterests = data['interests'];
    if (savedInterests is List) {
      _interests.addAll(savedInterests.whereType<String>());
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _nickname.dispose();
    _userName.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _auth.saveMyProfile(
        fullName: _fullName.text,
        nickname: _nickname.text,
        userName: _userName.text,
        gender: _gender,
        countryCode: _countryCode,
        about: _about.text,
        interests: _interests.toList(),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
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
                decoration: const InputDecoration(
                  labelText: 'الاسم المستعار',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'أدخل اسمًا مستعارًا'
                    : null,
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: _userName,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
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
                  labelText: 'النوع والتفضيل',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'singleOtherMen', child: Text('رجل')),
                  DropdownMenuItem(
                    value: 'singleOtherWomen',
                    child: Text('امرأة'),
                  ),
                  DropdownMenuItem(
                    value: 'marriedStraightMen',
                    child: Text('رجل متزوج'),
                  ),
                  DropdownMenuItem(
                    value: 'marriedStraightWomen',
                    child: Text('امرأة متزوجة'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _gender = value ?? _gender),
              ),
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                initialValue: _countryCode,
                decoration: const InputDecoration(
                  labelText: 'الدولة',
                  prefixIcon: Icon(Icons.public),
                ),
                items: const [
                  DropdownMenuItem(value: 'SA', child: Text('السعودية')),
                  DropdownMenuItem(value: 'AE', child: Text('الإمارات')),
                  DropdownMenuItem(value: 'KW', child: Text('الكويت')),
                  DropdownMenuItem(value: 'QA', child: Text('قطر')),
                  DropdownMenuItem(value: 'EG', child: Text('مصر')),
                  DropdownMenuItem(value: 'JO', child: Text('الأردن')),
                ],
                onChanged: (value) =>
                    setState(() => _countryCode = value ?? _countryCode),
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
              const SizedBox(height: 26),
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
