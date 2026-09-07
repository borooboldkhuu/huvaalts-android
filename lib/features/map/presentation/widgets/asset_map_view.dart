import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/storage_urls.dart';
import '../../../assets/domain/entities/asset_card.dart';
import '../../../home/presentation/controllers/nearby_location_provider.dart';

/// Ulaanbaatar city center — used only as a last-resort camera target when
/// neither the device's location nor any asset in the current result set
/// has coordinates to center on. Not a claim about where assets actually
/// are, just a sane default so the map doesn't open on the middle of the
/// ocean (0, 0).
const LatLng _ulaanbaatarCenter = LatLng(47.9184, 106.9177);

/// Map view for Search (spec section 13, "Map/list hybrid browsing"):
/// plots a pin for every asset in the *currently loaded* result page that
/// has `latitude`/`longitude` set (map view doesn't fetch its own separate
/// page — it reuses whatever [SearchAssetsController] already has, same as
/// the list view, so the two stay in sync with the active filters).
///
/// "Live" location is the device's own position, shown via
/// [GoogleMap.myLocationEnabled] — that's the native Google Maps SDK layer
/// continuously updating a blue dot from the platform's location services,
/// not a custom GPS-polling/broadcast pipeline. Asset pins themselves are
/// static (an asset's location is set once at listing time, spec section
/// 14), so there's nothing else that needs to move in real time here.
///
/// Requires the same platform setup as [nearbyLocationProvider] (README
/// "Known issues": `android`/`ios` platform projects generated via
/// `flutter create .`, plus a real Google Maps API key wired into
/// `AndroidManifest.xml`/`AppDelegate.swift` — none of which exist in this
/// scaffold yet) — until then this widget builds and type-checks but has
/// no platform view to actually render against.
class AssetMapView extends ConsumerStatefulWidget {
  const AssetMapView({required this.assets, required this.onAssetTap, super.key});

  final List<AssetCard> assets;
  final ValueChanged<String> onAssetTap;

  @override
  ConsumerState<AssetMapView> createState() => _AssetMapViewState();
}

class _AssetMapViewState extends ConsumerState<AssetMapView> {
  GoogleMapController? _controller;
  AssetCard? _selected;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<AssetCard> get _located =>
      widget.assets.where((a) => a.latitude != null && a.longitude != null).toList();

  Set<Marker> _buildMarkers(List<AssetCard> located) {
    return {
      for (final asset in located)
        Marker(
          markerId: MarkerId(asset.id),
          position: LatLng(asset.latitude!, asset.longitude!),
          onTap: () => setState(() => _selected = asset),
        ),
    };
  }

  LatLng _initialCenter(List<AssetCard> located, (double, double)? deviceLocation) {
    if (deviceLocation != null) {
      return LatLng(deviceLocation.$1, deviceLocation.$2);
    }
    if (located.isNotEmpty) {
      return LatLng(located.first.latitude!, located.first.longitude!);
    }
    return _ulaanbaatarCenter;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final AsyncValue<(double, double)?> deviceLocationAsync = ref.watch(nearbyLocationProvider);
    final (double, double)? deviceLocation = deviceLocationAsync.value;
    final List<AssetCard> located = _located;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialCenter(located, deviceLocation),
            zoom: deviceLocation != null || located.isNotEmpty ? 12 : 10,
          ),
          markers: _buildMarkers(located),
          // Only ask the Maps SDK to draw the blue "my location" dot once
          // `nearbyLocationProvider` has actually confirmed a location fix
          // — enabling this without a granted permission throws a
          // PlatformException on Android rather than degrading quietly.
          myLocationEnabled: deviceLocation != null,
          myLocationButtonEnabled: deviceLocation != null,
          onMapCreated: (controller) => _controller = controller,
          onTap: (_) => setState(() => _selected = null),
        ),
        if (located.isEmpty)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _InfoBanner(text: l10n.mapNoLocatedAssets, theme: theme),
          )
        else if (deviceLocationAsync.hasValue && deviceLocation == null)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: _InfoBanner(text: l10n.mapMyLocationUnavailable, theme: theme),
          ),
        if (_selected != null)
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: _MarkerPreviewCard(
              asset: _selected!,
              l10n: l10n,
              onTap: () => widget.onAssetTap(_selected!.id),
              onClose: () => setState(() => _selected = null),
            ),
          ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.md),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Text(text, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
      ),
    );
  }
}

class _MarkerPreviewCard extends StatelessWidget {
  const _MarkerPreviewCard({
    required this.asset,
    required this.l10n,
    required this.onTap,
    required this.onClose,
  });

  final AssetCard asset;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onClose;

  String _priceLabel() {
    if (asset.pricePerDay != null) {
      return CurrencyFormatter.formatPerUnit(asset.pricePerDay!, l10n.unitDay);
    }
    if (asset.pricePerHour != null) {
      return CurrencyFormatter.formatPerUnit(asset.pricePerHour!, l10n.unitHour);
    }
    if (asset.pricePerWeek != null) {
      return CurrencyFormatter.formatPerUnit(asset.pricePerWeek!, l10n.unitWeek);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? imageUrl = StorageUrls.assetImage(asset.primaryImagePath);

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: imageUrl != null
                      ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.inventory_2_outlined,
                              color: theme.colorScheme.secondary.withOpacity(0.4)),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      asset.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _priceLabel(),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
