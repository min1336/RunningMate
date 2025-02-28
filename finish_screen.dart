import 'package:flutter/material.dart';
import 'package:run1220/main.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class FinishScreen extends StatelessWidget {
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

  String _formatTime(int seconds) {
    if (seconds <= 0) return "--:--";
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('런닝 종료'),
        automaticallyImplyLeading: false, // 뒤로 가기 버튼 제거
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("오늘 - 오후 러닝", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text("목요일 오후 러닝", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // 거리
                    Center(
                      child: Text(
                        distance.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Center(
                      child: Text("킬로미터", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ),

                    const SizedBox(height: 20),

                    // 달리기 정보
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoColumn("평균 페이스", (distance > 0) ? "${_formatTime((time / distance).toInt())} /km" : "--:-- /km"),
                        _infoColumn("시간", _formatTime(time)),
                        _infoColumn("칼로리", "${calories.toStringAsFixed(0)} kcal"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 지도 화면
          SizedBox(
            height: 300,
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: (routePath.isNotEmpty)
                      ? routePath.first
                      : const NLatLng(37.5665, 126.9780), // 기본 위치 설정
                  zoom: 15,
                ),
              ),
              onMapReady: (controller) {
                if (routePath.isNotEmpty) {
                  controller.addOverlay(
                    NPathOverlay(
                      id: 'running_path',
                      coords: routePath,
                      color: Colors.orange,
                      width: 6,
                    ),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 20),

          // 메인 화면으로 돌아가기 버튼
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                      (route) => false, // 기존 화면 모두 제거
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Center(child: Text("메인 화면으로", style: TextStyle(fontSize: 18))),
            ),
          ),
        ],
      ),
    );
  }

  // 정보 표시용 위젯
  Widget _infoColumn(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
