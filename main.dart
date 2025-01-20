import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:permission_handler/permission_handler.dart';

//메인
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
  Set<NLatLng> _visitedCoordinates = {}; // 지나온 경로를 저장할 Set

  //위치(주소)정보 받아오기
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

  //경로 설정 함수
  Future<void> _getDirections() async {
    if (_mapController == null || _start == null) return;

    const clientId = 'rz7lsxe3oo';
    const clientSecret = 'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg';

    final userDistance = double.parse(_distanceController.text); // 입력 거리 (m)
    const tolerance = 200; // 허용 오차 범위 (±200m)

    bool isWithinTolerance = false;

    while (!isWithinTolerance) {
      // 경유지 설정
      await _setupWaypoints(_start!, userDistance);

      // 경유지 최적화
      await _optimizeRoute(_waypoints);

      // 경유지 파라미터 생성
      final waypointsParam = _waypoints.map((point) => '${point.longitude},${point.latitude}').join('|');

      // Directions API 호출
      final url = 'https://naveropenapi.apigw.ntruss.com/map-direction-15/v1/driving'
          '?start=${_start!.longitude},${_start!.latitude}'
          '&goal=${_start!.longitude},${_start!.latitude}'
          '&waypoints=$waypointsParam'
          '&option=trafast';

      final response = await http.get(Uri.parse(url), headers: {
        'X-NCP-APIGW-API-KEY-ID': clientId,
        'X-NCP-APIGW-API-KEY': clientSecret,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 실제 경로 거리(m)
        final totalDistance = data['route']['trafast'][0]['summary']['distance'];

        if ((totalDistance >= (userDistance - tolerance)) && (totalDistance <= (userDistance + tolerance))) {
          isWithinTolerance = true; // 허용 범위 내면 루프 종료
          _drawRoute(data); // 경로 그리기
          _showTotalDistance(totalDistance); // 지도에 총 거리 표시
          _addWaypointMarkers(); // 경유지 마커 추가
          _moveCameraToStart(); //카메라 추적
          print('✅ 경로 생성 성공: 실제 거리 $totalDistance m');
        } else {
          print('❗ 경로 조정 필요: 실제 거리 $totalDistance m');
          await _adjustWaypointsSmartly(data, userDistance, tolerance); // 스마트 경유지 조정
        }
      } else {
        print('❗ Error: ${response.statusCode}');
        print('❗ Response Body: ${response.body}');
        throw Exception('자동차 도로 경로 요청에 실패했습니다.');
      }
    }
  }

  //경로를 부드럽게 만들기 위한 최적화 함수
  Future<void> _optimizeRoute(List<NLatLng> waypoints) async {
    // 1. 경유지 개수가 너무 많으면, 적당히 줄여서 경로를 직선적으로 만듦
    if (waypoints.length > 5) {
      // 첫 번째와 마지막 경유지만 남기고 중간 경유지 제거
      final optimizedWaypoints = [waypoints.first, waypoints.last];
      setState(() {
        _waypoints = optimizedWaypoints;
      });
      print("경유지 최적화: 경유지 수를 줄였습니다.");
    } else {
      // 2. 경유지 간의 위치가 너무 멀거나, 경로 상에서 부자연스러울 경우 보간법 적용
      final optimizedWaypoints = _applyLinearInterpolation(waypoints);
      setState(() {
        _waypoints = optimizedWaypoints;
      });
      print("경유지 최적화: 경로를 부드럽게 연결했습니다.");
    }
  }

  //경유지 간 보간법을 적용하는 함수 (Linear interpolation)
  List<NLatLng> _applyLinearInterpolation(List<NLatLng> waypoints) {
    List<NLatLng> optimizedWaypoints = [];
    for (int i = 0; i < waypoints.length - 1; i++) {
      optimizedWaypoints.add(waypoints[i]);
      // 경유지 간 거리가 너무 멀면 중간에 추가 지점을 넣어줌
      final start = waypoints[i];
      final end = waypoints[i + 1];
      final distance = _calculateDistance(start, end);

      if (distance > 1000) {  // 1km 이상 간격이면 중간 지점 추가
        final midPoint = _getMidPoint(start, end);
        optimizedWaypoints.add(midPoint);
      }
    }
    optimizedWaypoints.add(waypoints.last);
    return optimizedWaypoints;
  }

  //두 지점의 중간 지점을 계산하는 함수
  NLatLng _getMidPoint(NLatLng start, NLatLng end) {
    final lat = (start.latitude + end.latitude) / 2;
    final lon = (start.longitude + end.longitude) / 2;
    return NLatLng(lat, lon);
  }

  //경유지 설정 함수
  Future<void> _setupWaypoints(NLatLng startLatLng, double totalDistance) async {
    List<NLatLng> waypoints = [];
    double distancePerSegment = (totalDistance / 2.0) / 4.0;

    NLatLng currentLocation = startLatLng;
    Random random = Random();

    for (int i = 1; i <= 3; i++) {
      double angle = (random.nextDouble() * 2 * pi) / i;  // 점차 부드럽게
      currentLocation = await _calculateWaypoint(currentLocation, distancePerSegment, angle);
      // 지나온 경로와 겹치지 않는 경유지만 추가
      if (!_visitedCoordinates.contains(currentLocation)) {
        waypoints.add(currentLocation);
        _visitedCoordinates.add(currentLocation); // 지나온 경로에 추가
      }
    }

    _waypoints = waypoints;
  }

  //경유지 초기 설정
  Future<NLatLng> _calculateWaypoint(NLatLng start, double distance, double angle) async {
    const earthRadius = 6371000.0;
    final deltaLat = (distance / earthRadius) * cos(angle);
    final deltaLon = (distance / (earthRadius * cos(start.latitude * pi / 180))) * sin(angle);

    final newLat = start.latitude + (deltaLat * 180 / pi);
    final newLon = start.longitude + (deltaLon * 180 / pi);

    return NLatLng(newLat, newLon);
  }

  //경유지 수정
  Future<void> _adjustWaypointsSmartly(Map<String, dynamic> routeData, double userDistance, final tolerance) async {
    final route = routeData['route']['trafast'][0];
    final path = route['path'] as List<dynamic>;

    // 경로 상의 모든 좌표 리스트 (NLatLng)
    final List<NLatLng> routeCoordinates = path.map((coord) => NLatLng(coord[1], coord[0])).toList();

    // 각 경유지를 경로에 더 가까운 점으로 이동
    for (int i = 0; i < _waypoints.length; i++) {
      final waypoint = _waypoints[i];
      double closestDistance = double.infinity;
      NLatLng? closestPoint;

      // 경로 상의 각 점과 현재 경유지 간 거리 계산
      for (final routePoint in routeCoordinates) {
        final distance = _calculateDistance(waypoint, routePoint);
        if (distance < closestDistance) {
          closestDistance = distance;
          closestPoint = routePoint;
        }
      }

      // 가장 가까운 경로 상의 점으로 경유지 이동
      if (closestPoint != null) {
        _waypoints[i] = closestPoint;
      }
    }
  }

  //거리 계산 함수
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const earthRadius = 6371000.0; // 지구 반지름 (미터)
    final dLat = (point2.latitude - point1.latitude) * pi / 180.0;
    final dLon = (point2.longitude - point1.longitude) * pi / 180.0;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(point1.latitude * pi / 180.0) *
            cos(point2.latitude * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // 거리 (미터)
  }

  //경로 그리는 함수
  void _drawRoute(Map<String, dynamic> routeData) {
    if (_mapController == null) return;

    final List<NLatLng> polylineCoordinates = [];
    final route = routeData['route']['trafast'][0];
    final path = route['path'];

    for (var coord in path) {
      polylineCoordinates.add(NLatLng(coord[1], coord[0]));
    }

    _mapController!.addOverlay(NPolylineOverlay(
      id: 'route',
      color: Colors.blue,
      width: 8,  // 두꺼운 경로선
      coords: polylineCoordinates,
    ));
  }

  //주소 자동완성 HTML 태그 제거 함수
  String _removeHtmlTags(String text) {
    final regex = RegExp(r'<[^>]*>');
    return text.replaceAll(regex, '').trim();
  }

  //주소 자동완성
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

  //주소누르면 자동완성 도움
  void _onAddressSelected(String address) {
    _startController.text = address;
    setState(() {
      _suggestedAddresses.clear();
    });
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

  //지도 위에 총 거리(km) 표시
  void _showTotalDistance(int distanceInMeters) {
    if (_mapController == null || _start == null) return;

    final distanceInKm = (distanceInMeters / 1000).toStringAsFixed(2);

    //NMarker의 caption 속성 활용
    _mapController!.addOverlay(NMarker(
      id: 'distance_marker',
      position: _start!,
      caption: NOverlayCaption(
        text: '총 거리: $distanceInKm km',
        textSize: 14.0,
        color: Colors.black,
        haloColor: Colors.white,
      ),
    ));
  }

  //경유지마다 마커 추가
  void _addWaypointMarkers() {
    if (_mapController == null) return;

    for (int i = 0; i < _waypoints.length; i++) {
      final waypoint = _waypoints[i];

      _mapController!.addOverlay(NMarker(
        id: 'waypoint_marker_$i',
        position: waypoint,
        caption: NOverlayCaption(
          text: '경유지 ${i + 1}',
          textSize: 14.0,
          color: Colors.blue,
          haloColor: Colors.white,
        ),
      ));
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
        body: Column(
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
                    decoration: const InputDecoration(labelText: '달릴 거리 입력 (미터)'),
                    keyboardType: TextInputType.number,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final totalDistance = double.parse(_distanceController.text);
                      _start = await getLocation(_startController.text);
                      await _setupWaypoints(_start!, totalDistance);
                      await _getDirections();
                    },
                    child: const Text('경로 표시'),
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