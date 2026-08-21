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
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'اللحظات',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'الرسائل',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.small(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('سيتم تفعيل الإنشاء بعد ربط حساب Supabase.'),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
