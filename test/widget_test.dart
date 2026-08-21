import 'package:flutter_test/flutter_test.dart';

import 'package:saki_chat_flutter/main.dart';

void main() {
  testWidgets('Saki Chat app renders the login shell', (tester) async {
    await tester.pumpWidget(const SakiChatApp());
    await tester.pump();

    expect(find.text('Saki'), findsOneWidget);
  });
}
