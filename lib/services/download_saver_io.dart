import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _downloadsChannel = MethodChannel(
  'com.insectcs.workoutapp/downloads',
);

/// Saves [bytes] into the Android Downloads collection through the native
/// MediaStore API. Returns a user-facing location on success, or `null` when
/// the platform/channel cannot handle the request (the caller then falls back
/// to the application documents directory).
Future<String?> saveToAndroidDownloads(
  String name,
  List<int> bytes,
  String mime,
) async {
  if (!Platform.isAndroid) return null;
  try {
    return await _downloadsChannel.invokeMethod<String>('saveDownload', {
      'name': name,
      'bytes': Uint8List.fromList(bytes),
      'mime': mime,
    });
  } on PlatformException catch (e) {
    debugPrint('Could not save $name to Downloads: ${e.message}');
    return null;
  } on MissingPluginException catch (e) {
    debugPrint('Downloads channel unavailable: ${e.message}');
    return null;
  }
}
