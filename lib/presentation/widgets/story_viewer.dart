import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              final photoUrl = (photo['imageUrl'] ?? photo['url'] ?? '') as String;
              final displayName = (photo['displayName'] ?? 'Unknown') as String;
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
                        CircleAvatar(
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
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
