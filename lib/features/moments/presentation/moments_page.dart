import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/moments_repository.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final _repository = const MomentsRepository();
  List<Map<String, dynamic>> _moments = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  bool _loading = true;

  final _demoMoments = <Map<String, dynamic>>[
    {
      'id': 'demo-1',
      'user_id': 'demo-sarah',
      'name': 'سارة',
      'content': 'أجمل الأوقات تكون مع الأصدقاء الحقيقيين.',
      'likes_count': 28,
      'comments_count': 3,
      'shares_count': 2,
      'liked_by_me': false,
    },
    {
      'id': 'demo-2',
      'user_id': 'demo-mohamed',
      'name': 'محمد',
      'content': 'بانتظاركم في غرفة ليالي السمر الليلة.',
      'likes_count': 15,
      'comments_count': 1,
      'shares_count': 4,
      'liked_by_me': false,
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
        _moments = List<Map<String, dynamic>>.from(_demoMoments);
      } else {
        _moments = await _repository.fetchMoments();
        _subscription ??= _repository.watchMoments().listen((items) {
          if (mounted) setState(() => _moments = items);
        });
      }
    } catch (_) {
      _moments = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateMoment() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateMomentPage(demoMode: widget.demoMode),
      ),
    );
    if (created == true && mounted) await _load();
  }

  Future<void> _openComments(Map<String, dynamic> moment) async {
    final momentId = moment['id'] as String?;
    if (momentId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _MomentCommentsSheet(
        momentId: momentId,
        repository: _repository,
        demoMode: widget.demoMode,
      ),
    );
  }

  Future<void> _shareMoment(Map<String, dynamic> moment) async {
    final momentId = moment['id'] as String?;
    if (momentId == null) return;
    try {
      if (!widget.demoMode && AppConfig.isConfigured) {
        await _repository.shareMoment(momentId);
      }
      await Clipboard.setData(
        ClipboardData(text: 'https://saki.chat/moments/$momentId'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل المشاركة ونسخ رابط المنشور')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
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
                          subtitle: 'شارك أول منشور مع مجتمع Saki Chat.',
                          icon: Icons.auto_awesome_outlined,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                      itemCount: _moments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, index) => _MomentCard(
                        row: _moments[index],
                        repository: _repository,
                        demoMode: widget.demoMode,
                        onComments: () => _openComments(_moments[index]),
                        onShare: () => _shareMoment(_moments[index]),
                      ),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _openCreateMoment,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('رفع منشور'),
      ),
    );
  }
}

class CreateMomentPage extends StatefulWidget {
  const CreateMomentPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<CreateMomentPage> createState() => _CreateMomentPageState();
}

