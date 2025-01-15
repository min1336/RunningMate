import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  await _initialize();
  runApp(const NaverMapApp());
}

Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(clientId: 'rz7lsxe3oo');
}

class NaverMapApp extends StatefulWidget {
  const NaverMapApp({super.key});

  @override
  State<NaverMapApp> createState() => _NaverMapAppState();
}

class _NaverMapAppState extends State<NaverMapApp> {
  NaverMapController? _mapController;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  List<Map<String, String>> _suggestedAddresses = [];

  NLatLng? _start;
  List<NLatLng> _waypoints = [];

  double _calculatedDistance = 0.0;

  bool _isLoading = false;  // 🔥 로딩 상태 추가

  // HTML 태그 제거 함수
  String _removeHtmlTags(String text) {
    final regex = RegExp(r'<[^>]*>');
    return text.replaceAll(regex, '').trim();
  }

  // 자동완성 API 호출
  Future<void> _getSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestedAddresses.clear();
      });
      return;
    }

    const clientId = 'SuuXcENvj8j80WSDEPRe'; // Naver Client ID
    const clientSecret = '1KARXNrW1q'; // Naver Client Secret

    final url =
        'https://openapi.naver.com/v1/search/local.json?query=$query&display=5'; // Display is the number of results you want

    final response = await http.get(Uri.parse(url), headers: {
      'X-Naver-Client-Id': clientId,
      'X-Naver-Client-Secret': clientSecret,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['items'] as List<dynamic>;

      setState(() {
        _suggestedAddresses = items.map<Map<String, String>>((item) {
          // 장소 이름과 도로명 주소를 함께 반환
          return {
            'place': _removeHtmlTags(item['title'] ?? '장소 이름 없음'), // HTML 태그 제거
            'address': item['roadAddress'] ?? item['jibunAddress'] ?? '주소 정보 없음',
          };
        }).toList();
      });
    } else {
      print('❗ Error: ${response.statusCode}');
      print('❗ Response Body: ${response.body}');
    }
  }

  // 선택한 주소 처리
  void _onAddressSelected(String address) {
    _startController.text = address;
    setState(() {
      _suggestedAddresses.clear();
    });
  }

  void _drawRoute(Map<String, dynamic> routeData) {
    if (_mapController == null) return;

    final List<NLatLng> polylineCoordinates = [];
    final route = routeData['route']['traavoidcaronly'][0];
    final path = route['path'];

    for (var coord in path) {
      polylineCoordinates.add(NLatLng(coord[1], coord[0]));
    }

    _mapController!.addOverlay(NPolylineOverlay(
      id: 'route',
      color: Colors.lightGreen,
      width: 4,
      coords: polylineCoordinates,
    ));
  }

  Future<List<NLatLng>> _generateWaypoints(NLatLng start, double totalDistance) async {
    const int numberOfWaypoints = 5;  // 경유지 개수
    final Random random = Random();
    final List<NLatLng> waypoints = [];

    for (int i = 0; i < numberOfWaypoints; i++) {
      final double angle = random.nextDouble() * 2 * pi;
      final double distance = (totalDistance / numberOfWaypoints) * random.nextDouble();
      final NLatLng waypoint = await _calculateWaypoint(start, distance, angle);
      waypoints.add(waypoint);
    }

    return waypoints;
  }


  Future<List<NLatLng>> optimizeWaypoints(List<NLatLng> waypoints) async {
    if (waypoints.isEmpty) return waypoints;

    List<int> bestOrder = List.generate(waypoints.length, (index) => index);
    double bestDistance = _calculateTotalDistance(waypoints, bestOrder);

    bool improved = true;
    while (improved) {
      improved = false;
      for (int i = 1; i < waypoints.length - 1; i++) {
        for (int j = i + 1; j < waypoints.length; j++) {
          List<int> newOrder = List.from(bestOrder);
          newOrder.setRange(i, j + 1, bestOrder.sublist(i, j + 1).reversed);
          double newDistance = _calculateTotalDistance(waypoints, newOrder);
          if (newDistance < bestDistance) {
            bestDistance = newDistance;
            bestOrder = newOrder;
            improved = true;
          }
        }
      }
    }

    return bestOrder.map((index) => waypoints[index]).toList();
  }

  double _calculateTotalDistance(List<NLatLng> waypoints, List<int> order) {
    double totalDistance = 0.0;
    for (int i = 0; i < order.length - 1; i++) {
      totalDistance += _calculateDistance(waypoints[order[i]], waypoints[order[i + 1]]);
    }
    return totalDistance;
  }

  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const earthRadius = 6371000.0;
    final dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final dLon = _degreesToRadians(point2.longitude - point1.longitude);
    final a = pow(sin(dLat / 2), 2) +
        cos(_degreesToRadians(point1.latitude)) * cos(_degreesToRadians(point2.latitude)) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degree) {
    return degree * pi / 180;
  }


  Future<NLatLng> _calculateWaypoint(NLatLng start, double distance, double angle) async {
    const earthRadius = 6371000.0;
    final deltaLat = (distance / earthRadius) * cos(angle);
    final deltaLon = (distance / (earthRadius * cos(start.latitude * pi / 180))) * sin(angle);

    final newLat = start.latitude + (deltaLat * 180 / pi);
    final newLon = start.longitude + (deltaLon * 180 / pi);

    return NLatLng(newLat, newLon);
  }

  Future<NLatLng> getLocation(String address) async {
    const clientId = 'rz7lsxe3oo';
    const clientSecret = 'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg';
    final url = 'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=${Uri.encodeComponent(address)}';

    final response = await http.get(Uri.parse(url), headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId,
      'X-NCP-APIGW-API-KEY': clientSecret,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['addresses'] == null || data['addresses'].isEmpty) {
        throw Exception('주소를 찾을 수 없습니다.');
      }
      final lat = double.parse(data['addresses'][0]['y']);
      final lon = double.parse(data['addresses'][0]['x']);
      return NLatLng(lat, lon);
    } else {
      throw Exception('위치 정보를 불러오지 못했습니다.');
    }
  }
