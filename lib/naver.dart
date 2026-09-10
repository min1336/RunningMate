import 'dart:async'; // 비동기 작업 (Future, Stream) 처리
import 'dart:convert'; // JSON 데이터 인코딩 및 디코딩
import 'dart:math'; // 수학적 계산 (랜덤 값, 삼각 함수 등)

import 'package:http/http.dart' as http; // HTTP 요청 처리
import 'package:flutter/material.dart'; // Flutter UI 구성
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 네이버 지도 SDK 사용
import 'package:permission_handler/permission_handler.dart';
import 'package:run1220/running_screen.dart'; // 권한 요청 관리
import 'countdown.dart'; // 🔥 countdown.dart 임포트

class NaverMapApp extends StatefulWidget {
  const NaverMapApp({super.key}); // StatefulWidget 생성자

  @override
  State<NaverMapApp> createState() => _NaverMapAppState(); // 상태 관리 클래스 반환
}

class _NaverMapAppState extends State<NaverMapApp> {
  NaverMapController? _mapController; // 네이버 지도 컨트롤러
  final TextEditingController _startController =
      TextEditingController(); // 출발지 입력 필드 컨트롤러
  List<Map<String, String>> _suggestedAddresses = []; // 자동완성된 주소 목록

  List<NLatLng> _routePath = []; // 🔥 실제 도로 경로 데이터를 저장할 변수 추가
  NLatLng? _start; // 출발지 좌표
  List<NLatLng> _waypoints = []; // 경유지 좌표 목록
  double _calculatedDistance = 0.0; // 계산된 총 거리 (km 단위)
  bool _isLoading = false; // 로딩 상태 플래그
  String? _selectedDistance; // 선택한 거리 (km)

  // ✅ 주소 자동완성 결과 선택 시 검색 기록에 추가
  void _onAddressSelected(String address) {
    _startController.text = address;
    setState(() {
      _suggestedAddresses.clear();
    });
  }

  // 🔽 HTML 태그 제거 (자동완성 결과에서 불필요한 태그 제거)
  String _removeHtmlTags(String text) {
    final regex = RegExp(r'<[^>]*>'); // HTML 태그를 찾는 정규식
    return text.replaceAll(regex, '').trim(); // 태그 제거 후 문자열 반환
  }

  // 🔽 네이버 검색 API 호출 (주소 자동완성)
  Future<void> _getSuggestions(String query) async {
    if (query.isEmpty) {
      // 입력값이 비어 있으면
      setState(() {
        _suggestedAddresses.clear(); // 추천 주소 초기화
      });
      return;
    }

    const clientId = 'SuuXcENvj8j80WSDEPRe'; // 자동완성 api
    const clientSecret = '1KARXNrW1q'; // 자동완성 api secret

    final url =
        'https://openapi.naver.com/v1/search/local.json?query=$query&display=5'; // API 호출 URL

    final response = await http.get(Uri.parse(url), headers: {
      'X-Naver-Client-Id': clientId, // 인증 헤더
      'X-Naver-Client-Secret': clientSecret,
    });

    if (response.statusCode == 200) {
      // 성공적인 응답 처리
      final data = jsonDecode(response.body); // JSON 디코딩
      final items = data['items'] as List<dynamic>; // 장소 데이터 추출

      setState(() {
        _suggestedAddresses = items.map<Map<String, String>>((item) {
          return {
            'place': _removeHtmlTags(item['title'] ?? '장소 이름 없음'), // 장소 이름
            'address': item['roadAddress'] ??
                item['jibunAddress'] ??
                '주소 정보 없음', // 주소 정보
          };
        }).toList();
      });
    }
  }

  // 🔽 지도 경로 그리기
  void _drawRoute(Map<String, dynamic> routeData) {
    if (_mapController == null) return; // 지도 컨트롤러가 초기화되지 않았으면 반환

    final List<NLatLng> polylineCoordinates = []; // 경로 좌표 목록 초기화
    final route = routeData['route']['traavoidcaronly'][0]; // 경로 데이터 추출
    final path = route['path']; // 경로의 경로점 목록

    for (var coord in path) {
      // 경로점 순회
      polylineCoordinates.add(NLatLng(coord[1], coord[0])); // 좌표 추가
    }

    setState(() {
      _routePath = polylineCoordinates; // 🔥 경로 데이터를 변수에 저장
    });

    _mapController!.addOverlay(NPathOverlay(
      id: 'full_route', // 오버레이 ID
      color: Colors.lightGreen, // 경로 색상
      width: 8, // 경로 선 두께
      coords: _routePath, // 경로 좌표
      patternImage: NOverlayImage.fromAssetImage("assets/images/pattern.jpg"),
      patternInterval: 20,
    ));
  }

