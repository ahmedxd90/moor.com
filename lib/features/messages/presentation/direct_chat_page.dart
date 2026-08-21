import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../rooms/data/rooms_repository.dart';
import '../../rooms/models/room.dart';

class DirectChatPage extends StatefulWidget {
  const DirectChatPage({
    super.key,
    required this.member,
    this.demoMode = false,
  });

  final RoomMember member;
  final bool demoMode;

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  final _rooms = const RoomsRepository();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      _messages = [
        {
          'sender_id': widget.member.userId,
          'content': 'أهلًا، سعدت بوجودك في الغرفة.',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
    } else {
      try {
        _messages = await _rooms.fetchDirectMessages(widget.member.userId);
        _messageSubscription = _rooms
            .watchDirectMessages(widget.member.userId)
            .listen((items) {
              if (mounted) setState(() => _messages = items);
            });
      } catch (_) {
        _messages = [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty || _sending) return;
    _text.clear();
    if (mounted) setState(() => _sending = true);
    try {
      if (widget.demoMode || !AppConfig.isConfigured) {
        _messages = [
          ..._messages,
          {
            'sender_id': _rooms.currentUserId ?? 'me',
            'content': content,
            'created_at': DateTime.now().toIso8601String(),
          },
        ];
      } else {
        await _rooms.sendDirectMessage(
          receiverId: widget.member.userId,
          content: content,
        );
        _messages = [
          ..._messages,
          {
            'sender_id': _rooms.currentUserId,
            'content': content,
            'created_at': DateTime.now().toIso8601String(),
          },
        ];
      }
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
        });
      }
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
    _messageSubscription?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _rooms.currentUserId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            SakiAvatar(
              name: widget.member.name,
              url: widget.member.avatarUrl,
              size: 38,
            ),
            const SizedBox(width: 9),
            Text(
              widget.member.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'ابدأ محادثة خاصة الآن',
                            style: TextStyle(color: AppColors.mutedText),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                          itemCount: _messages.length,
                          itemBuilder: (_, index) {
                            final message = _messages[index];
                            final isMine =
                                message['sender_id'] == currentUserId ||
                                (currentUserId == null &&
                                    message['sender_id'] == 'me');
                            return Align(
                              alignment: isMine
                                  ? AlignmentDirectional.centerEnd
                                  : AlignmentDirectional.centerStart,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: isMine
                                      ? null
                                      : Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  (message['content'] as String?) ?? '',
                                  style: TextStyle(
                                    color: isMine
                                        ? Colors.white
                                        : AppColors.text,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'اكتب رسالة خاصة...',
                              prefixIcon: Icon(
                                Icons.chat_bubble_outline_rounded,
                              ),
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
                ),
              ],
            ),
    );
  }
}
