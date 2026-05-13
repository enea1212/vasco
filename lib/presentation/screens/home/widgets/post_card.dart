import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:vasco/presentation/screens/profile/profile_page.dart';
import 'package:vasco/presentation/screens/profile/user_profile_screen.dart';
import 'package:vasco/services/geocoding_service.dart';
import 'package:vasco/presentation/widgets/comments_sheet.dart';
import 'package:vasco/core/constants/app_colors.dart';

// ─── Card individual cu geocoding lazy + cache ────────────────────────────────

class PostCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String currentUserId;

  const PostCard({
    super.key,
    required this.docId,
    required this.data,
    required this.currentUserId,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static final Map<String, String> _geoCache = {};
  String? _locationLabel;
  bool _isLiking = false;
  Stream<DocumentSnapshot>? _likeStream;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
    if (widget.currentUserId.isNotEmpty) {
      _likeStream = FirebaseFirestore.instance
          .collection('location_photos')
          .doc(widget.docId)
          .collection('likes')
          .doc(widget.currentUserId)
          .snapshots();
    }
  }

  Future<void> _resolveLocation() async {
    final d = widget.data;
    final stored = d['locationName'] as String? ?? d['countryName'] as String?;
    if (stored != null && stored.isNotEmpty) {
      if (mounted) setState(() => _locationLabel = stored);
      return;
    }
    final lat = (d['latitude'] as num?)?.toDouble();
    final lng = (d['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      if (mounted) setState(() => _locationLabel = 'Location');
      return;
    }
    final key = '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
    if (_geoCache.containsKey(key)) {
      if (mounted) setState(() => _locationLabel = _geoCache[key]);
      return;
    }
    final result = await GeocodingService.reverseGeocode(lat, lng);
    final label = result ?? 'Location';
    _geoCache[key] = label;
    if (mounted) setState(() => _locationLabel = label);
  }

  Future<void> _toggleLike(String currentUserId) async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('toggleLike').call({
        'postId': widget.docId,
        'collection': 'location_photos',
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _openComments(BuildContext context, String currentUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        postId: widget.docId,
        collection: 'location_photos',
        currentUserId: currentUserId,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLikers() async {
    final likesSnap = await FirebaseFirestore.instance
        .collection('location_photos')
        .doc(widget.docId)
        .collection('likes')
        .get();
    final result = <Map<String, dynamic>>[];
    for (final likeDoc in likesSnap.docs) {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(likeDoc.id)
          .get();
      if (userSnap.exists) {
        final u = userSnap.data() as Map<String, dynamic>;
        result.add({
          'userId': likeDoc.id,
          'displayName': u['displayName'] ?? u['display_name'] ?? 'User',
          'photoUrl': u['photoUrl'] ?? u['photo_url'],
        });
      }
    }
    return result;
  }

  void _showLikers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Likes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchLikers(),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    final likers = snap.data ?? [];
                    if (likers.isEmpty) {
                      return const Center(
                        child: Text(
                          'No likes yet.',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: likers.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 60),
                      itemBuilder: (_, i) {
                        final liker = likers[i];
                        final photo = liker['photoUrl'] as String?;
                        final name =
                            liker['displayName'] as String? ?? 'User';
                        final likerId = liker['userId'] as String? ?? '';
                        return GestureDetector(
                          onTap: likerId.isNotEmpty
                              ? () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserProfileScreen(
                                        userId: likerId,
                                        initialDisplayName: name,
                                        initialPhotoUrl: photo,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: photo != null
                                      ? NetworkImage(photo)
                                      : null,
                                  backgroundColor: AppColors.surfaceAlt,
                                  child: photo == null
                                      ? const Icon(
                                          Icons.person_rounded,
                                          color: AppColors.textHint,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.divider,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final imageUrl = d['imageUrl'] as String? ?? '';
    final displayName = d['displayName'] as String? ?? 'User';
    final userPhotoUrl = d['userPhotoUrl'] as String? ?? '';
    final createdAt = d['createdAt'] as Timestamp?;
    final locationLabel = _locationLabel;
    final timeLabel = _timeAgo(createdAt);
    final currentUserId = widget.currentUserId;
    final postUserId = d['userId'] as String? ?? '';
    final spotifySong = d['spotifySong'] as String?;
    final spotifyArtist = d['spotifyArtist'] as String? ?? '';
    final spotifyAlbumArt = d['spotifyAlbumArt'] as String? ?? '';

    if (currentUserId.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (postUserId.isNotEmpty) {
                      if (postUserId == currentUserId) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ProfileScreen(showBackButton: true),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: postUserId,
                              initialDisplayName: displayName,
                              initialPhotoUrl: userPhotoUrl.isNotEmpty
                                  ? userPhotoUrl
                                  : null,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Row(
                    children: [
                      // Avatar cu border gradient
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.igOrange,
                              AppColors.igRed,
                              AppColors.igPurple,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(1.5),
                          child: CircleAvatar(
                            radius: 15,
                            backgroundImage: userPhotoUrl.isNotEmpty
                                ? NetworkImage(userPhotoUrl)
                                : null,
                            backgroundColor: AppColors.surfaceAlt,
                            child: userPhotoUrl.isEmpty
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.textHint,
                                    size: 16,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (locationLabel != null)
                              Text(
                                locationLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ],
          ),
        ),

        // ── Imagine full-width ─────────────────────────────────────────────
        Stack(
          children: [
            imageUrl.isNotEmpty
                ? _CachedBlurImage(imageUrl: imageUrl)
                : _placeholder(),
            if (spotifySong != null)
              Positioned(
                bottom: 10,
                left: 10,
                right: 60,
                child: _MusicBadge(
                  songName: spotifySong,
                  artistName: spotifyArtist,
                  albumArtUrl: spotifyAlbumArt,
                ),
              ),
          ],
        ),

        // ── Acțiuni + statistici ───────────────────────────────────────────
        StreamBuilder<DocumentSnapshot>(
          stream: _likeStream,
          builder: (_, likeSnap) {
            final isLiked = likeSnap.data?.exists ?? false;
            final likesCount = (d['likesCount'] as num?)?.toInt() ?? 0;
            final commentsCount = (d['commentsCount'] as num?)?.toInt() ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Butoane acțiuni
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleLike(currentUserId),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(isLiked),
                            size: 28,
                            color: isLiked
                                ? AppColors.danger
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _openComments(context, currentUserId),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 26,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Număr aprecieri (tap → cine a dat like)
                if (likesCount > 0)
                  GestureDetector(
                    onTap: () => _showLikers(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Text(
                        '$likesCount likes',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                // Comentarii count
                if (commentsCount > 0)
                  GestureDetector(
                    onTap: () => _openComments(context, currentUserId),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
                      child: Text(
                        'View all $commentsCount comments',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),

                // Timestamp
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const Divider(height: 0.5, thickness: 0.5),
      ],
    );
  }

  Widget _placeholder() => Container(
    height: 360,
    color: AppColors.surfaceAlt,
    child: const Center(
      child: Icon(
        Icons.image_rounded,
        size: 52,
        color: AppColors.textHint,
      ),
    ),
  );
}

// ─── Cached blur image ────────────────────────────────────────────────────────

class _CachedBlurImage extends StatelessWidget {
  final String imageUrl;

  const _CachedBlurImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width.toInt();
    return AspectRatio(
      aspectRatio: 1,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: w,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        imageBuilder: (context, imageProvider) => Image(
          image: imageProvider,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
        placeholder: (context, url) => Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.border,
                      AppColors.surfaceAlt,
                      AppColors.divider,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.surfaceAlt,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              size: 42,
              color: AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Music badge (BeReal-style Spotify) ──────────────────────────────────────

class _MusicBadge extends StatelessWidget {
  final String songName;
  final String artistName;
  final String albumArtUrl;

  const _MusicBadge({
    required this.songName,
    required this.artistName,
    required this.albumArtUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: albumArtUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: albumArtUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _albumPlaceholder(),
                    errorWidget: (_, _, _) => _albumPlaceholder(),
                  )
                : _albumPlaceholder(),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  songName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (artistName.isNotEmpty)
                  Text(
                    artistName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.music_note_rounded,
            color: AppColors.greenSpotify,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _albumPlaceholder() => Container(
    width: 36,
    height: 36,
    color: AppColors.textSecondary,
    child: const Icon(
      Icons.music_note_rounded,
      color: AppColors.textHint,
      size: 18,
    ),
  );
}
