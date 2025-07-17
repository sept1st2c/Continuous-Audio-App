import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models/session_recording.dart';
import '../widgets/recording_chunk_bubble.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioRecorder record = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();

  // Recording
  bool isRecording = false;
  bool isStopping = false;
  String? currentSessionId;
  int currentSessionElapsed = 0;
  List<String> currentChunks = [];
  Timer? chunkTimer;
  Timer? sessionTimer;
  List<Duration> currentChunkDurations = [];
  int? liveCurrentChunk;

  // Playback
  bool isPlayingSession = false;
  bool isPlayingChunk = false;
  int? playingSessionIdx;
  int? playingChunkIdxInSession;
  Duration? chunkProgress;
  Duration? chunkTotal;
  StreamSubscription<Duration>? _positionSub;

  // Persisted sessions
  List<SessionRecording> sessions = [];
  List<SessionRecording> filteredSessions = [];
  TextEditingController searchController = TextEditingController();

  // Storage helpers
  Future<String> _getSaveDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  // Session storage
  Future<void> saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final strList = sessions.map((s) => s.toJson()).toList();
    await prefs.setStringList('sessions', strList);
  }

  Future<void> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final strList = prefs.getStringList('sessions') ?? [];
    final loaded = strList.map((s) => SessionRecording.fromJson(s)).toList();
    setState(() {
      sessions = loaded;
      filteredSessions = List.from(loaded);
    });
  }

  @override
  void initState() {
    super.initState();
    loadSessions();
  }

  @override
  void dispose() {
    chunkTimer?.cancel();
    sessionTimer?.cancel();
    record.dispose();
    audioPlayer.dispose();
    _positionSub?.cancel();
    super.dispose();
  }

  // --- Recording logic ---
  Future<void> startSessionRecording() async {
    if (isRecording || isStopping) return;
    setState(() {
      isRecording = true;
      isStopping = false;
      currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      currentChunks = [];
      currentSessionElapsed = 0;
      currentChunkDurations = [];
      liveCurrentChunk = null;
    });
    sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        currentSessionElapsed++;
      });
    });
    await _startNewChunk();
    chunkTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _stopChunkAndStartNext();
    });
  }

  Future<void> _startNewChunk() async {
    final dir = await _getSaveDir();
    int idx = currentChunks.length + 1;
    final path = p.join(dir, 'session_${currentSessionId}_chunk_$idx.m4a');
    await record.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    setState(() {
      currentChunks.add(path);
      currentChunkDurations.add(Duration.zero);
      liveCurrentChunk = currentChunks.length - 1;
    });
  }

  Future<void> _stopChunkAndStartNext() async {
    if (!await record.isRecording()) return;
    await record.stop();
    setState(() {
      if (currentChunkDurations.isNotEmpty) {
        final idx = currentChunkDurations.length - 1;
        currentChunkDurations[idx] = const Duration(seconds: 10);
      }
    });
    await _startNewChunk();
  }

  Future<void> stopSessionRecording() async {
    if (!isRecording || isStopping) return;
    setState(() => isStopping = true);

    chunkTimer?.cancel();
    sessionTimer?.cancel();

    try {
      if (await record.isRecording()) {
        await record.stop();
        if (currentChunkDurations.isNotEmpty) {
          final idx = currentChunkDurations.length - 1;
          final remain =
              currentSessionElapsed % 10 == 0 ? 10 : currentSessionElapsed % 10;
          currentChunkDurations[idx] = Duration(seconds: remain);
        }
      }
    } catch (_) {}

    final session = SessionRecording(
      sessionId: currentSessionId ?? '',
      chunkPaths: List.of(currentChunks),
      date: DateTime.now(),
      durationSec: currentSessionElapsed,
    );
    setState(() {
      sessions.add(session);
      filteredSessions = List.from(sessions);
      isRecording = false;
      isStopping = false;
      currentSessionElapsed = 0;
      currentSessionId = null;
      currentChunks = [];
      currentChunkDurations = [];
      liveCurrentChunk = null;
    });
    await saveSessions();
  }

  // --- Delete logic ---
  Future<void> deleteSession(SessionRecording session) async {
    for (final path in session.chunkPaths) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      sessions.remove(session);
      filteredSessions.remove(session);
    });
    await saveSessions();
  }

  Future<void> deleteChunk(SessionRecording session, int chunkIdx) async {
    final path = session.chunkPaths[chunkIdx];
    final f = File(path);
    if (await f.exists()) await f.delete();
    setState(() {
      session.chunkPaths.removeAt(chunkIdx);
      if (session.chunkPaths.isEmpty) {
        sessions.remove(session);
        filteredSessions.remove(session);
      }
    });
    await saveSessions();
  }

  // --- Playback logic ---
  Future<void> playSession(SessionRecording session, int sessionIdx) async {
    if (isPlayingSession || isPlayingChunk) return;
    setState(() {
      isPlayingSession = true;
      playingSessionIdx = sessionIdx;
      playingChunkIdxInSession = 0;
      chunkProgress = null;
      chunkTotal = null;
    });
    for (int i = 0; i < session.chunkPaths.length; i++) {
      if (!isPlayingSession) break; // For manual stop
      await playChunk(session, session.chunkPaths[i], i, inSession: true);
    }
    setState(() {
      isPlayingSession = false;
      playingSessionIdx = null;
      playingChunkIdxInSession = null;
      chunkProgress = null;
      chunkTotal = null;
    });
  }

  Future<void> playChunk(SessionRecording session, String path, int chunkIdx,
      {bool inSession = false}) async {
    if (isPlayingChunk && !inSession) return;
    setState(() {
      isPlayingChunk = !inSession;
      playingChunkIdxInSession = chunkIdx;
      chunkProgress = Duration.zero;
      chunkTotal = null;
    });
    await audioPlayer.setFilePath(path);
    chunkTotal = audioPlayer.duration;
    _positionSub?.cancel();
    _positionSub = audioPlayer.positionStream.listen((d) {
      setState(() {
        chunkProgress = d;
      });
    });

    await audioPlayer.play();
    await audioPlayer.playerStateStream.firstWhere(
      (state) => state.processingState == ProcessingState.completed,
    );
    if (!inSession) {
      setState(() {
        isPlayingChunk = false;
        playingChunkIdxInSession = null;
        chunkProgress = null;
        chunkTotal = null;
      });
    }
  }

  void stopPlayback() {
    audioPlayer.stop();
    setState(() {
      isPlayingSession = false;
      isPlayingChunk = false;
      playingSessionIdx = null;
      playingChunkIdxInSession = null;
      chunkProgress = null;
      chunkTotal = null;
    });
  }

  void handleSeek(Duration position) {
    audioPlayer.seek(position);
  }

  // --- Search ---
  void searchSessions(String query) {
    if (query.trim().isEmpty) {
      setState(() => filteredSessions = List.from(sessions));
      return;
    }
    setState(() {
      filteredSessions = sessions
          .where((s) =>
              s.date
                  .toIso8601String()
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              s.sessionId.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  String formatElapsed(int seconds) {
    final d = Duration(seconds: seconds);
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0)
      return "${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
    return "${d.inMinutes}:${two(d.inSeconds % 60)}";
  }

  @override
  Widget build(BuildContext context) {
    final showLiveChunks = isRecording || isStopping;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Recorder',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: isRecording ? "Stop recording" : "Record session",
        icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record,
            color: isRecording ? Colors.red : null),
        backgroundColor: isRecording ? Colors.red[300] : Colors.green,
        label: Text(isRecording ? "Stop" : "Record"),
        isExtended: true,
        onPressed: isStopping
            ? null
            : () async {
                if (isRecording)
                  await stopSessionRecording();
                else
                  await startSessionRecording();
              },
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LIVE CHUNK PANEL
              if (showLiveChunks)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(18),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.fiber_manual_record,
                          color: Colors.red, size: 34),
                      const SizedBox(height: 8),
                      Text('Recording session...',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      Text(formatElapsed(currentSessionElapsed),
                          style: const TextStyle(fontSize: 21)),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(currentChunks.length, (i) {
                          final d = i < currentChunkDurations.length
                              ? currentChunkDurations[i]
                              : Duration(
                                  seconds: (i == currentChunks.length - 1)
                                      ? currentSessionElapsed % 10
                                      : 10);
                          return RecordingChunkBubble(
                            index: i,
                            fileName: p.basename(currentChunks[i]),
                            isCurrent: i == currentChunks.length - 1,
                            duration: d,
                          );
                        }),
                      ),
                      if (isStopping)
                        Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3)),
                                const SizedBox(width: 12),
                                const Text("Saving session…"),
                              ],
                            )),
                    ],
                  ),
                ),
              if (!showLiveChunks)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search sessions...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      fillColor: Theme.of(context).cardColor.withAlpha(25),
                      filled: true,
                    ),
                    onChanged: searchSessions,
                  ),
                ),
              if (!showLiveChunks)
                ...filteredSessions.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                              child: Text(
                                  "No sessions yet.\nTap record to get started.",
                                  textAlign: TextAlign.center)),
                        )
                      ]
                    : [
                        for (int sessionIdx = 0;
                            sessionIdx < filteredSessions.length;
                            sessionIdx++)
                          sessionCard(filteredSessions[sessionIdx], sessionIdx)
                      ]
            ],
          ),
        ),
      ),
    );
  }

  Widget sessionCard(SessionRecording session, int sessionIdx) {
    final d = Duration(seconds: session.durationSec);
    final formattedDate =
        DateFormat('EEE d MMM | HH:mm:ss').format(session.date);
    final isActiveSession = isPlayingSession && playingSessionIdx == sessionIdx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_open,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  IconButton(
                    tooltip: "Delete session",
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: isPlayingSession || isPlayingChunk
                        ? null
                        : () => deleteSession(session),
                  ),
                ],
              ),
              Text(
                  "Total duration: ${formatElapsed(session.durationSec)}  |  Chunks: ${session.chunkPaths.length}",
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icon(
                      isActiveSession ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                        isActiveSession ? "Pause Session" : "Play Session"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActiveSession
                          ? Colors.orange
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isPlayingChunk
                        ? null
                        : isActiveSession
                            ? stopPlayback
                            : () => playSession(session, sessionIdx),
                  ),
                  const SizedBox(width: 16),
                  if (isActiveSession)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                              "Current Chunk: ${playingChunkIdxInSession != null ? playingChunkIdxInSession! + 1 : ''}/${session.chunkPaths.length}"),
                        ],
                      ),
                    )
                ],
              ),
              const SizedBox(height: 10),
              // Chunks
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(session.chunkPaths.length, (i) {
                    final isCurrent =
                        (isActiveSession && playingChunkIdxInSession == i) ||
                            (isPlayingChunk &&
                                playingSessionIdx == sessionIdx &&
                                playingChunkIdxInSession == i);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: isPlayingSession
                            ? null
                            : () =>
                                playChunk(session, session.chunkPaths[i], i),
                        child: Chip(
                          label: Text(
                            "#${i + 1}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          avatar: Icon(Icons.music_note,
                              color: Theme.of(context).colorScheme.primary,
                              size: 18),
                          backgroundColor: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withAlpha(60),
                          deleteIcon: isPlayingSession || isPlayingChunk
                              ? null
                              : const Icon(Icons.delete, size: 18),
                          onDeleted: isPlayingSession || isPlayingChunk
                              ? null
                              : () => deleteChunk(session, i),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Progress bar and timer when playing a chunk
              if (isPlayingChunk && playingSessionIdx == sessionIdx)
                sliderWithTimes(),
            ],
          ),
        ),
      ),
    );
  }

  Widget sliderWithTimes() {
    final cur = chunkProgress ?? Duration.zero;
    final tot = chunkTotal ?? const Duration(seconds: 1);
    return Column(
      children: [
        Slider(
          value: cur.inMilliseconds.toDouble(),
          max: tot.inMilliseconds.toDouble(),
          onChanged: (v) => handleSeek(Duration(milliseconds: v.toInt())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatElapsed(cur.inSeconds),
                style: const TextStyle(fontSize: 12)),
            Text(formatElapsed(tot.inSeconds),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
