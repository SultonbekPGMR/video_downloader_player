import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

class VideoDownloadManager {
  final String downloadPath;
  static VideoDownloadManager? _instance;
  static ReceivePort? _port;

  final BehaviorSubject<List<String>> _downloadedVideosController = BehaviorSubject<List<String>>();
  Stream<List<String>> get downloadedVideosStream => _downloadedVideosController.stream;

  final StreamController<double> _downloadProgressController = StreamController<double>.broadcast();
  Stream<double> get downloadProgressStream => _downloadProgressController.stream;

  final StreamController<String> _downloadCompleteController = StreamController<String>.broadcast();
  Stream<String> get downloadCompleteStream => _downloadCompleteController.stream;

  final StreamController<String> _downloadErrorController = StreamController<String>.broadcast();
  Stream<String> get downloadErrorStream => _downloadErrorController.stream;

  VideoDownloadManager._({required this.downloadPath}) {
    _instance = this;
  }

  static Future<VideoDownloadManager> initialize() async {
    if (_instance != null) return _instance!;



    // Register port and callback
    _port ??= ReceivePort();
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    IsolateNameServer.registerPortWithName(_port!.sendPort, 'downloader_send_port');
    FlutterDownloader.registerCallback(downloadCallback);

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String downloadPath = appDocDir.path;

    final manager = VideoDownloadManager._(downloadPath: downloadPath);

    _port!.listen((dynamic data) {
      print('TTTPPP port received: $data');
      String id = data[0];
      int status = data[1];
      int progress = data[2];

      if (status == DownloadTaskStatus.complete.index) {
        print('TTTPPP status complete for $id');
        manager._downloadCompleteController.add(id);
        manager._updateDownloadedVideosStream();
      } else if (status == DownloadTaskStatus.failed.index) {
        print('TTTPPP status failed for $id');
        manager._downloadErrorController.add("Download failed: $id");
      } else {
        print('TTTPPP progress $progress for $id');
        manager._downloadProgressController.add(progress / 100.0);
      }
    });

    // Initial scan for downloaded videos
    await manager._updateDownloadedVideosStream();

    return manager;
  }



  Future<String?> startDownload(String url) async {
    try {
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: downloadPath,
        fileName: url.split('/').last,
        showNotification: true,
        openFileFromNotification: true,
      );
      return taskId;
    } catch (e) {
      _downloadErrorController.add("Download failed: $e");
      throw DownloadException("Download failed: $e");
    }
  }

  Future<void> cancelDownload(String taskId) async {
    try {
      await FlutterDownloader.cancel(taskId: taskId);
    } catch (e) {
      _downloadErrorController.add("Failed to cancel: $e");
      throw DownloadException("Failed to cancel: $e");
    }
  }

  Future<void> removeDownload(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        await _updateDownloadedVideosStream();
      }
    } catch (e) {
      _downloadErrorController.add("Error removing file: $e");
      throw DownloadException("Error removing file: $e");
    }
  }

  bool fileExists(String filePath) {
    return File(filePath).existsSync();
  }

  Future<void> _updateDownloadedVideosStream() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final videos = await _getDownloadedVideoPaths();
    print('TTTPPP _updateDownloadedVideosStream $videos');
    _downloadedVideosController.add(videos);
  }

  Future<List<String>> _getDownloadedVideoPaths({List<String>? allowedExtensions}) async {
    final dir = Directory(downloadPath);
    if (!await dir.exists()) return [];
    final files = await dir.list().toList();
    final exts = allowedExtensions ?? ['.mp4', '.mkv', '.mov', '.webm', '.m3u8'];
    return files
        .whereType<File>()
        .where((file) => exts.any((ext) => file.path.toLowerCase().endsWith(ext)))
        .map((file) => file.path)
        .toList();
  }

  void dispose() {
    _downloadProgressController.close();
    _downloadCompleteController.close();
    _downloadErrorController.close();
    _downloadedVideosController.close();
    if (_instance == this) {
      _instance = null;
    }
  }
}

class DownloadException implements Exception {
  final String message;
  DownloadException(this.message);
}

@pragma('vm:entry-point')
 void downloadCallback(String id, int status, int progress) {
print('TTTPPP downloadCallback $id $status $progress');
final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
send?.send([id, status, progress]);
}