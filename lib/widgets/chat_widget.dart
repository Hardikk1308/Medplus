import 'package:flutter/material.dart';
import 'package:medplus/pages/chat/chat_screen.dart';

class ChatWidget extends StatelessWidget {
  const ChatWidget({super.key});
               
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            bottom: 20 + bottomInset,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                debugPrint('ChatWidget: Navigating to ChatScreen');
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
              },
              backgroundColor: const Color.fromARGB(255, 113, 158, 255),
              child: const Icon(Icons.chat, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
