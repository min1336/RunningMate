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

  NLatLng? _start;
  List<NLatLng> _waypoints = [];

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


  Future<void> _setupWaypoints(NLatLng startLatLng, double totalDistance) async {
    List<NLatLng> waypoints = [];
    double distancePerSegment = (totalDistance / 2.0) / 4.0;

    NLatLng currentLocation = startLatLng;
    Random random = Random();

    for (int i = 1; i <= 3; i++) {
      double angle = (random.nextDouble() * 2 * pi) / i;  // 점차 부드럽게
      currentLocation = await _calculateWaypoint(currentLocation, distancePerSegment, angle);
      waypoints.add(currentLocation);
    }

    _waypoints = waypoints;
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
    if (_mapController == null || _start == null) return;

    final distanceInKm = (distanceInMeters / 1000).toStringAsFixed(2);

    // ✅ NMarker의 caption 속성 활용
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

// ⭐ 경유지마다 마커를 추가하는 함수
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

// 🚀 _getDirections 함수 수정: 경유지 마커 추가
  Future<void> _getDirections() async {
    if (_mapController == null) return;

    await _moveCameraToStart();  // 🚀 카메라 이동

    const clientId = 'rz7lsxe3oo';
    const clientSecret = 'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg';
    final waypointsParam = _waypoints.map((point) => '${point.longitude},${point.latitude}').join('|');

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
      _drawRoute(data);

      // ✅ 전체 거리 정보 추출 및 표시
      final totalDistance = data['route']['trafast'][0]['summary']['distance'];  // 전체 거리(m)
      _showTotalDistance(totalDistance);  // 지도에 거리 표시

      // ✅ 경유지마다 마커 추가
      _addWaypointMarkers();
    } else {
      print('❗ Error: ${response.statusCode}');
      print('❗ Response Body: ${response.body}');
      throw Exception('자동차 도로 경로 요청에 실패했습니다.');
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
