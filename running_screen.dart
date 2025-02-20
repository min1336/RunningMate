import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:screenshot/screenshot.dart';
import 'Calendar.dart';
import 'package:run1230/main.dart';

class RunningScreen extends StatefulWidget {
  final List<NLatLng> roadPath; // 네이버 길찾기 API에서 받은 실제 도로 경로
  final NLatLng startLocation; // 출발지 좌표

  const RunningScreen({
    super.key,
    required this.roadPath,
    required this.startLocation,
  });

  @override
  _RunningScreenState createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  NaverMapController? _mapController;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;
  Timer? _stopTimer;
  Timer? _stopHoldTimer;
  StreamSubscription<Position>? _positionStream; // 🔥 위치 스트림 변수 추가
  int _elapsedTime = 0; // 초 단위
  double _totalDistance = 0.0; // 실제 이동 거리 (m)
  double _caloriesBurned = 0.0;
  Position? _lastPosition;
  NMarker? _userLocationMarker;
  bool _isTimerRunning = false;
  final List<Position> _recentPositions = [];
  // 지나온 경로 저장용 리스트
  final List<NLatLng> _traveledPath = [];

  static const double MIN_DISTANCE_THRESHOLD = 1.0; // 1m 이하 이동 무시
  static const double MIN_SPEED_THRESHOLD = 0.5; // 0.5m/s 이하 속도 무시
  static const double MIN_ACCURACY_THRESHOLD = 10.0; // 10m 이하 정확도만 사용

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<String?> _captureMapScreenshot() async {
    try {
      final now = DateTime.now();
      final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour}-${now.minute}-${now.second}";
      final directory = await getApplicationDocumentsDirectory();

      // 디렉토리가 올바르게 생성되었는지 확인
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      // ScreenshotController 초기화 확인
      final imagePath = await _screenshotController.captureAndSave(directory.path, fileName: "run_$dateString.png");

      if (imagePath != null) {
        print("캡처 성공: $imagePath");

        // 정보 저장
        final summaryData = {
          "distance": "${(_totalDistance / 1000).toStringAsFixed(2)} km",
          "time": "${_elapsedTime ~/ 60}분 ${_elapsedTime % 60}초",
          //"pace": "${_calculatePace()} /km",
          "calories": "${_caloriesBurned.toStringAsFixed(1)} kcal"
        };

        final summaryFile = File("${directory.path}/run_$dateString.json");
        await summaryFile.writeAsString(jsonEncode(summaryData));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CalendarScreen()),
          );
        }
      } else {
        print('캡처 실패: 반환된 경로가 null입니다.');
      }
      return imagePath;
  } catch (e) {
      print('경로 캡처 실패: $e');
      return null;
    }
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

    // 현재 위치 가져오기
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 지도 카메라를 현재 위치로 이동
    if (_mapController != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(
          target: NLatLng(position.latitude, position.longitude),
          zoom: 16,
        ),
      );

      // 🏃 사용자 위치 마커 추가 (주황색 달리기 아이콘)
      final icon = await NOverlayImage.fromWidget(
        context: context, // 🔴 필수 context
        widget: const Icon(Icons.directions_run, color: Colors.orange, size: 50), // 🟠 주황색
        size: const Size(60, 60),
      );

      _userLocationMarker = NMarker(
        id: 'user_location_marker',
        position: NLatLng(position.latitude, position.longitude),
        icon: icon,
      );

      _mapController!.addOverlay(_userLocationMarker!);
    }

    // 위치 변경을 지속적으로 추적하여 카메라를 따라가게 설정
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // 2m 이동 시마다 업데이트
      ),
    ).listen((Position newPosition) async {
      if (_mapController != null) {
        // 카메라를 사용자의 새로운 위치로 이동
        await _mapController!.updateCamera(
          NCameraUpdate.withParams(
            target: NLatLng(newPosition.latitude, newPosition.longitude),
            zoom: 16,
          ),
        );

        // 기존 마커 삭제 및 새 마커 추가
        if (_userLocationMarker != null) {
          _mapController!.deleteOverlay(_userLocationMarker!.info);
        }

        final updatedIcon = await NOverlayImage.fromWidget(
          context: context, // 🔴 필수 context
          widget: const Icon(Icons.directions_run, color: Colors.orange, size: 50), // 🟠 주황색
          size: const Size(60, 60),
        );

        _userLocationMarker = NMarker(
          id: 'user_location_marker',
          position: NLatLng(newPosition.latitude, newPosition.longitude),
          icon: updatedIcon,
        );

        _mapController!.addOverlay(_userLocationMarker!);
      }
    });
  }

  // 타이머 시작 (🔥 중복 실행 방지)
  void _startTimer() {
    if (_isTimerRunning) return;

    _isTimerRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRunning) {
        setState(() {
          _elapsedTime++;
        });
      } else {
        timer.cancel();
        _isTimerRunning = false;
      }
    });
  }

  // Navigator 이동 함수
  void _navigateToMain() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false, // 기존 화면 모두 제거
      );
    }
  }

  // 위치 추적 시작 (🔥 실제 이동한 거리만 반영)
  void _startTracking() {
    _positionStream?.cancel(); // 🔥 기존 스트림이 있다면 해제
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    ).listen((Position position) {
      if (mounted && _isRunning && !_isPaused) return; // 🔥 mounted 체크 추가
      if (position.accuracy > MIN_ACCURACY_THRESHOLD) return;

      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        double timeDiff = (position.timestamp.difference(_lastPosition!.timestamp).inMilliseconds) / 1000.0;
        double speed = timeDiff > 0 ? (distance / timeDiff) : 0.0;

        // 🚶 지나온 경로 기록
        final currentLatLng = NLatLng(position.latitude, position.longitude);
        if (_traveledPath.isEmpty || _calculateDistanceBetween(_traveledPath.last, currentLatLng) >= 5) {
          _traveledPath.add(currentLatLng);
          _updateTraveledPathOverlay();
        }

        // 최근 위치 5개 저장
        _recentPositions.add(position);
        if (_recentPositions.length > 5) {
          _recentPositions.removeAt(0);
        }

        // 평균 속도 계산
        double avgSpeed = _recentPositions.length > 1
            ? _recentPositions.sublist(0, _recentPositions.length - 1).map((p) {
          int index = _recentPositions.indexOf(p);
          return Geolocator.distanceBetween(
              p.latitude,
              p.longitude,
              _recentPositions[index + 1].latitude,
              _recentPositions[index + 1].longitude) /
              (position.timestamp.difference(p.timestamp).inSeconds);
        }).reduce((a, b) => a + b) /
            _recentPositions.length
            : 0;

        // 평균 속도 및 위치 변화량 검사
        if (avgSpeed < MIN_SPEED_THRESHOLD &&
            _calculateDistanceBetween(
              NLatLng(_recentPositions.first.latitude, _recentPositions.first.longitude),
              NLatLng(_recentPositions.last.latitude, _recentPositions.last.longitude),
            ) < 1.5) {
          if (_stopTimer == null) {
            _stopTimer = Timer(const Duration(seconds: 3), () {
              if (_isRunning && !_isPaused) {
                _stopRun();
              }
            });
          }
        } else {
          _stopTimer?.cancel();
          _stopTimer = null;
        }

        setState(() {
          _totalDistance += distance;
          _lastPosition = position;
          _caloriesBurned = _calculateCalories(speed);
        });
      }
      _lastPosition = position;
    });
  }

  // 지나온 경로 오버레이 업데이트
  void _updateTraveledPathOverlay() {
    if (_mapController == null || _traveledPath.length < 2) return;

    final traveledOverlay = NPathOverlay(
      id: 'traveled_path',
      coords: List.from(_traveledPath),
      color: Colors.orange, // 🔶 주황색 경로
      width: 4,
      outlineWidth: 2,
      outlineColor: Colors.white,
    );

    _mapController!.addOverlay(traveledOverlay);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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

    double timeInHours = _elapsedTime / 3600.0;
    return met * weight * timeInHours; // 🔥 분 단위까지 고려한 보정
  }

  // 두 좌표 간 거리 계산
  double _calculateDistanceBetween(NLatLng p1, NLatLng p2) {
    const earthRadius = 6371000.0;
    final dLat = (p2.latitude - p1.latitude) * (pi / 180);
    final dLon = (p2.longitude - p1.longitude) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1.latitude * (pi / 180)) * cos(p2.latitude * (pi / 180)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
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
    _isTimerRunning = false;
    _stopTimer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel(); // 🔥 타이머 해제
    _positionStream?.cancel(); // 🔥 위치 스트림 해제
    _stopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("달리기 진행 중")),
      body: Stack(
        children: [
        Screenshot(  // ✅ 캡처 가능하도록 감싸기
          controller: _screenshotController,
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: widget.startLocation,
                zoom: 16,
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
                  width: 8,
                  color: Color(0xFFD32F2F),
                  outlineWidth: 2,
                  outlineColor: Colors.white,
                  patternImage: NOverlayImage.fromAssetImage("assets/images/pattern.jpg"),
                  patternInterval: 30,
                ),
              );
            },
          ),
      ),

          // UI 오버레이
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 거리,시간,칼로리
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text("거리", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${(_totalDistance / 1000).toStringAsFixed(2)} km", style: TextStyle(fontSize: 18)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text("시간", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(_formatTime(_elapsedTime), style: TextStyle(fontSize: 18)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text("칼로리", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${_caloriesBurned.toStringAsFixed(1)} kcal", style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 버튼 배치
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 시작 버튼
                      GestureDetector(
                        onTap: _isRunning ? null : _startRun,
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white,
                          child: Icon(
                              Icons.play_arrow,
                              color: Color(0xFFE53935), size: 40),
                        ),
                      ),
                      const SizedBox(width: 40),

                      // 정지 버튼 (3초 길게 누르면 main.dart로 이동)
                      GestureDetector(
                        onTap: _isRunning ? _pauseRun : null,
                        onLongPressStart: (_) {
                          // 3초 타이머 시작
                          _stopHoldTimer = Timer(const Duration(seconds: 3), () {
                            _captureMapScreenshot();
                            _navigateToMain();
                          });
                        },
                        onLongPressEnd: (_) {
                          // 손을 떼면 타이머 취소
                          _stopHoldTimer?.cancel();
                        },
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Color(0xFFE53935),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
