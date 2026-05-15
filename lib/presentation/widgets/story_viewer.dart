import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/core/utils/coauthor_names.dart';
import 'package:vasco/presentation/providers/domain/user_provider.dart';
import 'package:vasco/presentation/screens/profile/profile_page.dart';
import 'package:vasco/presentation/screens/profile/user_profile_screen.dart';

/// Full-screen story viewer with progress bar, avatar header,
/// Firestore timestamp support, and interactive zoom.
///
/// Merged from lib/widget/story_viewer.dart (complete UI) and
/// lib/widgets/story_viewer.dart (InteractiveViewer).
class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  final List<Map<String, dynamic>> photos;
  final int initialIndex;

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, List<String>> _coAuthorIds = {};
  final Map<int, List<String>> _coAuthorNames = {};
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _resolveCoAuthorsFor(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _resolveCoAuthorsFor(int index) async {
    if (index < 0 || index >= widget.photos.length) return;
    if (_coAuthorIds.containsKey(index)) return;
    final raw = widget.photos[index]['acceptedCoAuthorIds'];
    if (raw is! List || raw.isEmpty) {
      _coAuthorIds[index] = const [];
      _coAuthorNames[index] = const [];
      return;
    }
    final ids = raw.whereType<String>().toList();
    _coAuthorIds[index] = ids;
    final names = await CoAuthorNames.resolve(ids);
    if (mounted) setState(() => _coAuthorNames[index] = names);
  }

  void _openUserProfile(String uid, {String? name, String? photoUrl}) {
    if (uid.isEmpty) return;
    final currentUserId = context.read<UserProvider>().user?.id;
    Navigator.pop(context); // close the story viewer first
    final navigator = Navigator.of(context, rootNavigator: false);
    if (uid == currentUserId) {
      navigator.push(MaterialPageRoute(
        builder: (_) => const ProfileScreen(showBackButton: true),
      ));
    } else {
      navigator.push(MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: uid,
          initialDisplayName: name,
          initialPhotoUrl: (photoUrl?.isNotEmpty == true) ? photoUrl : null,
        ),
      ));
    }
  }

  TapGestureRecognizer _newRecognizer(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  Widget _buildAuthorsRichText({
    required int index,
    required String creatorName,
    required String creatorUid,
    required String creatorPhotoUrl,
  }) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final ids = _coAuthorIds[index] ?? const <String>[];
    final names = _coAuthorNames[index] ?? const <String>[];

    const linkStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    const separatorStyle = TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w500,
      fontSize: 14,
    );

    final spans = <InlineSpan>[
      TextSpan(
        text: creatorName,
        style: linkStyle,
        recognizer: _newRecognizer(() => _openUserProfile(
              creatorUid,
              name: creatorName,
              photoUrl: creatorPhotoUrl,
            )),
      ),
    ];

    if (ids.isNotEmpty) {
      final maxNames = ids.length > 2 ? 1 : ids.length;
      spans.add(const TextSpan(text: ' & ', style: separatorStyle));
      for (var i = 0; i < maxNames; i++) {
        final uid = ids[i];
        final name = i < names.length ? names[i] : 'User';
        if (i > 0) {
          spans.add(const TextSpan(text: ', ', style: separatorStyle));
        }
        spans.add(TextSpan(
          text: name,
          style: linkStyle,
          recognizer: _newRecognizer(() => _openUserProfile(uid, name: name)),
        ));
      }
      if (ids.length > maxNames) {
        spans.add(TextSpan(
          text: ' +${ids.length - maxNames}',
          style: separatorStyle,
        ));
      }
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              _resolveCoAuthorsFor(i);
            },
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              final photoUrl = (photo['imageUrl'] ?? photo['url'] ?? '') as String;
              final creatorName = (photo['displayName'] ?? 'Unknown') as String;
              final creatorUid = (photo['userId'] ?? '') as String;
              final userPhotoUrl = (photo['userPhotoUrl'] ?? '') as String;
              final createdAt = photo['createdAt'];

              String timeStr = '';
              if (createdAt != null) {
                try {
                  final dt = (createdAt as Timestamp).toDate();
                  timeStr =
                      '${dt.day}.${dt.month}.${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                } catch (_) {}
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Photo
                  photoUrl.isNotEmpty
                      ? InteractiveViewer(
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              );
                            },
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white, size: 64),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white, size: 64),
                        ),

                  // Top gradient
                  Positioned(
                    top: 0, left: 0, right: 0, height: 130,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                  // Bottom gradient
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 140,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                  // Progress bar
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8, right: 8,
                    child: Row(
                      children: List.generate(widget.photos.length, (i) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 3,
                            decoration: BoxDecoration(
                              color: i <= _currentIndex
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Avatar + name + timestamp
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 22,
                    left: 16, right: 48,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openUserProfile(
                            creatorUid,
                            name: creatorName,
                            photoUrl: userPhotoUrl,
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: userPhotoUrl.isNotEmpty
                                ? NetworkImage(userPhotoUrl)
                                : null,
                            backgroundColor: Colors.grey.shade700,
                            child: userPhotoUrl.isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAuthorsRichText(
                                index: index,
                                creatorName: creatorName,
                                creatorUid: creatorUid,
                                creatorPhotoUrl: userPhotoUrl,
                              ),
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 18,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                    ),
                  ),

                  // Counter
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 0, right: 0,
                    child: Center(
                      child: Text(
                        '${_currentIndex + 1} / ${widget.photos.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
