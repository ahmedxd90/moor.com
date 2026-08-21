import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
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
  List<Room> _items = [];
  bool _loading = true;
  String _category = 'الكل';

  final _demoRooms = const [
    Room(
      id: 'demo-music',
      ownerId: 'demo-owner',
      name: 'ليالي السمر',
      description: 'غرفة موسيقى وأصدقاء',
      roomTheme: 'music',
      memberCount: 128,
      likesCount: 320,
      isLive: true,
      country: 'SA',
    ),
    Room(
      id: 'demo-games',
      ownerId: 'demo-owner',
      name: 'تحدي الأصدقاء',
      description: 'ألعاب ومسابقات يومية',
      roomTheme: 'games',
      memberCount: 76,
      likesCount: 180,
      isLive: true,
      country: 'KW',
    ),
    Room(
      id: 'demo-chat',
      ownerId: 'demo-owner',
      name: 'جلسة هادئة',
      description: 'تعارف ودردشة محترمة',
      roomTheme: 'radio',
      memberCount: 42,
      likesCount: 95,
      isLive: false,
      country: 'AE',
    ),
    Room(
      id: 'demo-vip',
      ownerId: 'demo-owner',
      name: 'القاعة الملكية',
      description: 'غرفة خاصة للأعضاء',
      roomTheme: 'royal',
      memberCount: 18,
      likesCount: 66,
      isLive: true,
      isLocked: true,
      country: 'QA',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    try {
      _items = widget.demoMode ? _demoRooms : await _rooms.fetchRooms();
    } catch (_) {
      _items = widget.demoMode ? _demoRooms : [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _category == 'الكل'
        ? _items
        : _items.where((room) => room.roomTheme == _category).toList();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadRooms,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 164,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'مرحبًا بك في',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Saki Chat',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/saki-icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('البحث سيكون متاحًا مع صفحة البحث الجديدة.'),
                  ),
                ),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34205C), Color(0xFF1D244A)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: .35),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.mic_external_on,
                          color: AppColors.secondary,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اكتشف غرفًا جديدة',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'انضم إلى الأصدقاء وشارك صوتك ولحظاتك.',
                                style: TextStyle(
                                  color: AppColors.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: AppColors.mutedText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['الكل', 'music', 'games', 'radio', 'royal']
                          .map((category) {
                            return Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text(
                                  category == 'الكل'
                                      ? category
                                      : _label(category),
                                ),
                                selected: _category == category,
                                onSelected: (_) =>
                                    setState(() => _category = category),
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                labelStyle: TextStyle(
                                  color: _category == category
                                      ? AppColors.white
                                      : AppColors.mutedText,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SakiSectionTitle(
                    title: 'الغرف النشطة',
                    actionLabel: 'تحديث',
                    onAction: _loadRooms,
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (filtered.isEmpty)
            const SliverFillRemaining(
              child: SakiEmptyState(
                title: 'لا توجد غرف حاليًا',
                subtitle: 'أنشئ أول غرفة وابدأ مجتمعك الخاص.',
                icon: Icons.mic_none,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _RoomCard(
                  room: filtered[index],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoomPage(
                        room: filtered[index],
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

  String _label(String value) => switch (value) {
    'music' => 'موسيقى',
    'games' => 'ألعاب',
    'radio' => 'راديو',
    'royal' => 'ملكية',
    _ => value,
  };
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeColors = switch (room.roomTheme) {
      'games' => const [Color(0xFF0E7490), Color(0xFF164E63)],
      'royal' => const [Color(0xFF854D0E), Color(0xFF451A03)],
      'radio' => const [Color(0xFF4338CA), Color(0xFF1E1B4B)],
      _ => const [Color(0xFF7E22CE), Color(0xFF312E81)],
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeColors,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.white.withValues(alpha: .12)),
          boxShadow: [
            BoxShadow(
              color: themeColors.first.withValues(alpha: .18),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                room.isLocked ? Icons.lock_outline : Icons.mic,
                color: AppColors.secondary,
                size: 30,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.description ?? 'غرفة صوتية جديدة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: .72),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 15,
                        color: AppColors.white.withValues(alpha: .72),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.memberCount}',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: .82),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.favorite_border,
                        size: 15,
                        color: AppColors.white.withValues(alpha: .72),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room.likesCount}',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: .82),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (room.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'مباشر',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                const Spacer(),
                const Icon(Icons.chevron_left, color: AppColors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
