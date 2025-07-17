import 'package:flutter/material.dart';

class RecordingChunkBubble extends StatelessWidget {
  final int index;
  final String fileName;
  final bool isCurrent;
  final Duration duration;
  final VoidCallback? onDelete;
  const RecordingChunkBubble({
    super.key,
    required this.index,
    required this.fileName,
    required this.isCurrent,
    required this.duration,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: isCurrent
          ? Theme.of(context).colorScheme.primary.withAlpha(35)
          : Theme.of(context).cardColor,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      avatar: CircleAvatar(
        backgroundColor: Colors.black12,
        child: Text('${index + 1}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
      ),
      label: Text(
          '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'),
      deleteIcon: onDelete != null ? Icon(Icons.delete, size: 18) : null,
      onDeleted: onDelete,
    );
  }
}
