import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pin_service.dart';

Widget _pinField(
  TextEditingController controller, {
  required String label,
  bool autofocus = false,
  bool enabled = true,
  ValueChanged<String>? onSubmitted,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    autofocus: autofocus,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(labelText: label),
    onSubmitted: onSubmitted,
  );
}

String _timeLeft(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

// returns true if pin was right
class PinEntryDialog extends StatefulWidget {
  final PinService pinService;

  const PinEntryDialog({super.key, required this.pinService});

  static Future<bool> show(BuildContext context, PinService pinService) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PinEntryDialog(pinService: pinService),
    );
    return result ?? false;
  }

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  final _controller = TextEditingController();
  String? _error;
  Duration? _lockout;
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // might still be locked from last time the dialog was open
    _lockout = widget.pinService.lockoutLeft();
    if (_lockout != null) _startTimer();
  }

  // updates the countdown every second until the lockout is over
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _lockout = widget.pinService.lockoutLeft();
      });
      if (_lockout == null) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.length < 4) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await widget.pinService.verifyPin(_controller.text);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    _controller.clear();
    final left = widget.pinService.lockoutLeft();
    setState(() {
      _checking = false;
      if (left != null) {
        _lockout = left;
      } else {
        _error = 'Wrong PIN';
      }
    });
    if (left != null) _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final lockedOut = _lockout != null;
    return AlertDialog(
      title: const Text('Enter parent PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pinField(
            _controller,
            label: 'PIN',
            autofocus: true,
            enabled: !lockedOut && !_checking,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          if (lockedOut)
            Text(
              'Try again in ${_timeLeft(_lockout!)}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: lockedOut || _checking ? null : _submit,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}

class ChangePinDialog extends StatefulWidget {
  final PinService pinService;

  const ChangePinDialog({super.key, required this.pinService});

  static Future<bool> show(BuildContext context, PinService pinService) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ChangePinDialog(pinService: pinService),
    );
    return result ?? false;
  }

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPin = _newController.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(newPin)) {
      setState(() => _error = 'New PIN must be 4 to 6 digits');
      return;
    }
    if (newPin != _confirmController.text) {
      setState(() => _error = "New PINs don't match");
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.pinService.changePin(_oldController.text, newPin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _error = 'Current PIN is wrong';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pinField(
            _oldController,
            label: 'Current PIN',
            autofocus: true,
            enabled: !_saving,
          ),
          const SizedBox(height: 8),
          _pinField(_newController, label: 'New PIN', enabled: !_saving),
          const SizedBox(height: 8),
          _pinField(
            _confirmController,
            label: 'Confirm new PIN',
            enabled: !_saving,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Change'),
        ),
      ],
    );
  }
}
