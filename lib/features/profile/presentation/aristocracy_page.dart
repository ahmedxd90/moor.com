import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/supabase_client.dart';

class AristocracyPage extends StatefulWidget {
  const AristocracyPage({super.key});

  @override
  State<AristocracyPage> createState() => _AristocracyPageState();
}

class _AristocracyPageState extends State<AristocracyPage> {
  final _client = SupabaseService.client;
  final _uuid = const Uuid();

  List<_AristocracyLevel> _levels = const [];
  _AristocracyLevel? _selected;
  Map<String, dynamic>? _membership;
  Map<String, dynamic> _profileData = const {};
  String? _avatarUrl;
  String? _username;
  int _goldCoins = 0;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const AuthException('يجب تسجيل الدخول أولًا');

      final catalogRows = await _client
          .from('aristocracy_levels')
          .select(
            'id,slug,name_ar,color_primary,color_secondary,icon_url,price_gold,duration_days,sort_order,aristocracy_features(id,feature_key,name_ar,description_ar,icon,sort_order)',
          )
          .eq('is_active', true)
          .order('sort_order');
      final levels = catalogRows
          .map(
            (row) => _AristocracyLevel.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();

      final walletResponse = await _client.rpc('get_my_wallet');
      final walletRow = walletResponse is List && walletResponse.isNotEmpty
          ? Map<String, dynamic>.from(walletResponse.first as Map)
          : walletResponse is Map
          ? Map<String, dynamic>.from(walletResponse)
          : const <String, dynamic>{};
      final goldCoins = (walletRow['gold_coins'] as num?)?.toInt() ?? 0;

      final membershipRow = await _client
          .from('user_aristocracy')
          .select('level_id,started_at,expires_at')
          .eq('user_id', user.id)
          .maybeSingle();
      Map<String, dynamic>? membership;
      if (membershipRow != null) {
        final row = Map<String, dynamic>.from(membershipRow);
        final levelId = (row['level_id'] as num).toInt();
        final memberLevel = levels.where((level) => level.id == levelId);
        membership = {
          ...row,
          'level_name': memberLevel.isEmpty ? '' : memberLevel.first.nameAr,
          'slug': memberLevel.isEmpty ? '' : memberLevel.first.slug,
        };
      }

      final profileRow = await _client
          .from('user_profiles')
          .select('data')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      final rawData = profileRow?['data'];
      final profileData = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      final username =
          (profileData['userName'] ??
                  profileData['username'] ??
                  user.userMetadata?['userName'] ??
                  user.email?.split('@').first ??
                  '')
              .toString();
      final avatarUrl =
          (profileData['avatarUrl'] ??
                  profileData['avatar_url'] ??
                  user.userMetadata?['avatar_url'])
              ?.toString();
      final currentLevelId = (membership?['level_id'] as num?)?.toInt();
      final selected = levels.where((level) => level.id == currentLevelId);

      if (!mounted) return;
      setState(() {
        _levels = levels;
        _selected = selected.isNotEmpty
            ? selected.first
            : (levels.isEmpty ? null : levels.first);
        _membership = membership;
        _profileData = profileData;
        _username = username;
        _avatarUrl = avatarUrl;
        _goldCoins = goldCoins;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (showLoader && mounted) setState(() => _loading = false);
    }
  }

  bool get _membershipActive {
    final raw = _membership?['expires_at'];
    final expiresAt = raw == null ? null : DateTime.tryParse(raw.toString());
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  int get _membershipLevelId =>
      (_membership?['level_id'] as num?)?.toInt() ?? 0;

  bool get _alreadyHasSelectedOrHigher =>
      _membershipActive &&
      _selected != null &&
      _membershipLevelId >= _selected!.id;

  bool get _canPurchase =>
      !_loading &&
      !_purchasing &&
      _selected != null &&
      _goldCoins >= _selected!.priceGold &&
      !_alreadyHasSelectedOrHigher;

  Future<void> _purchase() async {
    final selected = _selected;
    if (selected == null || !_canPurchase) return;
    setState(() => _purchasing = true);
    try {
      await _client.rpc(
        'purchase_aristocracy',
        params: {'p_level_id': selected.id, 'p_request_id': _uuid.v4()},
      );
      await _load(showLoader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم شراء وتفعيل العضوية بنجاح')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();
    if (normalized.contains('insufficient_gold_coins')) {
      return 'رصيد الذهب غير كافٍ لهذه الرتبة.';
    }
    if (normalized.contains('aristocracy_level_not_found')) {
      return 'هذه الرتبة غير متاحة حاليًا.';
    }
    if (normalized.contains('aristocracy_already_active_or_higher')) {
      return 'لديك رتبة فعالة مساوية أو أعلى.';
    }
    if (normalized.contains('not_authenticated')) {
      return 'انتهت الجلسة؛ سجّل الدخول مجددًا.';
    }
    return raw
        .replaceFirst('PostgrestException(message: ', '')
        .replaceFirst('AuthException: ', '')
        .replaceFirst(')', '');
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      backgroundColor: const Color(0xFF08090D),
      appBar: AppBar(
        title: const Text('الاستقراطية'),
        backgroundColor: const Color(0xFF08090D),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF5C85B)),
            )
          : _error != null
          ? _errorView()
          : _levels.isEmpty
          ? _emptyView()
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFFF5C85B),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _userCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _levels.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 9),
                      itemBuilder: (context, index) {
                        final level = _levels[index];
                        final active = selected?.id == level.id;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _selected = level),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 98,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF3B2C19)
                                  : const Color(0xFF141621),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? const Color(0xFFF5C85B)
                                    : const Color(0xFF2A2B36),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _crown(level.slug),
                                  style: TextStyle(
                                    color: _parseColor(level.colorPrimary),
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  level.nameAr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFFB8BBC8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  _hero(selected),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'المميزات المتاحة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${selected?.features.length ?? 0} امتيازات',
                        style: const TextStyle(
                          color: Color(0xFF9DA3B5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _featuresGrid(selected),
                  const SizedBox(height: 12),
                ],
              ),
            ),
      bottomNavigationBar: _error == null && !_loading && selected != null
          ? _purchaseBar(selected)
          : null,
    );
  }

  Widget _userCard() {
    final displayName =
        (_profileData['fullName'] ??
                _profileData['name'] ??
                _username ??
                'مستخدم SAKI')
            .toString();
    final status = _membershipActive
        ? 'الرتبة الحالية: ${_membership?['level_name'] ?? ''} · حتى ${_date(_membership?['expires_at'])}'
        : 'لا توجد عضوية فعالة';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x44E4AE4C)),
        gradient: const LinearGradient(
          colors: [Color(0xFF211B18), Color(0xFF12131A)],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF2B2020),
            backgroundImage: _avatarUrl == null || _avatarUrl!.isEmpty
                ? null
                : NetworkImage(_avatarUrl!),
            child: _avatarUrl == null || _avatarUrl!.isEmpty
                ? const Icon(Icons.person, color: Color(0xFFF5C85B))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9DA3B5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'رصيدك',
                style: TextStyle(color: Color(0xFF9DA3B5), fontSize: 10),
              ),
              Text(
                '${_formatNumber(_goldCoins)} ذهب',
                style: const TextStyle(
                  color: Color(0xFFF5C85B),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hero(_AristocracyLevel? level) {
    final color = _parseColor(level?.colorPrimary ?? '#F5C85B');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [Color(0xFF493111), Color(0xFF17131A), Color(0xFF08090D)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF33281A),
              border: Border.all(color: color.withValues(alpha: .38)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .20), blurRadius: 30),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _crown(level?.slug ?? ''),
              style: TextStyle(color: color, fontSize: 66),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            level?.nameAr ?? 'امتيازات الاستقراطية',
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'اختر رتبتك وفعّل حضورك داخل SAKI',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9DA3B5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _featuresGrid(_AristocracyLevel? level) {
    final features = level?.features ?? const <_AristocracyFeature>[];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF171923), Color(0xFF101117)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x33F5D77F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  feature.icon,
                  style: const TextStyle(
                    color: Color(0xFFF5C85B),
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                feature.nameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Text(
                  feature.descriptionAr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9DA3B5),
                    fontSize: 9,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _purchaseBar(_AristocracyLevel selected) {
    final insufficient = _goldCoins < selected.priceGold;
    final label = _alreadyHasSelectedOrHigher
        ? 'مفعّلة حاليًا'
        : insufficient
        ? 'الرصيد غير كافٍ'
        : 'شراء وتفعيل';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Color(0xF20D0E14),
          border: Border(top: BorderSide(color: Color(0x20FFFFFF))),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selected.durationDays} يومًا',
                  style: const TextStyle(
                    color: Color(0xFF9DA3B5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${_formatNumber(selected.priceGold)} ذهب',
                  style: const TextStyle(
                    color: Color(0xFFF5C85B),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              onPressed: _canPurchase ? _purchase : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFE9A5),
                foregroundColor: const Color(0xFF271B06),
                disabledBackgroundColor: const Color(0xFF4A4437),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _purchasing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 42),
          const SizedBox(height: 12),
          Text(
            _error ?? 'تعذر تحميل الصفحة',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );

  Widget _emptyView() => const Center(
    child: Text(
      'لا توجد رتب متاحة حاليًا',
      style: TextStyle(color: Colors.white),
    ),
  );

  static String _crown(String slug) => switch (slug) {
    'king' => '♛',
    'emperor' => '♕',
    _ => '✦',
  };

  static Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final colorValue = int.tryParse(normalized, radix: 16);
    return colorValue == null
        ? const Color(0xFFF5C85B)
        : Color(0xFF000000 | colorValue);
  }

  static String _formatNumber(int value) =>
      NumberFormat.decimalPattern().format(value);

  static String _date(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    if (parsed == null) return '—';
    return DateFormat('yyyy/MM/dd').format(parsed.toLocal());
  }
}

class _AristocracyLevel {
  const _AristocracyLevel({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.colorPrimary,
    required this.colorSecondary,
    required this.priceGold,
    required this.durationDays,
    required this.sortOrder,
    required this.features,
  });

  final int id;
  final String slug;
  final String nameAr;
  final String colorPrimary;
  final String colorSecondary;
  final int priceGold;
  final int durationDays;
  final int sortOrder;
  final List<_AristocracyFeature> features;

  factory _AristocracyLevel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['aristocracy_features'];
    final features = rawFeatures is List
        ? rawFeatures
              .whereType<Map>()
              .map(
                (feature) => _AristocracyFeature.fromJson(
                  Map<String, dynamic>.from(feature),
                ),
              )
              .toList()
        : <_AristocracyFeature>[];
    features.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return _AristocracyLevel(
      id: (json['id'] as num).toInt(),
      slug: (json['slug'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      colorPrimary: (json['color_primary'] ?? '#F5C85B').toString(),
      colorSecondary: (json['color_secondary'] ?? '#6B3D12').toString(),
      priceGold: (json['price_gold'] as num).toInt(),
      durationDays: (json['duration_days'] as num).toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      features: features,
    );
  }
}

class _AristocracyFeature {
  const _AristocracyFeature({
    required this.nameAr,
    required this.descriptionAr,
    required this.icon,
    required this.sortOrder,
  });

  final String nameAr;
  final String descriptionAr;
  final String icon;
  final int sortOrder;

  factory _AristocracyFeature.fromJson(Map<String, dynamic> json) =>
      _AristocracyFeature(
        nameAr: (json['name_ar'] ?? '').toString(),
        descriptionAr: (json['description_ar'] ?? '').toString(),
        icon: (json['icon'] ?? '✦').toString(),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );
}
