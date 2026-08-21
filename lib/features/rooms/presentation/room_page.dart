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

  late Room _room;
  List<RoomMember> _members = [];
  List<RoomMessage> _messageItems = [];
  List<RoomGift> _gifts = [];
  List<SeatReaction> _reactions = [];
  StreamSubscription<List<RoomMessage>>? _messageSubscription;
  StreamSubscription<List<RoomMember>>? _memberSubscription;
  StreamSubscription<List<RoomGift>>? _giftSubscription;
  StreamSubscription<List<SeatReaction>>? _reactionSubscription;
  Timer? _giftTimer;
  String? _giftOverlay;
  bool _joined = false;
  bool _composerOpen = false;
  bool _micOn = false;
  bool _loading = true;

  static final _demoTime1 = DateTime(2026, 1, 1, 20, 10);
  static final _demoTime2 = DateTime(2026, 1, 1, 20, 11);
  static final _demoTime3 = DateTime(2026, 1, 1, 20, 12);

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
      content: 'نبدأ الجلسة؟ اضغطوا على المقاعد للتفاعل',
      createdAt: _demoTime3,
      authorName: 'ليان',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    if (widget.demoMode) {
      _messageItems = _demoMessages;
      _members = _demoMembers();
      _loading = false;
      _joined = true;
    } else {
      _connect();
    }
  }

  List<RoomMember> _demoMembers() => List.generate(_room.seatCount, (index) {
    if (index == 0) {
      return const RoomMember(
        userId: 'demo-owner',
        seatIndex: 0,
        role: 'owner',
        name: 'كلك نظر',
        sakiId: 3668252,
        isSpeaking: true,
      );
    }
    if (index == 1) {
      return const RoomMember(
        userId: 'demo-sarah',
        seatIndex: 1,
        role: 'speaker',
        name: 'سارة',
      );
    }
    if (index == 2) {
      return const RoomMember(
        userId: 'demo-mohamed',
        seatIndex: 2,
        role: 'speaker',
        name: 'محمد',
      );
    }
    if (index == 3) {
      return const RoomMember(
        userId: 'demo-layan',
        seatIndex: 3,
        role: 'listener',
        name: 'ليان',
      );
    }
    return RoomMember(
      userId: 'demo-$index',
      seatIndex: index,
      name: 'No.${index + 1}',
    );
  });

  Future<void> _connect() async {
    try {
      await _rooms.joinRoom(_room.id);
      _memberSubscription = _rooms.watchRoomMembers(_room.id).listen((items) {
        if (mounted) setState(() => _members = items);
      });
      _messageSubscription = _messages.watchRoomMessages(_room.id).listen((
        items,
      ) {
        if (mounted) setState(() => _messageItems = items);
      });
      _giftSubscription = _rooms.watchGifts(_room.id).listen((items) {
        if (mounted) {
          setState(() {
            if (items.length > _gifts.length && items.isNotEmpty) {
              _showGiftOverlay(items.first.giftType);
            }
            _gifts = items;
          });
        }
      });
      _reactionSubscription = _rooms.watchSeatReactions(_room.id).listen((
        items,
      ) {
        if (mounted) setState(() => _reactions = items);
      });
      if (mounted) {
        setState(() {
          _joined = true;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _show(
          error.toString().replaceFirst('AuthException: ', ''),
          error: true,
        );
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _memberSubscription?.cancel();
    _giftSubscription?.cancel();
    _reactionSubscription?.cancel();
    _giftTimer?.cancel();
    if (!widget.demoMode) _rooms.leaveRoom(_room.id);
    _text.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _text.text.trim();
    if (content.isEmpty) return;
    _text.clear();
    if (widget.demoMode) {
      setState(() {
        _messageItems = [
          ..._messageItems,
          RoomMessage(
            id: DateTime.now().toIso8601String(),
            roomId: _room.id,
            userId: 'me',
            content: content,
            createdAt: DateTime.now(),
            authorName: 'أنت',
            type: 'text',
          ),
        ];
      });
      return;
    }
    try {
      await _messages.sendRoomMessage(roomId: _room.id, content: content);
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    }
  }

  Future<void> _sendGift(String giftType) async {
    if (widget.demoMode) {
      final gift = RoomGift(
        id: DateTime.now().toIso8601String(),
        roomId: _room.id,
        senderId: 'me',
        giftType: giftType,
        quantity: 1,
        senderName: 'أنت',
        createdAt: DateTime.now(),
      );
      setState(() => _gifts = [gift, ..._gifts]);
      _showGiftOverlay(giftType);
      return;
    }
    try {
      await _rooms.sendGift(roomId: _room.id, giftType: giftType);
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    }
  }

  Future<void> _sendReaction(int seatIndex, String reaction) async {
    if (widget.demoMode) {
      setState(() {
        _reactions = [
          SeatReaction(
            id: DateTime.now().toIso8601String(),
            roomId: _room.id,
            seatIndex: seatIndex,
            userId: 'me',
            reaction: reaction,
            createdAt: DateTime.now(),
          ),
          ..._reactions,
        ];
      });
      return;
    }
    try {
      await _rooms.sendSeatReaction(
        roomId: _room.id,
        seatIndex: seatIndex,
        reaction: reaction,
      );
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    }
  }

  Future<void> _toggleMic() async {
    final userId = widget.demoMode ? 'demo-owner' : _rooms.currentUserId;
    if (userId == null) {
      _show('يجب تسجيل الدخول لتشغيل الميكروفون.', error: true);
      return;
    }
    final member = _members.where((item) => item.userId == userId).firstOrNull;
    if (member == null) {
      _show('لم يتم تخصيص مقعد لك بعد.', error: true);
      return;
    }
    if (!_room.allowMemberMic && !member.isOwner) {
      _show('الميكروفون متاح بإذن مالك الغرفة.', error: true);
      return;
    }
    final newValue = !_micOn;
    setState(() => _micOn = newValue);
    if (!widget.demoMode) {
      try {
        await _rooms.setMemberMuted(
          roomId: _room.id,
          userId: userId,
          muted: !newValue,
        );
      } catch (error) {
        if (mounted) _show(error.toString(), error: true);
      }
    }
  }

  RoomMember? _memberAt(int index) =>
      _members.where((member) => member.seatIndex == index).firstOrNull;

  SeatReaction? _reactionAt(int index) =>
      _reactions.where((reaction) => reaction.seatIndex == index).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final colors = _themeColors;
    return Scaffold(
      backgroundColor: colors.last,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.first, colors.last],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildAtmosphere(),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildRoomSummary(),
                  _buildSeats(),
                  Expanded(child: _buildChat()),
                  _buildToolbar(),
                ],
              ),
            ),
            if (_giftOverlay != null) _buildGiftOverlay(),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              ),
          ],
        ),
      ),
    );
  }

  List<Color> get _themeColors => switch (_room.roomTheme) {
    'games' => const [Color(0xFF082F49), Color(0xFF042F2E)],
    'royal' => const [Color(0xFF172554), Color(0xFF312E81)],
    'radio' => const [Color(0xFF172554), Color(0xFF111827)],
    _ => const [Color(0xFF071A35), Color(0xFF043D45)],
  };

  Widget _buildAtmosphere() {
    return IgnorePointer(
      child: Stack(
        children: [
          if (_room.coverUrl != null && _room.coverUrl!.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: .15,
                child: Image.network(
                  _room.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned(
            top: 120,
            left: 40,
            child: _GlowCircle(color: const Color(0xFF06B6D4), size: 230),
          ),
          Positioned(
            top: 260,
            right: 30,
            child: _GlowCircle(color: const Color(0xFF2563EB), size: 190),
          ),
          Positioned(
            bottom: 130,
            left: 80,
            child: _GlowCircle(color: const Color(0xFF14B8A6), size: 210),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final owner = _members.where((member) => member.isOwner).firstOrNull;
    return SizedBox(
      height: 62,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 5,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  color: Colors.white,
                  icon: const Icon(Icons.close_rounded),
                ),
                IconButton(
                  onPressed: _openRoomInfo,
                  color: Colors.white70,
                  icon: const Icon(Icons.info_outline_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      owner?.name ?? 'مالك الغرفة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'ID: ${owner?.sakiId ?? _room.roomNumber ?? '—'}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: owner == null ? null : () => _openMemberInfo(owner),
                  child: SakiAvatar(
                    name: owner?.name ?? 'م',
                    size: 42,
                    url: owner?.avatarUrl,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF34D399), size: 8),
                    const SizedBox(width: 5),
                    Text(
                      _joined
                          ? '${_members.length} متصل الآن'
                          : 'جارٍ الاتصال...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${_room.roomNumber ?? '—'}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openMembers,
            color: Colors.white70,
            tooltip: 'قائمة المتصلين',
            icon: const Icon(Icons.people_alt_outlined),
          ),
          if (_isCurrentUserOwner)
            IconButton(
              onPressed: _openRoomSettings,
              color: Colors.white70,
              tooltip: 'إعدادات الغرفة',
              icon: const Icon(Icons.tune_rounded),
            ),
        ],
      ),
    );
  }

  bool get _isCurrentUserOwner {
    if (widget.demoMode) return true;
    return _rooms.currentUserId == _room.ownerId;
  }

  Widget _buildSeats() {
    final columns = _room.seatCount >= 10 ? 5 : 4;
    final rows = (_room.seatCount / columns).ceil();
    const tileHeight = 82.0;
    final height = rows * tileHeight + (rows - 1) * 6 + 18;
    return SizedBox(
      height: height,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _room.seatCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          mainAxisExtent: tileHeight,
        ),
        itemBuilder: (_, index) {
          final member = _memberAt(index);
          return _SeatTile(
            index: index,
            member: member,
            reaction: _reactionAt(index),
            onTap: () => member == null
                ? _show('هذا المقعد متاح للانضمام.')
                : _openMemberInfo(member),
            onLongPress: () => _openReactionPicker(index),
          );
        },
      ),
    );
  }

  Widget _buildChat() {
    if (_messageItems.isEmpty) {
      return const Center(
        child: Text(
          'ابدأ الحديث مع أعضاء الغرفة',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      itemCount: _messageItems.length,
      itemBuilder: (_, index) {
        final item = _messageItems[_messageItems.length - 1 - index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SakiAvatar(
                name: item.authorName,
                url: item.authorAvatarUrl,
                size: 28,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: item.type == 'gift'
                        ? const Color(0xFF064E3B).withValues(alpha: .75)
                        : const Color(0xFF061A2B).withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${item.authorName ?? 'عضو'}  ',
                          style: const TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: item.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
        child: Row(
          children: [
            _ToolButton(
              icon: Icons.card_giftcard_rounded,
              color: const Color(0xFFFBBF24),
              onTap: _openGiftPicker,
            ),
            _ToolButton(
              icon: Icons.emoji_emotions_outlined,
              onTap: () => _openReactionPicker(null),
            ),
            _ToolButton(icon: Icons.people_alt_outlined, onTap: _openMembers),
            _ToolButton(icon: Icons.grid_view_rounded, onTap: _openRoomInfo),
            const SizedBox(width: 5),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _composerOpen = true),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .13),
                    ),
                  ),
                  child: _composerOpen
                      ? TextField(
                          controller: _text,
                          autofocus: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالة...',
                            hintStyle: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        )
                      : const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'اكتب رسالة...',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            _ToolButton(
              icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: _micOn ? const Color(0xFF34D399) : Colors.white70,
              onTap: _toggleMic,
            ),
            if (_composerOpen)
              _ToolButton(
                icon: Icons.send_rounded,
                color: AppColors.secondary,
                onTap: _sendMessage,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftOverlay() {
    return Positioned(
      left: 20,
      bottom: 105,
      child: AnimatedScale(
        scale: _giftOverlay == null ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 16),
            ],
          ),
          child: Text(
            '${_giftEmoji(_giftOverlay ?? 'rose')} هدية $_giftOverlay',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openGiftPicker() async {
    final gift = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF10243A),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'الهدايا',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _GiftOption(type: 'rose', label: 'وردة', emoji: '🌹'),
                  _GiftOption(type: 'heart', label: 'قلب', emoji: '💖'),
                  _GiftOption(type: 'crown', label: 'تاج', emoji: '👑'),
                  _GiftOption(type: 'car', label: 'سيارة', emoji: '🏎️'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (gift != null) await _sendGift(gift);
  }

  Future<void> _openReactionPicker(int? seatIndex) async {
    final reaction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF10243A),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            children: ['❤️', '👏', '🔥', '😂', '😍', '🎉']
                .map(
                  (emoji) => IconButton(
                    onPressed: () => Navigator.pop(context, emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 29)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (reaction == null) return;
    if (seatIndex == null) {
      _show('اضغط مطولًا على مقعد لإرسال التفاعل عليه.');
    } else {
      await _sendReaction(seatIndex, reaction);
    }
  }

  Future<void> _openMembers() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10243A),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _ConnectedMembersSheet(members: _members, onTap: _openMemberInfo),
    );
  }

  Future<void> _openMemberInfo(RoomMember member) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10243A),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Material(
        color: const Color(0xFF10243A),
        child: Container(
          color: const Color(0xFF10243A),
          constraints: const BoxConstraints(minHeight: 260),
          child: _UserInfoSheet(
            member: member,
            isOwner: _isCurrentUserOwner,
            onMute: member.userId == _rooms.currentUserId || member.isOwner
                ? null
                : () async {
                    Navigator.pop(context);
                    await _rooms.setMemberMuted(
                      roomId: _room.id,
                      userId: member.userId,
                      muted: !member.isMuted,
                    );
                  },
          ),
        ),
      ),
    );
  }

  Future<void> _openRoomInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10243A),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _RoomInfoSheet(room: _room, membersCount: _members.length),
    );
  }

  Future<void> _openRoomSettings() async {
    final updated = await Navigator.of(context).push<Room>(
      MaterialPageRoute(builder: (_) => RoomSettingsPage(room: _room)),
    );
    if (updated != null && mounted) setState(() => _room = updated);
  }

  void _showGiftOverlay(String type) {
    _giftTimer?.cancel();
    setState(() => _giftOverlay = type);
    _giftTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _giftOverlay = null);
    });
  }

  String _giftEmoji(String type) => switch (type) {
    'heart' => '💖',
    'crown' => '👑',
    'car' => '🏎️',
    _ => '🌹',
  };

  void _show(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('PostgrestException: ', '')),
        backgroundColor: error ? AppColors.danger : AppColors.text,
      ),
    );
  }
}

