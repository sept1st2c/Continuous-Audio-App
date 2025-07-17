import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class OtherMethods {
  Future<String?> saveToExternalStorage(String sourceFilePath) async {
    try {
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('No downloads directory found.');
      }
      final String targetPath = p.join(downloadsDir.path, 'recording.mp3');
      final File sourceFile = File(sourceFilePath);
      final File targetFile = await sourceFile.copy(targetPath);
      // recordedFiles.add(targetPath);

      return targetFile.path;
    } catch (err) {
      print("Error saving file: $err");
      return null;
    }
  }

  void shareFile(String filePath) {
    try {
      final XFile file = XFile(filePath);
      Share.shareXFiles([file], text: 'share my recording');
    } catch (e) {
      print("Error sharing file: $e");
    }
  }
}
