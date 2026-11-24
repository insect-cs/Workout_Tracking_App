import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
// camera re-exports only the public camera types; the platform-interface data
// classes are needed to build synthetic frames for these unit tests.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:workout_app/services/pose_analysis_service.dart';

CameraImage _nv21Image(Uint8List bytes, {int width = 4, int height = 4}) {
  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.nv21, raw: 17),
      width: width,
      height: height,
      planes: [
        CameraImagePlane(bytes: bytes, bytesPerRow: width, bytesPerPixel: 1),
      ],
    ),
  );
}

void main() {
  group('packedNv21FromCameraImage', () {
    test('keeps an already correctly sized NV21 buffer', () {
      final bytes = Uint8List(4 * 4 * 3 ~/ 2);
      final result = packedNv21FromCameraImage(_nv21Image(bytes));

      expect(result, isNotNull);
      expect(result!.length, 24);
      expect(identical(result, bytes), isTrue);
    });

    test('trims the padding CameraX can add to NV21 buffers', () {
      // CameraX allocates based on the padded Y stride, so the buffer can be
      // longer than width * height * 1.5. ML Kit rejects the extra bytes.
      final bytes = Uint8List(4 * 4 * 3 ~/ 2 + 4);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = i;
      }
      final result = packedNv21FromCameraImage(_nv21Image(bytes));

      expect(result, isNotNull);
      expect(result!.length, 24);
      expect(result, bytes.sublist(0, 24));
    });

    test('rejects a buffer that is too short', () {
      final result = packedNv21FromCameraImage(_nv21Image(Uint8List(4 * 4)));
      expect(result, isNull);
    });

    test('converts three YUV_420_888 planes into interleaved NV21', () {
      // 4x4 frame: 16 Y bytes, 2x2 U and V bytes.
      const width = 4;
      const height = 4;
      final y = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
      final u = Uint8List.fromList([101, 102, 103, 104]);
      final v = Uint8List.fromList([201, 202, 203, 204]);

      final image = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
          width: width,
          height: height,
          planes: [
            CameraImagePlane(bytes: y, bytesPerRow: width, bytesPerPixel: 1),
            CameraImagePlane(bytes: u, bytesPerRow: 2, bytesPerPixel: 1),
            CameraImagePlane(bytes: v, bytesPerRow: 2, bytesPerPixel: 1),
          ],
        ),
      );

      final result = packedNv21FromCameraImage(image);

      expect(result, isNotNull);
      expect(result!.length, 24);
      expect(result.sublist(0, 16), y);
      // NV21 stores V then U for each chroma pair.
      expect(result.sublist(16), [201, 101, 202, 102, 203, 103, 204, 104]);
    });

    test('honours plane strides for YUV_420_888 frames', () {
      const width = 4;
      const height = 4;
      // Y has a padded row stride of 6; chroma uses a pixel stride of 2.
      final y = Uint8List(6 * height);
      for (var row = 0; row < height; row++) {
        for (var col = 0; col < width; col++) {
          y[row * 6 + col] = row * width + col + 1;
        }
      }
      final u = Uint8List(8);
      final v = Uint8List(8);
      for (var i = 0; i < 4; i++) {
        u[i * 2] = 100 + i * 2;
        v[i * 2] = 200 + i * 2;
      }

      final image = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
          width: width,
          height: height,
          planes: [
            CameraImagePlane(bytes: y, bytesPerRow: 6, bytesPerPixel: 1),
            CameraImagePlane(bytes: u, bytesPerRow: 4, bytesPerPixel: 2),
            CameraImagePlane(bytes: v, bytesPerRow: 4, bytesPerPixel: 2),
          ],
        ),
      );

      final result = packedNv21FromCameraImage(image);

      expect(result, isNotNull);
      expect(result!.sublist(0, 16), List<int>.generate(16, (i) => i + 1));
      expect(result.sublist(16), [200, 100, 202, 102, 204, 104, 206, 106]);
    });
  });

  group('poseFrameSize', () {
    test('uses frame dimensions for unrotated frames', () {
      expect(
        poseFrameSize(640, 480, InputImageRotation.rotation0deg),
        const Size(640, 480),
      );
      expect(
        poseFrameSize(640, 480, InputImageRotation.rotation180deg),
        const Size(640, 480),
      );
    });

    test('swaps dimensions for quarter-turn rotations', () {
      expect(
        poseFrameSize(640, 480, InputImageRotation.rotation90deg),
        const Size(480, 640),
      );
      expect(
        poseFrameSize(640, 480, InputImageRotation.rotation270deg),
        const Size(480, 640),
      );
    });
  });
}
