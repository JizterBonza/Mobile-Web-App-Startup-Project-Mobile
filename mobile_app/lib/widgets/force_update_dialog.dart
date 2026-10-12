import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../provider/app_update_provider.dart';

/// Non-dismissible dialog shown when the backend requires an update.
class ForceUpdateDialog extends StatelessWidget {
  const ForceUpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ForceUpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updater = context.watch<AppUpdateProvider>();
    final release = updater.latest;
    final percent = (updater.progress * 100).toStringAsFixed(0);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.system_update,
                color: AppColors.brandPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Update Required')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version${release != null ? ' (v${release.versionName})' : ''} '
                'is required to continue using the app.',
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
              if (release?.releaseNotes?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  "What's new",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  release!.releaseNotes!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
              if (release != null && release.formattedFileSize.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Download size: ${release.formattedFileSize}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (updater.isDownloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: updater.progress > 0 ? updater.progress : null,
                  color: AppColors.brandPrimary,
                  backgroundColor: AppColors.brandPrimary.withOpacity(0.1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Downloading... $percent%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (updater.error != null && !updater.isDownloading) ...[
                const SizedBox(height: 12),
                Text(
                  updater.error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: updater.isDownloading ? null : updater.startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              updater.isDownloading
                  ? 'Downloading...'
                  : updater.error != null
                      ? 'Retry'
                      : 'Update Now',
            ),
          ),
        ],
      ),
    );
  }
}
