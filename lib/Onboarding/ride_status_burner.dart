import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
import 'package:aminidriver/Onboarding/ride_status_provider.dart';
import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
import 'package:aminidriver/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideStatusBanner extends ConsumerStatefulWidget {
  final String userId;
  const RideStatusBanner({super.key, required this.userId});

  @override
  ConsumerState<RideStatusBanner> createState() => _RideStatusBannerState();
}

class _RideStatusBannerState extends ConsumerState<RideStatusBanner>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _animationController;
  late final Animation<double> _heightAnimation;

  // Draggable position
  double _bottom = 20;
  double _left = 16;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _heightAnimation = Tween<double>(
      begin: 70,
      end: 150,
    ).animate(_animationController);
  }

  void _toggleBanner() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  // void _navigateToLiveRide(String rideId) {
  //   // Hide banner before navigating
  //   setState(() {
  //     _isExpanded = false;
  //     _animationController.reverse();
  //   });

  //   navigatorKey.currentState?.push(
  //     MaterialPageRoute(
  //       builder: (_) => LiveTrackingScreen(rideId: rideId),
  //       settings: const RouteSettings(name: '/rideInProgress'),
  //     ),
  //   );
  // }
  void _navigateToRideScreen(RideInfo rideInfo) {
    // Hide banner before navigating
    setState(() {
      _isExpanded = false;
      _animationController.reverse();
    });

    if (rideInfo.status == RideStatus.assigned) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (_) => TripDetailScreen(
                rideId: rideInfo.rideId,
                pickupLat: rideInfo.pickup.latitude,
                pickupLng: rideInfo.pickup.longitude,
                destLat: rideInfo.destination.latitude,
                destLng: rideInfo.destination.longitude,
                rider: rideInfo.riderName,
                mobile: rideInfo.mobile,
              ),
          settings: const RouteSettings(name: '/assignedRide'),
        ),
      );
    } else if (rideInfo.status == RideStatus.inProgress) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (_) => LiveTrackingScreen(
                rideId: rideInfo.rideId,
                pickup: LatLng(
                  rideInfo.pickup.latitude,
                  rideInfo.pickup.longitude,
                ),
                destination: LatLng(
                  rideInfo.destination.latitude,
                  rideInfo.destination.longitude,
                ), // rideInfo.pickup.longitude,
              ),
          settings: const RouteSettings(name: '/rideInProgress'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideInfoAsync = ref.watch(rideStatusStreamProvider(widget.userId));

    return rideInfoAsync.when(
      data: (rideInfo) {
        if (rideInfo.status == RideStatus.none || rideInfo.rideId.isEmpty) {
          return const SizedBox.shrink();
        }

        // Hide banner on live ride screen
        final isLiveRideScreen =
            ModalRoute.of(context)?.settings.name == '/rideInProgress';
        if (isLiveRideScreen) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Positioned(
          bottom: _bottom,
          left: _left,
          child: GestureDetector(
            onTap: () => _navigateToRideScreen(rideInfo),
            onPanUpdate: (details) {
              setState(() {
                _left += details.delta.dx;
                _bottom -= details.delta.dy; // dragging up increases bottom

                // Clamp horizontal
                if (_left < 0) _left = 0;
                if (_left > screenWidth - 300) _left = screenWidth - 300;

                // Clamp vertical from bottom
                if (_bottom < 0) _bottom = 0;
                if (_bottom > screenHeight - _heightAnimation.value - 20) {
                  _bottom = screenHeight - _heightAnimation.value - 20;
                }
              });
            },
            child: AnimatedBuilder(
              animation: _heightAnimation,
              builder: (context, child) {
                return Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black87,
                  child: Container(
                    width: 300,
                    height: _heightAnimation.value,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_taxi,
                          color: Colors.yellow,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "You have an active ride",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Status: ${rideInfo.status.name}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "Tap to view ride details",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_up,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