  Future<List<NLatLng>> _generateWaypoints(NLatLng start, double totalDistance,
      {int? seed}) async {
    const int numberOfWaypoints = 3; // 경유지 개수
    final Random random =
        seed != null ? Random(seed) : Random(); // 랜덤 값 생성기 ( 시드값으로 랜덤 반복 방지 )
    final List<NLatLng> waypoints = []; // 경유지 좌표 리스트

    for (int i = 1; i < numberOfWaypoints; i++) {
      final double angle = random.nextDouble() * 2 * pi; // 임의의 방향 ( 0~360도 )
      final double distance = (totalDistance / numberOfWaypoints) *
          (0.8 + random.nextDouble() * 0.4);
      // 경유지 간 거리 계산 ( 거리 범위 다양화 : 총 거리의 약 0.8 ~ 1.2배 )

      final NLatLng waypoint =
          await _calculateWaypoint(start, distance, angle); // 새로운 경유지 좌표 계산
      waypoints.add(waypoint); // 경유지 리스트에 추가
    }

    return waypoints; // 생성된 경유지 리스트 반환
  }

  Future<List<NLatLng>> optimizeWaypoints(List<NLatLng> waypoints) async {
    if (waypoints.isEmpty) return waypoints; // 경유지가 없으면 그대로 반환

    List<int> bestOrder =
        List.generate(waypoints.length, (index) => index); // 기본 순서 생성
    double bestDistance =
        _calculateTotalDistance(waypoints, bestOrder); // 초기 경로 거리 계산

    bool improved = true; // 최적화 여부 플래그
    while (improved) {
      // 최적화 반복
      improved = false; // 개선 상태 초기화
      for (int i = 1; i < waypoints.length - 1; i++) {
        // 모든 경유지 쌍 반복
        for (int j = i + 1; j < waypoints.length; j++) {
          List<int> newOrder = List.from(bestOrder); // 새로운 순서 생성
          newOrder.setRange(
              i, j + 1, bestOrder.sublist(i, j + 1).reversed); // 경유지 순서 뒤집기
          double newDistance =
              _calculateTotalDistance(waypoints, newOrder); // 새 경로 거리 계산
          if (newDistance < bestDistance) {
            // 새로운 경로가 더 짧으면
            bestDistance = newDistance; // 최적 거리 갱신
            bestOrder = newOrder; // 최적 순서 갱신
            improved = true; // 개선 여부 업데이트
          }
        }
      }
    }

    return bestOrder
        .map((index) => waypoints[index])
        .toList(); // 최적화된 순서에 따라 경유지 반환
  }

  double _calculateTotalDistance(List<NLatLng> waypoints, List<int> order) {
    double totalDistance = 0.0; // 총 거리 초기화
    for (int i = 0; i < order.length - 1; i++) {
      // 경유지 쌍 반복
      totalDistance +=
          _calculateDistance(waypoints[order[i]], waypoints[order[i + 1]]);
      // 두 점 간 거리 계산 후 합산
    }
    return totalDistance; // 총 거리 반환
  }

  double _calculateDistance(NLatLng point1, NLatLng point2) {
    const earthRadius = 6371000.0; // 지구 반지름 (미터)
    final dLat = _degreesToRadians(point2.latitude - point1.latitude); // 위도 차이
    final dLon =
        _degreesToRadians(point2.longitude - point1.longitude); // 경도 차이
    final a = pow(sin(dLat / 2), 2) +
        cos(_degreesToRadians(point1.latitude)) *
            cos(_degreesToRadians(point2.latitude)) *
            pow(sin(dLon / 2), 2);
    // 구면 좌표 거리 계산
    final c = 2 * atan2(sqrt(a), sqrt(1 - a)); // 중심 각도
    return earthRadius * c; // 거리 반환
  }

  double _degreesToRadians(double degree) {
    return degree * pi / 180; // 각도를 라디안으로 반환
  }