class RoomSettingsPage extends StatefulWidget {
  const RoomSettingsPage({super.key, required this.room});

  final Room room;

  @override
  State<RoomSettingsPage> createState() => _RoomSettingsPageState();
}

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  final _rooms = const RoomsRepository();
  late final TextEditingController _name;
  late final TextEditingController _announcement;
  late int _seatCount;
  late bool _allowMemberMic;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.room.name);
    _announcement = TextEditingController(text: widget.room.announcement);
    _seatCount = widget.room.seatCount;
    _allowMemberMic = widget.room.allowMemberMic;
  }

  @override
  void dispose() {
    _name.dispose();
    _announcement.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return;
    setState(() => _busy = true);
    try {
      await _rooms.updateRoomName(room: widget.room, name: _name.text.trim());
      await _rooms.updateRoomSettings(
        room: widget.room,
        seatCount: _seatCount,
        settings: {
          'announcement': _announcement.text.trim(),
          'allow_member_mic': _allowMemberMic,
          'member_fee': widget.room.memberFee,
        },
      );
      if (mounted) {
        Navigator.pop(
          context,
          widget.room.copyWith(
            name: _name.text.trim(),
            seatCount: _seatCount,
            settings: {
              ...widget.room.settings,
              'announcement': _announcement.text.trim(),
              'allow_member_mic': _allowMemberMic,
            },
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'إعدادات الغرفة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _SettingsCover(room: widget.room),
          const SizedBox(height: 20),
          const _SettingsLabel('اسم الغرفة'),
          const SizedBox(height: 7),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.meeting_room_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const _SettingsLabel('إعلان الغرفة'),
          const SizedBox(height: 7),
          TextField(
            controller: _announcement,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب إعلانًا يظهر لأعضاء الغرفة',
              prefixIcon: Icon(Icons.campaign_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          const _SettingsLabel('عدد المقاعد'),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_seat_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$_seatCount مقعد',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: _seatCount <= 4
                      ? null
                      : () => setState(() => _seatCount -= 2),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed: _seatCount >= 20
                      ? null
                      : () => setState(() => _seatCount += 2),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: _allowMemberMic,
            onChanged: (value) => setState(() => _allowMemberMic = value),
            activeThumbColor: AppColors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 5),
            title: const Text(
              'السماح للأعضاء بتشغيل الميكروفون',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'يتحكم المالك في صلاحية التحدث داخل الغرفة.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 18),
          SakiGradientButton(
            label: 'حفظ إعدادات الغرفة',
            icon: Icons.save_outlined,
            onPressed: _save,
            busy: _busy,
          ),
        ],
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.index,
    required this.member,
    required this.reaction,
    required this.onTap,
    required this.onLongPress,
  });

  final int index;
  final RoomMember? member;
  final SeatReaction? reaction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final occupied = member != null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 57,
                height: 57,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: occupied
                      ? LinearGradient(
                          colors: member!.isSpeaking
                              ? const [Color(0xFF2DD4BF), Color(0xFF0EA5E9)]
                              : const [Color(0xFF64748B), Color(0xFF334155)],
                        )
                      : const LinearGradient(
                          colors: [Color(0x446B8296), Color(0x33475C70)],
                        ),
                  boxShadow: member?.isSpeaking == true
                      ? const [
                          BoxShadow(
                            color: Color(0xAA2DD4BF),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: occupied
                      ? SakiAvatar(
                          name: member!.name,
                          url: member!.avatarUrl,
                          size: 53,
                        )
                      : const Icon(
                          Icons.mic_none_rounded,
                          color: Colors.white70,
                          size: 25,
                        ),
                ),
              ),
              if (member?.isOwner == true)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              if (member?.isMuted == true)
                const Positioned(
                  left: -2,
                  bottom: -2,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Color(0xFFEF4444),
                    child: Icon(
                      Icons.mic_off_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              if (reaction != null)
                Positioned(
                  top: -6,
                  left: -4,
                  child: Text(
                    reaction!.reaction,
                    style: const TextStyle(fontSize: 19),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 74,
            child: Text(
              member?.name ?? 'No.${index + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: occupied ? Colors.white : Colors.white54,
                fontSize: 9,
                fontWeight: occupied ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white70,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: const EdgeInsets.all(7),
      constraints: const BoxConstraints.tightFor(width: 39, height: 42),
      splashRadius: 21,
      icon: Icon(icon, color: color, size: 21),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _GiftOption extends StatelessWidget {
  const _GiftOption({
    required this.type,
    required this.label,
    required this.emoji,
  });

  final String type;
  final String label;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, type),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedMembersSheet extends StatelessWidget {
  const _ConnectedMembersSheet({required this.members, required this.onTap});

  final List<RoomMember> members;
  final ValueChanged<RoomMember> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 16),
          child: Column(
            children: [
              const Text(
                'المتصلون في الغرفة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${members.length} متصل',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: members.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد متصلون بعد',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.separated(
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white12),
                        itemBuilder: (_, index) {
                          final member = members[index];
                          return ListTile(
                            onTap: () => onTap(member),
                            contentPadding: EdgeInsets.zero,
                            leading: SakiAvatar(
                              name: member.name,
                              url: member.avatarUrl,
                              size: 40,
                            ),
                            title: Text(
                              member.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              member.isOwner
                                  ? 'مالك الغرفة'
                                  : member.isSpeaker
                                  ? 'متحدث'
                                  : 'مستمع',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Icon(
                              member.isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              color: member.isMuted
                                  ? Colors.redAccent
                                  : Colors.tealAccent,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserInfoSheet extends StatelessWidget {
  const _UserInfoSheet({
    required this.member,
    required this.isOwner,
    this.onMute,
  });

  final RoomMember member;
  final bool isOwner;
  final VoidCallback? onMute;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SakiAvatar(name: member.name, url: member.avatarUrl, size: 72),
            const SizedBox(height: 10),
            Text(
              member.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${member.sakiId ?? 'غير متاح'}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoChip(
                  icon: Icons.event_seat_rounded,
                  label:
                      'المقعد ${member.seatIndex == null ? '—' : member.seatIndex! + 1}',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.mic_rounded,
                  label: member.isMuted ? 'مكتوم' : 'متحدث',
                ),
              ],
            ),
            if (isOwner && onMute != null) ...[
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: onMute,
                icon: const Icon(Icons.mic_off_rounded),
                label: const Text('كتم العضو'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _RoomInfoSheet extends StatelessWidget {
  const _RoomInfoSheet({required this.room, required this.membersCount});

  final Room room;
  final int membersCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _RoomCoverSmall(room: room),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'رقم الغرفة: ${room.roomNumber ?? '—'}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (room.description?.isNotEmpty == true)
              Text(
                room.description!,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
            const SizedBox(height: 12),
            _DarkInfoRow(
              icon: Icons.event_seat_rounded,
              label: 'المقاعد',
              value: '${room.seatCount}',
            ),
            _DarkInfoRow(
              icon: Icons.people_alt_outlined,
              label: 'المتصلون',
              value: '$membersCount',
            ),
            _DarkInfoRow(
              icon: Icons.mic_rounded,
              label: 'الميكروفون',
              value: room.allowMemberMic ? 'مسموح للأعضاء' : 'بإذن المالك',
            ),
            if (room.announcement.isNotEmpty)
              _DarkInfoRow(
                icon: Icons.campaign_outlined,
                label: 'الإعلان',
                value: room.announcement,
              ),
          ],
        ),
      ),
    );
  }
}

class _DarkInfoRow extends StatelessWidget {
  const _DarkInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 17),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCoverSmall extends StatelessWidget {
  const _RoomCoverSmall({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: room.coverUrl?.isNotEmpty == true
          ? Image.network(
              room.coverUrl!,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
    width: 58,
    height: 58,
    color: Colors.white12,
    child: const Icon(Icons.mic_rounded, color: Colors.tealAccent),
  );
}

class _SettingsCover extends StatelessWidget {
  const _SettingsCover({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoomCoverSmall(room: room),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'إعدادات المالك فقط\nتتحكم هنا في المقاعد والإعلان وصلاحية الميكروفون.',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
  );
}
