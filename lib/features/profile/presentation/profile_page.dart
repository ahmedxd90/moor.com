import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
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
        },
      };
    } else {
      try {
        _profile = await _auth.getMyProfile();
        _wallet = await _walletRepository.fetchWallet();
      } catch (_) {
        _profile = null;
        _wallet = WalletSnapshot.empty;
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

  int get _followingCount => _countValue(
    _data,
    ['followingCount', 'following_count'],
    listKeys: ['following', 'followingUsers'],
  );

  int get _followersCount => _countValue(
    _data,
    ['followersCount', 'followers_count'],
    listKeys: ['followers', 'followerUsers'],
  );

  int get _visitorsCount => _countValue(_data, [
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
          height: 128,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFFFDE68A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                _buildIdentity(),
                const SizedBox(height: 20),
                _buildStats(),
                const SizedBox(height: 10),
                _buildWealthChip(),
                const SizedBox(height: 16),
                _buildActionGrid(),
                const SizedBox(height: 16),
                _buildMenu(),
                if (widget.demoMode || !AppConfig.isConfigured) ...[
                  const SizedBox(height: 16),
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
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const SizedBox(height: 8),
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
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'محفظتي',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFFF59E0B),
              background: const Color(0xFFFEF3C7),
              onTap: _openWallet,
            ),
          ),
          Expanded(
            child: _ActionButton(
              label: 'المتجر',
              icon: Icons.storefront_rounded,
              color: const Color(0xFFEC4899),
              background: const Color(0xFFFCE7F3),
              onTap: _openStore,
            ),
          ),
          Expanded(
            child: _ActionButton(
              label: 'المستوى',
              icon: Icons.layers_rounded,
              color: const Color(0xFFA855F7),
              background: const Color(0xFFF3E8FF),
              onTap: _openLevel,
            ),
          ),
          Expanded(
            child: _ActionButton(
              label: 'المهمات',
              icon: Icons.event_available_rounded,
              color: const Color(0xFF06B6D4),
              background: const Color(0xFFCFFAFE),
              showBadge: true,
              onTap: _openTasks,
            ),
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
