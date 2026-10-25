import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../auth/parent_session.dart';
import '../auth/pin_entry_dialog.dart';
import '../auth/pin_service.dart';
import '../geofence/location_monitor.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'zone_model.dart';
import 'zone_storage.dart';

class ZoneMapScreen extends StatefulWidget {
  final ZoneStorage zoneStorage;
  final LocationMonitor locationMonitor;
  final ThemeController themeController;
  final ParentSession parentSession;
  final PinService pinService;

  const ZoneMapScreen({
    super.key,
    required this.zoneStorage,
    required this.locationMonitor,
    required this.themeController,
    required this.parentSession,
    required this.pinService,
  });

  @override
  State<ZoneMapScreen> createState() => _ZoneMapScreenState();
}

class _ZoneMapScreenState extends State<ZoneMapScreen> {
  static const _startPos = LatLng(37.7749, -122.4194); // SF
  static const _startRadius = 150.0; // TODO: let parent pick the radius better

  List<RestrictedZone> _zones = [];
  LatLng? _newCenter;
  double _newRadius = _startRadius;
  String? _editId;
  GoogleMapController? _mapController;

  bool get _isParent => widget.parentSession.isParentMode;

  @override
  void initState() {
    super.initState();
    _zones = widget.zoneStorage.getZones();
    widget.parentSession.addListener(_onSessionChanged);
  }

  // call after adding/editing/deleting so the map updates
  void _reloadZones() {
    setState(() {
      _zones = widget.zoneStorage.getZones();
    });
  }

