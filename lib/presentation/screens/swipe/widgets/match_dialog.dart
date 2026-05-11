import 'package:flutter/material.dart';
import 'package:vasco/presentation/screens/chat/chat_screen.dart';

class MatchDialog extends StatelessWidget {
  final String currentUserId;
  final String currentUserPhoto;
  final Map<String, dynamic> matchedUser;
  final String conversationId;

  const MatchDialog({
    super.key,
    required this.currentUserId,
    required this.currentUserPhoto,
    required this.matchedUser,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    final matchedName = matchedUser['displayName'] ?? 'Utilizator';
    final matchedPhoto = matchedUser['photoUrl'] as String?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "It's a Match!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu și $matchedName v-ați apreciat reciproc',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Pozele ambilor useri
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _avatar(currentUserPhoto, border: const Color(0xFF818CF8)),
                  const SizedBox(width: 24),
                  const Text('❤️', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 24),
                  _avatar(matchedPhoto, border: const Color(0xFFF472B6)),
                ],
              ),

              const SizedBox(height: 56),

              // Buton trimite mesaj
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: conversationId,
                            currentUserId: currentUserId,
                            otherUserId: matchedUser['id'],
                            otherUserName: matchedName,
                            otherUserPhoto: matchedPhoto,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Trimite un mesaj 💬',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Continuă să explorezi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String? photoUrl, {required Color border}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
        color: Colors.white.withValues(alpha: 0.2),
      ),
      child: CircleAvatar(
        radius: 60,
        backgroundImage:
            photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        backgroundColor: Colors.white24,
        child: photoUrl == null || photoUrl.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 50)
            : null,
      ),
    );
  }
}
