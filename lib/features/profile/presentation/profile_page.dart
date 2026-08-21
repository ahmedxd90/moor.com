import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/countries.dart';
import '../../auth/presentation/complete_profile_page.dart';
import '../../wallet/data/wallet_repository.dart';
import 'account_pages.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = const AuthRepository();
  final _walletRepository = const WalletRepository();
  Map<String, dynamic>? _profile;
  WalletSnapshot _wallet = WalletSnapshot.empty;
  Map<String, int> _stats = const {};
  bool _loading = true;
  int _profileTab = 0;
  final _profileTabController = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _profileTabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      _stats = const {'visitors': 10, 'following': 49, 'followers': 24};
      _profile = const {
        'saki_id': '3668252',
        'data': {
          'fullName': 'كلك نظر',
          'userName': 'kulk_nazar',
          'avatarUrl':
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=240&q=85',
          'followersCount': 1,
          'followingCount': 1,
          'visitsCount': 11,
          'diamonds': 2,
          'wealth_level': 12,
          'charisma_level': 9,
          'countryCode': 'SA',
          'about': 'أشارككم أجمل لحظاتي وغرفي الصوتية على Saki',
          'interests': ['موسيقى', 'تعارف', 'أصدقاء'],
          'isVerified': true,
          'isPremium': true,
        },
      };
    } else {
      try {
        _profile = await _auth.getMyProfile();
        _wallet = await _walletRepository.fetchWallet();
        try {
          _stats = await _auth.getMyProfileStats();
        } catch (_) {
          _stats = const {};
        }
      } catch (_) {
        _profile = null;
        _wallet = WalletSnapshot.empty;
        _stats = const {};
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> get _data => _auth.profileData(_profile);

  String get _name => _firstString(_data, [
    'fullName',
    'nickname',
    'userName',
    'name',
  ], fallback: 'مستخدم Saki');

  String? get _avatarUrl {
    final value = _firstString(_data, ['avatarUrl', 'avatar_url']);
    return value.isEmpty ? null : value;
  }

  int get _followingCount => _stats['following'] ?? _countValue(
    _data,
    ['followingCount', 'following_count'],
    listKeys: ['following', 'followingUsers'],
  );

  int get _followersCount => _stats['followers'] ?? _countValue(
    _data,
    ['followersCount', 'followers_count'],
    listKeys: ['followers', 'followerUsers'],
  );

  int get _visitorsCount => _stats['visitors'] ?? _countValue(_data, [
    'visitsCount',
    'visitorsCount',
    'visitors_count',
    'profileViews',
  ]);

  int get _gemCount => _numberValue(_data, [
    'gemCount',
    'gems',
    'diamonds',
    'vipLevel',
  ], fallback: 0);

  int get _wealthLevel =>
      _numberValue(_data, ['wealth_level', 'wealthLevel'], fallback: 1);

  String get _sakiId => (_profile?['saki_id'] ?? '—').toString();

  String get _countryCode => _firstString(
    _data,
    ['countryCode', 'country_code', 'country'],
    fallback: '',
  ).toUpperCase();

  CountryOption? get _country => worldCountries
      .where((item) => item.code == _countryCode)
      .firstOrNull;

  String get _about => _firstString(
    _data,
    ['about', 'bio', 'description'],
    fallback: 'أهلاً بكم في ملفي على Saki',
  );

  List<String> get _interests => (_data['interests'] is List)
      ? (_data['interests'] as List).whereType<String>().toList(growable: false)
      : const [];

  bool get _isVerified => _data['isVerified'] == true;

  bool get _isPremium => _data['isPremium'] == true;

  String _flagEmoji(String code) {
    if (code.length != 2) return '🌐';
    return String.fromCharCodes(
      code.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _ProfileHeaderDelegate(child: _buildHeader()),
              ),
              SliverToBoxAdapter(child: _buildProfileBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Material(
      color: Colors.transparent,
      elevation: 1,
      shadowColor: const Color(0x22000000),
      child: Container(
        height: 58,
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'رجوع',
              onPressed: () {
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              },
              color: Colors.white,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _editProfile,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              icon: const Icon(Icons.edit, size: 13),
              label: const Text(
                'تعديل الملف الشخصي',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBody() {
    return Column(
      children: [
        Container(
          height: 136,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFFFDE68A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                _buildIdentity(),
                const SizedBox(height: 18),
                _buildProfileTabs(),
                const SizedBox(height: 10),
                SizedBox(
                  height: 510,
                  child: PageView(
                    controller: _profileTabController,
                    onPageChanged: (value) => setState(() => _profileTab = value),
                    children: [
                      _buildOverviewTab(),
                      _buildAboutTab(),
                    ],
                  ),
                ),
                if (widget.demoMode || !AppConfig.isConfigured) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'وضع المعاينة مفعّل — البيانات المعروضة تجريبية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTabs() {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          _ProfileTab(
            title: 'الرئيسية',
            selected: _profileTab == 0,
            onTap: () => _selectProfileTab(0),
          ),
          _ProfileTab(
            title: 'معلوماتي',
            selected: _profileTab == 1,
            onTap: () => _selectProfileTab(1),
          ),
        ],
      ),
    );
  }

  void _selectProfileTab(int index) {
    setState(() => _profileTab = index);
    _profileTabController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _buildStats(),
        const SizedBox(height: 10),
        _buildWealthChip(),
        const SizedBox(height: 14),
        _buildActionGrid(),
        const SizedBox(height: 14),
        _buildMenu(),
      ],
    );
  }

  Widget _buildAboutTab() {
    final country = _country;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _profileCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: AppColors.primary),
                  const SizedBox(width: 9),
                  const Text(
                    'معلومات الحساب',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  if (_isVerified)
                    const Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 19),
                ],
              ),
              const SizedBox(height: 14),
              _InfoLine(icon: Icons.alternate_email_rounded, label: 'اسم المستخدم', value: '@${_firstString(_data, ['userName', 'username'], fallback: 'saki_user')}'),
              _InfoLine(icon: Icons.fingerprint_rounded, label: 'ID المستخدم', value: _sakiId),
              _InfoLine(icon: Icons.public_rounded, label: 'الدولة', value: '${_flagEmoji(_countryCode)}  ${country?.name ?? (_countryCode.isEmpty ? 'غير محددة' : _countryCode)}'),
              _InfoLine(icon: Icons.workspace_premium_rounded, label: 'المستوى', value: 'المستوى $_wealthLevel'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _profileCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نبذة عني', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(_about, style: const TextStyle(color: AppColors.mutedText, height: 1.5)),
              if (_interests.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('اهتماماتي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _interests.map((interest) => Chip(
                    label: Text(interest, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    backgroundColor: const Color(0xFFFFF7ED),
                    side: const BorderSide(color: Color(0xFFFED7AA)),
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildActionGrid(),
      ],
    );
  }

  BoxDecoration get _profileCardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: const Color(0xFFF3F4F6)),
    boxShadow: const [
      BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3)),
    ],
  );

  Widget _buildIdentity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileAvatar(url: _avatarUrl, name: _name),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (_isPremium) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1D6),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: const Color(0xFFF6C453)),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_flagEmoji(_countryCode)}  ${_country?.name ?? 'الدولة غير محددة'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'ID: $_sakiId',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diamond_outlined,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.demoMode || !AppConfig.isConfigured ? _gemCount : _wallet.diamonds}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(value: '$_followingCount', label: 'متابعة'),
          ),
          const _StatDivider(),
          Expanded(
            child: _Stat(value: '$_followersCount', label: 'المعجبين'),
          ),
          const _StatDivider(),
          Expanded(
            child: _Stat(value: '$_visitorsCount', label: 'زائر'),
          ),
        ],
      ),
    );
  }

  Widget _buildWealthChip() {
    final level = widget.demoMode || !AppConfig.isConfigured
        ? _wealthLevel
        : _wallet.wealthLevel;
    final spent = widget.demoMode || !AppConfig.isConfigured
        ? 30000
        : _wallet.lifetimeSpentGold;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openLevel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'مستوى الثروة $level  •  أرسلت $spent عملة',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: .86,
        children: [
          _ActionButton(
            label: 'الشحن',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFF59E0B),
            background: const Color(0xFFFEF3C7),
            onTap: _openWallet,
          ),
          _ActionButton(
            label: 'VIP',
            icon: Icons.diamond_rounded,
            color: const Color(0xFFF59E0B),
            background: const Color(0xFFFFF7D6),
            onTap: _openVip,
          ),
          _ActionButton(
            label: 'المتجر',
            icon: Icons.storefront_rounded,
            color: const Color(0xFFEC4899),
            background: const Color(0xFFFCE7F3),
            onTap: _openStore,
          ),
          _ActionButton(
            label: 'المهمات',
            icon: Icons.event_available_rounded,
            color: const Color(0xFFEAB308),
            background: const Color(0xFFFEF9C3),
            showBadge: true,
            onTap: _openTasks,
          ),
          _ActionButton(
            label: 'المستوى',
            icon: Icons.leaderboard_rounded,
            color: const Color(0xFF3B82F6),
            background: const Color(0xFFDBEAFE),
            onTap: _openLevel,
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.workspace_premium_rounded,
            title: 'VIP',
            color: const Color(0xFFF59E0B),
            onTap: _openVip,
          ),
          const Divider(height: 1, indent: 58, color: Color(0xFFF3F4F6)),
          _MenuRow(
            icon: Icons.settings_rounded,
            title: 'الإعدادات',
            color: const Color(0xFF6B7280),
            onTap: _openSettings,
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CompleteProfilePage(
          existingProfile: _profile,
          onCompleted: () {
            Navigator.of(context).pop();
            _load();
          },
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (widget.demoMode || !AppConfig.isConfigured) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    await _auth.signOut();
  }

  void _openWallet() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => WalletPage(demoMode: widget.demoMode)),
    );
  }

  void _openStore() {
    _showDetails(
      title: 'المتجر',
      icon: Icons.storefront_rounded,
      color: const Color(0xFFEC4899),
      message: 'تصفح العناصر والهدايا والملابس الخاصة بملفك قريبًا.',
    );
  }

  void _openLevel() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WealthLevelPage(demoMode: widget.demoMode),
      ),
    );
  }

  void _openTasks() {
    _showDetails(
      title: 'المهمات',
      icon: Icons.event_available_rounded,
      color: const Color(0xFF06B6D4),
      message: 'لديك مهمات يومية جديدة. سيتم ربط التقدم والجوائز قريبًا.',
    );
  }

  void _openVip() {
    _showDetails(
      title: 'VIP',
      icon: Icons.workspace_premium_rounded,
      color: const Color(0xFFF59E0B),
      message: 'استكشف مزايا VIP وPRO عند تفعيل العضويات في المرحلة القادمة.',
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AccountSettingsPage(profile: _profile, demoMode: widget.demoMode),
      ),
    );
  }

  Future<void> _showDetails({
    required String title,
    required IconData icon,
    required Color color,
    String? message,
    List<Widget> children = const [],
    bool showSignOut = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .14),
                    foregroundColor: color,
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    height: 1.5,
                  ),
                ),
              ],
              if (children.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...children,
              ],
              if (showSignOut) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _signOut();
                  },
                  icon: const Icon(Icons.logout, color: AppColors.danger),
                  label: const Text('تسجيل الخروج'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _firstString(
    Map<String, dynamic> values,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = values[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  int _numberValue(
    Map<String, dynamic> values,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = values[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  int _countValue(
    Map<String, dynamic> values,
    List<String> keys, {
    List<String> listKeys = const [],
  }) {
    final value = _numberValue(values, keys, fallback: -1);
    if (value >= 0) return value;
    for (final key in listKeys) {
      final list = values[key];
      if (list is List) return list.length;
    }
    return 0;
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF1E6) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? AppColors.primaryDark : AppColors.mutedText,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 58;

  @override
  double get maxExtent => 58;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _ProfileHeaderDelegate oldDelegate) => true;
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: url == null
            ? Container(
                color: AppColors.surfaceElevated,
                alignment: Alignment.center,
                child: Text(
                  name.characters.first,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceElevated,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 30,
      child: VerticalDivider(width: 1, color: Color(0xFFF3F4F6)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 88,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 23),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (showBadge)
                Positioned(
                  top: 4,
                  left: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFFD1D5DB),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
