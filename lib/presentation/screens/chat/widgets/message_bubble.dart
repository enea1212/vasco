import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/models/message_model.dart';

/// Widget for an individual message bubble.
/// Receives [msg], [isMe] and [showTime] as parameters.
class MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final bool showTime;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.showTime,
  });

  String _formatLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return time;
    if (diff == 1) return 'Yesterday · $time';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[dt.month - 1];

    if (dt.year == now.year) return '${dt.day} $month · $time';
    return '${dt.day} $month ${dt.year} · $time';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showTime)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              _formatLabel(msg.createdAt),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe ? null : AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
