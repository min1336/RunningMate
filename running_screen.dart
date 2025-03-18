import 'dart:async';
import 'dart:math'; // 수학적 계산 (랜덤 값, 삼각 함수 등)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:run1220/finish_screen.dart';
import 'package:screenshot/screenshot.dart';
import 'Calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:run1220/tts.dart';

import 'main.dart';


class RunningScreen extends StatefulWidget {
  final List<NLatLng> roadPath;
  final NLatLng startLocation;

  final StreamController<Map<String, dynamic>> _statsController = StreamController.broadcast();

  RunningScreen({
    super.key,
    required this.roadPath,
    required this.startLocation,
  });

  @override
  _RunningScreenState createState() => _RunningScreenState();

  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;
}

class _RunningScreenState extends State<RunningScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  NaverMapController? _mapController;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isGuideMuted = false;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  Timer? _stopTimer;
  Timer? _stopHoldTimer;
  int _elapsedTime = 0;
  double _totalDistance = 0.0;
  double _caloriesBurned = 0.0;
  Position? _lastPosition;
  NMarker? _userLocationMarker;
  RunningTTS? _runningTTS;

  static const double MIN_SPEED_THRESHOLD = 0.5; // 0.5m/s 이하 속도 무시
  static const double MIN_ACCURACY_THRESHOLD = 10.0; // 10m 이하 정확도만 사용

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndFollowUser(); // 내 위치 버튼과 동일한 동작 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _runningTTS = RunningTTS(widget); // ✅ `RunningScreen`의 데이터를 전달
      });
    });
    _startStatsave();
  }

  void _startStatsave() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _elapsedTime;
        _caloriesBurned;
        _totalDistance;
        _formatPace();
        _isPaused;
        _isRunning;
      });

      // 🔥 최신 데이터 전송
      widget._statsController.add({
        'elapsedTime': _elapsedTime,
        'caloriesBurned': _caloriesBurned,
        'pace': _formatPace(),
        'totalDistance': _totalDistance,
        'paused': _isPaused,
        'restart': _isRunning,
      });
    });
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
          "pace": "${_formatPace()} /km",
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

  bool _isTimerRunning = false; // ✅ 타이머 실행 여부 확인용 변수

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

  void _navigateToFinishScreen() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => FinishScreen(
            distance: _totalDistance / 1000, // m → km 변환
            time: _elapsedTime,
            calories: _caloriesBurned,
            routePath: _traveledPath, // 사용자가 이동한 경로
          ),
        ),
            (route) => false, // 기존 화면 모두 제거
      );
    }
  }

  List<Position> _recentPositions = [];
  // 지나온 경로 저장용 리스트
  List<NLatLng> _traveledPath = [];


  double _calculateGradient(double previousAltitude, double currentAltitude, double distance) {
    if (distance == 0) return 0.0; // 이동거리가 0이면 경사도 0%
    double elevationChange = currentAltitude - previousAltitude; // 고도 차이 계산
    return (elevationChange / distance) * 100; // 경사도 계산 (단위: %)
  }

  void _startTracking() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    ).listen((Position position) {
      if (!mounted || !_isRunning || _isPaused) return;
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

          double previousAltitude = _lastPosition != null ? _lastPosition!.altitude : position.altitude;
          double currentAltitude = position.altitude;
          double currentGradient = _calculateGradient(previousAltitude, currentAltitude, distance);

          _caloriesBurned = _calculateCalories(speed, currentGradient);
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

  double _calculateCalories(double speed, double gradient) {
    double weight = 70.0; // 사용자 체중 (TODO: 프로필에서 가져오기)
    double met = 1.5; // 기본 MET 값

    if (speed >= 12.0) {
      met = 12.0;
    } else if (speed >= 8.0) {
      met = 10.0;
    } else if (speed >= 5.0) {
      met = 6.0;
    } else if (speed >= 3.0) {
      met = 3.0;
    }

    // 🔥 경사도 반영
    if (gradient >= 5) {
      met += 1.5; // 오르막길 5% 이상 → MET 증가
    }
    if (gradient >= 10) {
      met += 2.5; // 오르막길 10% 이상 → MET 더 증가
    }
    if (gradient < -5) {
      met -= 1.0; // 내리막길 → MET 약간 감소
    }

    double timeInHours = _elapsedTime / 3600.0;
    return met * weight * timeInHours;
  }


  void _startRun() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _startTimer(); // ✅ 타이머 실행
    _startTracking(); // ✅ GPS 위치 트래킹 다시 시작
  }


  void _pauseRun() {
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _stopRun() {
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });

    _timer?.cancel(); // ✅ 타이머 정지
    _isTimerRunning = false; // ✅ 타이머 실행 상태 업데이트
    _positionStream?.cancel(); // ✅ GPS 위치 업데이트 정지
    _stopTimer?.cancel(); // ✅ 3초 후 정지 타이머 취소
  }



  @override
  void dispose() {
    widget._statsController.close();
    _runningTTS?.dispose();
    _timer?.cancel();
    _positionStream?.cancel();
    _stopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Screenshot(
            controller: _screenshotController,
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: widget.startLocation,
                  zoom: 16,
                ),
                locationButtonEnable: false,
              ),
              onMapReady: (controller) {
                _mapController = controller;
                _mapController!.addOverlay(
                  NPathOverlay(
                    id: 'recommended_road',
                    coords: widget.roadPath,
                    width: 8,
                    color: const Color(0xFFD32F2F),
                    outlineWidth: 2,
                    outlineColor: Colors.white,
                    patternImage: NOverlayImage.fromAssetImage("assets/images/pattern_white.png"),
                    patternInterval: 30,
                  ),
                );
              },
            ),
          ),

          // ✅ 지도 위 좌측 상단에 뒤로가기 버튼 추가
          Positioned(
            top: 50,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12), // 🔥 동글 네모 버튼
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
              ),
            ),
          ),

          Align(
              alignment: Alignment.topRight,
              child: Padding(
                  padding: const EdgeInsets.only(top: 50, right: 13),
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
                      ]
                  )
              )
          ),

// 정보 표시 박스 - 버튼 포함
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
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
                  // 거리, 시간, 칼로리, 평균페이스
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
                      Column(
                        children: [
                          const Text("평균페이스", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${_formatPace()} /km", style: TextStyle(fontSize: 18)),
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
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(
                              Icons.play_arrow,
                              color: Color(0xFFE53935), size: 30),
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
                            _navigateToFinishScreen();
                          });
                        },
                        onLongPressEnd: (_) {
                          // 손을 떼면 타이머 취소
                          _stopHoldTimer?.cancel();
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFFE53935),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 30,
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