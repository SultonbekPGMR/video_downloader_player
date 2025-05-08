import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';

class VideoDownloadManager {
  final String downloadPath;

  VideoDownloadManager({required this.downloadPath});

  Future<String?> startDownload(String url, String fileName) async {
    try {
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
      );
      return taskId;
    } catch (e) {
      throw DownloadException("Download failed: $e");
    }
  }

  Future<void> cancelDownload(String taskId) async {
    try {
      await FlutterDownloader.cancel(taskId: taskId);
    } catch (e) {
      throw DownloadException("Failed to cancel: $e");
    }
  }

  Future<void> removeDownload(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw DownloadException("Error removing file: $e");
    }
  }

  bool fileExists(String filePath) {
    return File(filePath).existsSync();
  }
}

class DownloadException implements Exception {
  final String message;
  DownloadException(this.message);
}
