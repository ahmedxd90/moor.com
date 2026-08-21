import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import 'direct_chat_page.dart';
import '../../rooms/models/room.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  final _demo = const [
    {
      'name': 'سارة',
      'message': 'نلتقي في الغرفة مساءً؟',
      'time': 'منذ 5 د',
      'unread': 2,
    },
    {
      'name': 'محمد',
      'message': 'أرسلت لك هدية جديدة',
      'time': 'منذ 20 د',
      'unread': 0,
    },
    {
      'name': 'ليان',
      'message': 'شكرًا على الإضافة',
      'time': 'أمس',
      'unread': 0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.demoMode || !AppConfig.isConfigured) {
        _rows = List<Map<String, dynamic>>.from(_demo);
      } else {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId != null) {
          final data = await SupabaseService.client
              .from('direct_messages')
              .select('id,sender_id,receiver_id,content,created_at,read_at')
              .or('sender_id.eq.$userId,receiver_id.eq.$userId')
              .order('created_at', ascending: false)
              .limit(100);
          final rawRows = (data as List).cast<Map<String, dynamic>>();
          final partnerIds = rawRows
              .map(
                (row) => row['sender_id'] == userId
                    ? row['receiver_id'] as String
                    : row['sender_id'] as String,
              )
              .toSet()
              .toList(growable: false);
          final profiles = partnerIds.isEmpty
              ? const <String, Map<String, dynamic>>{}
              : {
                  for (final profile
                      in (await SupabaseService.client
                                  .from('user_profiles')
                                  .select('auth_user_id,data')
                                  .inFilter('auth_user_id', partnerIds)
                                  .limit(100)
                              as List)
                          .cast<Map<String, dynamic>>())
                    profile['auth_user_id'] as String: profile,
                };
          final latestByPartner = <String, Map<String, dynamic>>{};
          for (final row in rawRows) {
            final partnerId = row['sender_id'] == userId
                ? row['receiver_id'] as String
                : row['sender_id'] as String;
            if (latestByPartner.containsKey(partnerId)) continue;
            final profile = profiles[partnerId];
            final profileData = profile?['data'] is Map
                ? Map<String, dynamic>.from(profile!['data'] as Map)
                : const <String, dynamic>{};
            latestByPartner[partnerId] = {
              ...row,
              'partner_id': partnerId,
              'name':
                  profileData['fullName'] ??
                  profileData['userName'] ??
                  profileData['name'] ??
                  'مستخدم',
              'avatar_url':
                  profileData['avatarUrl'] ?? profileData['avatar_url'],
            };
          }
          _rows = latestByPartner.values.toList(growable: false);
        }
      }
    } catch (_) {
      _rows = widget.demoMode ? List<Map<String, dynamic>>.from(_demo) : [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الرسائل',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _rows.isEmpty
          ? const SakiEmptyState(
              title: 'لا توجد محادثات',
              subtitle: 'ابدأ محادثة مع أحد أصدقائك من ملفه الشخصي.',
              icon: Icons.chat_bubble_outline,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rows.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, index) => _ConversationTile(row: _rows[index]),
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final sender = row['sender'] is Map
        ? Map<String, dynamic>.from(row['sender'] as Map)
        : null;
    final receiver = row['receiver'] is Map
        ? Map<String, dynamic>.from(row['receiver'] as Map)
        : null;
    final name =
        (row['name'] as String?) ??
        (sender?['name'] as String?) ??
        (receiver?['name'] as String?) ??
        'محادثة جديدة';
    final message =
        (row['message'] as String?) ??
        (row['content'] as String?) ??
        'ابدأ المحادثة الآن';
    final unread = (row['unread'] as num?)?.toInt() ?? 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: SakiAvatar(
        name: name,
        url: (sender?['avatar_url'] ?? receiver?['avatar_url']) as String?,
        size: 52,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          message,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.mutedText),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            (row['time'] as String?) ?? 'الآن',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 7),
            CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.primary,
              child: Text(
                '$unread',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        final partnerId = row['partner_id'] as String?;
        if (partnerId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DirectChatPage(
              member: RoomMember(
                userId: partnerId,
                name: name,
                avatarUrl:
                    (row['avatar_url'] ??
                            sender?['avatar_url'] ??
                            receiver?['avatar_url'])
                        as String?,
              ),
            ),
          ),
        );
      },
    );
  }
}
