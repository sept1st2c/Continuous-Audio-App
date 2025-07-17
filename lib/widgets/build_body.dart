import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session_recording.dart';
import 'package:path/path.dart' as p;

class BuildBody extends StatefulWidget {
  final bool isRecording;
  final bool isStopping;
  final TextEditingController searchController;
  final List<SessionRecording> sessions;
  final List<SessionRecording> filteredSessions;
  final int currentSessionElapsed;
  final String currentSessionElapsedString;
  final void Function(SessionRecording) deleteSession;
  final Future<void> Function(SessionRecording) playSession;
  final Future<void> Function(SessionRecording, String) playChunk;
  final void Function(SessionRecording, int) deleteChunk;
  final void Function() stopPlayback;
  final void Function(String) searchSessions;
  final bool isAnyPlaying;
  final String? currentlyPlayingSessionId;
  final String? currentlyPlayingChunk;

  const BuildBody({
    super.key,
    required this.isRecording,
    required this.isStopping,
    required this.searchController,
    required this.sessions,
    required this.filteredSessions,
    required this.currentSessionElapsed,
    required this.currentSessionElapsedString,
    required this.deleteSession,
    required this.playSession,
    required this.playChunk,
    required this.deleteChunk,
    required this.stopPlayback,
    required this.searchSessions,
    required this.isAnyPlaying,
    required this.currentlyPlayingSessionId,
    required this.currentlyPlayingChunk,
  });

  @override
  State<BuildBody> createState() => _BuildBodyState();
}

class _BuildBodyState extends State<BuildBody> {
  Set<int> expandedSessions = {};

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final showSessions = widget.filteredSessions;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: widget.isRecording || widget.sessions.isEmpty
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.isRecording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    'Recording ${widget.currentSessionElapsedString}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red),
                  ),
                ],
              )
            else if (widget.isStopping)
              const Padding(
                padding: EdgeInsets.all(10.0),
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else if (widget.sessions.isEmpty &&
                widget.searchController.text.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.mic_none,
                        size: size.height * 0.09,
                        color: Theme.of(context).cardColor),
                    const Text(
                      textAlign: TextAlign.center,
                      'Welcome, click the button to start recording',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  controller: widget.searchController,
                  onChanged: widget.searchSessions,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search by date (YYYY-MM-DD)...',
                    filled: true,
                    fillColor: Theme.of(context)
                        .cardColor
                        .withAlpha((0.10 * 255).toInt()),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: showSessions.isEmpty
                    ? Center(
                        child: Text('No sessions found',
                            style: TextStyle(fontSize: 18)),
                      )
                    : ListView.builder(
                        itemCount: showSessions.length,
                        itemBuilder: (context, idx) {
                          final session = showSessions[idx];
                          final d = Duration(seconds: session.durationSec);
                          final formattedDate = DateFormat('yyyy-MM-dd HH:mm')
                              .format(session.date);
                          final isPlayingSession = widget.isAnyPlaying &&
                              widget.currentlyPlayingSessionId ==
                                  session.sessionId &&
                              widget.currentlyPlayingChunk == null;
                          final isExpanded = expandedSessions.contains(idx);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 7),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                ListTile(
                                  tileColor: isPlayingSession
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha((0.08 * 255).toInt())
                                      : null,
                                  leading: Icon(Icons.folder_open,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  title: Text(
                                    "Session $formattedDate",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                      "Duration: ${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}  |  Chunks: ${session.chunkPaths.length}"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(isPlayingSession
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_filled),
                                        tooltip: isPlayingSession
                                            ? 'Pause'
                                            : 'Play session',
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        iconSize: 32,
                                        onPressed: widget.isAnyPlaying &&
                                                !isPlayingSession
                                            ? null
                                            : isPlayingSession
                                                ? widget.stopPlayback
                                                : () =>
                                                    widget.playSession(session),
                                      ),
                                      IconButton(
                                        icon: Icon(isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more),
                                        tooltip: isExpanded
                                            ? 'Collapse'
                                            : 'Show audio chunks',
                                        onPressed: () {
                                          setState(() {
                                            isExpanded
                                                ? expandedSessions.remove(idx)
                                                : expandedSessions.add(idx);
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: "Delete session",
                                        onPressed: widget.isAnyPlaying
                                            ? null
                                            : () =>
                                                widget.deleteSession(session),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isExpanded)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 22, right: 22, bottom: 9),
                                    child: Column(
                                      children: [
                                        for (int ci = 0;
                                            ci < session.chunkPaths.length;
                                            ci++)
                                          Card(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 3),
                                            color: widget.isAnyPlaying &&
                                                    widget.currentlyPlayingChunk ==
                                                        session.chunkPaths[ci]
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withAlpha(
                                                        (0.12 * 255).toInt())
                                                : null,
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              dense: true,
                                              leading: CircleAvatar(
                                                backgroundColor: Theme.of(
                                                        context)
                                                    .colorScheme
                                                    .primary
                                                    .withAlpha(
                                                        (0.15 * 255).toInt()),
                                                child: Text("${ci + 1}",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary)),
                                              ),
                                              title: Text(
                                                p.basename(
                                                    session.chunkPaths[ci]),
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      widget.isAnyPlaying &&
                                                              widget.currentlyPlayingChunk ==
                                                                  session
                                                                      .chunkPaths[ci]
                                                          ? Icons.pause
                                                          : Icons.play_arrow,
                                                    ),
                                                    color: widget
                                                                .isAnyPlaying &&
                                                            widget.currentlyPlayingChunk ==
                                                                session.chunkPaths[
                                                                    ci]
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                        : null,
                                                    tooltip: widget
                                                                .isAnyPlaying &&
                                                            widget.currentlyPlayingChunk ==
                                                                session
                                                                    .chunkPaths[ci]
                                                        ? 'Pause'
                                                        : 'Play chunk',
                                                    onPressed: widget
                                                                .isAnyPlaying &&
                                                            widget.currentlyPlayingChunk !=
                                                                session.chunkPaths[
                                                                    ci]
                                                        ? null
                                                        : widget.isAnyPlaying
                                                            ? widget
                                                                .stopPlayback
                                                            : () => widget
                                                                .playChunk(
                                                                    session,
                                                                    session.chunkPaths[
                                                                        ci]),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        size: 22),
                                                    tooltip: "Delete chunk",
                                                    onPressed: widget
                                                            .isAnyPlaying
                                                        ? null
                                                        : () =>
                                                            widget.deleteChunk(
                                                                session, ci),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
