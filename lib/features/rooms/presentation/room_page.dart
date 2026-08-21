import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../messages/data/messages_repository.dart';
import '../data/agora_audio_service.dart';
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
  final _agora = AgoraAudioService();
  final _text = TextEditingController();

  late Room _room;
  List<RoomMember> _members = [];
  List<RoomMessage> _messageItems = [];
  List<RoomGift> _gifts = [];
  List<GiftCatalogItem> _giftCatalog = [];
  List<SeatReaction> _reactions = [];
  RoomMember? _giftReceiver;
  String _giftCategory = 'general';
  int _goldCoins = 0;
  StreamSubscription<List<RoomMessage>>? _messageSubscription;
  StreamSubscription<List<RoomMember>>? _memberSubscription;
  StreamSubscription<List<RoomGift>>? _giftSubscription;
  StreamSubscription<List<SeatReaction>>? _reactionSubscription;
  StreamSubscription<AgoraAudioState>? _agoraSubscription;
  Timer? _giftTimer;
  Timer? _joinBannerTimer;
  String? _giftOverlay;
  int? _giftOverlaySeatIndex;
  RoomMember? _joinBannerMember;
  final _knownMemberIds = <String>{};
  bool _joinBannerVisible = false;
  bool _remoteAudioOn = true;
  bool _joined = false;
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
      _knownMemberIds.addAll(_members.map((member) => member.userId));
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
      _memberSubscription = _rooms
          .watchRoomMembers(_room.id)
          .listen(_handleMembersChanged);
      _messageSubscription = _messages.watchRoomMessages(_room.id).listen((
        items,
      ) {
        if (mounted) setState(() => _messageItems = items);
      });
      _giftSubscription = _rooms.watchGifts(_room.id).listen((items) {
        final shouldShowGift = items.length > _gifts.length && items.isNotEmpty;
        if (mounted) {
          setState(() => _gifts = items);
          if (shouldShowGift) {
            final gift = items.first;
            final receiverSeat = _members
                .where((member) => member.userId == gift.receiverId)
                .firstOrNull
                ?.seatIndex;
            _showGiftOverlay(gift.giftType, seatIndex: receiverSeat);
          }
        }
      });
      _reactionSubscription = _rooms.watchSeatReactions(_room.id).listen((
        items,
      ) {
        if (mounted) setState(() => _reactions = items);
      });
      _agoraSubscription = _agora.states.listen((state) {
        if (!mounted) return;
        setState(() {
          _micOn = state.speaking && !state.muted;
          _remoteAudioOn = !state.remoteMuted;
        });
      });
      try {
        await _agora.joinAsListener(
          'saki-${_room.roomNumber?.toString() ?? _room.id}',
        );
      } catch (_) {
        // Database room access remains usable when Agora is not configured yet.
      }
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
    _agoraSubscription?.cancel();
    _giftTimer?.cancel();
    _joinBannerTimer?.cancel();
    _agora.dispose();
    if (!widget.demoMode) _rooms.leaveRoom(_room.id);
    _text.dispose();
    super.dispose();
  }

  void _handleMembersChanged(List<RoomMember> items) {
    if (!mounted) return;
    final newMember = items.cast<RoomMember?>().firstWhere(
      (member) => member != null && !_knownMemberIds.contains(member.userId),
      orElse: () => null,
    );
    _knownMemberIds.addAll(items.map((member) => member.userId));
    setState(() => _members = items);
    if (newMember != null && newMember.userId != _rooms.currentUserId) {
      _joinBannerTimer?.cancel();
      setState(() {
        _joinBannerMember = newMember;
        _joinBannerVisible = true;
      });
      _joinBannerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _joinBannerVisible = false);
      });
    }
  }

  RoomMember? get _currentMember {
    final userId = widget.demoMode ? 'demo-owner' : _rooms.currentUserId;
    if (userId == null) return null;
    return _members.where((member) => member.userId == userId).firstOrNull;
  }

  RoomMember? get _currentSeatedMember {
    final member = _currentMember;
    return member?.seatIndex == null ? null : member;
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

  Future<void> _sendGift(
    String giftType, {
    String? receiverId,
    int? seatIndex,
  }) async {
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
      _showGiftOverlay(giftType, seatIndex: seatIndex);
      return;
    }
    try {
      await _rooms.sendGift(
        roomId: _room.id,
        giftType: giftType,
        receiverId: receiverId,
      );
      _showGiftOverlay(giftType, seatIndex: seatIndex);
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
    final member = _currentSeatedMember;
    if (member == null) {
      _show('اضغط على مقعد أولًا للتحدث.', error: true);
      return;
    }
    final userId = member.userId;
    if (!_room.allowMemberMic && !member.isOwner) {
      _show('الميكروفون متاح بإذن مالك الغرفة.', error: true);
      return;
    }
    final newValue = !_micOn;
    try {
      if (!widget.demoMode) {
        await _agora.setMicrophoneMuted(!newValue);
        await _rooms.setMemberMuted(
          roomId: _room.id,
          userId: userId,
          muted: !newValue,
        );
      }
      if (mounted) setState(() => _micOn = newValue);
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    }
  }

  Future<void> _toggleRemoteAudio() async {
    final next = !_remoteAudioOn;
    try {
      if (!widget.demoMode) await _agora.setRemoteAudioMuted(!next);
      if (mounted) setState(() => _remoteAudioOn = next);
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
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
            if (_joinBannerMember != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOut,
                left: _joinBannerVisible ? 0 : MediaQuery.sizeOf(context).width,
                top: 112,
                child: _JoinBanner(member: _joinBannerMember!),
              ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              ),
          ],
        ),
      ),
    );
  }

  List<Color> get _themeColors => const [Color(0xFFFFEDD5), Color(0xFFFFFBEB)];

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openRoomInfo,
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  _RoomCoverSmall(room: _room, size: 50),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID الغرفة: ${_room.roomNumber ?? '—'}',
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _openMembers,
            tooltip: 'المتصلون',
            color: AppColors.text,
            icon: const Icon(Icons.people_alt_outlined),
          ),
          IconButton(
            onPressed: _openRankings,
            tooltip: 'ترتيب الهدايا',
            color: const Color(0xFFE08A00),
            icon: const Icon(Icons.emoji_events_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'خروج',
            color: AppColors.primary,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, color: Color(0xFF22C55E), size: 9),
            const SizedBox(width: 7),
            Text(
              _joined ? '${_members.length} متصل الآن' : 'جارٍ الاتصال...',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (_room.announcement.isNotEmpty)
              Flexible(
                child: Text(
                  _room.announcement,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 10,
                  ),
                ),
              )
            else
              const Text(
                'اضغط على مقعد للتحدث',
                style: TextStyle(color: AppColors.mutedText, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  bool get _isCurrentUserOwner {
    if (widget.demoMode) return true;
    return _rooms.currentUserId == _room.ownerId;
  }

  Future<void> _openSeatAction(int index) async {
    final member = _memberAt(index);
    final current = _currentMember;
    if (member != null && member.userId != current?.userId) {
      await _openMemberInfo(member);
      return;
    }
    if (member?.userId == current?.userId && current?.seatIndex == index) {
      final leave = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (_) => _SeatActionSheet(
          title: 'أنت على المقعد ${index + 1}',
          actionLabel: 'النزول من المقعد',
          icon: Icons.event_seat_outlined,
        ),
      );
      if (leave == true) await _leaveSeat();
      return;
    }
    final take = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _SeatActionSheet(
        title: 'المقعد ${index + 1} متاح',
        actionLabel: 'خذ مقعدًا وتحدث',
        icon: Icons.mic_rounded,
      ),
    );
    if (take == true) await _takeSeat(index);
  }

  Future<void> _takeSeat(int index) async {
    final member = _currentMember;
    if (member == null) {
      _show('لم يتم تسجيل دخولك إلى الغرفة بعد.', error: true);
      return;
    }
    if (!_room.allowMemberMic && !member.isOwner) {
      _show('الميكروفون متاح بإذن مالك الغرفة.', error: true);
      return;
    }
    try {
      if (!widget.demoMode) await _agora.takeSeat();
      if (!widget.demoMode) {
        await _rooms.setSeat(
          roomId: _room.id,
          userId: member.userId,
          seatIndex: index,
        );
      } else {
        setState(() {
          _members = _members
              .map(
                (item) => item.userId == member.userId
                    ? RoomMember(
                        userId: item.userId,
                        seatIndex: index,
                        role: item.role == 'listener' ? 'speaker' : item.role,
                        name: item.name,
                        avatarUrl: item.avatarUrl,
                        sakiId: item.sakiId,
                        joinedAt: item.joinedAt,
                        isMuted: false,
                        isSpeaking: true,
                      )
                    : item,
              )
              .toList(growable: false);
          _micOn = true;
        });
      }
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    }
  }

  Future<void> _leaveSeat() async {
    final member = _currentSeatedMember;
    if (member == null) return;
    try {
      if (!widget.demoMode) {
        await _agora.leaveSeat();
        await _rooms.setSeat(
          roomId: _room.id,
          userId: member.userId,
          seatIndex: null,
        );
        await _rooms.setMemberMuted(
          roomId: _room.id,
          userId: member.userId,
          muted: true,
        );
      } else {
        setState(() {
          _members = _members
              .map(
                (item) => item.userId == member.userId
                    ? RoomMember(
                        userId: item.userId,
                        seatIndex: null,
                        role: 'listener',
                        name: item.name,
                        avatarUrl: item.avatarUrl,
                        sakiId: item.sakiId,
                        joinedAt: item.joinedAt,
                        isMuted: true,
                      )
                    : item,
              )
              .toList(growable: false);
          _micOn = false;
        });
      }
    } catch (error) {
      if (mounted) _show(error.toString(), error: true);
    }
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
            onTap: () => _openSeatAction(index),
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
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
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
                        ? const Color(0xFFFFF0C2)
                        : Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${item.authorName ?? 'عضو'}  ',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: item.content,
                          style: const TextStyle(
                            color: AppColors.text,
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
    final seated = _currentSeatedMember != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ToolButton(
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
              onTap: _openMessageComposer,
            ),
            if (seated)
              _ToolButton(
                icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: _micOn ? const Color(0xFF16A34A) : AppColors.primary,
                onTap: _toggleMic,
              ),
            _ToolButton(
              icon: _remoteAudioOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: AppColors.text,
              onTap: _toggleRemoteAudio,
            ),
            _ToolButton(
              icon: Icons.emoji_emotions_outlined,
              color: AppColors.text,
              onTap: () => _openReactionPicker(null),
            ),
            _ToolButton(
              icon: Icons.card_giftcard_rounded,
              color: const Color(0xFFE08A00),
              onTap: _openGiftPicker,
            ),
            _ToolButton(
              icon: Icons.grid_view_rounded,
              color: AppColors.text,
              onTap: _openRoomInfo,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMessageComposer() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) async {
                  await _sendMessage();
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة...',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () async {
                await _sendMessage();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftOverlay() {
    final columns = _room.seatCount >= 10 ? 5 : 4;
    final index = _giftOverlaySeatIndex ?? 0;
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = (width - 24) / columns;
    final left = (12 + (index % columns) * tileWidth + tileWidth / 2 - 42)
        .clamp(8.0, width - 92.0);
    final top = 178.0 + (index ~/ columns) * 84.0;
    return Positioned(
      left: left,
      top: top,
      child: AnimatedScale(
        scale: _giftOverlay == null ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 12),
            ],
          ),
          child: Text(
            '${_giftEmoji(_giftOverlay ?? 'rose')} هدية',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openGiftPicker() async {
    if (!widget.demoMode) {
      try {
        final catalog = await _rooms.fetchGiftCatalog();
        final coins = await _rooms.fetchMyGoldCoins();
        if (mounted) {
          setState(() {
            _giftCatalog = catalog;
            _goldCoins = coins;
          });
        }
      } catch (error) {
        if (mounted) _show(error.toString(), error: true);
        return;
      }
    }
    final catalog = _giftCatalog.isEmpty ? _fallbackGiftCatalog : _giftCatalog;
    final seated = _members
        .where((member) => member.seatIndex != null)
        .toList(growable: false);
    if (seated.isEmpty) {
      _show('لا يوجد مستخدم على مقعد لإرسال هدية له.', error: true);
      return;
    }
    _giftReceiver ??= seated.first;
    if (!seated.any((member) => member.userId == _giftReceiver?.userId)) {
      _giftReceiver = seated.first;
    }
    if (!mounted) return;
    final selection = await showModalBottomSheet<GiftSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GiftPickerSheet(
        members: seated,
        catalog: catalog,
        coins: _goldCoins,
        initialReceiverId: _giftReceiver!.userId,
        initialCategory: _giftCategory,
      ),
    );
    if (selection == null) return;
    _giftReceiver = seated
        .where((member) => member.userId == selection.receiverId)
        .firstOrNull;
    _giftCategory = selection.gift.category;
    final receiver = _giftReceiver;
    await _sendGift(
      selection.gift.giftType,
      receiverId: receiver?.userId,
      seatIndex: receiver?.seatIndex,
    );
    if (!widget.demoMode && mounted) {
      setState(() => _goldCoins -= selection.gift.price);
    }
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
      backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Material(
        color: Colors.white,
        child: Container(
          color: Colors.white,
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

  Future<void> _openRankings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GiftRankingsSheet(roomId: _room.id),
    );
  }

  Future<void> _openRoomInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RoomInfoSheet(
        room: _room,
        membersCount: _members.length,
        onSettings: _isCurrentUserOwner ? _openRoomSettings : null,
      ),
    );
  }

  Future<void> _openRoomSettings() async {
    final updated = await Navigator.of(context).push<Room>(
      MaterialPageRoute(builder: (_) => RoomSettingsPage(room: _room)),
    );
    if (updated != null && mounted) setState(() => _room = updated);
  }

  void _showGiftOverlay(String type, {int? seatIndex}) {
    _giftTimer?.cancel();
    setState(() {
      _giftOverlay = type;
      _giftOverlaySeatIndex = seatIndex;
    });
    _giftTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _giftOverlay = null;
          _giftOverlaySeatIndex = null;
        });
      }
    });
  }

  List<GiftCatalogItem> get _fallbackGiftCatalog => const [
    GiftCatalogItem(
      giftType: 'rose',
      displayName: 'وردة',
      category: 'general',
      price: 10,
      emoji: '🌹',
    ),
    GiftCatalogItem(
      giftType: 'heart',
      displayName: 'قلب',
      category: 'general',
      price: 50,
      emoji: '💖',
    ),
    GiftCatalogItem(
      giftType: 'crown',
      displayName: 'تاج',
      category: 'famous',
      price: 500,
      emoji: '👑',
    ),
    GiftCatalogItem(
      giftType: 'car',
      displayName: 'سيارة',
      category: 'famous',
      price: 2500,
      emoji: '🏎️',
    ),
  ];

  String _giftEmoji(String type) =>
      _fallbackGiftCatalog
          .where((gift) => gift.giftType == type)
          .firstOrNull
          ?.emoji ??
      '🎁';

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
                              ? const [Color(0xFFFFA63D), Color(0xFFE87513)]
                              : const [Color(0xFFFFD8A8), Color(0xFFFFEDD5)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                        ),
                  boxShadow: member?.isSpeaking == true
                      ? const [
                          BoxShadow(
                            color: Color(0x66F59E0B),
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
                          color: AppColors.mutedText,
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
                color: occupied ? AppColors.text : AppColors.mutedText,
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

class GiftSelection {
  const GiftSelection({required this.gift, required this.receiverId});

  final GiftCatalogItem gift;
  final String receiverId;
}

class _JoinBanner extends StatelessWidget {
  const _JoinBanner({required this.member});

  final RoomMember member;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SakiAvatar(name: member.name, url: member.avatarUrl, size: 34),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'انضم إلى الغرفة كمستمع',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatActionSheet extends StatelessWidget {
  const _SeatActionSheet({
    required this.title,
    required this.actionLabel,
    required this.icon,
  });

  final String title;
  final String actionLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 34),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: Icon(icon),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftPickerSheet extends StatefulWidget {
  const _GiftPickerSheet({
    required this.members,
    required this.catalog,
    required this.coins,
    required this.initialReceiverId,
    required this.initialCategory,
  });

  final List<RoomMember> members;
  final List<GiftCatalogItem> catalog;
  final int coins;
  final String initialReceiverId;
  final String initialCategory;

  @override
  State<_GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<_GiftPickerSheet> {
  late String _receiverId;
  late String _category;
  GiftCatalogItem? _selected;

  static const _categories = <String, String>{
    'general': 'العامة',
    'famous': 'المشاهير',
    'countries': 'الدول',
    'cp': 'CP',
    'bag': 'الحقيبة',
  };

  @override
  void initState() {
    super.initState();
    _receiverId = widget.initialReceiverId;
    _category = _categories.containsKey(widget.initialCategory)
        ? widget.initialCategory
        : 'general';
  }

  @override
  Widget build(BuildContext context) {
    final gifts = widget.catalog
        .where((gift) => gift.category == _category)
        .toList(growable: false);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .76,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'الهدايا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.members.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 13),
                  itemBuilder: (_, index) {
                    final member = widget.members[index];
                    final selected = member.userId == _receiverId;
                    return InkWell(
                      onTap: () => setState(() => _receiverId = member.userId),
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            child: SakiAvatar(
                              name: member.name,
                              url: member.avatarUrl,
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: 60,
                            child: Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categories.entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _category == entry.key,
                            onSelected: (_) => setState(() {
                              _category = entry.key;
                              _selected = null;
                            }),
                            selectedColor: AppColors.primary.withValues(
                              alpha: .16,
                            ),
                            labelStyle: TextStyle(
                              color: _category == entry.key
                                  ? AppColors.primary
                                  : AppColors.mutedText,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: gifts.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد هدايا في هذه الفئة',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      )
                    : GridView.builder(
                        itemCount: gifts.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisExtent: 96,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemBuilder: (_, index) {
                          final gift = gifts[index];
                          final selected = _selected?.giftType == gift.giftType;
                          return InkWell(
                            onTap: () => setState(() => _selected = gift),
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: .1)
                                    : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    gift.emoji,
                                    style: const TextStyle(fontSize: 30),
                                  ),
                                  Text(
                                    gift.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${gift.price} عملة',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFE08A00),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${widget.coins} عملة ذهبية',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.pop(
                            context,
                            GiftSelection(
                              gift: _selected!,
                              receiverId: _receiverId,
                            ),
                          ),
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text('إرسال هدية'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftRankingsSheet extends StatefulWidget {
  const _GiftRankingsSheet({required this.roomId});

  final String roomId;

  @override
  State<_GiftRankingsSheet> createState() => _GiftRankingsSheetState();
}

class _GiftRankingsSheetState extends State<_GiftRankingsSheet> {
  final _rooms = const RoomsRepository();
  String _period = 'daily';
  late Future<List<GiftRankingEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GiftRankingEntry>> _load() {
    return _rooms.fetchGiftRankings(roomId: widget.roomId, period: _period);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .74,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 14),
          child: Column(
            children: [
              const Text(
                'ترتيب الهدايا',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('اليومي')),
                  ButtonSegment(value: 'weekly', label: Text('الأسبوعي')),
                ],
                selected: {_period},
                onSelectionChanged: (selection) {
                  setState(() {
                    _period = selection.first;
                    _future = _load();
                  });
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<GiftRankingEntry>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'تعذر تحميل الترتيب',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                      );
                    }
                    final entries = snapshot.data ?? const <GiftRankingEntry>[];
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text(
                          'لا توجد هدايا في هذه الفترة بعد',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final entry = entries[index];
                        final medal = switch (entry.rank) {
                          1 => '🥇',
                          2 => '🥈',
                          3 => '🥉',
                          _ => '${entry.rank}',
                        };
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 44,
                            height: 44,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SakiAvatar(
                                  name: entry.name,
                                  url: entry.avatarUrl,
                                  size: 42,
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: entry.rank <= 3
                                          ? const Color(0xFFFFE7A3)
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      medal,
                                      style: TextStyle(
                                        fontSize: entry.rank <= 3 ? 13 : 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          title: Text(
                            entry.name ??
                                'مستخدم ${entry.userId.substring(0, 5)}',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            '${entry.totalGifts} هدية مرسلة',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 10,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${entry.totalCoins}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.monetization_on_rounded,
                                color: Color(0xFFE08A00),
                                size: 16,
                              ),
                            ],
                          ),
                        );
                      },
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
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${members.length} متصل',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: members.isEmpty
                    ? const Center(
                        child: Text(
                          'لا يوجد متصلون بعد',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      )
                    : ListView.separated(
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: AppColors.border),
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
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              member.isOwner
                                  ? 'مالك الغرفة'
                                  : member.isSpeaker
                                  ? 'متحدث على المقعد ${member.seatIndex! + 1}'
                                  : 'مستمع',
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 11,
                              ),
                            ),
                            trailing: Icon(
                              member.isMuted
                                  ? Icons.mic_off_rounded
                                  : member.isSpeaker
                                  ? Icons.mic_rounded
                                  : Icons.headphones_rounded,
                              color: member.isMuted
                                  ? AppColors.danger
                                  : member.isSpeaker
                                  ? const Color(0xFF16A34A)
                                  : AppColors.mutedText,
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
                color: AppColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${member.sakiId ?? 'غير متاح'}',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
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
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _RoomInfoSheet extends StatelessWidget {
  const _RoomInfoSheet({
    required this.room,
    required this.membersCount,
    this.onSettings,
  });

  final Room room;
  final int membersCount;
  final VoidCallback? onSettings;

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
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID الغرفة: ${room.roomNumber ?? '—'}',
                        style: const TextStyle(
                          color: AppColors.mutedText,
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
                style: const TextStyle(color: AppColors.mutedText, height: 1.5),
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
            if (onSettings != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('إعدادات الغرفة'),
              ),
            ],
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
          Icon(icon, color: AppColors.primary, size: 17),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.text,
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
  const _RoomCoverSmall({required this.room, this.size = 58});

  final Room room;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: room.coverUrl?.isNotEmpty == true
          ? Image.network(
              room.coverUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
    width: size,
    height: size,
    color: AppColors.background,
    child: const Icon(Icons.mic_rounded, color: AppColors.primary),
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
