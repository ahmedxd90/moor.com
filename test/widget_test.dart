import 'package:flutter_test/flutter_test.dart';

import 'package:saki_chat_flutter/main.dart';
import 'package:saki_chat_flutter/features/home/presentation/home_shell.dart';

void main() {
  testWidgets('Saki Chat renders HomeShell in demo mode', (tester) async {
    await tester.pumpWidget(const SakiChatApp(demoMode: true));
    await tester.pump();

    expect(find.byType(HomeShell), findsOneWidget);
  });
}
