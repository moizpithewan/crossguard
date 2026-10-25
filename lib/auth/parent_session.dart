import 'dart:async';

import 'package:flutter/material.dart';

// is parent mode on or not. locks again after 2 min of no taps.
// not saved so app always opens in child mode
class ParentSession extends ChangeNotifier {
  bool isParentMode = false;
  Timer? _timer;

  void unlock() {
    isParentMode = true;
    _restartTimer();
    notifyListeners();
  }

  void lock() {
    isParentMode = false;
    _timer?.cancel();
    notifyListeners();
  }

  // call on every tap
  void recordActivity() {
    if (isParentMode) _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 2), lock);
  }
}