// 시작 위치로 카메라 이동
  Future<void> _moveCameraToStart() async {
    if (_mapController != null && _start != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(
          target: _start!,
          zoom: 15,  // 적당한 확대 수준
        ),
      );
    }
  }
// ⭐ 지도 위에 총 거리(km) 표시
  // ⭐ 지도 위에 총 거리(km) 표시 (수정 버전)
  void _showTotalDistance(int distanceInMeters) {
    setState(() {
      _calculatedDistance = distanceInMeters / 1000;  // m → km 변환
    });

    if (_mapController == null || _start == null) return;

    _mapController!.addOverlay(NMarker(
      id: 'distance_marker',
      position: _start!,
    ));
  }

// ⭐ 경유지마다 마커를 추가하는 함수
  void _addWaypointMarkers() {
    if (_mapController == null) return;

    for (int i = 0; i < _waypoints.length; i++) {
      final waypoint = _waypoints[i];

      _mapController!.addOverlay(NMarker(
        id: 'waypoint_marker_$i',
        position: waypoint,
        caption: NOverlayCaption(
          text: '${i + 1}',
          textSize: 12.0,
          color: Colors.black,
          haloColor: Colors.white,
        ),
      ));
    }
  }

// 🚀 _getDirections 함수 수정: 경유지 마커 추가
  Future<void> _getDirections() async {
    if (_mapController == null) return;

    await _moveCameraToStart();

    const clientId = 'rz7lsxe3oo';
    const clientSecret = 'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg';

    final waypointsParam = _waypoints
        .sublist(0, _waypoints.length - 1)
        .map((point) => '${point.longitude},${point.latitude}')
        .join('|');

    final url = 'https://naveropenapi.apigw.ntruss.com/map-direction-15/v1/driving'
        '?start=${_start!.longitude},${_start!.latitude}'
        '&goal=${_start!.longitude},${_start!.latitude}'
        '&waypoints=$waypointsParam'
        '&option=traavoidcaronly';  // ✅ trafast → tracomfort로 변경

    final response = await http.get(Uri.parse(url), headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId,
      'X-NCP-APIGW-API-KEY': clientSecret,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _drawRoute(data);

      // ✅ trafast → tracomfort로 변경
      final totalDistance = data['route']['traavoidcaronly'][0]['summary']['distance'];
      _showTotalDistance(totalDistance);

      _addWaypointMarkers();
    }
  }

  @override
  void initState() {
    super.initState();
    _permission();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Naver Map Directions')),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _startController,
                        decoration: const InputDecoration(labelText: '출발지 주소 입력'),
                        onChanged: _getSuggestions, // 실시간 주소 검색
                      ),
                      if (_suggestedAddresses.isNotEmpty)
                        Container(
                          height: 200,
                          color: Colors.white,
                          child: ListView.builder(
                            itemCount: _suggestedAddresses.length,
                            itemBuilder: (context, index) {
                              final place = _suggestedAddresses[index]['place']!;
                              final address = _suggestedAddresses[index]['address']!;

                              return ListTile(
                                title: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: place, // 장소 이름
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '\n$address', // 도로명 주소
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey, // 회색 글씨
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => _onAddressSelected(address),
                              );
                            },
                          ),
                        ),
                      TextField(
                        controller: _distanceController,
                        decoration: const InputDecoration(labelText: '달릴 거리 입력 (킬로미터)'),
                        keyboardType: TextInputType.number,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          '계산된 총 거리: ${_calculatedDistance.toStringAsFixed(2)} km',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                          FocusScope.of(context).unfocus();  // 🔥 키보드 내리기

                          setState(() {
                            _isLoading = true;  // 🔥 로딩 시작
                          });

                          try {
                            final totalDistance = double.parse(_distanceController.text) * 1000;
                            _start = await getLocation(_startController.text);

                            final waypoints = await _generateWaypoints(_start!, totalDistance);
                            _waypoints = await optimizeWaypoints(waypoints);

                            await _getDirections();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('오류 발생: $e')),
                            );
                          } finally {
                            setState(() {
                              _isLoading = false;  // 🔥 로딩 종료
                            });
                          }
                        },
                        child: const Text('길찾기'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: NaverMap(
                    options: const NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: NLatLng(37.5665, 126.9780),
                        zoom: 10,
                      ),
                      locationButtonEnable: true,
                    ),
                    onMapReady: (controller) {
                      _mapController = controller;
                    },
                  ),
                ),
              ],
            ),
            if (_isLoading)  // 🔥 로딩 인디케이터
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _permission() async {
  var status = await Permission.location.status;
  if (!status.isGranted) {
    await Permission.location.request();
  }
}
