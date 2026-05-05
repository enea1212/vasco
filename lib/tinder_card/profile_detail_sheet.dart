import 'package:flutter/material.dart';

void showProfileDetail(BuildContext context, Map<String, dynamic> profile) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileDetailSheet(profile: profile),
  );
}

class _ProfileDetailSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _ProfileDetailSheet({required this.profile});

  @override
  State<_ProfileDetailSheet> createState() => _ProfileDetailSheetState();
}

class _ProfileDetailSheetState extends State<_ProfileDetailSheet> {
  int _currentPage = 0;

  List<Map<String, dynamic>> _parsePhotos() {
    try {
      final raw = widget.profile['photos'];
      if (raw is List && raw.isNotEmpty) {
        final parsed = raw
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .where((m) => (m['imageUrl'] as String?)?.isNotEmpty == true)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    final fallback = widget.profile['photoUrl'] as String?;
    if (fallback != null && fallback.isNotEmpty) {
      return [{'imageUrl': fallback, 'locationName': null}];
    }
    return [];
  }

  void _goNext(int total) {
    if (_currentPage < total - 1) setState(() => _currentPage++);
  }

  void _goPrev() {
    if (_currentPage > 0) setState(() => _currentPage--);
  }

  @override
  Widget build(BuildContext context) {
    final profile  = widget.profile;
    final name     = profile['displayName'] as String? ?? 'Anonim';
    final age      = profile['age'];
    final distance = profile['distance'] as String?;
    final bio      = profile['bio'] as String?;
    final interests = List<String>.from(profile['interests'] ?? []);
    final photos   = _parsePhotos();

    final currentPhoto    = photos.isNotEmpty ? photos[_currentPage] : null;
    final currentImageUrl = currentPhoto?['imageUrl'] as String?;
    final currentLocation = currentPhoto?['locationName'] as String?;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 1.0,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // ── Foto header ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Poza curentă cu fade la schimbare
                      if (currentImageUrl != null)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Image.network(
                            key: ValueKey(_currentPage),
                            currentImageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : Container(
                                        color: const Color(0xFFE5E7EB),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                            errorBuilder: (context, err, stack) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(Icons.broken_image_rounded,
                                  color: Colors.white54, size: 60),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFFE5E7EB),
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white54, size: 100),
                        ),

                      // Zone tap stânga / dreapta — Row umple tot Stack-ul
                      if (photos.length > 1)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 35,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: _goPrev,
                              ),
                            ),
                            Expanded(
                              flex: 65,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => _goNext(photos.length),
                              ),
                            ),
                          ],
                        ),

                      // Dots indicator (sus)
                      if (photos.length > 1)
                        Positioned(
                          top: 14,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              photos.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _currentPage ? 20 : 6,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: i == _currentPage
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Gradient jos
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 180,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.72),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Nume + vârstă + locație poză
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 60,
                        child: IgnorePointer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                age != null ? '$name, $age' : name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (currentLocation != null &&
                                  currentLocation.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        currentLocation,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              else if (distance != null)
                                Row(
                                  children: [
                                    const Icon(Icons.near_me_rounded,
                                        color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      distance,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Buton închide
                      Positioned(
                        top: 12,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Conținut scrollabil ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (photos.length > 1) ...[
                      Row(
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              size: 16, color: Color(0xFF9CA3AF)),
                          const SizedBox(width: 6),
                          Text(
                            '${photos.length} fotografii',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (bio != null && bio.isNotEmpty) ...[
                      _SectionTitle('Despre mine'),
                      const SizedBox(height: 10),
                      Text(
                        bio,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    if (interests.isNotEmpty) ...[
                      _SectionTitle('Interese'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: interests
                            .map((tag) => _InterestChip(tag))
                            .toList(),
                      ),
                      const SizedBox(height: 28),
                    ],

                    if (photos.isEmpty &&
                        (bio == null || bio.isEmpty) &&
                        interests.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Acest utilizator nu a adăugat\nîncă informații despre sine.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 14),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;
  const _InterestChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4F46E5),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
