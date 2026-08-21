import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

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
              .select(
                '*, sender:profiles!direct_messages_sender_id_fkey(name, avatar_url), receiver:profiles!direct_messages_receiver_id_fkey(name, avatar_url)',
              )
              .or('sender_id.eq.$userId,receiver_id.eq.$userId')
              .order('created_at', ascending: false)
              .limit(40);
          _rows = (data as List).cast<Map<String, dynamic>>();
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
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شاشة المحادثة الخاصة ستُستكمل في المرحلة التالية.'),
        ),
      ),
    );
  }
}
