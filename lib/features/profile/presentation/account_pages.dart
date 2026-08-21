import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../wallet/data/wallet_repository.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _walletRepository = const WalletRepository();
  WalletSnapshot _wallet = WalletSnapshot.empty;
  List<WalletPackage> _packages = const [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      _wallet = const WalletSnapshot(
        goldCoins: 126500,
        diamonds: 88400,
        lifetimeSpentGold: 30000,
        wealthLevel: 2,
      );
      _packages = const [
        WalletPackage(id: 'gold_30000', goldCoins: 30000, priceUsd: 1),
        WalletPackage(id: 'gold_150000', goldCoins: 150000, priceUsd: 5),
        WalletPackage(id: 'gold_300000', goldCoins: 300000, priceUsd: 10),
      ];
    } else {
      try {
        final result = await Future.wait<dynamic>([
          _walletRepository.fetchWallet(),
          _walletRepository.fetchPackages(),
        ]);
        _wallet = result[0] as WalletSnapshot;
        _packages = result[1] as List<WalletPackage>;
      } catch (_) {
        _wallet = WalletSnapshot.empty;
        _packages = const [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _claimFree() async {
    if (!_walletRepository.canClaimFreeGold(_wallet)) {
      _show('يمكنك استخدام الشحن المجاني مرة كل 24 ساعة.', error: true);
      return;
    }
    setState(() => _working = true);
    try {
      _wallet = widget.demoMode || !AppConfig.isConfigured
          ? WalletSnapshot(
              goldCoins: _wallet.goldCoins + 30000,
              diamonds: _wallet.diamonds,
              lifetimeSpentGold: _wallet.lifetimeSpentGold,
              wealthLevel: _wallet.wealthLevel,
              lastFreeClaimAt: DateTime.now(),
            )
          : await _walletRepository.claimFreeGold();
      if (mounted) _show('تمت إضافة 30,000 عملة ذهبية مجانًا');
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _convertDiamonds() async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'تحويل الماس',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'عدد الماسات'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('تحويل'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || amount == null || amount <= 0) return;
    if (amount > _wallet.diamonds) {
      _show('رصيد الماس غير كافٍ.', error: true);
      return;
    }
    setState(() => _working = true);
    try {
      _wallet = widget.demoMode || !AppConfig.isConfigured
          ? WalletSnapshot(
              goldCoins: _wallet.goldCoins + amount,
              diamonds: _wallet.diamonds - amount,
              lifetimeSpentGold: _wallet.lifetimeSpentGold,
              wealthLevel: _wallet.wealthLevel,
              lastFreeClaimAt: _wallet.lastFreeClaimAt,
            )
          : await _walletRepository.convertDiamondsToGold(amount);
      if (mounted) _show('تم تحويل الماس إلى عملات ذهبية');
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _startTopup(WalletPackage package) async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      _show('وضع المعاينة لا ينفذ عمليات دفع حقيقية.');
      return;
    }
    setState(() => _working = true);
    try {
      await _walletRepository.createTopupOrder(package.id);
      if (mounted) {
        _show(
          'تم إنشاء طلب الشحن. يلزم ربط مزود الدفع لإتمام الخصم وإضافة العملات.',
          error: true,
        );
      }
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _show(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.danger : AppColors.primary,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المحفظة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _BalanceCard(wallet: _wallet),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _WalletAction(
                          icon: Icons.card_giftcard_rounded,
                          label: 'شحن مجاني',
                          color: AppColors.primary,
                          onTap: _working ? null : _claimFree,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _WalletAction(
                          icon: Icons.autorenew_rounded,
                          label: 'تحويل الماس',
                          color: const Color(0xFF0EA5E9),
                          onTap: _working ? null : _convertDiamonds,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'باقات العملات الذهبية',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '30,000 عملة ذهبية = 1 دولار. الدفع المدفوع لا يضيف العملات إلا بعد تأكيد مزود الدفع.',
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._packages.map(
                    (package) => _PackageTile(
                      package: package,
                      onTap: _working ? null : () => _startTopup(package),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class WealthLevelPage extends StatefulWidget {
  const WealthLevelPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<WealthLevelPage> createState() => _WealthLevelPageState();
}

class _WealthLevelPageState extends State<WealthLevelPage> {
  WalletSnapshot _wallet = WalletSnapshot.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      _wallet = const WalletSnapshot(
        goldCoins: 126500,
        diamonds: 88400,
        lifetimeSpentGold: 30000,
        wealthLevel: 2,
      );
    } else {
      try {
        _wallet = await const WalletRepository().fetchWallet();
      } catch (_) {
        _wallet = WalletSnapshot.empty;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  int _threshold(int level) {
    var value = 10000;
    for (var i = 0; i < level; i++) {
      value *= 3;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final currentThreshold = _threshold(_wallet.wealthLevel);
    final nextThreshold = _threshold(_wallet.wealthLevel + 1);
    final progress = _wallet.wealthLevel >= 100
        ? 1.0
        : ((_wallet.lifetimeSpentGold - currentThreshold).clamp(
                0,
                nextThreshold - currentThreshold,
              )) /
              (nextThreshold - currentThreshold);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مستوى الثروة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'المستوى ${_wallet.wealthLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_wallet.lifetimeSpentGold} عملة ذهبية مرسلة',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _LevelMetric(
                  label: 'المستوى الحالي',
                  value: '${_wallet.wealthLevel} / 100',
                ),
                _LevelMetric(
                  label: 'العملات المرسلة',
                  value: '${_wallet.lifetimeSpentGold}',
                ),
                _LevelMetric(
                  label: 'المطلوب للمستوى التالي',
                  value: _wallet.wealthLevel >= 100
                      ? 'اكتمل'
                      : '$nextThreshold',
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: progress.toDouble(),
                    backgroundColor: const Color(0xFFFFEDD5),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'يبدأ المستوى الأول عند إرسال 10,000 عملة ذهبية. بعد ذلك يتطلب كل مستوى ثلاثة أضعاف عتبة المستوى السابق: 30,000 ثم 90,000 ثم 270,000، حتى المستوى 100.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText, height: 1.6),
                ),
              ],
            ),
    );
  }
}

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    this.profile,
    this.demoMode = false,
    this.onSignedOut,
  });

  final Map<String, dynamic>? profile;
  final bool demoMode;
  final VoidCallback? onSignedOut;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _auth = const AuthRepository();
  late final TextEditingController _name;
  late final TextEditingController _nickname;
  bool _saving = false;

  Map<String, dynamic> get _data {
    final raw = widget.profile?['data'];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: (_data['fullName'] ?? _data['name'] ?? '').toString(),
    );
    _nickname = TextEditingController(
      text: (_data['nickname'] ?? _data['userName'] ?? '').toString(),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!widget.demoMode && AppConfig.isConfigured) {
        await _auth.updateMyProfile({
          'fullName': _name.text.trim(),
          'nickname': _nickname.text.trim(),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الحساب')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    if (!widget.demoMode && AppConfig.isConfigured) await _auth.signOut();
    widget.onSignedOut?.call();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إعدادات الحساب',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'بيانات الحساب',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nickname,
            decoration: const InputDecoration(labelText: 'اسم المستخدم'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التغييرات'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('تسجيل الخروج'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});
  final WalletSnapshot wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB15C), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x25000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'رصيدك الحالي',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 8),
              Text(
                '${wallet.goldCoins}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'عملة ذهبية',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.diamond_rounded,
                color: Color(0xFFBAE6FD),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '${wallet.diamonds} ماس',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'مستوى الثروة ${wallet.wealthLevel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: color.withValues(alpha: .45)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.package, this.onTap});
  final WalletPackage package;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFEDD5),
          foregroundColor: AppColors.primary,
          child: const Icon(Icons.monetization_on_rounded),
        ),
        title: Text(
          '${package.goldCoins} عملة ذهبية',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${package.priceUsd.toStringAsFixed(0)} دولار'),
        trailing: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('شحن'),
        ),
      ),
    );
  }
}

class _LevelMetric extends StatelessWidget {
  const _LevelMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedText)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
