import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'route_detail_screen.dart'; // 실제 경로에 맞게 수정해줘

class RecommendedRoutesSlider extends StatefulWidget {
  const RecommendedRoutesSlider({super.key});

  @override
  State<RecommendedRoutesSlider> createState() => _RecommendedRoutesSliderState();
}

class _RecommendedRoutesSliderState extends State<RecommendedRoutesSlider> {
  List<Map<String, dynamic>> routes = [];

  @override
  void initState() {
    super.initState();
    fetchRandomSharedRoutes().then((data) {
      setState(() {
        routes = data;
      });
    });
  }

  Future<List<Map<String, dynamic>>> fetchRandomSharedRoutes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shared_routes')
        .get();

    final docs = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    docs.shuffle(Random());
    return docs.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "🏃 오늘의 추천 루트",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.88),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              final routePath = (route['route'] as List)
                  .map((e) => NLatLng(e['lat'], e['lng']))
                  .toList();

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RouteDetailScreen(route: route),
                    ),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      // 지도 미리보기
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: NaverMap(
                            options: NaverMapViewOptions(
                              initialCameraPosition: NCameraPosition(
                                target: routePath.first,
                                zoom: 13,
                              ),
                            ),
                            onMapReady: (controller) async {
                              await controller.clearOverlays();
                              await controller.addOverlay(NPathOverlay(
                                id: 'preview_path_$index',
                                coords: routePath,
                                color: Colors.redAccent,
                                width: 4,
                              ));
                            },
                          ),
                        ),
                      ),

                      // 텍스트 정보
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    route['title'] ?? '제목 없음',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    '추천',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.route, size: 18, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Text("${((route['distance'] ?? 0)).round()} m"),
                                const SizedBox(width: 16),
                                const Icon(Icons.timer, size: 18, color: Colors.redAccent),
                                const SizedBox(width: 4),
                                Text(route['estimatedTime'] ?? '시간 정보 없음'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
