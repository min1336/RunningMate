import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

class RunningScreen extends StatefulWidget {
  final List<NLatLng> roadPath; // 네이버 길찾기 API에서 받은 실제 도로 경로
  final List<NLatLng> roadPath2; // 네이버 길찾기 API에서 받은 실제 도로 경로
  final NLatLng startLocation; // 출발지 좌표

  const RunningScreen({
    super.key,
    required this.roadPath,
    required this.roadPath2,
    required this.startLocation,
  });

  @override
  _RunningScreenState createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  NaverMapController? _mapController;
  Position? _currentPosition;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream; // 🔥 위치 스트림 변수 추가
  int _elapsedTime = 0; // 초 단위
  double _totalDistance = 0.0; // 실제 이동 거리 (m)
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    setState(() {});
  }

  // 위치 추적 시작 (🔥 실제 이동한 거리만 반영)
  void _startTracking() {
    _positionStream?.cancel(); // 🔥 기존 스트림이 있다면 해제
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((Position position) {
      if (mounted && _isRunning && !_isPaused) { // 🔥 mounted 체크 추가
        if (_lastPosition != null) {
          double distance = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (distance > 1.0) { // 🔥 너무 작은 움직임(1m 이하)은 무시
            setState(() {
              _totalDistance += distance;
              _lastPosition = position;
            });
          }
        }
        _lastPosition = position;
      }
    });
  }

  // 타이머 시작 (🔥 중복 실행 방지)
  void _startTimer() {
    _timer?.cancel(); // 🔥 기존 타이머가 있으면 해제
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRunning) { // 🔥 mounted 체크 추가
        setState(() {
          _elapsedTime++;
        });
      }
    });
  }

  // ✅ 평균 페이스 계산 (🔥 100m 이상 이동했을 때만 계산)
  String _calculatePace() {
    if (_totalDistance < 100 || _elapsedTime == 0) return "0'00''"; // 100m 이하 또는 시간 0이면 0'00''

    double paceInSecondsPerKm = _elapsedTime / (_totalDistance / 1000); // km 당 시간(초)
    int minutes = (paceInSecondsPerKm ~/ 60);
    int seconds = (paceInSecondsPerKm % 60).toInt();

    return "$minutes'${seconds.toString().padLeft(2, '0')}''";
  }

  // 칼로리 계산 (🔥 이동 거리 반영)
  double _calculateCalories() {
    double weight = 70.0; // 기본 체중 (kg)
    double met = 8.0; // 달리기의 MET 값
    return (met * weight * (_elapsedTime / 3600)); // kcal 계산
  }

  // 달리기 시작
  void _startRun() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _startTimer();
    _startTracking();
  }

  // 일시 정지
  void _pauseRun() {
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  // 종료 (🔥 타이머 & 위치 스트림 해제)
  void _stopRun() {
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });
    _timer?.cancel();
    _positionStream?.cancel(); // 🔥 위치 스트림 해제
  }

  @override
  void dispose() {
    _timer?.cancel(); // 🔥 타이머 해제
    _positionStream?.cancel(); // 🔥 위치 스트림 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("달리기 진행 중")),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: widget.startLocation,
                zoom: 15,
              ),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;

              // 🔥 실제 추천 받은 도로 경로 지도에 그리기
              _mapController!.addOverlay(
                NPathOverlay(
                  id: 'recommended_road',
                  coords: widget.roadPath,
                  width: 6,
                  color: Colors.blue,
                  patternImage: NOverlayImage.fromAssetImage("assets/images/pattern.jpg"),
                  patternInterval: 20,
                ),
              );

              _mapController!.addOverlay(
                NPathOverlay(
                  id: 'recommended_road2',
                  coords: widget.roadPath2,
                  width: 6,
                  color: Colors.blue,
                  patternImage: NOverlayImage.fromAssetImage("assets/images/pattern.jpg"),
                  patternInterval: 20,
                ),
              );
            },
          ),

          // UI 오버레이
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text("거리: ${(_totalDistance / 1000).toStringAsFixed(2)} km"),
                      Text("시간: ${_elapsedTime ~/ 60}분 ${_elapsedTime % 60}초"),
                      Text("평균 페이스: ${_calculatePace()} /km"),
                      Text("칼로리 소모: ${_calculateCalories().toStringAsFixed(1)} kcal"),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isRunning ? null : _startRun,
                      child: const Text("▶ 시작"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isRunning ? _pauseRun : null,
                      child: const Text("⏸ 일시 정지"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _stopRun,
                      child: const Text("⏹ 종료"),
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
