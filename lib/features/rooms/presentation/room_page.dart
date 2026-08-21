import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../messages/data/messages_repository.dart';
import '../data/rooms_repository.dart';
import '../models/room.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.room, this.demoMode = false});

  final Room room;
  final bool demoMode;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  final _rooms = const RoomsRepository();
  final _messages = const MessagesRepository();
  final _text = TextEditingController();
  StreamSubscription<List<RoomMessage>>? _subscription;
  List<RoomMessage> _items = [];
  bool _joined = false;

  final _demoMessages = [
    RoomMessage(
      id: 'm1',
      roomId: 'demo',
      userId: 'u1',
      content: 'أهلًا بالجميع، نورتوا الغرفة',
      createdAt: _demoTime1,
      authorName: 'سارة',
    ),
    RoomMessage(
      id: 'm2',
      roomId: 'demo',
      userId: 'u2',
      content: 'مساء الخير يا أصدقاء',
      createdAt: _demoTime2,
      authorName: 'محمد',
    ),
    RoomMessage(
      id: 'm3',
      roomId: 'demo',
      userId: 'u3',
      content: 'هل نبدأ اللعبة؟',
      createdAt: _demoTime3,
      authorName: 'ليان',
    ),
  ];

  static final _demoTime1 = DateTime(2026, 1, 1, 20, 10);
  static final _demoTime2 = DateTime(2026, 1, 1, 20, 11);
  static final _demoTime3 = DateTime(2026, 1, 1, 20, 12);

  @override
  void initState() {
    super.initState();
    _items = widget.demoMode ? _demoMessages : [];
    _connect();
  }

  Future<void> _connect() async {
    if (widget.demoMode) {
      setState(() => _joined = true);
      return;
    }
    try {
      await _rooms.joinRoom(widget.room.id);
      _subscription = _messages.watchRoomMessages(widget.room.id).listen((
        items,
      ) {
        if (mounted) setState(() => _items = items);
      });
      if (mounted) setState(() => _joined = true);
    } catch (error) {
      if (mounted) _show(error.toString());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (!widget.demoMode) _rooms.leaveRoom(widget.room.id);
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty) return;
    _text.clear();
    if (widget.demoMode) {
      setState(
        () => _items = [
          ..._items,
          RoomMessage(
            id: DateTime.now().toIso8601String(),
            roomId: widget.room.id,
            userId: 'me',
            content: content,
            createdAt: DateTime.now(),
            authorName: 'أنت',
          ),
        ],
      );
      return;
    }
    try {
      await _messages.sendRoomMessage(roomId: widget.room.id, content: content);
    } catch (error) {
      if (mounted) _show(error.toString());
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.replaceFirst('AuthException: ', ''))),
  );

  @override
  Widget build(BuildContext context) {
    final themeColors = switch (widget.room.roomTheme) {
      'games' => const [Color(0xFF0E7490), Color(0xFF0F172A)],
      'royal' => const [Color(0xFF854D0E), Color(0xFF1C1917)],
      'radio' => const [Color(0xFF4338CA), Color(0xFF0F0F1A)],
      _ => const [Color(0xFF7E22CE), Color(0xFF0F0F1A)],
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: themeColors.first.withValues(alpha: .72),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_forward),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.room.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              '${widget.room.memberCount} عضو في الغرفة',
              style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _show('ستتم إضافة مشاركة الغرفة قريبًا.'),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            onPressed: () => _show('قائمة إعدادات الغرفة'),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeColors.first.withValues(alpha: .22),
              AppColors.background,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _RoomHero(room: widget.room, joined: _joined),
            _SeatsGrid(room: widget.room),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: _MessagesList(items: _items)),
            _Composer(
              controller: _text,
              onSend: _send,
              onGift: () =>
                  _show('الهدايا ستُربط بمخزون Supabase في المرحلة التالية.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomHero extends StatelessWidget {
  const _RoomHero({required this.room, required this.joined});
  final Room room;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: .16),
            ),
            child: const Icon(Icons.mic, color: AppColors.secondary, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.description ?? 'مرحبًا بكم في الغرفة',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 9, color: AppColors.success),
                    const SizedBox(width: 5),
                    Text(
                      joined ? 'أنت متصل الآن' : 'جارٍ الاتصال...',
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.favorite, size: 15, color: AppColors.accentPink),
                SizedBox(width: 5),
                Text(
                  'إعجاب',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatsGrid extends StatelessWidget {
  const _SeatsGrid({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final names = [
      'المضيف',
      'سارة',
      'محمد',
      'ليان',
      'نور',
      'متاح',
      'متاح',
      'متاح',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: .76,
        ),
        itemBuilder: (_, index) {
          final occupied = names[index] != 'متاح';
          return Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 53,
                    height: 53,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: occupied
                          ? AppColors.primary.withValues(alpha: .20)
                          : AppColors.surface,
                      border: Border.all(
                        color: occupied ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      occupied ? Icons.person : Icons.add,
                      color: occupied ? AppColors.primary : AppColors.mutedText,
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondary,
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 11,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                names[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: occupied ? AppColors.text : AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({required this.items});
  final List<RoomMessage> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SakiEmptyState(
        title: 'لا توجد رسائل بعد',
        subtitle: 'ابدأ الحديث مع أعضاء الغرفة.',
        icon: Icons.forum_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SakiAvatar(
              name: item.authorName,
              url: item.authorAvatarUrl,
              size: 34,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: .86),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${item.authorName ?? 'عضو'}\n',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: item.content,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onGift,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onGift;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onGift,
              icon: const Icon(Icons.card_giftcard, color: AppColors.secondary),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: IconButton(
                onPressed: onSend,
                icon: const Icon(
                  Icons.send_rounded,
                  color: AppColors.white,
                  size: 19,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
