import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vasco/utils/scroll_utils.dart';
import 'package:vasco/providers/friends_provider.dart';
import 'package:vasco/providers/user_provider.dart';
import 'package:vasco/repository/edit_profile.dart';
import 'package:vasco/repository/messaging_repository.dart';
import 'package:vasco/screens/chat_screen.dart';
import 'package:vasco/screens/map_page.dart';
import 'package:vasco/widgets/post_story_viewer.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialDisplayName;
  final String? initialPhotoUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialDisplayName,
    this.initialPhotoUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _loadingUser = true;
  bool _friendActionLoading = false;
  bool _hasPendingRequest = false;
  Stream<QuerySnapshot>? _photosStream;

  @override
  void initState() {
    super.initState();
    _photosStream = FirebaseFirestore.instance
        .collection('location_photos')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkPendingRequest();
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([_loadUserData(), _checkPendingRequest()]);
    if (mounted) {
      setState(() {
        _photosStream = FirebaseFirestore.instance
            .collection('location_photos')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('createdAt', descending: true)
            .snapshots();
      });
    }
  }

  Future<void> _checkPendingRequest() async {
    if (!mounted) return;
    final currentUserId = context.read<UserProvider>().user?.id ?? '';
    if (currentUserId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (mounted) setState(() => _hasPendingRequest = snap.docs.isNotEmpty);
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (mounted) {
        setState(() {
          _userData = userDoc.data();
          _loadingUser = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  String get _displayName =>
      _userData?['displayName'] as String? ??
      _userData?['display_name'] as String? ??
      widget.initialDisplayName ??
      'Utilizator';

  String? get _photoUrl =>
      _userData?['photoUrl'] as String? ??
      _userData?['photo_url'] as String? ??
      widget.initialPhotoUrl;

  int get _countriesCount =>
      (_userData?['shared_countries'] as List?)?.length ?? 0;

  Future<void> _sendFriendRequest() async {
    if (_friendActionLoading) return;
    setState(() => _friendActionLoading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('sendFriendRequest').call({
        'toUserId': widget.userId,
      });
      if (mounted) {
        setState(() => _hasPendingRequest = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cerere de prietenie trimisă!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la trimiterea cererii.')),
        );
      }
    } finally {
      if (mounted) setState(() => _friendActionLoading = false);
    }
  }

  Future<void> _cancelFriendRequest() async {
    if (_friendActionLoading) return;
    setState(() => _friendActionLoading = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('cancelFriendRequest')
          .call({'toUserId': widget.userId});
      if (mounted) setState(() => _hasPendingRequest = false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la anularea cererii.')),
        );
      }
    } finally {
      if (mounted) setState(() => _friendActionLoading = false);
    }
  }

  Future<void> _goToChat(String currentUserId) async {
    if (_friendActionLoading || currentUserId.isEmpty) return;
    setState(() => _friendActionLoading = true);
    try {
      final convId = await MessagingRepository().getOrCreateConversation(
        currentUserId,
        widget.userId,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              currentUserId: currentUserId,
              otherUserId: widget.userId,
              otherUserName: _displayName,
              otherUserPhoto: _photoUrl,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la deschiderea chat-ului.')),
        );
      }
    } finally {
      if (mounted) setState(() => _friendActionLoading = false);
    }
  }

  Future<void> _removeFriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Elimini prietenul?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nu'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Da'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true || _friendActionLoading) return;

    setState(() => _friendActionLoading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('removeFriend').call({
        'friendId': widget.userId,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Prieten eliminat.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Eroare.')));
      }
    } finally {
      if (mounted) setState(() => _friendActionLoading = false);
    }
  }

  bool get _isPrivate => _userData?['isPrivate'] as bool? ?? false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserProvider>().user?.id ?? '';
    final isOwnProfile = widget.userId == currentUserId;
    final friends = context.watch<FriendsProvider>().friends;
    final isFriend = friends.any((f) => f.id == widget.userId);
    final isLocked = !_loadingUser && _isPrivate && !isOwnProfile && !isFriend;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isLocked
          ? ScrollConfiguration(
              behavior: const NoGlowScrollBehavior(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: _onRefresh,
                    refreshTriggerPullDistance: 36,
                    refreshIndicatorExtent: 30,
                    builder: buildPullRefreshIndicator,
                  ),
                  SliverToBoxAdapter(child: _buildHeader(isFriend, isOwnProfile)),
                  SliverToBoxAdapter(child: _buildLockedPlaceholder()),
                  const SliverToBoxAdapter(child: SizedBox(height: 60)),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _photosStream,
              builder: (context, photosSnap) {
                final photoDocs = photosSnap.data?.docs ?? [];
                return ScrollConfiguration(
                  behavior: const NoGlowScrollBehavior(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
                    ),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: _onRefresh,
                        refreshTriggerPullDistance: 36,
                        refreshIndicatorExtent: 30,
                        builder: buildPullRefreshIndicator,
                      ),
                      SliverToBoxAdapter(
                        child: _buildHeader(isFriend, isOwnProfile),
                      ),
                      SliverToBoxAdapter(child: _buildStats(photoDocs.length)),
                      SliverToBoxAdapter(child: _buildPhotosSection(photoDocs)),
                      const SliverToBoxAdapter(child: SizedBox(height: 60)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLockedPlaceholder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 8),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Color(0xFF9CA3AF),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cont privat',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adaugă-l ca prieten pentru a-i\nvedea profilul.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isFriend, bool isOwnProfile) {
    final initials = _displayName
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    final username = '@${_displayName.toLowerCase().replaceAll(' ', '_')}';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Avatar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundImage: (_photoUrl?.isNotEmpty == true)
                      ? NetworkImage(_photoUrl!)
                      : null,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: (_photoUrl == null || _photoUrl!.isEmpty)
                      ? Text(
                          initials.isEmpty ? 'U' : initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              _displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              username,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            // Buton acțiune
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: isOwnProfile
                  ? OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Editează profilul',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    )
                  : _friendActionLoading
                  ? const SizedBox(
                      height: 44,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : isFriend
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _removeFriend,
                            icon: const Icon(
                              Icons.person_remove_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Unfriend',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _goToChat(
                              context.read<UserProvider>().user?.id ?? '',
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 15),
                            label: const Text('Mesaj'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF4F46E5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _hasPendingRequest
                  ? OutlinedButton.icon(
                      onPressed: _cancelFriendRequest,
                      icon: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Cerere trimisă',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _sendFriendRequest,
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Adaugă prieten'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                    ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(int photosCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapPage(userId: widget.userId),
                ),
              ),
              child: _StatCard(
                icon: Icons.public_rounded,
                iconColor: const Color(0xFF4F46E5),
                iconBg: const Color(0xFFEEF2FF),
                value: _loadingUser ? '—' : '$_countriesCount',
                label: 'Țări',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFF059669),
              iconBg: const Color(0xFFD1FAE5),
              value: '$photosCount',
              label: 'Fotografii',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(List<QueryDocumentSnapshot> photoDocs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fotografii',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (photoDocs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 40,
                    color: Color(0xFFD1D5DB),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nicio fotografie',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photoDocs.length,
              itemBuilder: (context, index) {
                final data = photoDocs[index].data() as Map<String, dynamic>;
                final imageUrl = data['imageUrl'] as String? ?? '';
                final location =
                    data['locationName'] as String? ??
                    data['countryName'] as String? ??
                    '';

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostStoryViewer(
                        docs: photoDocs.cast<QueryDocumentSnapshot>(),
                        initialIndex: index,
                        collection: 'location_photos',
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : Container(color: const Color(0xFFF3F4F6)),
                        if (location.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      location,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─── Stat card (vertical layout pentru 3 coloane) ─────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
