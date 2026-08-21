import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  List<Map<String, dynamic>> _moments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.demoMode || !AppConfig.isConfigured) {
        _moments = const [
          {
            'name': 'سارة',
            'content': 'أجمل الأوقات تكون مع الأصدقاء الحقيقيين.',
            'likes_count': 28,
            'avatar_url': null,
          },
          {
            'name': 'محمد',
            'content': 'بانتظاركم في غرفة ليالي السمر الليلة.',
            'likes_count': 15,
            'avatar_url': null,
          },
        ];
      } else {
        final data = await SupabaseService.client
            .from('moments')
            .select('*, profiles(name, avatar_url)')
            .order('created_at', ascending: false)
            .limit(30);
        _moments = (data as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {
      _moments = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اللحظات',
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
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: _moments.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        SakiEmptyState(
                          title: 'لا توجد لحظات بعد',
                          subtitle: 'شارك أول لحظة مع مجتمع Saki Chat.',
                          icon: Icons.auto_awesome_outlined,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _moments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, index) =>
                          _MomentCard(row: _moments[index]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'إنشاء اللحظة سيُربط بتخزين Supabase في الخطوة التالية.',
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('لحظة جديدة'),
      ),
    );
  }
}

class _MomentCard extends StatefulWidget {
  const _MomentCard({required this.row});
  final Map<String, dynamic> row;

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.row['profiles'] is Map
        ? Map<String, dynamic>.from(widget.row['profiles'] as Map)
        : null;
    final name =
        (widget.row['name'] as String?) ??
        (profile?['name'] as String?) ??
        'عضو Saki';
    final content = (widget.row['content'] as String?) ?? '';
    final likes = (widget.row['likes_count'] as num?)?.toInt() ?? 0;
    final mediaUrl = widget.row['media_url'] as String?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SakiAvatar(
                  name: name,
                  url:
                      (widget.row['avatar_url'] ?? profile?['avatar_url'])
                          as String?,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'منذ قليل',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: AppColors.mutedText),
              ],
            ),
            const SizedBox(height: 14),
            Text(content, style: const TextStyle(height: 1.6, fontSize: 14)),
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  mediaUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _liked = !_liked),
                  icon: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? AppColors.accentPink : AppColors.mutedText,
                  ),
                ),
                Text(
                  '${likes + (_liked ? 1 : 0)}',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 18),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: AppColors.mutedText,
                  ),
                ),
                const Text(
                  'تعليق',
                  style: TextStyle(color: AppColors.mutedText),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
