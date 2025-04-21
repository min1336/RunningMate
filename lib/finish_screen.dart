// 🔥 루트 평가 기능이 포함된 FinishScreen 전체 코드
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:run1220/home_screen.dart';

class FinishScreen extends StatefulWidget {
  final String runRecordId;
  final double distance;
  final int time;
  final double calories;
  final List<NLatLng> routePath;
  final int averageHeartRate;
  final bool fromSharedRoute;
  final String? routeDocId;

  const FinishScreen({
    super.key,
    required this.runRecordId,
    required this.distance,
    required this.time,
    required this.calories,
    required this.routePath,
    required this.averageHeartRate,
    this.fromSharedRoute = false,
    this.routeDocId,
  });

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _distanceAnimation;
  late Animation<int> _timeAnimation;
  late Animation<int> _caloriesAnimation;
  late Animation<int> _heartRateAnimation;

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
    _heartRateAnimation = IntTween(begin: 0, end: widget.averageHeartRate).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  Future<void> _submitRouteRating(double newRating) async {
    try {
      final routeDocId = widget.routeDocId;
      if (routeDocId == null) return;

      final docRef = FirebaseFirestore.instance.collection('shared_routes').doc(routeDocId);
      final snapshot = await docRef.get();

      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final double currentRating = (data['rating'] ?? 0).toDouble();
      final int currentCount = (data['ratingCount'] ?? 0).toInt();
      final int currentUserCount = (data['userPlayedCount'] ?? 0).toInt();
      final int currentCommunityCount = (data['communityPlayedCount'] ?? 0).toInt();

      final double newAverage = ((currentRating * currentCount) + newRating) / (currentCount + 1);

      await docRef.update({
        'rating': double.parse(newAverage.toStringAsFixed(2)),
        'ratingCount': currentCount + 1,
        'userPlayedCount': currentUserCount + 1,
        'communityPlayedCount': currentCommunityCount + 1,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 루트 평가가 저장되었습니다.')),
      );
    } catch (e) {
      print('❌ 평가 저장 실패: $e');
    }
  }

  void _showRatingDialog() {
    double rating = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('루트 별점 평가'),
          content: StatefulBuilder(
            builder: (context, setState) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => IconButton(
                icon: Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => setState(() => rating = index + 1.0),
              )),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () async {
                await _submitRouteRating(rating);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareRouteToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String routeTitle = '';
    double rating = 0.0;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('루트 공유'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: '루트 이름 입력'),
                onChanged: (value) => routeTitle = value,
              ),
              const SizedBox(height: 16),
              const Text('평점 선택'),
              StatefulBuilder(
                builder: (context, setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) => IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () {
                        setState(() => rating = index + 1.0);
                      },
                    )),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('공유'),
              onPressed: () async {
                if (routeTitle.trim().isEmpty || rating == 0.0) return;

                final recordRef = FirebaseFirestore.instance.collection('run_records').doc(widget.runRecordId);

                await FirebaseFirestore.instance.collection('shared_routes').add({
                  'title': routeTitle.trim(),
                  'distance': (widget.distance * 1000).toInt(),
                  'estimatedTime': '${widget.time ~/ 60}분',
                  'calories': widget.calories.toStringAsFixed(1),
                  'route': widget.routePath.map((point) => {
                    'lat': point.latitude,
                    'lng': point.longitude,
                  }).toList(),
                  'createdAt': Timestamp.now(),
                  'rating': rating,
                  'ratingCount': 1,
                  'communityPlayedCount': 0,
                  'userPlayedCount': 0,
                  'location': '알 수 없음',
                  'userId': uid,
                  'recordRef': recordRef.id,
                });

                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 루트가 공유되었습니다.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dayOfWeek = DateFormat('EEEE', 'ko_KR').format(DateTime.now());

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: widget.routePath.isNotEmpty ? widget.routePath.first : const NLatLng(37.5665, 126.9780),
                  zoom: 15,
                ),
              ),
              onMapReady: (controller) {
                if (widget.routePath.isNotEmpty) {
                  controller.addOverlay(NPathOverlay(
                    id: 'running_path',
                    coords: widget.routePath,
                    color: Colors.orange,
                    width: 6,
                  ));
                }
              },
            ),
          ),
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text("$dayOfWeek 러닝 완료!", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _distanceAnimation,
                    builder: (context, child) => Text(
                      "${_distanceAnimation.value.toStringAsFixed(2)} km",
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _heartRateAnimation,
                    builder: (context, child) => Text(
                      "❤️ 평균 심박수: ${widget.averageHeartRate == 0 ? '--' : '${widget.averageHeartRate} bpm'}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn("⏱ 시간", _timeAnimation, isTime: true),
                      _buildInfoColumn("🔥 칼로리", _caloriesAnimation),
                      _buildInfoColumn("⚡ 평균 페이스",
                        Tween<int>(
                          begin: 0,
                          end: widget.distance > 0 ? (widget.time ~/ widget.distance) : 0,
                        ).animate(_controller),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  widget.fromSharedRoute
                      ? ElevatedButton(
                    onPressed: _showRatingDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('⭐ 루트 평가하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                      : ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('루트 공유하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                      (route) => false,
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

  Widget _buildInfoColumn(String title, Animation<int> animation, {bool isTime = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.white)),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Text(
            isTime ? _formatTime(animation.value) : "${animation.value} ${title == '🔥 칼로리' ? 'kcal' : '/km'}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
