import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';
import 'package:vasco/services/spotify_service.dart';

/// Spotify connect / disconnect tile.
/// Manages its own connection state — no parameters needed.
class SpotifyCard extends StatefulWidget {
  const SpotifyCard({super.key});

  @override
  State<SpotifyCard> createState() => _SpotifyCardState();
}

class _SpotifyCardState extends State<SpotifyCard> {
  bool? _isConnected;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await SpotifyService.isConnected();
    if (mounted) setState(() => _isConnected = connected);
  }

  Future<void> _handleTap() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    if (_isConnected == true) {
      await SpotifyService.logout();
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    } else {
      final success = await SpotifyService.login();
      if (mounted) {
        setState(() {
          _isConnected = success;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isConnected == true
                ? AppColors.greenLight
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.greenSpotify,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Spotify',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      _isConnected == null
                          ? 'Checking...'
                          : _isConnected == true
                          ? 'Connected — music appears on posts'
                          : 'Connect to add music',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.greenSpotify,
                  ),
                )
              else
                Icon(
                  _isConnected == true
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: _isConnected == true
                      ? AppColors.greenEmerald
                      : AppColors.textHint,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
