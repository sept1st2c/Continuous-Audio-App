import 'package:flutter/material.dart';

class RecordingButton extends StatelessWidget {
  final bool isRecording;
  final void Function(bool) onRecordingStateChanged;
  final bool disabled;

  const RecordingButton({
    super.key,
    required this.isRecording,
    required this.onRecordingStateChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor:
          disabled ? Colors.grey : Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      onPressed: disabled
          ? null
          : () {
              onRecordingStateChanged(!isRecording);
            },
      child: isRecording ? const Icon(Icons.stop) : const Icon(Icons.mic),
    );
  }
}
