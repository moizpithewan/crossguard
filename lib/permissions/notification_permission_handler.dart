import 'package:permission_handler/permission_handler.dart';

class NotificationPermissionHandler {
  Future<bool> requestAll() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
