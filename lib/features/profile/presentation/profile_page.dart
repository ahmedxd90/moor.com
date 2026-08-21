import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/data/auth_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = const AuthRepository();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      _profile = const {
        'name': 'زائر Saki',
        'saki_id': 'S-Demo2026',
        'bio': 'مرحبًا بكم في Saki Chat',
        'gold_coins': 12500,
        'diamonds': 620,
        'followers_count': 128,
        'following_count': 84,
        'wealth_level': 12,
        'charisma_level': 9,
      };
    } else {
      try {
        _profile = await _auth.getMyProfile();
      } catch (_) {
        _profile = null;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signOut() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final nestedProfile = _auth.profileData(_profile);
    final profile = nestedProfile.isNotEmpty ? nestedProfile : (_profile ?? {});
    final name =
        (profile['fullName'] as String?) ??
        (profile['nickname'] as String?) ??
        'مستخدم Saki';
    final sakiId =
        _profile?['saki_id']?.toString() ??
        profile['saki_id']?.toString() ??
        profile['userName']?.toString() ??
        '—';
    final avatarUrl =
        profile['avatarUrl'] as String? ?? profile['avatar_url'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'حسابي',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: () => _show('الإعدادات التفصيلية ستُضاف تدريجيًا.'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B1D68), Color(0xFF1E2145)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: .35),
                ),
              ),
              child: Column(
                children: [
                  SakiAvatar(name: name, url: avatarUrl, size: 82),
                  const SizedBox(height: 11),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'معرف Saki: $sakiId',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((profile['about'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      profile['about'] as String,
                      style: const TextStyle(color: AppColors.mutedText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(
                        value: '${profile['followersCount'] ?? 0}',
                        label: 'المتابعون',
                      ),
                      _Stat(
                        value: '${profile['followingCount'] ?? 0}',
                        label: 'أتابعهم',
                      ),
                      _Stat(
                        value: '${profile['wealth_level'] ?? 1}',
                        label: 'مستوى الثروة',
                      ),
                      _Stat(
                        value: '${profile['charisma_level'] ?? 1}',
                        label: 'الكاريزما',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BalanceCard(
                    icon: Icons.monetization_on,
                    label: 'العملات الذهبية',
                    value: '${profile['gold_coins'] ?? 0}',
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BalanceCard(
                    icon: Icons.diamond,
                    label: 'الماس',
                    value: '${profile['diamonds'] ?? 0}',
                    color: AppColors.accentBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SakiSectionTitle(title: 'الخدمات'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'المحفظة والشحن',
                    color: AppColors.secondary,
                    onTap: () =>
                        _show('المحفظة ستتصل بعمليات Supabase الآمنة.'),
                  ),
                  _MenuTile(
                    icon: Icons.shopping_bag_outlined,
                    title: 'المتجر والحقيبة',
                    color: AppColors.primary,
                    onTap: () =>
                        _show('المتجر سيستخدم store_items وuser_store_items.'),
                  ),
                  _MenuTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'VIP و PRO',
                    color: AppColors.accentPink,
                    onTap: () =>
                        _show('عضويات VIP وPRO ستكون في المرحلة اللاحقة.'),
                  ),
                  _MenuTile(
                    icon: Icons.people_alt_outlined,
                    title: 'الأصدقاء والعائلة',
                    color: AppColors.accentBlue,
                    onTap: () => _show('سيتم ربط العلاقات الاجتماعية لاحقًا.'),
                  ),
                  _MenuTile(
                    icon: Icons.logout,
                    title: 'تسجيل الخروج',
                    color: AppColors.danger,
                    onTap: _signOut,
                    last: true,
                  ),
                ],
              ),
            ),
            if (widget.demoMode) ...[
              const SizedBox(height: 16),
              const Text(
                'وضع المعاينة مفعّل — البيانات المعروضة تجريبية.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
      ),
    ],
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool last;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_left, color: AppColors.mutedText),
      ),
      if (!last) const Divider(height: 1, indent: 70, color: AppColors.border),
    ],
  );
}
