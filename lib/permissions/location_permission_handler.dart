import 'package:permission_handler/permission_handler.dart';

// gotta ask for foreground first THEN background, if u ask for
// background first ios/android just auto denies it, found that out the
// hard way
class LocationPermissionHandler {
  Future<bool> requestAll() async {
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) return false;

    final background = await Permission.locationAlways.request();
    return background.isGranted;
  }

  Future<bool> get hasBackgroundAccess async =>
      Permission.locationAlways.isGranted;
}
