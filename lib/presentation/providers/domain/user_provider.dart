import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/usecases/profile/get_user_usecase.dart';
import '../../../domain/usecases/profile/update_profile_usecase.dart';

class UserProvider extends ChangeNotifier {
  UserProvider(this._getUser, this._updateProfile);

  final GetUserUsecase _getUser;
  final UpdateProfileUsecase _updateProfile;

  UserEntity? _user;
  bool _isLoading = false;
  StreamSubscription<UserEntity?>? _sub;

  UserEntity? get user => _user;
  bool get isLoading => _isLoading;

  void init(String userId) {
    _sub?.cancel();
    _sub = _getUser(userId).listen((u) {
      _user = u;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[UserProvider] stream error: $e');
    });
  }

  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _updateProfile(userId, fields);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
