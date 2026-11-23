import 'dart:io';

import 'package:video_player/video_player.dart';

import '../models/pose_history_models.dart';

/// Native video playback: the recorder wrote the video into app documents.
abstract final class PoseVideoSource {
  static Future<VideoPlayerController> fromSession(
    LiveTrackingSession session,
  ) async {
    final path = session.videoPath;
    if (path == null || path.isEmpty) {
      throw UnsupportedError('This session has no recorded video.');
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return VideoPlayerController.networkUrl(Uri.parse(path));
    }

    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('Recorded video is no longer on disk.');
    }
    return VideoPlayerController.file(file);
  }
}
