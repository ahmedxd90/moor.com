import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/countries.dart';
import '../data/rooms_repository.dart';
import '../models/room.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final _auth = const AuthRepository();
  final _rooms = const RoomsRepository();
  String _countryCode = 'SA';
  Uint8List? _coverBytes;
  bool _loadingCountry = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadUserCountry();
  }

  Future<void> _loadUserCountry() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      if (mounted) setState(() => _loadingCountry = false);
      return;
    }
    try {
      final profile = await _auth.getMyProfile();
      final data = _auth.profileData(profile);
      final code = data['countryCode'];
      if (code is String &&
          worldCountries.any((country) => country.code == code)) {
        _countryCode = code;
      }
    } catch (_) {
      // Keep the safe default country when the profile cannot be read.
    }
    if (mounted) setState(() => _loadingCountry = false);
  }

  CountryOption get _country => worldCountries.firstWhere(
    (country) => country.code == _countryCode,
    orElse: () => const CountryOption('SA', 'السعودية'),
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 900,
      imageQuality: 86,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _coverBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.demoMode) {
      _show('وضع المعاينة: يلزم تسجيل الدخول لإنشاء غرفة حقيقية.');
      return;
    }
    setState(() => _busy = true);
    try {
      String? coverUrl;
      if (_coverBytes != null) {
        coverUrl = await _rooms.uploadRoomCover(
          _coverBytes!,
          fileName: 'cover-${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }
      final room = await _rooms.createRoom(
        name: _name.text.trim(),
        countryCode: _countryCode,
        coverUrl: coverUrl,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
      if (mounted) Navigator.of(context).pop<Room>(room);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'إنشاء غرفة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            children: [
              _buildCoverPicker(),
              const SizedBox(height: 24),
              _label('اسم الغرفة'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                textDirection: TextDirection.rtl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'أدخل اسم الغرفة',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'أدخل اسمًا من حرفين على الأقل';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _label('وصف الغرفة (اختياري)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اكتب وصفًا مختصرًا للغرفة',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              _label('دولة الغرفة'),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.public_rounded),
                  suffixIcon: Icon(Icons.lock_outline_rounded),
                ),
                child: Row(
                  children: [
                    Text(
                      _countryFlag(_country.code),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _loadingCountry
                            ? 'جارٍ تحميل دولة المستخدم...'
                            : _country.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Text(
                      'تلقائيًا',
                      style: TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتم استخدام دولة صاحب الغرفة تلقائيًا.',
                style: TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
              const SizedBox(height: 28),
              SakiGradientButton(
                label: 'إنشاء الغرفة',
                icon: Icons.add_home_work_outlined,
                onPressed: _save,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    return Center(
      child: GestureDetector(
        onTap: _busy ? null : _pickCover,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 170,
              height: 130,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.secondary, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: _coverBytes == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 38,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 7),
                        Text(
                          'صورة الغرفة',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Image.memory(_coverBytes!, fit: BoxFit.cover),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.text,
      fontWeight: FontWeight.w900,
      fontSize: 13,
    ),
  );

  void _show(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.danger : AppColors.text,
      ),
    );
  }
}

String _countryFlag(String code) => switch (code) {
  'SA' => '🇸🇦',
  'AE' => '🇦🇪',
  'KW' => '🇰🇼',
  'QA' => '🇶🇦',
  'JO' => '🇯🇴',
  'EG' => '🇪🇬',
  'PK' => '🇵🇰',
  'BD' => '🇧🇩',
  'SY' => '🇸🇾',
  _ => '🌐',
};
