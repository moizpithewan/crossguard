import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// saves + checks the parent pin. locks for 30 sec after 5 wrong tries
class PinService {
  final _storage = const FlutterSecureStorage();

  int _wrongTries = 0;
  DateTime? _lockedUntil;

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: 'pin');
    return pin != null;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: 'pin', value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    if (lockoutLeft() != null) return false;

    final savedPin = await _storage.read(key: 'pin');
    if (pin == savedPin) {
      _wrongTries = 0;
      return true;
    }

    _wrongTries++;
    if (_wrongTries >= 5) {
      _wrongTries = 0;
      _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
    }
    return false;
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    final ok = await verifyPin(oldPin);
    if (!ok) return false;
    await setPin(newPin);
    return true;
  }

  // null if not locked, otherwise how much time is left
  Duration? lockoutLeft() {
    if (_lockedUntil == null) return null;
    final left = _lockedUntil!.difference(DateTime.now());
    if (left <= Duration.zero) return null;
    return left;
  }
}
