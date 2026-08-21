import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../rooms/data/rooms_repository.dart';
import '../../rooms/models/room.dart';
import '../../rooms/presentation/room_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _rooms = const RoomsRepository();
  final _bannerController = PageController();
  StreamSubscription<List<Room>>? _roomSubscription;
  List<Room> _items = [];
  Timer? _bannerTimer;
  bool _loading = true;
  String _scope = 'all';
  String _country = 'ALL';
  String _searchQuery = '';

  static const _bannerImages = [
    'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1000&q=85',
    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1000&q=85',
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1000&q=85',
  ];

  static const _countryFilters = [
    ('ALL', 'جميع الغرف', '🌐'),
    ('JO', 'الأردن', '🇯🇴'),
    ('PK', 'باكستان', '🇵🇰'),
    ('BD', 'بنغلاديش', '🇧🇩'),
    ('EG', 'مصر', '🇪🇬'),
  ];

  final _demoRooms = const [
    Room(
      id: 'demo-1',
      ownerId: 'demo-owner',
      name: 'مرحبا بالمستخدمين الجدد',
      description: 'غرفة دردشة وتعارف يومية',
      roomTheme: 'chat',
      memberCount: 137,
      likesCount: 420,
      isLive: true,
      country: 'SA',
      coverUrl:
          'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=240&q=85',
      participantAvatars: [
        'https://randomuser.me/api/portraits/women/44.jpg',
        'https://randomuser.me/api/portraits/men/32.jpg',
        'https://randomuser.me/api/portraits/women/68.jpg',
      ],
    ),
    Room(
      id: 'demo-2',
      ownerId: 'demo-owner',
      name: 'وكالة حرة ولوصف KM',
      description: 'جلسة تواصل وأصدقاء',
      roomTheme: 'chat',
      memberCount: 286,
      likesCount: 610,
      isLive: true,
      country: 'TR',
      coverUrl:
          'https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&w=240&q=85',
      participantAvatars: [
        'https://randomuser.me/api/portraits/women/12.jpg',
        'https://randomuser.me/api/portraits/women/22.jpg',
        'https://randomuser.me/api/portraits/women/33.jpg',
      ],
    ),
    Room(
      id: 'demo-3',
      ownerId: 'demo-owner',
      name: 'وكالة ابراهيم',
      description: 'أصدقاء وعائلة Saki',
      roomTheme: 'family',
      memberCount: 9226,
      likesCount: 1800,
      isLive: true,
      country: 'SY',
      coverUrl:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=240&q=85',
      participantAvatars: [
        'https://randomuser.me/api/portraits/men/85.jpg',
        'https://randomuser.me/api/portraits/women/85.jpg',
        'https://randomuser.me/api/portraits/women/90.jpg',
      ],
    ),
    Room(
      id: 'demo-4',
      ownerId: 'demo-owner',
      name: 'جلسة طرب وأشعار',
      description: 'موسيقى وقصائد وأصوات جميلة',
      roomTheme: 'music',
      memberCount: 73,
      likesCount: 330,
      isLive: true,
      country: 'BD',
      coverUrl:
          'https://images.unsplash.com/photo-1501386761508-aedfafc04374?auto=format&fit=crop&w=240&q=85',
      participantAvatars: [
        'https://randomuser.me/api/portraits/men/15.jpg',
        'https://randomuser.me/api/portraits/women/15.jpg',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      _items = _demoRooms;
      _loading = false;
    } else {
      _subscribeToRooms();
    }
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_bannerController.hasClients || !mounted) return;
      final current = _bannerController.page?.round() ?? 0;
      _bannerController.animateToPage(
        (current + 1) % _bannerImages.length,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _subscribeToRooms() async {
    if (mounted) setState(() => _loading = true);
    await _roomSubscription?.cancel();
    _roomSubscription = _rooms.watchRooms().listen(
      (rooms) {
        if (mounted) setState(() => _items = rooms);
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
      onDone: () {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  Future<void> _refreshRooms() async {
    if (widget.demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _items = _demoRooms);
      return;
    }
    try {
      final rooms = await _rooms.fetchRooms();
      if (mounted) setState(() => _items = rooms);
    } catch (error) {
      if (mounted) _show('تعذر تحديث الغرف: $error', error: true);
    }
  }

  List<Room> get _visibleRooms {
    final currentUserId = widget.demoMode ? 'demo-owner' : _rooms.currentUserId;
    return _items
        .where((room) {
          final matchesScope = _scope == 'all' || room.ownerId == currentUserId;
          final matchesCountry = _country == 'ALL' || room.country == _country;
          final query = _searchQuery.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              room.name.toLowerCase().contains(query) ||
              (room.description ?? '').toLowerCase().contains(query);
          return matchesScope && matchesCountry && matchesSearch;
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _visibleRooms;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshRooms,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(child: _buildTopContent()),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (rooms.isEmpty)
            SliverFillRemaining(child: _buildEmptyRooms())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
              sliver: SliverList.separated(
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _RoomCard(
                  room: rooms[index],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomPage(
                        room: rooms[index],
                        demoMode: widget.demoMode,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      pinned: true,
      elevation: 2,
      shadowColor: AppColors.primaryDark.withValues(alpha: .18),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScopeTab(
            label: 'الكل',
            selected: _scope == 'all',
            onTap: () => setState(() => _scope = 'all'),
          ),
          const SizedBox(width: 20),
          _ScopeTab(
            label: 'خاص بي',
            selected: _scope == 'mine',
            onTap: () => setState(() => _scope = 'mine'),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'قائمة المرتبة',
          onPressed: _showRanking,
          icon: const Icon(Icons.emoji_events_outlined),
        ),
        IconButton(
          tooltip: 'بحث',
          onPressed: _openSearch,
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'إنشاء غرفة',
          onPressed: _createRoom,
          icon: const Icon(Icons.add_home_work_outlined),
        ),
      ],
    );
  }

  Widget _buildTopContent() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFA24B), Color(0xFFFFEDD5), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.center,
          stops: [0, .34, 1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        children: [
          _buildBanner(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PromoCard(
                  label: 'النشاط',
                  icon: Icons.sports_esports_outlined,
                  colors: const [Color(0xFF34D399), Color(0xFF6EE7B7)],
                  onTap: () =>
                      _show('قسم النشاط سيعرض الفعاليات اليومية قريبًا.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PromoCard(
                  label: 'قائمة المرتبة',
                  icon: Icons.workspace_premium_outlined,
                  colors: const [Color(0xFFFB923C), Color(0xFFFCD34D)],
                  onTap: _showRanking,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCountryFilters(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _bannerImages.length,
              onPageChanged: (_) => setState(() {}),
              itemBuilder: (context, index) => Image.network(
                _bannerImages[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.secondary,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _bannerImages.length,
            (index) => AnimatedBuilder(
              animation: _bannerController,
              builder: (_, __) {
                final current = _bannerController.hasClients
                    ? (_bannerController.page?.round() ?? 0)
                    : 0;
                final active = current == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.secondary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        itemCount: _countryFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final (code, label, flag) = _countryFilters[index];
          final selected = _country == code;
          return InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => setState(() => _country = code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFEDD5) : Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: selected ? AppColors.secondary : AppColors.border,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.primaryDark : AppColors.text,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyRooms() {
    final hasFilters =
        _country != 'ALL' || _searchQuery.isNotEmpty || _scope == 'mine';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.search_off_rounded : Icons.mic_none_rounded,
              size: 54,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters ? 'لا توجد نتائج' : 'لا توجد غرف حاليًا',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'غيّر الفلتر أو ابحث عن غرفة أخرى.'
                  : 'أنشئ أول غرفة صوتية وابدأ مجتمعك الخاص.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText),
            ),
            if (!hasFilters) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _createRoom,
                icon: const Icon(Icons.add),
                label: const Text('إنشاء غرفة'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _searchQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('البحث عن غرفة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اكتب اسم الغرفة...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('مسح'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query != null && mounted) setState(() => _searchQuery = query);
  }

  Future<void> _createRoom() async {
    if (!widget.demoMode && _rooms.currentUserId == null) {
      _show('يجب تسجيل الدخول لإنشاء غرفة.', error: true);
      return;
    }
    final name = TextEditingController();
    final description = TextEditingController();
    final values = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء غرفة صوتية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم الغرفة'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'وصف مختصر (اختياري)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              name.text.trim(),
              description.text.trim(),
            )),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    name.dispose();
    description.dispose();
    if (values == null || values.$1.isEmpty || !mounted) return;
    if (widget.demoMode) {
      _show('وضع المعاينة: سيتم تفعيل إنشاء الغرف مع حساب Supabase حقيقي.');
      return;
    }
    try {
      final room = await _rooms.createRoom(
        name: values.$1,
        description: values.$2.isEmpty ? null : values.$2,
      );
      if (mounted) {
        setState(() => _items = [room, ..._items]);
        _show('تم إنشاء الغرفة بنجاح.');
      }
    } catch (error) {
      if (mounted) _show('تعذر إنشاء الغرفة: $error', error: true);
    }
  }

  void _showRanking() =>
      _show('قائمة المرتبة ستعرض الغرف والمستخدمين الأكثر نشاطًا.');

  void _show(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.text,
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 20 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: -4,
                bottom: -10,
                child: Icon(icon, size: 48, color: Colors.white30),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tag = _roomTag(room.roomTheme);
    final tagColors = _tagColors(room.roomTheme);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F0F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 9,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoomCover(room: room),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _countryFlag(room.country),
                            style: const TextStyle(fontSize: 19),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tagColors.$1,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tag.$2, size: 12, color: tagColors.$2),
                                const SizedBox(width: 4),
                                Text(
                                  tag.$1,
                                  style: TextStyle(
                                    color: tagColors.$2,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const _SoundWave(),
                        ],
                      ),
                      Row(
                        children: [
                          _ParticipantStack(room: room),
                          const Spacer(),
                          Icon(
                            Icons.bar_chart_rounded,
                            size: 16,
                            color: const Color(0xFF2DD4BF),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${room.memberCount}',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, IconData) _roomTag(String value) => switch (value) {
    'music' => ('موسيقى', Icons.music_note),
    'family' => ('عائلة', Icons.groups_rounded),
    _ => ('دردشة', Icons.chat_bubble_outline),
  };

  (Color, Color) _tagColors(String value) => switch (value) {
    'music' => (const Color(0xFFE0F2FE), const Color(0xFF2563EB)),
    'family' => (const Color(0xFFF3E8FF), const Color(0xFF9333EA)),
    _ => (const Color(0xFFCCFBF1), const Color(0xFF0F766E)),
  };
}

class _RoomCover extends StatelessWidget {
  const _RoomCover({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: room.coverUrl == null || room.coverUrl!.isEmpty
            ? Container(
                color: AppColors.surfaceElevated,
                child: Icon(
                  room.isLocked ? Icons.lock_outline : Icons.mic_none_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              )
            : Image.network(
                room.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Icon(
                    Icons.mic_none_rounded,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ParticipantStack extends StatelessWidget {
  const _ParticipantStack({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    if (room.participantAvatars.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_alt_outlined,
            size: 17,
            color: AppColors.mutedText,
          ),
          const SizedBox(width: 4),
          Text(
            '${room.memberCount} متواجد',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: math.min(78, room.participantAvatars.length * 22.0 + 24),
      height: 24,
      child: Stack(
        children: room.participantAvatars
            .take(4)
            .toList()
            .asMap()
            .entries
            .map(
              (entry) => Positioned(
                right: entry.key * 18,
                child: Container(
                  width: 24,
                  height: 24,
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.network(
                      entry.value,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SoundWave extends StatefulWidget {
  const _SoundWave();

  @override
  State<_SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<_SoundWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final progress = (_controller.value * math.pi * 2) + index * .7;
            final height = 4 + 11 * ((math.sin(progress) + 1) / 2);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ),
    );
  }
}

String _countryFlag(String? code) => switch (code) {
  'SA' => '🇸🇦',
  'AE' => '🇦🇪',
  'KW' => '🇰🇼',
  'QA' => '🇶🇦',
  'JO' => '🇯🇴',
  'PK' => '🇵🇰',
  'BD' => '🇧🇩',
  'EG' => '🇪🇬',
  'TR' => '🇹🇷',
  'SY' => '🇸🇾',
  _ => '🌐',
};
