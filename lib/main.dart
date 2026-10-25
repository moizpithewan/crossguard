import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'alerts/alert_service.dart';
import 'auth/parent_session.dart';
import 'auth/pin_service.dart';
import 'auth/pin_setup_screen.dart';
import 'geofence/geofence_service.dart';
import 'geofence/location_monitor.dart';
import 'permissions/location_permission_handler.dart';
import 'permissions/notification_permission_handler.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'zones/zone_map_screen.dart';
import 'zones/zone_storage.dart';

// stuff the whole app uses
late ThemeController themeController;
late ZoneStorage zoneStorage;
final parentSession = ParentSession();
final pinService = PinService();
final locationMonitor = LocationMonitor();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  themeController = await ThemeController.open();
  zoneStorage = await ZoneStorage.open();
  runApp(const CrossGuardApp());
}

class CrossGuardApp extends StatelessWidget {
  const CrossGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Cross Guard',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          builder: (context, child) {
            // resets the parent mode timer on tap
            return Listener(
              onPointerDown: (_) => parentSession.recordActivity(),
              child: child,
            );
          },
          home: const _AppRoot(),
        );
      },
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool? _hasPin;

  @override
  void initState() {
    super.initState();
    _checkPin();
  }

  Future<void> _checkPin() async {
    final hasPin = await pinService.hasPin();
    if (!mounted) return;
    setState(() => _hasPin = hasPin);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasPin!) {
      return PinSetupScreen(
        pinService: pinService,
        onDone: () => setState(() => _hasPin = true),
      );
    }
    return const _StartupGate();
  }
}

// asks for permissions + starts tracking before the map shows
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _ready = false;
  String? _warning;
  GeofenceService? _geofence;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final gotLocation = await LocationPermissionHandler().requestAll();
    await NotificationPermissionHandler().requestAll();

    final alertService = AlertService(parentSession);
    await alertService.init();
    _geofence = GeofenceService(zoneStorage, locationMonitor, alertService);
    _geofence!.start();

    if (!mounted) return;
    setState(() {
      _ready = true;
      _warning = gotLocation
          ? null
          : "Background location wasn't granted - zone monitoring may only "
                'work while the app is open. You can enable "Always allow" '
                'in system settings.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          if (_warning != null)
            MaterialBanner(
              backgroundColor: colorScheme.errorContainer,
              leading: Icon(Icons.warning_amber, color: colorScheme.onErrorContainer),
              content: Text(
                _warning!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _warning = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: ZoneMapScreen(
              zoneStorage: zoneStorage,
              locationMonitor: locationMonitor,
              themeController: themeController,
              parentSession: parentSession,
              pinService: pinService,
            ),
          ),
        ],
      ),
    );
  }
}
