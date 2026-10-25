import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

import '../auth/parent_session.dart';
import '../geofence/geofence_evaluator.dart';
import '../zones/zone_model.dart';

// notif when ur close to a zone, notif + talks + vibrates when ur in it.
// doesnt alert in parent mode
class AlertService {
  final ParentSession parentSession;
  final _notifications = FlutterLocalNotificationsPlugin();
  final _tts = FlutterTts();

  int _notifId = 0;

  AlertService(this.parentSession);

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // without this ios mutes the voice when the screen is locked
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      ]);
    }
  }

  // GeofenceService calls this when the state of a zone changes
  Future<void> onZoneChange(RestrictedZone zone, ZoneProximityState state) async {
    if (parentSession.isParentMode) return;

    if (state == ZoneProximityState.approaching) {
      await _notify(
        title: 'Getting close to the restricted zone named: ${zone.name}',
        body: 'You are approaching a restricted zone.',
      );
      await _tts.speak(
        'Warning. You are approaching the restricted zone named: ${zone.name}.',
      );
    } else if (state == ZoneProximityState.inside) {
      await _notify(
        title: 'Entered the restricted zone named: ${zone.name}',
        body: 'You have entered a restricted zone.',
      );
      await _tts.speak(
        'Warning. You have entered the restricted zone named: ${zone.name}.',
      );
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 800);
      }
    }
    // nothing when u leave
  }

  Future<void> _notify({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'zone_alerts',
      'Zone alerts',
      channelDescription: 'Alerts when approaching or entering a zone',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _notifications.show(
      id: _notifId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
