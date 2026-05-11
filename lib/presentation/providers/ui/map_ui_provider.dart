import 'package:flutter/foundation.dart';

class MapUiProvider extends ChangeNotifier {
  bool _showFriendInfo = false;
  String? _selectedFriendId;

  bool get showFriendInfo => _showFriendInfo;
  String? get selectedFriendId => _selectedFriendId;

  void selectFriend(String friendId) {
    _selectedFriendId = friendId;
    _showFriendInfo = true;
    notifyListeners();
  }

  void dismissFriendInfo() {
    _selectedFriendId = null;
    _showFriendInfo = false;
    notifyListeners();
  }
}