class _CreateMomentPageState extends State<CreateMomentPage> {
  final _repository = const MomentsRepository();
  final _picker = ImagePicker();
  final _content = TextEditingController();
  Uint8List? _imageBytes;
  String? _extension;
  bool _publishing = false;

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _extension = file.name.split('.').last.toLowerCase();
      });
    }
  }

  Future<void> _publish() async {
    final content = _content.text.trim();
    if (content.isEmpty && _imageBytes == null) {
      _show('أضف نصًا أو صورة للمنشور.', error: true);
      return;
    }
    setState(() => _publishing = true);
    try {
      if (widget.demoMode || !AppConfig.isConfigured) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      String? mediaUrl;
      if (_imageBytes != null) {
        mediaUrl = await _repository.uploadMomentMedia(
          _imageBytes!,
          extension: _extension == 'png' ? 'png' : 'jpg',
        );
      }
      await _repository.createMoment(content: content, mediaUrl: mediaUrl);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
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
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'رفع منشور',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 230,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageBytes == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          color: AppColors.primary,
                          size: 52,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'اختيار صورة من الجهاز',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    )
                  : Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'اكتب نص المنشور...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: const Icon(Icons.publish_rounded),
            label: Text(_publishing ? 'جارٍ الرفع...' : 'نشر المنشور'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentCard extends StatefulWidget {
  const _MomentCard({
    required this.row,
    required this.repository,
    required this.demoMode,
    required this.onComments,
    required this.onShare,
  });

  final Map<String, dynamic> row;
  final MomentsRepository repository;
  final bool demoMode;
  final VoidCallback onComments;
  final VoidCallback onShare;

  @override
  State<_MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<_MomentCard> {
  late bool _liked;
  late int _likes;

  @override
  void initState() {
    super.initState();
    _liked = widget.row['liked_by_me'] == true;
    _likes = (widget.row['likes_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> _toggleLike() async {
    final previousLiked = _liked;
    final previousLikes = _likes;
    setState(() {
      _liked = !previousLiked;
      _likes = previousLikes + (_liked ? 1 : -1);
    });
    if (widget.demoMode || !AppConfig.isConfigured) return;
    try {
      await widget.repository.toggleLike(
        momentId: widget.row['id'] as String,
        liked: previousLiked,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _liked = previousLiked;
          _likes = previousLikes;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  String _timeAgo() {
    final raw = widget.row['created_at'] as String?;
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return 'منذ قليل';
    final minutes = DateTime.now().difference(date).inMinutes;
    if (minutes < 1) return 'الآن';
    if (minutes < 60) return 'منذ $minutes دقيقة';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'منذ $hours ساعة';
    return 'منذ ${hours ~/ 24} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.row['name'] as String?) ?? 'عضو Saki';
    final avatar = widget.row['avatar_url'] as String?;
    final content = (widget.row['content'] as String?) ?? '';
    final mediaUrl = widget.row['media_url'] as String?;
    final comments = (widget.row['comments_count'] as num?)?.toInt() ?? 0;
    final shares = (widget.row['shares_count'] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SakiAvatar(name: name, url: avatar, size: 44),
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
                      Text(
                        _timeAgo(),
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.mutedText,
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(content, style: const TextStyle(height: 1.6, fontSize: 14)),
            ],
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  mediaUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: _toggleLike,
                  icon: Icon(
                    _liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _liked ? AppColors.accentPink : AppColors.mutedText,
                  ),
                ),
                Text(
                  '$_likes',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: widget.onComments,
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: AppColors.mutedText,
                  ),
                ),
                Text(
                  '$comments',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onShare,
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.mutedText,
                  ),
                ),
                Text(
                  '$shares',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
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

class _MomentCommentsSheet extends StatefulWidget {
  const _MomentCommentsSheet({
    required this.momentId,
    required this.repository,
    required this.demoMode,
  });

  final String momentId;
  final MomentsRepository repository;
  final bool demoMode;

  @override
  State<_MomentCommentsSheet> createState() => _MomentCommentsSheetState();
}

class _MomentCommentsSheetState extends State<_MomentCommentsSheet> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.demoMode) {
      _comments = const [
        {'user_id': 'demo', 'content': 'منشور جميل جدًا'},
      ];
    } else {
      try {
        _comments = await widget.repository.fetchComments(widget.momentId);
      } catch (_) {
        _comments = [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty || _sending) return;
    _text.clear();
    setState(() => _sending = true);
    try {
      if (widget.demoMode) {
        _comments = [
          ..._comments,
          {'user_id': 'me', 'content': content},
        ];
      } else {
        await widget.repository.addComment(
          momentId: widget.momentId,
          content: content,
        );
        _comments = await widget.repository.fetchComments(widget.momentId);
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'التعليقات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _comments.isEmpty
                  ? const Center(
                      child: Text(
                        'كن أول من يعلّق',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = _comments[index];
                        return Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${item['user_id'] ?? 'عضو'}: ${item['content'] ?? ''}',
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                MediaQuery.viewInsetsOf(context).bottom + 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'اكتب تعليقًا...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
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
