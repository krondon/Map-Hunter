import 'package:flutter/foundation.dart';

enum GameMode {
  presencial,
  online,
}

class AppModeProvider with ChangeNotifier {
  GameMode? _selectedMode;

  GameMode? get selectedMode => _selectedMode;

  bool get isOnlineMode => _selectedMode == GameMode.online;
  bool get isPresencialMode => _selectedMode == GameMode.presencial;

  void setMode(GameMode mode) {
    _selectedMode = mode;
    notifyListeners();
  }

  void clearMode() {
    _selectedMode = null;
    notifyListeners();
  }
}
