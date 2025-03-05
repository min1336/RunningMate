import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:run1220/main.dart';

class FinishScreen extends StatefulWidget {
  final double distance;
  final int time;
  final double calories;
  final List<NLatLng> routePath;

  const FinishScreen({
    super.key,
    required this.distance,
    required this.time,
    required this.calories,
    required this.routePath,
  });

  @override
  _FinishScreenState createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _distanceAnimation;
  late Animation<int> _timeAnimation;
  late Animation<int> _caloriesAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _distanceAnimation = Tween<double>(begin: 0, end: widget.distance).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _timeAnimation = IntTween(begin: 0, end: widget.time).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _caloriesAnimation = IntTween(begin: 0, end: widget.calories.toInt()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 시간을 "MM:SS" 형식으로 변환
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    String dayOfWeek = DateFormat('EEEE', 'ko_KR').format(DateTime.now());

    return Scaffold(
      body: Stack(
        children: [
          // 📌 지도 화면 (기본 배경)
          Positioned.fill(
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: widget.routePath.isNotEmpty
                      ? widget.routePath.first
                      : const NLatLng(37.5665, 126.9780), // 기본 위치
                  zoom: 15,
                ),
              ),
              onMapReady: (controller) {
                if (widget.routePath.isNotEmpty) {
                  controller.addOverlay(
                    NPathOverlay(
                      id: 'running_path',
                      coords: widget.routePath,
                      color: Colors.orange,
                      width: 6,
                    ),
                  );
                }
              },
            ),
          ),

          // 📌 지도 위에 반투명 정보 패널
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6), // 반투명 배경
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(
                    "$dayOfWeek 러닝 완료!",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                  // 📌 거리 정보 (카운트 업 애니메이션 적용)
                  AnimatedBuilder(
                    animation: _distanceAnimation,
                    builder: (context, child) {
                      return Text(
                        "${_distanceAnimation.value.toStringAsFixed(2)} km",
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // 📌 달리기 상세 정보 (시간, 칼로리, 평균 페이스)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn("⏱ 시간", _timeAnimation, isTime: true),
                      _buildInfoColumn("🔥 칼로리", _caloriesAnimation),
                      _buildInfoColumn("⚡ 평균 페이스",
                          Tween<int>(
                              begin: 0,
                              end: widget.distance > 0 ? (widget.time ~/ widget.distance) : 0
                          ).animate(_controller)
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 📌 메인 화면으로 돌아가기 버튼 (하단에 고정)
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                      (route) => false, // 기존 화면 모두 제거
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
              child: const Text("🏠 메인 화면으로", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 📌 정보 표시용 위젯 (카운트 업 애니메이션 포함)
  Widget _buildInfoColumn(String title, Animation<int> animation, {bool isTime = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white)),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Text(
              isTime ? _formatTime(animation.value) : "${animation.value} ${title == '🔥 칼로리' ? 'kcal' : '/km'}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            );
          },
        ),
      ],
    );
  }
}
