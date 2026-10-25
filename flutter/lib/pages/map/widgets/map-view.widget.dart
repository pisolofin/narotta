import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';

import 'map-grid-painter.dart';
import 'map-controls.widget.dart';
import 'map-scale-bar.widget.dart';
import 'map-status-badge.widget.dart';
import 'map-telemetry-card.widget.dart';
import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../services/location-service.dart';

/// Displays the main interactive map viewport in the cartographic void.
class MapView extends StatefulWidget {
  const MapView({ super.key });

  @override
  State<MapView> createState() => _MapViewState();
}

/// State for [MapView] managing camera position, zoom, gestures, smooth physics-damped scroll, and radar pulse.
class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  static const double _minZoom = 0.1;
  static const double _maxZoom = 8.0;
  static const double _defaultZoom = 1.0;
  static const double _zoomStepFactor = 1.35;
  static const double _metersPerDegreeLat = 111320.0;
  static const double _scrollWheelSensitivity = 0.0015;
  static const double _dampingSpeed = 22.0;
  static const int _pulseAnimationDurationSeconds = 2;

  final LocationService _locationService = LocationService();
  late final AnimationController _pulseController;
  late final Ticker _smoothZoomTicker;

  Duration? _lastTickTime;
  Offset _cameraWorldMeters = Offset.zero;
  double _zoom = _defaultZoom;
  double _targetZoom = _defaultZoom;
  bool _isFollowingUser = true;

  double? _referenceLat;
  double? _referenceLon;

  double _gestureStartZoom = _defaultZoom;
  Offset? _focalScreenPos;
  Size? _viewportSize;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync   : this,
      duration: const Duration(seconds: _pulseAnimationDurationSeconds),
    )..repeat();

    _smoothZoomTicker = createTicker(_onSmoothTick);

    _locationService.addListener(_onLocationUpdated);

    if (_locationService.status == LocationStatus.idle) {
      _locationService.startTrackingAsync();
    }
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationUpdated);
    _smoothZoomTicker.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Ticker callback executing per-frame critically damped exponential smoothing for zoom and camera.
  void _onSmoothTick(Duration elapsed) {
    if (_lastTickTime == null) {
      _lastTickTime = elapsed;
      return;
    }

    final double dt = ((elapsed - _lastTickTime!).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastTickTime = elapsed;

    final double zoomDiff = _targetZoom - _zoom;
    if (zoomDiff.abs() < 0.0001) {
      _zoom = _targetZoom;
      _smoothZoomTicker.stop();
      _lastTickTime = null;
      if (_isFollowingUser) {
        final Position? pos = _locationService.currentPosition;
        if (pos != null) {
          _cameraWorldMeters = _positionToWorldMeters(pos);
        }
      }
      setState(() {});
      return;
    }

    // Frame-rate independent exponential smoothing
    final double blend = 1.0 - math.exp(-dt * _dampingSpeed);
    final double newZoom = _zoom + (zoomDiff * blend);

    if ((!_isFollowingUser) && (_focalScreenPos != null) && (_viewportSize != null)) {
      final Offset screenCenter = Offset(
        _viewportSize!.width / 2.0,
        _viewportSize!.height / 2.0,
      );

      final double cursorWorldX = _cameraWorldMeters.dx +
        ((_focalScreenPos!.dx - screenCenter.dx) / _zoom);
      final double cursorWorldY = _cameraWorldMeters.dy -
        ((_focalScreenPos!.dy - screenCenter.dy) / _zoom);

      _zoom = newZoom;

      final double newCameraX = cursorWorldX -
        ((_focalScreenPos!.dx - screenCenter.dx) / _zoom);
      final double newCameraY = cursorWorldY +
        ((_focalScreenPos!.dy - screenCenter.dy) / _zoom);

      _cameraWorldMeters = Offset(newCameraX, newCameraY);
    }else {
      _zoom = newZoom;
      if (_isFollowingUser) {
        final Position? pos = _locationService.currentPosition;
        if (pos != null) {
          _cameraWorldMeters = _positionToWorldMeters(pos);
        }
      }
    }

    setState(() {});
  }

  /// Converts a GPS [Position] to local world coordinates in meters.
  Offset _positionToWorldMeters(Position position) {
    if ((_referenceLat == null) || (_referenceLon == null)) {
      _referenceLat = position.latitude;
      _referenceLon = position.longitude;
      return Offset.zero;
    }

    final double latRadians = _referenceLat! * math.pi / 180.0;
    final double metersPerDegreeLon = _metersPerDegreeLat * math.cos(latRadians);

    final double deltaX = (position.longitude - _referenceLon!) * metersPerDegreeLon;
    final double deltaY = (position.latitude - _referenceLat!) * _metersPerDegreeLat;
    return Offset(deltaX, deltaY);
  }

  /// Listener invoked whenever the [LocationService] acquires or updates the GPS fix.
  void _onLocationUpdated() {
    final Position? position = _locationService.currentPosition;
    if (position != null) {
      final Offset userWorldPos = _positionToWorldMeters(position);
      if (_isFollowingUser) {
        setState(() {
          _cameraWorldMeters = userWorldPos;
        });
      }
    }
  }

  /// Handles touch gesture scaling and panning on the cartographic canvas.
  void _handleScaleStart(ScaleStartDetails details) {
    if (_smoothZoomTicker.isActive) {
      _smoothZoomTicker.stop();
      _lastTickTime = null;
    }
    _targetZoom = _zoom;
    _gestureStartZoom = _zoom;
  }

  /// Updates camera world offset and zoom scale during multi-touch or pan gestures.
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _isFollowingUser = false;

      // Handle pinch zoom scaling
      if (details.scale != 1.0) {
        _zoom = (_gestureStartZoom * details.scale).clamp(_minZoom, _maxZoom);
        _targetZoom = _zoom;
      }

      // Handle pan offset translation in world meters
      final double deltaWorldX = details.focalPointDelta.dx / _zoom;
      final double deltaWorldY = -details.focalPointDelta.dy / _zoom;
      _cameraWorldMeters = Offset(
        _cameraWorldMeters.dx - deltaWorldX,
        _cameraWorldMeters.dy - deltaWorldY,
      );
    });
  }

  /// Starts or retargets smooth damping toward [targetZoom].
  void _startSmoothZoom({
    required double targetZoom,
    Offset? focalScreenPos,
    Size? viewportSize,
  }) {
    _targetZoom = targetZoom.clamp(_minZoom, _maxZoom);
    _focalScreenPos = focalScreenPos;
    _viewportSize = viewportSize;

    if (!_smoothZoomTicker.isActive) {
      _lastTickTime = null;
      _smoothZoomTicker.start();
    }
  }

  /// Handles mouse scroll wheel signals to smoothly zoom in or out focusing on the cursor position.
  void _handlePointerSignal(PointerSignalEvent event, Size viewportSize) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy == 0.0) {
        return;
      }

      final double zoomMultiplier = math.exp(-event.scrollDelta.dy * _scrollWheelSensitivity);
      final double nextTarget = _targetZoom * zoomMultiplier;

      _startSmoothZoom(
        targetZoom    : nextTarget,
        focalScreenPos: event.localPosition,
        viewportSize  : viewportSize,
      );
    }
  }

  /// Zooms in by the standard step factor with smooth damping.
  void _zoomIn() {
    _startSmoothZoom(
      targetZoom: _targetZoom * _zoomStepFactor,
    );
  }

  /// Zooms out by the standard step factor with smooth damping.
  void _zoomOut() {
    _startSmoothZoom(
      targetZoom: _targetZoom / _zoomStepFactor,
    );
  }

  /// Recenter the camera directly on the user's current GPS position.
  void _recenterOnUser() {
    if (_smoothZoomTicker.isActive) {
      _smoothZoomTicker.stop();
      _lastTickTime = null;
    }
    _targetZoom = _zoom;

    final Position? position = _locationService.currentPosition;
    setState(() {
      _isFollowingUser = true;
      if (position != null) {
        _cameraWorldMeters = _positionToWorldMeters(position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _locationService,
      builder   : (BuildContext context, Widget? child) {
        final Position? position = _locationService.currentPosition;
        final Offset? userWorldPos = (position != null)
          ? _positionToWorldMeters(position)
          : null
        ;
        final double? userAccuracy = position?.accuracy;
        final double? userHeading = ((position != null) && (position.heading >= 0.0) && (position.speed > 0.3))
          ? position.heading
          : null
        ;

        final double gridMetersStep = MapGridPainter.calculateGridMetersStep(_zoom);

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size viewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return Container(
              width : double.infinity,
              height: double.infinity,
              color : AppColors.mapVoid(context),
              child : Stack(
                children: [
                  // Interactive listener and gesture detector for mouse wheel zoom, pan, and pinch
                  Positioned.fill(
                    child: Listener(
                      behavior       : HitTestBehavior.opaque,
                      onPointerSignal: (PointerSignalEvent event) {
                        _handlePointerSignal(event, viewportSize);
                      },
                      child: GestureDetector(
                        behavior     : HitTestBehavior.opaque,
                        onScaleStart : _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        child        : AnimatedBuilder(
                          animation: _pulseController,
                          builder  : (BuildContext context, Widget? child) {
                            return CustomPaint(
                              painter: MapGridPainter(
                                cameraWorldMeters : _cameraWorldMeters,
                                zoom              : _zoom,
                                userWorldMeters   : userWorldPos,
                                userAccuracy      : userAccuracy,
                                userHeading       : userHeading,
                                pulseProgress     : _pulseController.value,
                                mapVoidColor      : AppColors.mapVoid(context),
                                gridMajorColor    : AppColors.mapGridMajor(context),
                                gridMinorColor    : AppColors.mapGridMinor(context),
                                gridCrosshairColor: AppColors.mapGridCrosshair(context),
                                userPulseColor    : AppColors.userPulse(context),
                                userAccuracyColor : AppColors.userAccuracy(context),
                                primaryColor      : AppColors.primary(context),
                                whiteColor        : AppColors.white(context),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Top status badge indicating the cartographic void waiting state
                  const Positioned(
                    top  : AppSizes.p16,
                    left : AppSizes.p16,
                    right: AppSizes.p16,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child    : MapStatusBadge(),
                    ),
                  ),

                  // Floating action controls on the right (recenter, zoom in, zoom out)
                  Positioned(
                    right : AppSizes.p16,
                    bottom: AppSizes.mapControlsBottomOffset,
                    child : MapControls(
                      isFollowingUser: _isFollowingUser,
                      onZoomIn       : _zoomIn,
                      onZoomOut      : _zoomOut,
                      onRecenter     : _recenterOnUser,
                    ),
                  ),

                  // Bottom left metric scale indicator
                  Positioned(
                    left  : AppSizes.p16,
                    bottom: AppSizes.mapControlsBottomOffset,
                    child : MapScaleBar(
                      gridMetersStep: gridMetersStep,
                      zoom          : _zoom,
                    ),
                  ),

                  // Bottom floating GPS telemetry and status card
                  Positioned(
                    left  : AppSizes.p16,
                    right : AppSizes.p16,
                    bottom: AppSizes.p16,
                    child : MapTelemetryCard(
                      status         : _locationService.status,
                      position       : position,
                      isFollowingUser: _isFollowingUser,
                      onRefresh      : () {
                        _locationService.refreshPositionAsync();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
