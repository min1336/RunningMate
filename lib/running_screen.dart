import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

import 'package:run1220/speedDashboard.dart';
import 'package:run1220/Calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';




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
  final ScreenshotController _screenshotController = ScreenshotController();
  NaverMapController? _mapController;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isGuideMuted = false;
  Timer? _timer;
  Timer? _stopTimer;
  StreamSubscription<Position>? _positionStream; // 🔥 위치 스트림 변수 추가
  Timer? _stopTimer;
  Timer? _stopHoldTimer;
  int _elapsedTime = 0; // 초 단위
  double _totalDistance = 0.0; // 실제 이동 거리 (m)
  double _caloriesBurned = 0.0;
  Position? _lastPosition;
  NMarker? _userLocationMarker;
  bool _isTimerRunning = false;
  final List<Position> _recentPositions = [];
  final List<NLatLng> _traveledPath = []; // 지나온 경로 저장용 리스트

  static const double MIN_DISTANCE_THRESHOLD = 1.0; // 1m 이하 이동 무시
  static const double MIN_SPEED_THRESHOLD = 0.5; // 0.5m/s 이하 속도 무시
  static const double MIN_ACCURACY_THRESHOLD = 10.0; // 10m 이하 정확도만 사용

  double _userWeight = 70.0; // 기본 체중 (kg)

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndFollowUser(); // 내 위치 버튼과 동일한 동작 실행
  }

  Future<String?> _captureMapScreenshot() async {
    try {
      final now = DateTime.now();
      final dateString = "${now.year}-${now.month.toString().padLeft(
          2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour}-${now
          .minute}-${now.second}";
      final directory = await getApplicationDocumentsDirectory();

      // 디렉토리가 올바르게 생성되었는지 확인
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      

      // ScreenshotController 초기화 확인
      final imagePath = await _screenshotController.captureAndSave(
          directory.path, fileName: "run_$dateString.png");

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

  // 사용자 위치를 표시할 마커 저장
  NMarker? _userLocationMarker;

  // 현재 위치 가져오기
  Future<void> _getCurrentLocationAndFollowUser() async {
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
        size: const Size(50, 50),
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
          widget: const Icon(
              Icons.directions_run, color: Colors.orange, size: 50), // 🟠 주황색
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

  bool _isStopping = false; // 정지 대기 상태 여부

  List<Position> _recentPositions = [];
  // 지나온 경로 저장용 리스트
  List<NLatLng> _traveledPath = [];
  
  // 위치 추적 시작 (🔥 실제 이동한 거리만 반영)
  void _startTracking() {
    _positionStream?.cancel(); // 🔥 기존 스트림이 있다면 해제
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation),
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
        if (_traveledPath.isEmpty ||
            _calculateDistanceBetween(_traveledPath.last, currentLatLng) >= 5) {
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
              (position.timestamp
                  .difference(p.timestamp)
                  .inSeconds);
        }).reduce((a, b) => a + b) /
            _recentPositions.length
            : 0;

        // 평균 속도 및 위치 변화량 검사
        if (avgSpeed < MIN_SPEED_THRESHOLD &&
            _calculateDistanceBetween(
              NLatLng(_recentPositions.first.latitude,
                  _recentPositions.first.longitude),
              NLatLng(_recentPositions.last.latitude,
                  _recentPositions.last.longitude),
            ) < 1.5) {
          _stopTimer ??= Timer(const Duration(seconds: 3), () {
            if (_isRunning && !_isPaused) {
              _stopRun();
            }
          });
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
      color: Colors.orange,
      // 🔶 주황색 경로
      width: 4,
      outlineWidth: 2,
      outlineColor: Colors.white,
    );

    _mapController!.addOverlay(traveledOverlay);
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

  String _formatPace() {
    double distanceInKm = _totalDistance / 1000;
    if (distanceInKm <= 0) return "--:--";
    double paceSeconds = _elapsedTime / distanceInKm; // 초/킬로미터
    int minutes = paceSeconds ~/ 60;
    int seconds = (paceSeconds % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

  void _toggleRun() {
    if (_isRunning) {
      _pauseRun();
    } else {
      _startRun();
    }
  }

  // 종료 (🔥 타이머 & 위치 스트림 해제)
  void _stopRun() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("달리기 종료"),
          content: const Text("정말로 달리기를 종료하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _isRunning = false;
                  _isPaused = false;
                });
                _timer?.cancel();
                _positionStream?.cancel();
                _stopTimer?.cancel();
                _isTimerRunning = false;

                await _captureMapScreenshot(); // 🔥 스크린샷 저장 추가
              },
              child: const Text("확인"),
            ),
          ],
        );
      },
    );
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
      body: Column(
        children: [
          // 📌 지도 (NaverMap)
          Expanded(
            child: Screenshot(
              controller: _screenshotController,
              child: Stack(
                children: [
                  NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: widget.startLocation,
                        zoom: 16,
                      ),
                      locationButtonEnable: true,
                    ),
                    onMapReady: (controller) {
                      _mapController = controller;
                      _mapController!.addOverlay(
                        NPathOverlay(
                          id: 'recommended_road',
                          coords: widget.roadPath,
                          width: 8,
                          color: Color(0xFFD32F2F),
                          outlineWidth: 2,
                          outlineColor: Colors.white,
                          patternImage: NOverlayImage.fromAssetImage(
                              "assets/images/pattern.jpg"),
                          patternInterval: 30,
                        ),
                      );
                    },
                  ),

                  // ✅ 지도 위 우측 하단에 버튼 2개 (잠금 버튼 + 음소거 버튼)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20, right: 13), // 🔥 버튼 위치 조정
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔒 잠금 버튼
                          FloatingActionButton(
                            heroTag: "lock_button",
                            onPressed: () {
                              setState(() {
                                // 🔒 잠금 기능 추가 (예: 화면 잠금)
                                _isRunning = !_isRunning;
                              });
                            },
                            backgroundColor: _isRunning ? Colors.red : Colors.green,
                            child: Icon(
                              _isRunning ? Icons.lock : Icons.lock_open,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10), // 버튼 간 간격

                          // 🔊 음소거 버튼
                          FloatingActionButton(
                            heroTag: "mute_button",
                            onPressed: () {
                              setState(() {
                                _isGuideMuted = !_isGuideMuted;
                              });
                            },
                            backgroundColor: _isGuideMuted ? Colors.grey : Colors.blue,
                            child: Icon(
                              _isGuideMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10), // 버튼 간 간격

                          // ✅ 설정 버튼 추가 (시점 변경 버튼 삭제)
                          FloatingActionButton(
                            heroTag: "settings_button",
                            onPressed: () {
                              // 설정 페이지로 이동 (Navigator 사용)
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SettingsScreen()), // 🔥 설정 페이지로 이동
                              );
                            },
                            backgroundColor: Colors.orange,
                            child: const Icon(Icons.settings, color: Colors.white), // ⚙️ 설정 아이콘
                          ),

                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📌 하단 계기판
          Container(
            width: double.infinity,
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
                const SizedBox(height: 10),
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
