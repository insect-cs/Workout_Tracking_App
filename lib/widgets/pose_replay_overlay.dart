import 'package:flutter/material.dart';

import '../models/pose_history_models.dart';
import '../theme/app_colors.dart';
import 'pose_skeleton_painter.dart';

/// Skeleton drawn over a saved live-session video at one replay timestamp.
///
/// The video player owns the playback clock and passes the index of the sample
/// to display. Keeping this widget separate from the player makes the overlay
/// reusable and lets tests inspect the decoded keypoints directly.
class PoseReplayOverlay extends StatelessWidget {
  const PoseReplayOverlay({
    super.key,
    required this.frames,
    required this.frameIndex,
    this.unmirrorX = false,
  });

  final List<PoseReplayFrame> frames;
  final int frameIndex;
  final bool unmirrorX;

  @override
  Widget build(BuildContext context) {
    if (frameIndex < 0 || frameIndex >= frames.length) {
      return const SizedBox.shrink();
    }

    final keypoints = frames[frameIndex].toPoseKeypoints(unmirrorX: unmirrorX);
    if (keypoints.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        key: const Key('pose-replay-overlay'),
        painter: PoseSkeletonPainter(
          keypoints: keypoints,
          lineColor: AppColors.emerald,
          pointColor: AppColors.textWhite,
        ),
      ),
    );
  }
}
