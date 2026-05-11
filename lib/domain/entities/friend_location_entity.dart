class FriendLocationEntity {
  const FriendLocationEntity({
    this.latitude,
    this.longitude,
    this.displayName,
    this.photoUrl,
  });

  final double? latitude;
  final double? longitude;
  final String? displayName;
  final String? photoUrl;

  bool get hasLocation => latitude != null && longitude != null;

  FriendLocationEntity withLocation({
    required double latitude,
    required double longitude,
    String? displayName,
    String? photoUrl,
  }) =>
      FriendLocationEntity(
        latitude: latitude,
        longitude: longitude,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
      );

  FriendLocationEntity withoutLocation() => FriendLocationEntity(
        displayName: displayName,
        photoUrl: photoUrl,
      );
}
