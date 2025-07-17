import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_recording.dart';
import '../widgets/build_body.dart';
import '../widgets/recording_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SessionRecording> sessions = [];
  final AudioRecorder recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();

  Timer? chunkTimer;
  Timer? sessionTimer;
  List<String> currentChunks = [];
  String? currentSessionId;
  int currentSessionElapsed = 0;
  bool isRecording = false;
  bool isStopping = false;
  bool isPlaying = false;
  String? currentlyPlayingChunk;
  String? currentlyPlayingSessionId;

  TextEditingController searchController = TextEditingController();
  List<SessionRecording> filteredSessions = [];

  // -- Lifecycle --
  @override
  void initState() {
    super.initState();
    loadSessions();
  }

  @override
  void dispose() {
    chunkTimer?.cancel();
    sessionTimer?.cancel();
    recorder.dispose();
    player.dispose();
    super.dispose();
  }

  // -- Session Storage --
  Future<String> _getSaveDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

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

  // -- Session/Chunk Deletion --
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

  // -- Recording State Management (Robust) --

  Future<void> startSessionRecording() async {
    if (isRecording || isStopping) return;
    setState(() {
      isRecording = true;
      isStopping = false;
      currentSessionElapsed = 0;
      currentlyPlayingSessionId = null;
      currentlyPlayingChunk = null;
      isPlaying = false;
    });

    currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    currentChunks = [];

    sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => currentSessionElapsed++);
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
    await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    currentChunks.add(path);
  }

  Future<void> _stopChunkAndStartNext() async {
    if (!await recorder.isRecording()) return;
    await recorder.stop();
    await _startNewChunk();
  }

  Future<void> stopSessionRecording() async {
    if (!isRecording || isStopping) return;
    setState(() => isStopping = true);

    chunkTimer?.cancel();
    sessionTimer?.cancel();
    try {
      if (await recorder.isRecording()) {
        await recorder.stop();
      }
    } catch (_) {}
    final session = SessionRecording(
      sessionId: currentSessionId ?? '',
      chunkPaths: List.of(currentChunks),
      date: DateTime.now(),
      durationSec: currentSessionElapsed, // <-- ADD THIS LINE
    );

    setState(() {
      sessions.add(session);
      filteredSessions = List.from(sessions);
      isRecording = false;
      isStopping = false;
      currentSessionElapsed = 0;
      currentSessionId = null;
      currentChunks.clear();
    });
    await saveSessions();
  }

  // -- Playback --
  Future<void> playSession(SessionRecording session) async {
    if (isPlaying) return;
    setState(() {
      isPlaying = true;
      currentlyPlayingSessionId = session.sessionId;
      currentlyPlayingChunk = null;
    });
    try {
      for (final chunk in session.chunkPaths) {
        await player.setFilePath(chunk);
        await player.play();
        await player.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
        if (!isPlaying) break; // For manual stop
      }
    } catch (_) {}
    setState(() {
      isPlaying = false;
      currentlyPlayingSessionId = null;
      currentlyPlayingChunk = null;
    });
  }

  Future<void> playChunk(SessionRecording session, String path) async {
    if (isPlaying) return;
    setState(() {
      isPlaying = true;
      currentlyPlayingSessionId = session.sessionId;
      currentlyPlayingChunk = path;
    });
    try {
      await player.setFilePath(path);
      await player.play();
      await player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } catch (_) {}
    setState(() {
      isPlaying = false;
      currentlyPlayingSessionId = null;
      currentlyPlayingChunk = null;
    });
  }

  void stopPlayback() {
    if (isPlaying) {
      player.stop();
      setState(() {
        isPlaying = false;
        currentlyPlayingSessionId = null;
        currentlyPlayingChunk = null;
      });
    }
  }

  // -- Search --
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

  String get currentSessionElapsedString {
    final d = Duration(seconds: currentSessionElapsed);
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0)
      return "${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
    return "${d.inMinutes}:${two(d.inSeconds % 60)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BuildBody(
        isRecording: isRecording && !isStopping,
        isStopping: isStopping,
        searchController: searchController,
        sessions: sessions,
        filteredSessions: filteredSessions,
        currentSessionElapsed: currentSessionElapsed,
        currentSessionElapsedString: currentSessionElapsedString,
        deleteSession: deleteSession,
        deleteChunk: deleteChunk,
        playSession: playSession,
        playChunk: playChunk,
        stopPlayback: stopPlayback,
        searchSessions: searchSessions,
        isAnyPlaying: isPlaying,
        currentlyPlayingSessionId: currentlyPlayingSessionId,
        currentlyPlayingChunk: currentlyPlayingChunk,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16),
        child: RecordingButton(
          isRecording: isRecording && !isStopping,
          onRecordingStateChanged: (val) async {
            if (val) {
              await startSessionRecording();
            } else {
              await stopSessionRecording();
            }
          },
          disabled: isStopping || isPlaying,
        ),
      ),
    );
  }
}
