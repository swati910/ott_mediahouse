import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/upload/s3_multipart_upload_service.dart';

class MultipartUploadProgressWidget extends StatelessWidget {
  final MultipartProgressInfo info;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;
  final VoidCallback? onAbort;
  final VoidCallback? onReselectFile;
  final bool isFileMissingForResume;

  const MultipartUploadProgressWidget({
    super.key,
    required this.info,
    this.onPause,
    this.onResume,
    this.onRetry,
    this.onAbort,
    this.onReselectFile,
    this.isFileMissingForResume = false,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final double numVal = bytes / pow(1024, i);
    return '${numVal.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    return '${formatBytes(bytesPerSec.toInt())}/s';
  }

  static String formatEta(int seconds) {
    if (seconds <= 0) return '--:--';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final m = mins % 60;
      return '${hrs}h ${m}m';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(info.state, theme);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_statusIcon(info.state), color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info.state == MultipartUploadState.idle
                      ? 'Multipart Video Uploader'
                      : _statusTitle(info.state),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.canvasColor,
                  ),
                ),
              ),
              Text(
                '${info.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          /// Linear Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (info.percentage / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.dividerColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),

          /// Statistics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatBytes(info.uploadedBytes)} / ${formatBytes(info.totalBytes)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.canvasColor.withOpacity(0.7),
                ),
              ),
              if (info.totalParts > 0)
                Text(
                  'Parts: ${info.completedParts}/${info.totalParts}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.canvasColor.withOpacity(0.7),
                  ),
                ),
            ],
          ),
          if (info.state == MultipartUploadState.uploading) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Speed: ${formatSpeed(info.speedBytesPerSec)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.canvasColor.withOpacity(0.6),
                  ),
                ),
                Text(
                  'Remaining: ${formatEta(info.remainingSeconds)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.canvasColor.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],

          /// File Reselection prompt if needed for resume
          if (isFileMissingForResume && info.state == MultipartUploadState.paused) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Please reselect the original file to resume upload.',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                  TextButton(
                    onPressed: onReselectFile,
                    child: const Text('Select File'),
                  ),
                ],
              ),
            ),
          ],

          /// Error Message Display
          if (info.errorMessage != null && info.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          ],

          /// Control Buttons
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (info.state == MultipartUploadState.uploading ||
                  info.state == MultipartUploadState.resuming) ...[
                OutlinedButton.icon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause, size: 16),
                  label: const Text('Pause'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (info.state == MultipartUploadState.paused) ...[
                ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (info.state == MultipartUploadState.failed) ...[
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (info.state == MultipartUploadState.initiating ||
                  info.state == MultipartUploadState.uploading ||
                  info.state == MultipartUploadState.paused ||
                  info.state == MultipartUploadState.resuming ||
                  info.state == MultipartUploadState.failed) ...[
                OutlinedButton.icon(
                  onPressed: () => _confirmAbort(context),
                  icon: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                  label: const Text('Cancel Upload', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _confirmAbort(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abort Upload?'),
        content: const Text(
          'Are you sure you want to abort this upload session? Upload progress for this video will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, keep upload'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              onAbort?.call();
            },
            child: const Text('Yes, Abort Upload'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(MultipartUploadState s, ThemeData theme) {
    switch (s) {
      case MultipartUploadState.idle:
        return theme.primaryColor;
      case MultipartUploadState.initiating:
        return Colors.orange;
      case MultipartUploadState.uploading:
        return Colors.blue;
      case MultipartUploadState.paused:
        return Colors.amber;
      case MultipartUploadState.resuming:
        return Colors.cyan;
      case MultipartUploadState.completing:
        return Colors.indigo;
      case MultipartUploadState.completed:
        return Colors.green;
      case MultipartUploadState.failed:
        return Colors.red;
      case MultipartUploadState.aborted:
        return Colors.grey;
    }
  }

  IconData _statusIcon(MultipartUploadState s) {
    switch (s) {
      case MultipartUploadState.idle:
        return Icons.cloud_upload;
      case MultipartUploadState.initiating:
        return Icons.cloud_sync;
      case MultipartUploadState.uploading:
        return Icons.cloud_upload;
      case MultipartUploadState.paused:
        return Icons.pause_circle_filled;
      case MultipartUploadState.resuming:
        return Icons.play_circle_fill;
      case MultipartUploadState.completing:
        return Icons.task_alt;
      case MultipartUploadState.completed:
        return Icons.check_circle;
      case MultipartUploadState.failed:
        return Icons.error;
      case MultipartUploadState.aborted:
        return Icons.cancel;
    }
  }

  String _statusTitle(MultipartUploadState s) {
    switch (s) {
      case MultipartUploadState.idle:
        return 'Ready to upload';
      case MultipartUploadState.initiating:
        return 'Initiating S3 multipart session...';
      case MultipartUploadState.uploading:
        return 'Uploading to Amazon S3...';
      case MultipartUploadState.paused:
        return 'Upload Paused';
      case MultipartUploadState.resuming:
        return 'Resuming upload...';
      case MultipartUploadState.completing:
        return 'Completing S3 upload session...';
      case MultipartUploadState.completed:
        return 'Upload Completed!';
      case MultipartUploadState.failed:
        return 'Upload Failed';
      case MultipartUploadState.aborted:
        return 'Upload Aborted';
    }
  }
}
