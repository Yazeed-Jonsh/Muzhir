import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:muzhir/core/utils/network_url_helper.dart';
import 'package:muzhir/theme/app_theme.dart';

/// 52×52 rounded thumbnail for [RecentScanTile]; falls back to leaf icon.
class RecentScanThumbnail extends StatelessWidget {
  const RecentScanThumbnail({super.key, required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = NetworkUrlHelper.normalizeRemoteUrl(imageUrl);
    if (url.isEmpty) {
      return _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => _loading(),
          errorWidget: (_, imageUrl, error) {
            debugPrint('[IMG_ERR] RecentScanThumbnail | $imageUrl | $error');
            return _placeholder();
          },
        ),
      ),
    );
  }

  Widget _loading() {
    return Container(
      width: 52,
      height: 52,
      color: MuzhirColors.luminousLime.withValues(alpha: 0.25),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: MuzhirColors.luminousLime.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.local_florist_rounded,
        color: MuzhirColors.coreLeafGreen,
        size: 28,
      ),
    );
  }
}
