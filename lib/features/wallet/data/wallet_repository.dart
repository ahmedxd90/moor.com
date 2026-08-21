import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class WalletSnapshot {
  const WalletSnapshot({
    required this.goldCoins,
    required this.diamonds,
    required this.lifetimeSpentGold,
    required this.wealthLevel,
    this.lastFreeClaimAt,
  });

  final int goldCoins;
  final int diamonds;
  final int lifetimeSpentGold;
  final int wealthLevel;
  final DateTime? lastFreeClaimAt;

  factory WalletSnapshot.fromMap(Map<String, dynamic> map) => WalletSnapshot(
    goldCoins: (map['gold_coins'] as num?)?.toInt() ?? 0,
    diamonds: (map['diamonds'] as num?)?.toInt() ?? 0,
    lifetimeSpentGold: (map['lifetime_spent_gold'] as num?)?.toInt() ?? 0,
    wealthLevel: (map['wealth_level'] as num?)?.toInt() ?? 0,
    lastFreeClaimAt: DateTime.tryParse(
      map['last_free_claim_at'] as String? ?? '',
    )?.toLocal(),
  );

  static const empty = WalletSnapshot(
    goldCoins: 0,
    diamonds: 0,
    lifetimeSpentGold: 0,
    wealthLevel: 0,
  );
}

class WalletPackage {
  const WalletPackage({
    required this.id,
    required this.goldCoins,
    required this.priceUsd,
  });

  final String id;
  final int goldCoins;
  final double priceUsd;

  factory WalletPackage.fromMap(Map<String, dynamic> map) => WalletPackage(
    id: map['id'] as String,
    goldCoins: (map['gold_coins'] as num?)?.toInt() ?? 0,
    priceUsd: (map['price_usd'] as num?)?.toDouble() ?? 0,
  );
}

class WalletRepository {
  const WalletRepository();

  SupabaseClient get _client => SupabaseService.client;

  Future<WalletSnapshot> fetchWallet() async {
    final rows = await _client.rpc('get_my_wallet');
    if (rows is List && rows.isNotEmpty) {
      return WalletSnapshot.fromMap(
        Map<String, dynamic>.from(rows.first as Map),
      );
    }
    return WalletSnapshot.empty;
  }

  Future<List<WalletPackage>> fetchPackages() async {
    final rows = await _client
        .from('wallet_topup_packages')
        .select('id,gold_coins,price_usd')
        .eq('is_active', true)
        .order('price_usd', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WalletPackage.fromMap)
        .toList(growable: false);
  }

  Future<WalletSnapshot> claimFreeGold() async {
    await _client.rpc('claim_free_gold');
    return fetchWallet();
  }

  Future<WalletSnapshot> convertDiamondsToGold(int diamonds) async {
    await _client.rpc(
      'convert_diamonds_to_gold',
      params: {'p_diamonds': diamonds},
    );
    return fetchWallet();
  }

  Future<Map<String, dynamic>> createTopupOrder(String packageId) async {
    final row = await _client.rpc(
      'create_topup_order',
      params: {'p_package_id': packageId},
    );
    if (row is Map) return Map<String, dynamic>.from(row);
    throw const PostgrestException(message: 'تعذر إنشاء طلب الشحن');
  }

  bool canClaimFreeGold(WalletSnapshot wallet) {
    final last = wallet.lastFreeClaimAt;
    return last == null || DateTime.now().difference(last).inHours >= 24;
  }

  @visibleForTesting
  static int thresholdForLevel(int level) {
    var threshold = 10000;
    for (var i = 0; i < level; i++) {
      threshold *= 3;
    }
    return threshold;
  }
}
