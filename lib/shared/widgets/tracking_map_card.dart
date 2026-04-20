import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/maps_service.dart';

class TrackingMapCard extends StatefulWidget {
  const TrackingMapCard({
    super.key,
    required this.mapsService,
    required this.title,
    required this.subtitle,
    required this.markers,
    required this.trackingPoints,
    this.polylines = const <TrackingMapPolyline>{},
    this.legendItems = const <TrackingMapLegendItem>[],
    this.height = 260,
    this.isInteractive = true,
    this.interactionHint,
    this.fallbackMessage,
  });

  final MapsService mapsService;
  final String title;
  final String subtitle;
  final Set<TrackingMapMarker> markers;
  final Set<TrackingMapPolyline> polylines;
  final List<TrackingMapLegendItem> legendItems;
  final List<TrackingCoordinate> trackingPoints;
  final double height;
  final bool isInteractive;
  final String? interactionHint;
  final String? fallbackMessage;

  @override
  State<TrackingMapCard> createState() => _TrackingMapCardState();
}

class _TrackingMapCardState extends State<TrackingMapCard> {
  final MapController _controller = MapController();
  Timer? _fitDebounce;

  @override
  void didUpdateWidget(covariant TrackingMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackingPoints.isNotEmpty &&
        oldWidget.trackingPoints != widget.trackingPoints) {
      _fitDebounce?.cancel();
      _fitDebounce = Timer(
        const Duration(milliseconds: 180),
        () => widget.mapsService.fitMapToPoints(_controller, widget.trackingPoints),
      );
    }
  }

  @override
  void dispose() {
    _fitDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = widget.mapsService.initialViewportFor(widget.trackingPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: widget.mapsService.isConfigured &&
                  widget.trackingPoints.isNotEmpty
              ? SizedBox(
                  height: widget.height,
                  child: FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: viewport.center,
                      initialZoom: viewport.zoom,
                      interactionOptions: InteractionOptions(
                        flags: widget.isInteractive
                            ? InteractiveFlag.all & ~InteractiveFlag.rotate
                            : InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: widget.mapsService.tileUrlTemplate,
                        userAgentPackageName: 'quickdeliver',
                      ),
                      PolylineLayer(
                        polylines: widget.polylines
                            .map(
                              (polyline) => Polyline(
                                points: polyline.points,
                                color: polyline.color,
                                strokeWidth: polyline.width.toDouble(),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      MarkerLayer(
                        markers: widget.markers
                            .map(
                              (marker) => Marker(
                                point: marker.point.latLng,
                                width: 44,
                                height: 44,
                                child: Tooltip(
                                  message: '${marker.title}\n${marker.snippet}',
                                  child: _TrackingMarkerPin(marker: marker),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            widget.mapsService.tileAttribution,
                            onTap: () => launchUrl(
                              widget.mapsService.tileAttributionUrl,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : _TrackingMapFallback(
                  height: widget.height,
                  message:
                      widget.fallbackMessage ?? MapsService.fallbackMessage,
                ),
        ),
        if (widget.legendItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.legendItems
                .map((item) => _LegendPill(item: item))
                .toList(growable: false),
          ),
        ],
        if (widget.interactionHint != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.interactionHint!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }
}

class TrackingMapLegendItem {
  const TrackingMapLegendItem({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

class _TrackingMarkerPin extends StatelessWidget {
  const _TrackingMarkerPin({required this.marker});

  final TrackingMapMarker marker;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: marker.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(marker.icon, color: Colors.white, size: 20),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.item});

  final TrackingMapLegendItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: item.color, size: 16),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingMapFallback extends StatelessWidget {
  const _TrackingMapFallback({
    required this.height,
    required this.message,
  });

  final double height;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