  Future<NLatLng> _calculateWaypoint(
      NLatLng start, double distance, double angle) async {
    const earthRadius = 6371000.0; // 지구 반지름
    final deltaLat = (distance / earthRadius) * cos(angle); // 위도 변화량
    final deltaLon =
        (distance / (earthRadius * cos(start.latitude * pi / 180))) *
            sin(angle); // 경도 변화량

    final newLat = start.latitude + (deltaLat * 180 / pi); // 새로운 위도
    final newLon = start.longitude + (deltaLon * 180 / pi); // 새로운 경도

    return NLatLng(newLat, newLon); // 새로운 좌표 반환
  }

  Future<NLatLng> getLocation(String address) async {
    const clientId = 'rz7lsxe3oo'; // 네이버 클라이언트 ID
    const clientSecret =
        'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg'; // 네이버 클라이언트 secret ID
    final url =
        'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=${Uri.encodeComponent(address)}';
    // 주소를 기반으로 좌표를 반환하는 API 호출 URL

    final response = await http.get(Uri.parse(url), headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId, // 인증 헤더
      'X-NCP-APIGW-API-KEY': clientSecret, // 인증 헤더
    });

    if (response.statusCode == 200) {
      // 응답 성공
      final data = jsonDecode(response.body); // JSON 데이터 파싱
      if (data['addresses'] == null || data['addresses'].isEmpty) {
        // 주소 정보가 없으면 예외 처리
        throw Exception('주소를 찾을 수 없습니다.');
      }
      final lat = double.parse(data['addresses'][0]['y']); // 위도
      final lon = double.parse(data['addresses'][0]['x']); // 경도
      return NLatLng(lat, lon); // 좌표 반환
    } else {
      throw Exception('위치 정보를 불러오지 못했습니다.'); // API 호출 실패 시 예외 발생
    }
  }

// 시작 위치로 카메라 이동
  Future<void> _moveCameraToStart() async {
    if (_mapController != null && _start != null) {
      // 지도 컨트롤러와 시작 위치가 초기화된 경우에만 실행
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(
          target: _start!, // 카메라를 이동시킬 목표 위치 ( 출발지 )
          zoom: 15, // 적당한 확대 수준
        ),
      );
    }
  }

// ⭐ 지도 위에 총 거리(km) 표시
  // ⭐ 지도 위에 총 거리(km) 표시 (수정 버전)
  void _showTotalDistance(int distanceInMeters) {
    setState(() {
      _calculatedDistance = distanceInMeters / 1000; // m → km 변환
    });

    if (_mapController == null || _start == null) return;
    // 지도 컨트롤러 또는 시작 위치가 없으면 함수 종료

    _mapController!.addOverlay(NMarker(
      id: 'distance_marker', // 마커의 고유 ID
      position: _start!, // 마커를 표시할 위치 ( 출발지 )
    ));
  }

