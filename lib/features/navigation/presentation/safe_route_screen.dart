import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/common_widgets/neon_button.dart';
import '../../../core/providers/safe_route_provider.dart';
import '../../../core/providers/telemetry_provider.dart';
import '../../../core/providers/night_safety_provider.dart';

class SafeRouteScreen extends ConsumerStatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  ConsumerState<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends ConsumerState<SafeRouteScreen>
    with SingleTickerProviderStateMixin {
  final _destCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;
  late AnimationController _compassCtrl;
  MapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  bool _isSearching = false;
  bool _isCardExpanded = true;

  // Preset quick destinations
  static const _quickPicks = [
    ('Home', Icons.home_rounded),
    ('Work', Icons.business_rounded),
    ('Station', Icons.train_rounded),
    ('Hospital', Icons.local_hospital_rounded),
    ('Airport', Icons.flight_rounded),
    ('Mall', Icons.shopping_bag_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _compassCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _mapController = MapController();

    // Load existing destination into text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existing = ref.read(safeRouteProvider).destination;
      if (existing.isNotEmpty) {
        _destCtrl.text = existing;
      }
      _getCurrentLocation();
    });

    _focusNode.addListener(() {
      setState(() => _showSuggestions = _focusNode.hasFocus);
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please enable location services.'),
              backgroundColor: AppColors.accentTeal,
            ),
          );
        }
        // Don't set fallback immediately to allow showing loading/error state
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController?.move(_currentLocation!, 15.0);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get precise location. Ensure GPS is enabled.'),
            backgroundColor: AppColors.accentTeal,
          ),
        );
      }
    }
  }

  void _zoomIn() {
    if (_mapController != null) {
      _mapController!.move(
        _mapController!.camera.center,
        _mapController!.camera.zoom + 1,
      );
    }
  }

  void _zoomOut() {
    if (_mapController != null) {
      _mapController!.move(
        _mapController!.camera.center,
        _mapController!.camera.zoom - 1,
      );
    }
  }

  void _goToCurrentLocation() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.move(_currentLocation!, 15.0);
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _focusNode.dispose();
    _compassCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onDestinationSubmit(String value) async {
    if (value.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    
    setState(() => _isSearching = true);
    
    try {
      // Geocode the place name to get coordinates
      final locations = await locationFromAddress(value.trim());
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _destinationLocation = LatLng(location.latitude, location.longitude);
          _isSearching = false;
        });
        
        // Move map to destination initially (will fit bounds once route is fetched)
        _mapController?.move(_destinationLocation!, 15.0);
        
        // Update provider with coords so it fetches the OSRM route
        ref.read(safeRouteProvider.notifier).setDestination(
          value.trim(), 
          _destinationLocation!,
          currentLocFallback: _currentLocation,
        );
        ref.read(recentDestinationsProvider.notifier).addDestination(value.trim());
      } else {
        setState(() => _isSearching = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location not found: $value'),
              backgroundColor: AppColors.accentTeal,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSearching = false);
      debugPrint('Geocoding error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find location. Please try again.'),
            backgroundColor: AppColors.accentTeal,
          ),
        );
      }
    }
    
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
  }

  void _selectQuickPick(String dest) {
    _destCtrl.text = dest;
    _onDestinationSubmit(dest);
  }

  void _startNavigation() {
    final route = ref.read(safeRouteProvider);
    if (!route.hasDestination) return;
    HapticFeedback.mediumImpact();
    // Launch Journey Guardian with pre-filled destination
    context.push(
      Uri(
        path: '/journey',
        queryParameters: {
          'destination': route.destination,
          'eta': route.estimatedTime.inMinutes.toString(),
          if (route.destLat != null) 'destLat': route.destLat.toString(),
          if (route.destLng != null) 'destLng': route.destLng.toString(),
          'distance': route.routeDistanceKm.toString(),
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(safeRouteProvider);
    final guardian = ref.watch(guardianProvider);
    final nightSafety = ref.watch(nightSafetyProvider);
    final recent = ref.watch(recentDestinationsProvider);
    final hour = DateTime.now().hour;
    final isNight = hour >= 20 || hour < 6;

    // Listen for route updates to auto-fit map bounds
    ref.listen<List<LatLng>>(
      safeRouteProvider.select((s) => s.routePoints),
      (prev, next) {
        if (next.isNotEmpty && _mapController != null) {
          try {
            _mapController!.fitCamera(CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(next),
              padding: const EdgeInsets.all(60.0),
            ));
          } catch (e) {
            debugPrint('Error fitting map bounds: $e');
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Live map background using flutter_map
          Positioned.fill(
            child: _currentLocation != null
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: 15.0,
                      minZoom: 2.0,
                      maxZoom: 18.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      if (Theme.of(context).brightness == Brightness.dark)
                        ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -1,  0,  0, 0, 255,
                             0, -1,  0, 0, 255,
                             0,  0, -1, 0, 255,
                             0,  0,  0, 1,   0,
                          ]),
                          child: TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                            userAgentPackageName: 'com.example.abhaya',
                            maxZoom: 18,
                          ),
                        )
                      else
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                          userAgentPackageName: 'com.example.abhaya',
                          maxZoom: 18,
                        ),
                      // Current location marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.accentTeal.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: AppColors.accentTeal,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentTeal.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Destination marker if route is set
                      if (_destinationLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _destinationLocation!,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.accentTeal.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColors.accentTeal,
                                  size: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      // Route lines for all fetched options
                      if (route.routes.isNotEmpty)
                        PolylineLayer(
                          polylines: route.routes
                              .where((opt) => opt.type == route.selectedRoute)
                              .map<Polyline>((option) {
                            final color = option.type == SafeRouteType.safest
                                ? AppColors.accentTeal
                                : option.type == SafeRouteType.fastest
                                    ? const Color(0xFFA55EED)
                                    : const Color(0xFFE67E22);
                            return Polyline(
                              points: option.points,
                              strokeWidth: 6.0,
                              color: color,
                            );
                          }).toList(),
                        ),
                      // Badges for all fetched options at midpoints
                      if (route.routes.isNotEmpty)
                        MarkerLayer(
                          markers: route.routes
                              .where((opt) => opt.points.isNotEmpty && opt.type == route.selectedRoute)
                              .map<Marker>((option) {
                            final color = option.type == SafeRouteType.safest
                                ? AppColors.accentTeal
                                : option.type == SafeRouteType.fastest
                                    ? const Color(0xFFA55EED)
                                    : const Color(0xFFE67E22);
                            
                            final midPoint = option.points[option.points.length ~/ 2];
                            final distText = (option.distanceMeters / 1000).toStringAsFixed(1) + ' km';
                            final timeText = (option.durationSeconds / 60).round().toString() + ' min';

                            return Marker(
                              point: midPoint,
                              width: 80,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: AnimatedScale(
                                scale: 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(distText, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold, height: 1.1)),
                                      Text(timeText, style: const TextStyle(color: Colors.black, fontSize: 10, height: 1.1)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      // Show loading indicator while fetching OSRM route
                      if (route.isFetchingRoute || _isSearching)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentTeal,
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentTeal,
                    ),
                  ),
          ),

          // Gradient overlay for readability (IgnorePointer fixes interaction issue)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bgDeep.withValues(alpha: 0.7),
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.bgDeep.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.25, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Map Controls
          if (_currentLocation != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapControlButton(
                      icon: Icons.add_rounded,
                      onTap: _zoomIn,
                    ),
                    const SizedBox(height: 8),
                    _buildMapControlButton(
                      icon: Icons.remove_rounded,
                      onTap: _zoomOut,
                    ),
                    const SizedBox(height: 8),
                    _buildMapControlButton(
                      icon: Icons.my_location_rounded,
                      onTap: _goToCurrentLocation,
                      color: AppColors.accentTeal,
                    ),
                  ],
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // ── Top Bar ─────────────────────────────────────────────────
                _buildTopBar(context, route, guardian),

                // Suggestions dropdown - limited height to not cover entire map
                if (_showSuggestions && recent.isNotEmpty)
                  _buildSuggestionsPanel(recent),

                const Spacer(),

                // ── GPS Status Banner ────────────────────────────────────────
                if (guardian.isActive) _buildGpsBanner(guardian),

                const SizedBox(height: 8),

                // ── Route Card ───────────────────────────────────────────────
                _buildRouteCard(route, nightSafety, isNight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.textPrimary,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: GlassCard(
        borderRadius: 12,
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildTopBar(
      BuildContext context, SafeRouteState route, GuardianState guardian) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => context.pop(),
                child: const GlassCard(
                  borderRadius: 12,
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 12),

              // Destination input
              Expanded(
                child: GlassCard(
                  borderRadius: 14,
                  borderColor: _focusNode.hasFocus
                      ? AppColors.accentTeal.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Your Location Row
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accentTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Your location',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Icon(Icons.swap_vert_rounded, color: AppColors.textMuted, size: 20),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3, top: 4, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 2,
                            height: 12,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      // Destination Row
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFA55EED), // Primary purple
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _destCtrl,
                              focusNode: _focusNode,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Where do you want to go?',
                                hintStyle: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _onDestinationSubmit,
                              onChanged: (v) {
                                setState(() {});
                              },
                            ),
                          ),
                          if (_destCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _destCtrl.clear();
                                ref
                                    .read(safeRouteProvider.notifier)
                                    .clearDestination();
                                setState(() {});
                              },
                              child: const Icon(Icons.close_rounded,
                                  color: AppColors.textMuted, size: 18),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Quick picks
          if (!_focusNode.hasFocus && !route.hasDestination) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 4),
                itemCount: _quickPicks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final pick = _quickPicks[i];
                  return GestureDetector(
                    onTap: () => _selectQuickPick(pick.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.accentTeal.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(pick.$2,
                            color: AppColors.accentTeal, size: 13),
                        const SizedBox(width: 6),
                        Text(pick.$1,
                            style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentTeal)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    ).animate().slideY(begin: -0.2).fadeIn();
  }

  Widget _buildSuggestionsPanel(List<String> recent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: GlassCard(
          borderRadius: 14,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(children: [
                    const Icon(Icons.history_rounded,
                        color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 8),
                    const Text('Recent',
                        style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ]),
                ),
                ...recent.take(5).map((dest) => InkWell(
                      onTap: () {
                        _destCtrl.text = dest;
                        _onDestinationSubmit(dest);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Row(children: [
                          const Icon(Icons.location_on_outlined,
                              color: AppColors.accentTeal, size: 16),
                          const SizedBox(width: 12),
                          Text(dest,
                              style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                        ]),
                      ),
                    )),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 150.ms),
      ),
    );
  }

  Widget _buildGpsBanner(GuardianState guardian) {
    final loc = guardian.telemetry;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassCard(
        borderRadius: 12,
        borderColor: AppColors.accentTeal.withValues(alpha: 0.2),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentTeal,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accentTeal.withValues(alpha: 0.6),
                      blurRadius: 6)
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.4, duration: 700.ms),
            const SizedBox(width: 10),
            const Text('GPS Active',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: AppColors.textSecondary)),
            const Spacer(),
            Text(
              loc.hasLocation
                  ? '${loc.latitude!.toStringAsFixed(5)}, ${loc.longitude!.toStringAsFixed(5)}'
                  : 'Acquiring location…',
              style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentTeal),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildRouteCard(
      SafeRouteState route, NightSafetyState nightSafety, bool isNight) {
    final hasRoute = route.hasDestination;
    
    if (!hasRoute) return const SizedBox.shrink();

    final accent = AppColors.accentTeal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 10 && _isCardExpanded) {
            setState(() => _isCardExpanded = false);
          } else if (details.delta.dy < -10 && !_isCardExpanded) {
            setState(() => _isCardExpanded = true);
          }
        },
        child: GlassCard(
          borderRadius: 24,
          borderColor: hasRoute
              ? accent.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            if (hasRoute)
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 40,
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Safe Route',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentTeal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'AI ACTIVE',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentTeal,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ]),
                  ),
                ],
              ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: _isCardExpanded
                      ? Column(
                          children: [
                            const SizedBox(height: 20),
                            // Route toggle
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: route.routes.map<Widget>((opt) {
                                  final isSelected = route.selectedRoute == opt.type;
                                  final color = opt.type == SafeRouteType.safest
                                      ? AppColors.accentTeal
                                      : opt.type == SafeRouteType.fastest
                                          ? const Color(0xFFA55EED)
                                          : const Color(0xFFE67E22);
                                  
                                  final title = opt.type == SafeRouteType.safest
                                      ? 'Safest'
                                      : opt.type == SafeRouteType.fastest
                                          ? 'Fastest'
                                          : 'Balanced';
                                          
                                  final icon = opt.type == SafeRouteType.safest
                                      ? Icons.shield_rounded
                                      : opt.type == SafeRouteType.fastest
                                          ? Icons.flash_on_rounded
                                          : Icons.balance_rounded;

                                  return _buildToggleOption(
                                    title: title,
                                    subtitle: '${(opt.durationSeconds / 60).round()} min',
                                    isSelected: isSelected,
                                    color: color,
                                    icon: icon,
                                    onTap: () => ref
                                        .read(safeRouteProvider.notifier)
                                        .selectRoute(opt.type),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Route intel removed for a cleaner look
                            const SizedBox(height: 20),
                          ],
                        )
                      : const SizedBox(height: 16),
                ),

                NeonButton(
                  label: 'START NAVIGATION',
                  leadingIcon: Icons.navigation_rounded,
                  variant: NeonButtonVariant.primary,
                  height: 52,
                  onPressed: _startNavigation,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 0.2).fadeIn();
  }


  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : AppColors.textMuted,
                  size: 22),
              const SizedBox(height: 6),
              Text(title,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : AppColors.textSecondary,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    color: isSelected
                        ? color.withValues(alpha: 0.8)
                        : AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }


}
