import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../rooms/data/rooms_repository.dart';
import '../../rooms/models/room.dart';
import '../../rooms/presentation/create_room_page.dart';
import '../../rooms/presentation/room_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.demoMode = false, this.onOpenRoom});

  final bool demoMode;
  final ValueChanged<Room>? onOpenRoom;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _rooms = const RoomsRepository();
  final _scopeController = PageController();
  final _feedControllers = <int, PageController>{
    0: PageController(),
    1: PageController(),
  };
  final _roomData = <String, List<Room>>{};
  final _loadingKeys = <String, bool>{};
  final _followedIds = <String>{};

  StreamSubscription<List<Room>>? _subscription;
  Timer? _bannerTimer;
  int _scopeIndex = 0;
  final _feedIndexes = <int, int>{0: 0, 1: 0};
  String _country = 'ALL';
  String _searchQuery = '';
  int _bannerIndex = 0;

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

  static const _feedItems = [
    (RoomFeed.latest, 'أحدث الغرف'),
    (RoomFeed.visited, 'زرتها'),
    (RoomFeed.followed, 'متابعة'),
  ];

  final _demoRooms = const [
    Room(
      id: 'demo-1',
      roomNumber: 412976435,
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
      roomNumber: 412976436,
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
      roomNumber: 412976437,
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
      roomNumber: 412976438,
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
    if (widget.demoMode || !AppConfig.isConfigured) {
      _roomData[_key(0, RoomFeed.latest)] = _demoRooms;
      _roomData[_key(0, RoomFeed.visited)] = _demoRooms.take(2).toList();
      _roomData[_key(0, RoomFeed.followed)] = _demoRooms
          .skip(1)
          .take(2)
          .toList();
      _roomData[_key(1, RoomFeed.latest)] = [_demoRooms.first];
      _roomData[_key(1, RoomFeed.visited)] = [_demoRooms.first];
      _roomData[_key(1, RoomFeed.followed)] = [_demoRooms.skip(1).first];
      _loadingKeys.addAll({for (final key in _roomData.keys) key: false});
    } else {
      _activateFeed();
      _loadFollowedIds();
    }
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _bannerIndex = (_bannerIndex + 1) % _bannerImages.length);
    });
  }

  String _key(int scope, RoomFeed feed) => '$scope-${feed.name}';

  RoomFeed get _activeFeed => _feedItems[_feedIndexes[_scopeIndex] ?? 0].$1;

  List<Room> get _activeRooms {
    final source = _roomData[_key(_scopeIndex, _activeFeed)] ?? const <Room>[];
    final query = _searchQuery.trim().toLowerCase();
    return source
        .where((room) {
          final matchesCountry = _country == 'ALL' || room.country == _country;
          final matchesSearch =
              query.isEmpty ||
              room.name.toLowerCase().contains(query) ||
              (room.description ?? '').toLowerCase().contains(query);
          return matchesCountry && matchesSearch;
        })
        .toList(growable: false);
  }

  Future<void> _activateFeed() async {
    await _subscription?.cancel();
    _subscription = null;
    if (widget.demoMode || !AppConfig.isConfigured) return;
    final feed = _activeFeed;
    final scope = _scopeIndex;
    final key = _key(scope, feed);
    if (mounted) setState(() => _loadingKeys[key] = true);
    _subscription = _rooms
        .watchRooms(feed: feed, onlyMine: scope == 1 && feed == RoomFeed.latest)
        .listen(
          (rooms) {
            if (mounted) {
              setState(() {
                _roomData[key] = rooms;
                _loadingKeys[key] = false;
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _loadingKeys[key] = false);
          },
          onDone: () {
            if (mounted) setState(() => _loadingKeys[key] = false);
          },
        );
  }

  Future<void> _loadFollowedIds() async {
    try {
      final ids = await _rooms.fetchFollowedRoomIds();
      if (mounted) setState(() => _followedIds.addAll(ids));
    } catch (_) {
      // The room list remains usable if the optional follow query is unavailable.
    }
  }

  Future<void> _refreshActiveFeed() async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() {});
      return;
    }
    final feed = _activeFeed;
    final scope = _scopeIndex;
    final key = _key(scope, feed);
    try {
      final rooms = await _rooms.fetchRooms(
        feed: feed,
        onlyMine: scope == 1 && feed == RoomFeed.latest,
      );
      if (mounted) {
        setState(() {
          _roomData[key] = rooms;
          _loadingKeys[key] = false;
        });
      }
    } catch (error) {
      if (mounted) _show('تعذر تحديث الغرف: $error', error: true);
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _subscription?.cancel();
    _scopeController.dispose();
    for (final controller in _feedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: PageView.builder(
            controller: _scopeController,
            itemCount: 2,
            onPageChanged: (index) {
              setState(() => _scopeIndex = index);
              _activateFeed();
            },
            itemBuilder: (_, index) => _buildScopePage(index),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Material(
      elevation: 2,
      shadowColor: AppColors.primaryDark.withValues(alpha: .18),
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 61,
          child: Row(
            children: [
              const SizedBox(width: 16),
              _ScopeTab(
                label: 'الكل',
                selected: _scopeIndex == 0,
                onTap: () => _selectScope(0),
              ),
              const SizedBox(width: 20),
              _ScopeTab(
                label: 'خاص بي',
                selected: _scopeIndex == 1,
                onTap: () => _selectScope(1),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'قائمة المرتبة',
                onPressed: _showRanking,
                color: Colors.white,
                icon: const Icon(Icons.emoji_events_outlined),
              ),
              IconButton(
                tooltip: 'بحث',
                onPressed: _openSearch,
                color: Colors.white,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'إنشاء غرفة',
                onPressed: _createRoom,
                color: Colors.white,
                icon: const Icon(Icons.add_home_work_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopePage(int scope) {
    return Column(
      children: [
        _buildFeedTabs(scope),
        Expanded(
          child: PageView.builder(
            controller: _feedControllers[scope],
            itemCount: _feedItems.length,
            onPageChanged: (index) {
              setState(() => _feedIndexes[scope] = index);
              if (scope == _scopeIndex) _activateFeed();
            },
            itemBuilder: (_, index) =>
                _buildFeedPage(scope, _feedItems[index].$1),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedTabs(int scope) {
    final selected = _feedIndexes[scope] ?? 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: List.generate(_feedItems.length, (index) {
          final active = selected == index;
          return Expanded(
            child: InkWell(
              onTap: () => _selectFeed(scope, index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  _feedItems[index].$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? AppColors.primaryDark : AppColors.mutedText,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeedPage(int scope, RoomFeed feed) {
    final key = _key(scope, feed);
    final loading = _loadingKeys[key] == true;
    final rooms = scope == _scopeIndex && feed == _activeFeed
        ? _activeRooms
        : _filterRooms(_roomData[key] ?? const <Room>[]);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: scope == _scopeIndex && feed == _activeFeed
          ? _refreshActiveFeed
          : () async {},
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildTopContent()),
          if (loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (rooms.isEmpty)
            SliverFillRemaining(child: _buildEmptyRooms(scope, feed))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 28),
              sliver: SliverList.separated(
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _RoomCard(
                  room: rooms[index],
                  followed: _followedIds.contains(rooms[index].id),
                  onFollow: () => _toggleFollow(rooms[index]),
                  onTap: () {
                    final room = rooms[index];
                    final openRoom = widget.onOpenRoom;
                    if (openRoom != null) {
                      openRoom(room);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomPage(
                            room: room,
                            demoMode: widget.demoMode,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Room> _filterRooms(List<Room> rooms) {
    final query = _searchQuery.trim().toLowerCase();
    return rooms
        .where((room) {
          final matchesCountry = _country == 'ALL' || room.country == _country;
          final matchesSearch =
              query.isEmpty ||
              room.name.toLowerCase().contains(query) ||
              (room.description ?? '').toLowerCase().contains(query);
          return matchesCountry && matchesSearch;
        })
        .toList(growable: false);
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 9),
      child: Column(
        children: [
          _buildBanner(),
          const SizedBox(height: 12),
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
              const SizedBox(width: 10),
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
          const SizedBox(height: 13),
          _buildCountryFilters(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return SizedBox(
      height: 148,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _bannerImages[_bannerIndex],
              key: ValueKey(_bannerIndex),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceElevated,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.secondary,
                  size: 40,
                ),
              ),
            ),
            Positioned(
              bottom: 7,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _bannerImages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _bannerIndex == index ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _bannerIndex == index
                          ? Colors.white
                          : Colors.white60,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        itemCount: _countryFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final (code, label, flag) = _countryFilters[index];
          final selected = _country == code;
          return InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => setState(() => _country = code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
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
                  Text(flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.primaryDark : AppColors.text,
                      fontSize: 11,
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

  Widget _buildEmptyRooms(int scope, RoomFeed feed) {
    final hasFilter = _country != 'ALL' || _searchQuery.isNotEmpty;
    final title = hasFilter
        ? 'لا توجد نتائج'
        : feed == RoomFeed.followed
        ? 'لا توجد غرف متابَعة'
        : feed == RoomFeed.visited
        ? 'لا توجد غرف تمت زيارتها'
        : scope == 1
        ? 'لم تنشئ غرفًا بعد'
        : 'لا توجد غرف حاليًا';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.search_off_rounded : Icons.mic_none_rounded,
              size: 54,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 7),
            Text(
              hasFilter
                  ? 'جرّب تغيير الدولة أو البحث.'
                  : 'أنشئ غرفة صوتية وابدأ مجتمعك الخاص.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
            if (!hasFilter && scope == 1) ...[
              const SizedBox(height: 16),
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

  Future<void> _selectScope(int index) async {
    if (_scopeIndex == index) return;
    await _scopeController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _selectFeed(int scope, int index) async {
    _feedIndexes[scope] = index;
    if (mounted) setState(() {});
    await _feedControllers[scope]!.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
    if (scope == _scopeIndex) _activateFeed();
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _searchQuery);
    final result = await showDialog<String>(
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
    if (result != null && mounted) setState(() => _searchQuery = result);
  }

  Future<void> _createRoom() async {
    if (!widget.demoMode && !AppConfig.isConfigured && mounted) {
      _show('يجب إعداد Supabase وتسجيل الدخول لإنشاء غرفة.', error: true);
      return;
    }
    final room = await Navigator.of(context).push<Room>(
      MaterialPageRoute(
        builder: (_) => CreateRoomPage(demoMode: widget.demoMode),
      ),
    );
    if (room == null || !mounted) return;
    final latestKey = _key(_scopeIndex, _activeFeed);
    setState(() {
      _roomData[latestKey] = [room, ...(_roomData[latestKey] ?? const [])];
    });
    _show('تم إنشاء الغرفة رقم ${room.roomNumber ?? 'الجديد'} بنجاح.');
  }

  Future<void> _toggleFollow(Room room) async {
    if (widget.demoMode || !AppConfig.isConfigured) {
      setState(() {
        if (_followedIds.contains(room.id)) {
          _followedIds.remove(room.id);
        } else {
          _followedIds.add(room.id);
        }
      });
      return;
    }
    try {
      final followed = await _rooms.toggleRoomFollow(room.id);
      if (!mounted) return;
      setState(() {
        if (followed) {
          _followedIds.add(room.id);
        } else {
          _followedIds.remove(room.id);
        }
      });
      if (_activeFeed == RoomFeed.followed && !followed) {
        await _refreshActiveFeed();
      }
    } catch (error) {
      if (mounted) {
        _show(
          error.toString().replaceFirst('AuthException: ', ''),
          error: true,
        );
      }
    }
  }

  void _showRanking() =>
      _show('قائمة المرتبة ستعرض الغرف والمستخدمين الأكثر نشاطًا.');

  void _show(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
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
          height: 56,
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
                child: Icon(icon, size: 46, color: Colors.white30),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
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
  const _RoomCard({
    required this.room,
    required this.followed,
    required this.onFollow,
    required this.onTap,
  });

  final Room room;
  final bool followed;
  final VoidCallback onFollow;
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
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0F0F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoomCover(room: room),
              const SizedBox(width: 11),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _countryFlag(room.country),
                            style: const TextStyle(fontSize: 18),
                          ),
                          IconButton(
                            onPressed: onFollow,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 26,
                              height: 26,
                            ),
                            splashRadius: 18,
                            tooltip: followed
                                ? 'إلغاء المتابعة'
                                : 'متابعة الغرفة',
                            icon: Icon(
                              followed ? Icons.favorite : Icons.favorite_border,
                              color: followed
                                  ? AppColors.danger
                                  : const Color(0xFFD1D5DB),
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tagColors.$1,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tag.$2, size: 11, color: tagColors.$2),
                                const SizedBox(width: 3),
                                Text(
                                  tag.$1,
                                  style: TextStyle(
                                    color: tagColors.$2,
                                    fontSize: 9,
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
                          const Icon(
                            Icons.bar_chart_rounded,
                            size: 15,
                            color: Color(0xFF2DD4BF),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${room.memberCount}',
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 10,
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
            size: 16,
            color: AppColors.mutedText,
          ),
          const SizedBox(width: 4),
          Text(
            '${room.memberCount} متواجد',
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: math.min(78, room.participantAvatars.length * 19.0 + 22),
      height: 24,
      child: Stack(
        children: room.participantAvatars
            .take(4)
            .toList()
            .asMap()
            .entries
            .map(
              (entry) => Positioned(
                right: entry.key * 17,
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
                          size: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final progress = (_controller.value * math.pi * 2) + index * .7;
            final height = 4 + 10 * ((math.sin(progress) + 1) / 2);
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