// _getDirections 함수 수정: 경유지 마커 추가
  Future<void> _getDirections() async {
    if (_mapController == null) return;
    // 지도 컨트롤러가 초기화 되지 않았으면 함수 종료

    await _moveCameraToStart();
    // 카메라를 출발지로 이동

    // 네이버지도 api 클라이언트 정보
    const clientId = 'rz7lsxe3oo';
    const clientSecret = 'DAozcTRgFuEJzSX9hPrxQNkYl5M2hCnHEkzh1SBg';

    // 경유지 좌표를 URL 파라미터 형식으로 변환
    final waypointsParam = _waypoints
        .sublist(0, _waypoints.length - 1) // 마지막 경유지를 제외
        .map((point) => '${point.longitude},${point.latitude}') // 좌표를 문자열료 변환
        .join('|'); // 좌표간 구분

    // 네이버지도 경로 API URL 구성
    final url = 'https://naveropenapi.apigw.ntruss.com/map-direction/v1/driving'
        '?start=${_start!.longitude},${_start!.latitude}' // 출발지 좌표
        '&goal=${_start!.longitude},${_start!.latitude}' // 도착지 좌표 ( 출발지와 동일 )
        '&waypoints=$waypointsParam' // 경유지 좌표
        '&option=traavoidcaronly'; // 교통체증 회피

    // API 요청 보내기
    final response = await http.get(Uri.parse(url), headers: {
      'X-NCP-APIGW-API-KEY-ID': clientId,
      'X-NCP-APIGW-API-KEY': clientSecret,
    });

    if (response.statusCode == 200) {
      // 응답 성공
      final data = jsonDecode(response.body); // 응답 데이터 JSON 디코딩
      _drawRoute(data); // 경로 그리기

      // ✅ trafast → tracomfort로 변경
      final totalDistance =
          data['route']['traavoidcaronly'][0]['summary']['distance'];
      // 경로의 총 거리 추출
      _showTotalDistance(totalDistance); // 표시
    }
  }

  @override
  void initState() {
    super.initState();
    _permission(); // 기존 위치 권한 요청
  }

  void _permission() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 50,
      left: 16,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: NaverMap(
                  options: const NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(37.5665, 126.9780),
                      zoom: 10,
                    ),
                    locationButtonEnable: false,
                    logoClickEnable: false,
                  ),
                  onMapReady: (controller) {
                    _mapController = controller;
                  },
                ),
              ),
              Positioned(
                top: 50,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildBackButton(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: TextField(
                              controller: _startController,
                              decoration: InputDecoration(
                                hintText: '출발지 주소 입력',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _startController.clear();
                                    setState(() {
                                      _suggestedAddresses.clear();
                                    });
                                  },
                                ),
                              ),
                              onChanged: _getSuggestions,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_suggestedAddresses.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        padding:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _suggestedAddresses.length,
                            itemBuilder: (context, index) {
                              final place =
                                  _suggestedAddresses[index]['place']!;
                              final address =
                                  _suggestedAddresses[index]['address']!;

                              return ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: place,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '\n$address',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
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
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDistance,
                          hint: const Text('러닝 모드 선택'),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          items: ['초급', '중급', '고급'].map((level) {
                            return DropdownMenuItem<String>(
                              value: level,
                              child: Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(level),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDistance = value;
                            });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '${_calculatedDistance.toStringAsFixed(2)} km',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // 버튼을 포함하는 컨테이너 추가
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Row(
                    children: [
                      // 길찾기 버튼
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () async {
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    if (_selectedDistance == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('달릴 거리를 선택해 주세요.')),
                                      );
                                      return;
                                    }

                                    double minDistance, maxDistance;
                                    switch (_selectedDistance) {
                                      case '초급':
                                        minDistance = 500;
                                        maxDistance = 2500;
                                        break;
                                      case '중급':
                                        minDistance = 2500;
                                        maxDistance = 4500;
                                        break;
                                      case '고급':
                                        minDistance = 4500;
                                        maxDistance = 7000;
                                        break;
                                      default:
                                        minDistance = 0;
                                        maxDistance = 0;
                                    }

                                    final totalDistance =
                                        (minDistance + maxDistance) / 2;
                                    _start = await getLocation(
                                        _startController.text);

                                    int retryCount = 0;
                                    const int maxRetries = 10;
                                    bool isRouteFound = false;

                                    while (retryCount < maxRetries) {
                                      final waypoints =
                                          await _generateWaypoints(
                                              _start!, totalDistance / 2,
                                              seed: DateTime.now()
                                                  .millisecondsSinceEpoch);
                                      _waypoints =
                                          await optimizeWaypoints(waypoints);

                                      await _getDirections();

                                      final calculatedDistance =
                                          _calculatedDistance *
                                              1000; // km → m 변환

                                      if (calculatedDistance >= minDistance &&
                                          calculatedDistance <= maxDistance) {
                                        isRouteFound = true;
                                        break;
                                      } else {
                                        retryCount++;
                                      }
                                    }

                                    if (!isRouteFound) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                '❗ 최적의 경로를 찾지 못했습니다.\n다시 시도해 주세요.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('오류 발생: $e')),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  }
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800], // 왼쪽 버튼 회색
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(0),
                                bottomLeft: Radius.circular(0),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.list, color: Colors.white),
                                const SizedBox(width: 8),
                                const Text(
                                  '경로탐색',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 달리기 시작 버튼
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_routePath.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CountdownScreen(
                                    onCountdownComplete: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RunningScreen(
                                            roadPath: _routePath,
                                            startLocation: _start!,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("먼저 경로를 추천받아야 합니다.")),
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red, // 오른쪽 버튼 파란색
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(0),
                                bottomRight: Radius.circular(0),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.directions_run,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                const Text(
                                  '안내시작',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoading)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
