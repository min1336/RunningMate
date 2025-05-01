import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:run1220/running_screen.dart';

class RouteDetailScreen extends StatelessWidget {
  final Map<String, dynamic> route;

  const RouteDetailScreen({super.key, required this.route});

  List<NLatLng> _parseRoute(List<dynamic> raw) {
    return raw.map((e) => NLatLng(e['lat'], e['lng'])).toList();
  }

  int _parseTime(String timeStr) {
    if (timeStr.contains(':')) {
      final parts = timeStr.split(':');
      if (parts.length != 2) return 0;
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return minutes * 60 + seconds;
    } else if (timeStr.contains('분')) {
      final minutes = int.tryParse(timeStr.replaceAll('분', '').trim()) ?? 0;
      return minutes * 60;
    } else if (timeStr.contains('초')) {
      final seconds = int.tryParse(timeStr.replaceAll('초', '').trim()) ?? 0;
      return seconds;
    }
    return 0;
  }

  List<Widget> _buildStarRating(double rating) {
    final List<Widget> stars = [];
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, color: Colors.amber, size: 20));
    }

    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, color: Colors.amber, size: 20));
    }

    for (int i = 0; i < emptyStars; i++) {
      stars.add(const Icon(Icons.star_border, color: Colors.amber, size: 20));
    }

    return stars;
  }

  @override
  Widget build(BuildContext context) {
    final path = _parseRoute(route['route']);
    final name = route['title'] ?? '이름 없음';
    final distance = route['distance'] ?? 0;
    final time = route['estimatedTime'] ?? '알 수 없음';
    final rating = route['rating'] ?? 0.0;
    final ratingCount = route['ratingCount'] ?? 0;
    final userPlayed = route['userPlayedCount'] ?? 0;
    final communityPlayed = route['communityPlayedCount'] ?? 0;
    final location = route['location'] ?? '위치 정보 없음';

    final ghostPath = path;
    final ghostDuration = _parseTime(time);

    return Scaffold(
      body: Stack(
        children: [
          // 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: path.isNotEmpty ? path.first : const NLatLng(37.5665, 126.9780),
                zoom: 15,
              ),
            ),
            onMapReady: (controller) {
              if (path.isNotEmpty) {
                controller.addOverlay(NPathOverlay(
                  id: 'shared_route',
                  coords: path,
                  color: Colors.redAccent,
                  width: 6,
                  patternImage: NOverlayImage.fromAssetImage('assets/images/pattern.png'),
                  patternInterval: 30,
                ));
              }
            },
          ),

          // 닫기 버튼
          Positioned(
            top: 45,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
          ),

          // 위로 덮는 상세 정보 UI
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('$distance m ($time)'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {
                        if (path.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("경로 정보가 없습니다.")),
                          );
                          return;
                        }
                        if (path.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RunningScreen(
                                roadPath: path,
                                startLocation: path.first,
                                fromSharedRoute: true,
                                routeDocId: route['docId'],
                                ghostPath: ghostPath,
                                ghostDuration: ghostDuration,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('루트 시작'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('$communityPlayed', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('커뮤니티가 플레이한 수'),
                          ],
                        ),
                        Column(
                          children: [
                            Row(
                              children: [
                                Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(' ($ratingCount)'),
                              ],
                            ),
                            Row(children: _buildStarRating(rating)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('$userPlayed', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('내가 플레이한 수'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('장소: $location'),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
