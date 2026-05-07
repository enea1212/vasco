import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SpotifyTrack {
  final String songName;
  final String artistName;
  final String albumArtUrl;

  const SpotifyTrack({
    required this.songName,
    required this.artistName,
    required this.albumArtUrl,
  });
}

class SpotifyService {
  static String get _clientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  static const _redirectUri = 'vasco://spotify-callback';
  static const _scopes =
      'user-read-currently-playing user-read-playback-state';

  static const _keyAccessToken = 'spotify_access_token';
  static const _keyRefreshToken = 'spotify_refresh_token';
  static const _keyExpiresAt = 'spotify_expires_at';

  static Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken) != null;
  }

  static Future<bool> login() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': _scopes,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'vasco',
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) return false;
      return await _exchangeCode(code, verifier);
    } catch (_) {
      return false;
    }
  }

  static Future<SpotifyTrack?> getCurrentTrack() async {
    final token = await _getValidToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player/currently-playing'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200 || response.body.isEmpty) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['is_playing'] != true) return null;

      final item = data['item'] as Map<String, dynamic>?;
      if (item == null) return null;

      final artists = (item['artists'] as List?)
              ?.map((a) => a['name'] as String)
              .join(', ') ??
          '';
      final images = item['album']?['images'] as List?;
      // prefer smallest image (index 2 = 64x64) for performance
      final albumArt = (images != null && images.length >= 3)
          ? images[2]['url'] as String
          : images?.isNotEmpty == true
              ? images!.last['url'] as String
              : '';

      return SpotifyTrack(
        songName: item['name'] as String? ?? '',
        artistName: artists,
        albumArtUrl: albumArt,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyExpiresAt);
  }

  static Future<String?> _getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt(_keyExpiresAt) ?? 0;

    if (DateTime.now().millisecondsSinceEpoch < expiresAt - 60000) {
      return prefs.getString(_keyAccessToken);
    }

    final refreshToken = prefs.getString(_keyRefreshToken);
    if (refreshToken == null) return null;
    return await _refreshToken(refreshToken);
  }

  static Future<bool> _exchangeCode(String code, String verifier) async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        'code_verifier': verifier,
      },
    );
    if (response.statusCode != 200) return false;
    await _saveTokens(json.decode(response.body) as Map<String, dynamic>);
    return true;
  }

  static Future<String?> _refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      },
    );
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    await _saveTokens(data);
    return data['access_token'] as String?;
  }

  static Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresIn = (data['expires_in'] as int?) ?? 3600;
    await prefs.setString(_keyAccessToken, data['access_token'] as String);
    if (data['refresh_token'] != null) {
      await prefs.setString(_keyRefreshToken, data['refresh_token'] as String);
    }
    await prefs.setInt(
      _keyExpiresAt,
      DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
    );
  }

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