  @override
  void dispose() {
    widget.parentSession.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (!_isParent) {
      // back to child mode, cancel any zone that was being edited
      setState(() {
        _newCenter = null;
        _editId = null;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _openParentLogin() async {
    final unlocked = await PinEntryDialog.show(context, widget.pinService);
    if (unlocked) widget.parentSession.unlock();
  }

  Future<void> _openChangePin() async {
    await ChangePinDialog.show(context, widget.pinService);
  }

  void _onMapTap(LatLng point) {
    if (!_isParent) return;
    setState(() {
      _newCenter = point;
      _newRadius = _startRadius;
      _editId = null;
    });
  }

  void _onZoneTapped(RestrictedZone zone) {
    if (_isParent) {
      _editZone(zone);
    } else {
      _showZoneInfo(zone);
    }
  }

  void _showZoneInfo(RestrictedZone zone) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(zone.name),
        content: Text('${zone.radiusMeters.round()} m restricted zone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editZone(RestrictedZone zone) {
    setState(() {
      _editId = zone.id;
      _newCenter = LatLng(zone.centerLat, zone.centerLng);
      _newRadius = zone.radiusMeters;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(zone.centerLat, zone.centerLng)),
    );
  }

  Future<void> _saveZone() async {
    final center = _newCenter;
    if (center == null) return;

    var name = await _promptForName(
      initial: _editId != null
          ? _zones.firstWhere((z) => z.id == _editId).name
          : '',
    );
    if (name == null || name.trim().isEmpty) return;

    if (_editId != null) {
      var existing = _zones.firstWhere((z) => z.id == _editId);
      await widget.zoneStorage.updateZone(
        existing.copyWith(
          name: name.trim(),
          centerLat: center.latitude,
          centerLng: center.longitude,
          radiusMeters: _newRadius,
        ),
      );
    } else {
      await widget.zoneStorage.addZone(
        RestrictedZone(
          id: const Uuid().v4(),
          name: name.trim(),
          centerLat: center.latitude,
          centerLng: center.longitude,
          radiusMeters: _newRadius,
          createdAt: DateTime.now(),
        ),
      );
    }

    _newCenter = null;
    _editId = null;
    _reloadZones();
  }

  Future<String?> _promptForName({required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zone name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Busy intersection'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteZone(String zoneId) async {
    await widget.zoneStorage.deleteZone(zoneId);
    if (_editId == zoneId) {
      _editId = null;
      _newCenter = null;
    }
    _reloadZones();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isParent = _isParent;

    final circles = <Circle>{
      for (final zone in _zones)
        Circle(
          circleId: CircleId(zone.id),
          center: LatLng(zone.centerLat, zone.centerLng),
          radius: zone.radiusMeters,
          fillColor: colorScheme.error.withValues(alpha: 0.15),
          strokeColor: colorScheme.error,
          strokeWidth: 2,
          consumeTapEvents: true,
          onTap: () => _onZoneTapped(zone),
        ),
      if (isParent && _newCenter != null)
        Circle(
          circleId: const CircleId('pending'),
          center: _newCenter!,
          radius: _newRadius,
          fillColor: colorScheme.primary.withValues(alpha: 0.2),
          strokeColor: colorScheme.primary,
          strokeWidth: 2,
        ),
    };

    final markers = <Marker>{
      if (isParent && _newCenter != null)
        Marker(
          markerId: const MarkerId('pending'),
          position: _newCenter!,
          draggable: true,
          onDragEnd: (pos) => setState(() => _newCenter = pos),
        ),
    };

    final noZones = _zones.isEmpty && _newCenter == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restricted zones'),
        actions: [
          _buildThemeMenu(),
          if (isParent)
            IconButton(
              icon: const Icon(Icons.password),
              tooltip: 'Change PIN',
              onPressed: _openChangePin,
            )
          else
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Parent',
              onPressed: _openParentLogin,
            ),
        ],
      ),
      body: Column(
        children: [
          if (isParent) _buildParentBanner(),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _startPos,
                    zoom: 14,
                  ),
                  // map needs its own dark style
                  style: isDark ? AppTheme.mapStyleDark : AppTheme.mapStyleLight,
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: isParent ? _onMapTap : null,
                  circles: circles,
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomGesturesEnabled: true,
                  // pinch zoom didnt work without this
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                ),
                if (noZones) _buildEmptyHint(isParent),
                // top left so it doesnt cover googles buttons
                if (isParent)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: FloatingActionButton.extended(
                      onPressed: _addZoneAtCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Zone at my location'),
                    ),
                  ),
              ],
            ),
          ),
          if (isParent && _newCenter != null) _buildPendingZonePanel(),
          if (_zones.isNotEmpty) _buildZoneList(isParent),
        ],
      ),
    );
  }

  Widget _buildParentBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.shield, color: colorScheme.onTertiaryContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Parent mode',
              style: TextStyle(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.parentSession.lock,
            child: const Text('Exit parent mode'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeMenu() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeController.mode,
      builder: (context, mode, _) {
        IconData icon;
        if (mode == ThemeMode.light) {
          icon = Icons.light_mode;
        } else if (mode == ThemeMode.dark) {
          icon = Icons.dark_mode;
        } else {
          icon = Icons.brightness_auto;
        }
        return PopupMenuButton<ThemeMode>(
          icon: Icon(icon),
          tooltip: 'Theme',
          onSelected: widget.themeController.setMode,
          itemBuilder: (context) => [
            _themeMenuItem(ThemeMode.light, Icons.light_mode, 'Light', mode),
            _themeMenuItem(ThemeMode.dark, Icons.dark_mode, 'Dark', mode),
            _themeMenuItem(
              ThemeMode.system,
              Icons.brightness_auto,
              'System',
              mode,
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<ThemeMode> _themeMenuItem(
    ThemeMode value,
    IconData icon,
    String label,
    ThemeMode current,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
          if (value == current) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyHint(bool isParent) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_location_alt_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No zones yet',
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                isParent
                    ? 'Tap anywhere on the map, or use\n"Zone at my location" below.'
                    : 'Ask a parent to set one up in\nparent mode.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addZoneAtCurrentLocation() async {
    try {
      final position = await widget.locationMonitor.getCurrentPosition();
      final center = LatLng(position.latitude, position.longitude);
      setState(() {
        _newCenter = center;
        _newRadius = _startRadius;
        _editId = null;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(center));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get current location: $e')),
      );
    }
  }

  Widget _buildPendingZonePanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editId != null ? 'Editing zone' : 'New zone',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  const Text('Radius'),
                  Expanded(
                    child: Slider(
                      value: _newRadius,
                      min: 25,
                      max: 1000,
                      divisions: 39,
                      label: '${_newRadius.round()} m',
                      onChanged: (value) =>
                          setState(() => _newRadius = value),
                    ),
                  ),
                  Text('${_newRadius.round()} m'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _newCenter = null;
                      _editId = null;
                    }),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveZone,
                    child: const Text('Save zone'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneList(bool isParent) {
    return SizedBox(
      height: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Your zones (${_zones.length})',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _zones.length,
              itemBuilder: (context, index) {
                final zone = _zones[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(zone.name),
                  subtitle: Text('${zone.radiusMeters.round()} m radius'),
                  onTap: () => _onZoneTapped(zone),
                  trailing: isParent
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteZone(zone.id),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
