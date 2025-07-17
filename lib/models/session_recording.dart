import 'dart:convert';

class SessionRecording {
  String sessionId;
  List<String> chunkPaths;
  DateTime date;
  int durationSec;

  SessionRecording({
    required this.sessionId,
    required this.chunkPaths,
    required this.date,
    required this.durationSec,
  });

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'chunkPaths': chunkPaths,
        'date': date.toIso8601String(),
        'durationSec': durationSec,
      };

  factory SessionRecording.fromMap(Map<String, dynamic> map) {
    return SessionRecording(
      sessionId: map['sessionId'],
      chunkPaths: List<String>.from(map['chunkPaths']),
      date: DateTime.parse(map['date']),
      durationSec: map['durationSec'],
    );
  }

  String toJson() => json.encode(toMap());
  factory SessionRecording.fromJson(String source) =>
      SessionRecording.fromMap(json.decode(source));
}
