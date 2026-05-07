import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/widgets/comments_sheet.dart';

class PostStoryViewer extends StatefulWidget {
  final List<QueryDocumentSnapshot> docs;
  final int initialIndex;
  final String collection;

  const PostStoryViewer({
    super.key,
    required this.docs,
    required this.initialIndex,
    this.collection = 'location_photos',
  });

  @override
  State<PostStoryViewer> createState() => _PostStoryViewerState();
}

class _PostStoryViewerState extends State<PostStoryViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

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

  void _goTo(int index) {
    if (index < 0 || index >= widget.docs.length) {
      Navigator.pop(context);
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Paginile cu poze
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: widget.docs.length,
            itemBuilder: (_, i) => _StoryPage(
              doc: widget.docs[i],
              collection: widget.collection,
              onTapLeft: () => _goTo(_currentIndex - 1),
              onTapRight: () => _goTo(_currentIndex + 1),
            ),
          ),

          // Bara de progres (sus)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 56, 0),
                child: Row(
                  children: List.generate(widget.docs.length, (i) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: i <= _currentIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          // Buton închidere
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── O singură pagină de story ────────────────────────────────────────────────

class _StoryPage extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String collection;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;

  const _StoryPage({
    required this.doc,
    required this.collection,
    required this.onTapLeft,
    required this.onTapRight,
  });

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage> {
  bool _isLiking = false;

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    const months = [
      'Ian', 'Feb', 'Mar', 'Apr', 'Mai', 'Iun',
      'Iul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _toggleLike(String docId, String currentUserId) async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('toggleLike')
          .call({'postId': docId, 'collection': widget.collection});
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _openComments(BuildContext context, String docId, String currentUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: docId,
        collection: widget.collection,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final docId = widget.doc.id;
    final currentUserId = context.read<UserProvider>().user?.id ?? '';

    final imageUrl = data['imageUrl'] as String? ?? '';
    final location = data['locationName'] as String? ??
        data['countryName'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final displayName = data['displayName'] as String? ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Imagine ────────────────────────────────────────────────────────
        imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.black38,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                errorBuilder: (context2, e, _) => Container(
                  color: Colors.black38,
                  child: const Icon(Icons.broken_image_rounded,
                      color: Colors.white38, size: 64),
                ),
              )
            : Container(color: Colors.black38),

        // ── Gradient sus ───────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 140,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Gradient jos ───────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.82),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Zone tap stânga / dreapta (nu acoperă bara de sus/jos) ─────────
        Positioned(
          top: 80,
          bottom: 90,
          left: 0,
          right: 0,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onTapLeft,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onTapRight,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),

        // ── Info sus (sub bara de progres) ─────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 56, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (displayName.isNotEmpty)
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (location.isNotEmpty) ...[
                        const Icon(Icons.location_on_rounded,
                            color: Colors.white70, size: 12),
                        const SizedBox(width: 3),
                        Text(location,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Acțiuni jos (like + comentarii) ───────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  // Like
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(widget.collection)
                        .doc(docId)
                        .collection('likes')
                        .doc(currentUserId)
                        .snapshots(),
                    builder: (_, likeSnap) {
                      final isLiked = likeSnap.data?.exists ?? false;
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(widget.collection)
                            .doc(docId)
                            .snapshots(),
                        builder: (_, postSnap) {
                          final d = postSnap.data?.data()
                              as Map<String, dynamic>?;
                          final count = d?['likesCount'] ?? 0;
                          return GestureDetector(
                            onTap: () =>
                                _toggleLike(docId, currentUserId),
                            child: Row(
                              children: [
                                AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  child: Icon(
                                    isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    key: ValueKey(isLiked),
                                    color: isLiked
                                        ? const Color(0xFFEF4444)
                                        : Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(width: 24),

                  // Comentarii
                  GestureDetector(
                    onTap: () =>
                        _openComments(context, docId, currentUserId),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(widget.collection)
                          .doc(docId)
                          .snapshots(),
                      builder: (_, snap) {
                        final d =
                            snap.data?.data() as Map<String, dynamic>?;
                        final count = d?['commentsCount'] ?? 0;
                        return Row(
                          children: [
                            const Icon(Icons.chat_bubble_rounded,
                                color: Colors.white, size: 26),
                            const SizedBox(width: 6),
                            Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
