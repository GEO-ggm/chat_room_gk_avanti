import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'feature/chat/chat_screen.dart';

void main() {
  runApp(const ProviderScope(child: ChatApp()));
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat room1',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const ChatScreen(),
    );
  }
}
