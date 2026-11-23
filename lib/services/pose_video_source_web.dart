import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import '../models/pose_history_models.dart';

/// Web playback: base64 bytes are turned into a blob URL so they survive a
/// page reload (the camera plugin's own blob URL does not).
abstract final class PoseVideoSource {
  static Future<VideoPlayerController> fromSession(
    LiveTrackingSession session,
  ) async {
    final path = session.videoPath;
    if (path != null && path.isNotEmpty) {
      return VideoPlayerController.networkUrl(Uri.parse(path));
    }

    final encoded = session.videoBase64;
    if (encoded == null || encoded.isEmpty) {
      throw UnsupportedError('This session has no recorded video.');
    }

    final Uint8List bytes = base64Decode(encoded);
    final type = session.videoMimeType?.isNotEmpty == true
        ? session.videoMimeType!
        : 'video/webm';
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: type),
    );
    final url = web.URL.createObjectURL(blob);
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }
}
