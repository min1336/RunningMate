import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'speedDashboard.dart';

class RunningScreen extends StatefulWidget {
  final List<NLatLng> roadPath;
  final NLatLng startLocation;

  const RunningScreen({
    super.key,
    required this.roadPath,
    required this.startLocation,
  });

  @override
  _RunningScreenState createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  NaverMapController? _mapController;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  Timer? _stopTimer;
  int _elapsedTime = 0;
  double _totalDistance = 0.0;
  double _caloriesBurned = 0.0;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    setState(() {});
  }

  void _startTracking() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) {
      if (mounted && _isRunning && !_isPaused) {
        double speed = 0.0;

        if (_lastPosition != null) {
          double distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          double timeDiff = (position.timestamp.difference(_lastPosition!.timestamp).inMilliseconds) / 1000.0;

          if (timeDiff > 0) {
            speed = (distance / timeDiff) * 3.6;
          }

          if (distance > 1.0) {
            setState(() {
              _totalDistance += distance;
              _lastPosition = position;
              _caloriesBurned = _calculateCalories(speed);
            });

            _stopTimer?.cancel();
            _stopTimer = null;
          } else {
            _stopTimer ??= Timer(const Duration(seconds: 3), () {
              if (_isRunning && !_isPaused) {
                _stopRun();
              }
            });
          }
        }

        _lastPosition = position;
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRunning) {
        setState(() {
          _elapsedTime++;
        });
      }
    });
  }

  double _calculateCalories(double speed) {
    double weight = 70.0;
    double met = 1.5;

    if (speed >= 12.0) {
      met = 12.0;
    } else if (speed >= 8.0) {
      met = 10.0;
    } else if (speed >= 5.0) {
      met = 6.0;
    } else if (speed >= 3.0) {
      met = 3.0;
    }

    return met * weight * (_elapsedTime / 3600);
  }

  void _triggerHapticFeedback() {
    HapticFeedback.heavyImpact();
  }

  void _toggleRun() {
    if (_isRunning) {
      _pauseRun();
    } else {
      _startRun();
    }
  }

  void _startRun() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _startTimer();
    _startTracking();

    _triggerHapticFeedback();
  }

  void _pauseRun() {
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });

    _triggerHapticFeedback();
  }

  void _stopRun() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("달리기 종료"),
          content: const Text("달리기를 종료하고 돌아가시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isRunning = false;
                  _isPaused = false;
                  _elapsedTime = 0;
                  _totalDistance = 0.0;
                  _caloriesBurned = 0.0;
                  _lastPosition = null;
                });
                _timer?.cancel();
                _positionStream?.cancel();
                _stopTimer?.cancel();
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
              child: const Text("확인"),
            ),
          ],
        );
      },
    );
  }

  void _resetRun() {
    setState(() {
      _elapsedTime = 0;
      _totalDistance = 0.0;
      _caloriesBurned = 0.0;
      _lastPosition = null;
    });
    _timer?.cancel();
    _positionStream?.cancel();
    _stopTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _stopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: widget.startLocation,
                  zoom: 15,
                ),
                locationButtonEnable: true,
              ),
              onMapReady: (controller) {
                _mapController = controller;

                _mapController!.addOverlay(
                  NPathOverlay(
                    id: 'recommended_road',
                    coords: widget.roadPath,
                    width: 6,
                    color: Color(0xFFD32F2F),
                    outlineWidth: 2,
                    outlineColor: Colors.white,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpeedDashboard(
                  speed: _lastPosition?.speed ?? 0.0,
                  distance: _totalDistance / 1000,
                  calories: _caloriesBurned,
                  elapsedTime: "${_elapsedTime ~/ 60}:${_elapsedTime % 60}",
                  heartRate: 138,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _toggleRun,
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: _isRunning ? Colors.amber : Colors.green,
                        child: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: _stopRun,
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.red,
                        child: const Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// running_screen.dart 코드 수정: 정지 버튼 클릭 시 확인 대화상자 추가
