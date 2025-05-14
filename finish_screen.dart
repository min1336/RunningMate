import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:run1220/home_screen.dart';
import 'dart:math';

class FinishScreen extends StatelessWidget {
  final double distance;
  final int time;
  final double calories;
  final List<NLatLng> routePath;
  final int averageHeartRate;
  final bool fromSharedRoute;
  final String? routeDocId;
  final String runRecordId;

  const FinishScreen({
    super.key,
    required this.distance,
    required this.time,
    required this.calories,
    required this.routePath,
    required this.averageHeartRate,
    this.fromSharedRoute = false,
    this.routeDocId,
    required this.runRecordId,
  });

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatPace(double distance, int time) {
    if (distance <= 0 || time <= 0) return "--:--";
    final paceSeconds = time / distance; // 초/km
    final minutes = paceSeconds ~/ 60;
    final seconds = (paceSeconds % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _submitRouteRating(BuildContext context, double newRating) async {
    try {
      if (routeDocId == null) {
        print('❌ routeDocId is null');
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('❌ uid is null');
        return;
      }

      final docRef = FirebaseFirestore.instance.collection('shared_routes').doc(routeDocId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        print('❌ shared_routes doc does not exist');
        return;
      }

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

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final nickname = userDoc['nickname'] ?? '익명';
      final averageSpeed = (distance * 1000) / time;

      print('🔥 routeDocId: $routeDocId');
      print('🔥 uid: $uid');
      print('🔥 speed: $averageSpeed');

      await docRef.update({
        'Evaluation': FieldValue.arrayUnion([
          {
            'userId': uid,
            'nickname': nickname,
            'distance': distance,
            'time': time,
            'speed': double.parse(averageSpeed.toStringAsFixed(2)),
            'rankingScore': double.parse((averageSpeed * log(distance * 1000 + 1)).toStringAsFixed(2)),
            'ratedAt': Timestamp.now(),
          }
        ])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 루트 평가가 저장되었습니다.')),
      );
    } catch (e) {
      print('❌ 평가 저장 실패: $e');
    }
  }

  void _showRatingDialog(BuildContext context) {
    double rating = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('루트 별점 평가'),
          content: StatefulBuilder(
            builder: (context, setState) =>
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) =>
                      IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => setState(() => rating = index + 1.0),
                      )),
                ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            TextButton(
              onPressed: () async {
                await _submitRouteRating(context, rating);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareRouteToFirestore(BuildContext context) async {
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
                    children: List.generate(5, (index) =>
                        IconButton(
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
                if (routeTitle
                    .trim()
                    .isEmpty || rating == 0.0) return;

                final recordRef = FirebaseFirestore.instance.collection(
                    'run_records').doc(runRecordId);

                await FirebaseFirestore.instance.collection('shared_routes')
                    .add({
                  'title': routeTitle.trim(),
                  'distance': (distance * 1000).toInt(),
                  'estimatedTime': '${time ~/ 60}분',
                  'calories': calories.toStringAsFixed(1),
                  'route': routePath.map((point) =>
                  {
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
                  target: routePath.isNotEmpty
                      ? routePath.first
                      : const NLatLng(37.5665, 126.9780),
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

          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(
                    "$dayOfWeek 러닝 완료!",
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${distance.toStringAsFixed(2)} km",
                    style: const TextStyle(fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(_formatTime(time), "시간"),
                      _buildInfoItem("${calories.toInt()}", "칼로리"),
                      _buildInfoItem(
                        _formatPace(distance, time),
                        "평균페이스",
                      ),
                      _buildInfoItem(
                        averageHeartRate == 0 ? "--" : "$averageHeartRate",
                        "BPM",
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  fromSharedRoute
                      ? ElevatedButton(
                    onPressed: () => _showRatingDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('⭐ 루트 평가하기', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                      : ElevatedButton(
                    onPressed: () => _shareRouteToFirestore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('루트 공유하기', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
              child: const Text("메인 화면으로",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
