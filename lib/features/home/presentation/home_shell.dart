import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../messages/presentation/messages_page.dart';
import '../../moments/presentation/moments_page.dart';
import '../../profile/presentation/profile_page.dart';
import 'home_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(demoMode: widget.demoMode),
      MomentsPage(demoMode: widget.demoMode),
      MessagesPage(demoMode: widget.demoMode),
      ProfilePage(demoMode: widget.demoMode),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BottomNavigation(
        selectedIndex: _index,
        onSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.house_rounded, 'الرئيسية'),
    (Icons.explore_rounded, 'اللحظات'),
    (Icons.chat_bubble_rounded, 'الرسائل'),
    (Icons.person_rounded, 'أنا'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            _items.length,
            (index) => _BottomNavItem(
              icon: _items[index].$1,
              label: _items[index].$2,
              selected: selectedIndex == index,
              showBadge: index == 2,
              onTap: () => onSelected(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showBadge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xFF9CA3AF);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 21),
                if (showBadge)
                  Positioned(
                    top: -3,
                    right: -5,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
