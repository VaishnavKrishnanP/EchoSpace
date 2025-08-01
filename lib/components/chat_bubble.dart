import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../themes/theme_provider.dart';

class ChatBubble extends StatelessWidget {
  final String name;
  final String message;
  final bool isCurrentUser;
  final bool isFirstMessage;
  final String time;

  const ChatBubble({
    super.key,
    required this.name,
    required this.message,
    required this.isCurrentUser,
    required this.isFirstMessage,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final Color messageColor = isCurrentUser
        ? Provider.of<ThemeProvider>(context, listen: false).accentColor
        : Colors.grey.shade700;

    return Row(
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCurrentUser) // Left-side pointer for received messages
          SizedBox(
            width: 10,
            height: 20,
            child: CustomPaint(
              painter:
                  ChatBubblePointer(color: messageColor, isCurrentUser: false,isFirstMessage :isFirstMessage),
            ),
          ),

        // Message Container
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: messageColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment:
                isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isFirstMessage && !isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Provider.of<ThemeProvider>(context, listen: false)
                          .accentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),

        if (isCurrentUser) // Right-side pointer for sent messages
          SizedBox(
            width: 10,
            height: 20,
            child: CustomPaint(
              painter:
                  ChatBubblePointer(color: messageColor, isCurrentUser: true,isFirstMessage: isFirstMessage),
            ),
          ),
      ],
    );
  }
}


class ChatBubblePointer extends CustomPainter {
  final Color color;
  final bool isCurrentUser;
  final bool isFirstMessage;

  ChatBubblePointer({required this.color, required this.isCurrentUser,required this.isFirstMessage,});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path();

     if (isFirstMessage) {
      if (isCurrentUser) {
        // Right-side pointer (outgoing first message)
        path.moveTo(10.0, 0.0);  // Use .0 to ensure double
        path.lineTo(-10.0, 0.0);
        path.lineTo(-5.0, 20.0);
      } else {
        // Left-side pointer (incoming first message)
        path.moveTo(20.0, 0.0);
        path.lineTo(0.0, 0.0);
        path.lineTo(20.0, 20.0);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}