import 'dart:io';

import 'package:flutter/material.dart';

class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.image_outlined,
    this.placeholderLabel,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;
  final String? placeholderLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = imageUrl.trim();
    final uri = Uri.tryParse(resolvedUrl);
    final isSupportedRemoteImage =
        resolvedUrl.isNotEmpty &&
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    final isLocalFile = resolvedUrl.isNotEmpty &&
        (resolvedUrl.startsWith('/') ||
            resolvedUrl.contains(':\\') ||
            resolvedUrl.startsWith('file://'));

    if (isLocalFile) {
      final filePath = resolvedUrl.startsWith('file://')
          ? uri?.toFilePath() ?? resolvedUrl
          : resolvedUrl;
      final image = Image.file(
        File(filePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );

      if (borderRadius == null) {
        return image;
      }

      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    if (!isSupportedRemoteImage) {
      return _buildFallback();
    }

    final image = Image.network(
      resolvedUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return _buildFallback();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildFallback(
          icon: Icons.image_search_outlined,
          label: 'Loading image',
          showLoader: true,
        );
      },
    );

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: image,
    );
  }

  Widget _buildFallback({
    IconData? icon,
    String? label,
    bool showLoader = false,
  }) {
    final fallback = _FallbackImage(
      width: width,
      height: height,
      icon: icon ?? placeholderIcon,
      label: label ?? placeholderLabel,
      showLoader: showLoader,
      borderRadius: borderRadius,
    );

    if (borderRadius == null) {
      return fallback;
    }

    return ClipRRect(borderRadius: borderRadius!, child: fallback);
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage({
    required this.width,
    required this.height,
    required this.icon,
    this.label,
    this.showLoader = false,
    this.borderRadius,
  });

  final double? width;
  final double? height;
  final IconData icon;
  final String? label;
  final bool showLoader;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final shortestSide = [
      if (width != null) width!,
      if (height != null) height!,
    ];
    final compact = shortestSide.isNotEmpty && shortestSide.reduce((a, b) => a < b ? a : b) < 72;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLoader) ...[
                SizedBox(
                  width: compact ? 16 : 20,
                  height: compact ? 16 : 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                if (!compact) const SizedBox(height: 10),
              ] else ...[
                Icon(
                  icon,
                  color: const Color(0xFF64748B),
                  size: compact ? 22 : 28,
                ),
                if (!compact) const SizedBox(height: 8),
              ],
              if (!compact)
                Text(
                  label ?? 'Image unavailable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
