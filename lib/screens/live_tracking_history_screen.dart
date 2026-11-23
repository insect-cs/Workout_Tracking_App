import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../models/pose_history_models.dart';
import '../services/live_tracking_history_service.dart';
import '../services/pose_video_source.dart';
import '../services/pose_analysis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/pose_skeleton_painter.dart';

/// Read-only view of live camera tracking sessions saved on this device.
///
/// Embedded in the Pose tracking screen's History tab. [onBack] is optional so
/// the same widget can also be used as a standalone screen.
class LiveTrackingHistoryScreen extends StatefulWidget {
  const LiveTrackingHistoryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LiveTrackingHistoryScreen> createState() =>
      _LiveTrackingHistoryScreenState();
}

class _LiveTrackingHistoryScreenState extends State<LiveTrackingHistoryScreen> {
  List<LiveTrackingSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _sessions = LiveTrackingHistoryStore.read();
    LiveTrackingHistoryStore.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    LiveTrackingHistoryStore.revision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _sessions = LiveTrackingHistoryStore.read());
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          'Clear live tracking history?',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        content: Text(
          'This permanently removes all saved live tracking sessions from '
          'this device.',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await LiveTrackingHistoryStore.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    widget.onBack == null ? Icons.history : Icons.arrow_back,
                    color: AppColors.textLight,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE TRACKING HISTORY',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textWhite,
                      ),
                    ),
                    Text(
                      '${_sessions.length} saved session'
                      '${_sessions.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSlate,
                      ),
                    ),
                  ],
                ),
              ),
              if (_sessions.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all',
                  onPressed: _confirmClear,
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    color: AppColors.rose,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _sessions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) =>
                      _buildSessionCard(_sessions[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.history_toggle_off,
                color: AppColors.primaryOrange,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No live tracking sessions yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start tracking in the Pose tab, then tap Save live tracking. '
              'Reps, angles and the last detected skeleton appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(LiveTrackingSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.exerciseName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(session.startedAt),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSlate,
                      ),
                    ),
                    if (session.exerciseName == 'No live tracking') ...[
                      const SizedBox(height: 4),
                      Text(
                        'NO LIVE TRACKING HAPPENED',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: AppColors.rose,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.formattedDuration,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => LiveTrackingHistoryStore.remove(session.id),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.rose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metric(Icons.repeat, 'Reps', '${session.repCount}'),
              ),
              Expanded(
                child: _metric(
                  Icons.accessibility_new,
                  'Knee',
                  session.minKneeAngle == null
                      ? '--'
                      : '${session.minKneeAngle!.round()}°',
                ),
              ),
              Expanded(
                child: _metric(
                  Icons.front_hand,
                  'Elbow',
                  session.minElbowAngle == null
                      ? '--'
                      : '${session.minElbowAngle!.round()}°',
                ),
              ),
            ],
          ),
          if (session.feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              session.feedback,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSlate,
              ),
            ),
          ],
          if (session.hasVideo) ...[
            const SizedBox(height: 10),
            _SessionVideoPlayer(
              key: Key('session-video-${session.id}'),
              session: session,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${session.engine}'
            '${session.cameraName == null ? '' : '  •  ${session.cameraName}'}',
            style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted),
          ),
          if (session.keypoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: PoseSkeletonPainter(
                  keypoints: session.keypoints
                      .map(
                        (point) => PoseKeypoint(
                          name: point.name,
                          x: point.x,
                          y: point.y,
                          confidence: point.confidence,
                        ),
                      )
                      .toList(),
                  lineColor: AppColors.primaryOrange,
                  pointColor: AppColors.textWhite,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardInset,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.primaryOrange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 9, color: AppColors.textSlate),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return '${date.day}/${date.month}/${date.year}  •  $time';
  }
}

/// Playback for the camera video captured with a saved live session.
class _SessionVideoPlayer extends StatefulWidget {
  const _SessionVideoPlayer({super.key, required this.session});

  final LiveTrackingSession session;

  @override
  State<_SessionVideoPlayer> createState() => _SessionVideoPlayerState();
}

class _SessionVideoPlayerState extends State<_SessionVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    VideoPlayerController? controller;
    try {
      controller = await PoseVideoSource.fromSession(widget.session);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      debugPrint('Could not play saved live video: $e');
      await controller?.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return _placeholder(Icons.videocam_off_outlined, 'Video unavailable');
    }
    if (controller == null) {
      return _placeholder(Icons.hourglass_top, 'Loading captured video...');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          GestureDetector(
            onTap: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            },
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Container(
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  key: Key('session-video-toggle-${widget.session.id}'),
                  onPressed: () {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                    setState(() {});
                  },
                  icon: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.textWhite,
                    size: 18,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controller.setVolume(controller.value.volume > 0 ? 0 : 1);
                    setState(() {});
                  },
                  icon: Icon(
                    controller.value.volume > 0
                        ? Icons.volume_up
                        : Icons.volume_off,
                    color: AppColors.textWhite,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: AppColors.primaryOrange,
                      bufferedColor: AppColors.orangeBorder,
                      backgroundColor: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(IconData icon, String label) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.cardInset,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 26),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSlate),
          ),
        ],
      ),
    );
  }
}
