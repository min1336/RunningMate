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
  List<Map<String, String>> _suggestedAddresses = [];
  double? _selectedDistance; // 선택한 거리 (km)
  double _calculatedDistance = 0.0; // 계산된 총 거리 (km 단위)
  bool _isLoading = false; // 로딩 상태 플래그

  NLatLng? _start;
  List<NLatLng> _waypoints = [];
  Set<NLatLng> _visitedCoordinates = {}; // 지나온 경로를 저장할 Set
  bool _isSearching = false;

  final List<String> _searchHistory = [];  // 🔥 최근 검색 기록 추가

  // 최근 검색 기록에 추가 (중복 방지, 최대 5개 유지)
  void _addToSearchHistory(String address) {
    setState(() {
      _searchHistory.remove(address);  // 중복 제거
      _searchHistory.insert(0, address);  // 최근 검색 추가
      if (_searchHistory.length > 5) {
        _searchHistory.removeLast();  // 최대 5개 유지
        _isSearching = false;  // 🔥 입력 중단 시 검색 기록 숨김
      }
    });
  }

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

    final userDistance = _selectedDistance! * 1000; // 입력 거리 (m)
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
      final url = 'https://naveropenapi.apigw.ntruss.com/map-direction/v1/driving'
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
          setState(() {
            _isLoading = false;  // 🔥 로딩 종료 → 버튼 활성화
          });
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

    // 🔥 원본 좌표 리스트 가져오기
    for (var coord in path) {
      polylineCoordinates.add(NLatLng(coord[1], coord[0]));
    }

    // 🔥 튀어나온 길 제거 (필터링)
    List<NLatLng> filteredCoordinates = _removeOutlierLines(polylineCoordinates);

    // 🔥 필터링된 경로를 그리기
    _mapController!.addOverlay(NPathOverlay(
      id: 'route',
      color: Colors.black,
      width: 8,  // 선 두께
      coords: filteredCoordinates,
      patternImage: NOverlayImage.fromAssetImage("assets/images/pattern.jpg"),
      patternInterval: 20,
    ));
  }

  List<NLatLng> _removeOutlierLines(List<NLatLng> coordinates) {
    if (coordinates.length < 3) return coordinates; // 🔥 3개 이하의 점이면 그대로 반환

    List<NLatLng> filtered = [coordinates.first]; // 🔥 첫 번째 점은 무조건 포함

    for (int i = 1; i < coordinates.length - 1; i++) {
      final prev = coordinates[i - 1];
      final curr = coordinates[i];
      final next = coordinates[i + 1];

      // 🔥 현재 점이 직선 구간에서 벗어나는 정도 측정
      double distanceFromLine = _perpendicularDistance(prev, next, curr);

      // 🔥 설정한 임계값 이상으로 튀어나온 점이면 제거 (예: 20m 이상 튀어나온 경우)
      if (distanceFromLine < 20) {
        filtered.add(curr);
      }
    }

    filtered.add(coordinates.last); // 🔥 마지막 점 포함
    return filtered;
  }

  double _perpendicularDistance(NLatLng start, NLatLng end, NLatLng point) {
    double x0 = point.longitude, y0 = point.latitude;
    double x1 = start.longitude, y1 = start.latitude;
    double x2 = end.longitude, y2 = end.latitude;

    double numerator = ((x2 - x1) * (y1 - y0)) - ((x1 - x0) * (y2 - y1));
    double denominator = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

    return (numerator.abs() / denominator) * 111000; // 🔥 미터(m) 단위 변환
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
    _addToSearchHistory(address);
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

  //총 거리(km) 표시
  void _showTotalDistance(int distanceInMeters) {
    setState(() {
      _calculatedDistance = distanceInMeters / 1000;  // m → km 변환
    });

    if (_mapController == null || _start == null) return;
    // 지도 컨트롤러 또는 시작 위치가 없으면 함수 종료

    _mapController!.addOverlay(
        NMarker(
          id: 'distance_marker', // 마커의 고유 ID
          position: _start!, // 마커를 표시할 위치 ( 출발지 )
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
                  // 🔥 입력 중일 때만 최근 검색 기록 표시
                  if (_isSearching && _searchHistory.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            '최근 검색 기록',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            itemCount: _searchHistory.length,
                            itemBuilder: (context, index) {
                              final historyItem = _searchHistory[index];
                              return ListTile(
                                title: Text(historyItem),
                                leading: const Icon(Icons.history),
                                onTap: () => _onAddressSelected(historyItem),
                              );
                            },
                          ),
                        ),
                      ],
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
                  DropdownButton<double>(
                    value: _selectedDistance,
                    hint: const Text('달릴 거리 선택 (km)'),
                    items: List.generate(10, (index) {
                      final distance = (index + 1).toDouble();
                      return DropdownMenuItem<double>(
                        value: distance,
                        child: Text('${distance.toStringAsFixed(1)} km'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _selectedDistance = value;
                      });
                    },
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

                      final totalDistance = _selectedDistance! * 1000;
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
              child: Stack(
                children: [
                  NaverMap(
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
              if (_isLoading)  // 🔥 로딩 인디케이터 표시
                Container(
                  color: Colors.black45, // 반투명 배경
                  child: const Center(
                    child: CircularProgressIndicator(), // 로딩 애니메이션
                  ),
                ),
            ],
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