import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A small rolling-history bar visualization driven by real amplitude
/// samples from `AudioRecorder.amplitudeStream` (via the controller's
/// `RxDouble amplitude`) — not a decorative animation.
class LiveWaveform extends StatefulWidget {
  const LiveWaveform({super.key, required this.amplitude, this.barCount = 28});

  final RxDouble amplitude;
  final int barCount;

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform> {
  late List<double> _history = List.filled(widget.barCount, 0.02);
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever<double>(widget.amplitude, (value) {
      setState(() {
        _history = [..._history.skip(1), value.clamp(0.02, 1.0)];
      });
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final level in _history)
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 4,
              height: 8 + level * 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
