import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  await _initialize();
  runApp(const NaverMapApp());
}

// 지도 초기화하기
Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(
      clientId: 'rz7lsxe3oo',     // 클라이언트 ID 설정
      onAuthFailed: (e) => log("네이버맵 인증오류 : $e", name: "onAuthFailed")
  );
}

class NaverMapApp extends StatefulWidget {
  const NaverMapApp({super.key});

  @override
  State<NaverMapApp> createState() => _NaverMapAppState();
}

class _NaverMapAppState extends State<NaverMapApp> {

  @override
  void initState() {
    super.initState();
    _permission();
  }

  @override
  Widget build(BuildContext context) {
    // NaverMapController 객체의 비동기 작업 완료를 나타내는 Completer 생성
    final Completer<NaverMapController> mapControllerCompleter = Completer();

    return MaterialApp(
      home: Scaffold(
        body: NaverMap(
          options: const NaverMapViewOptions(
            indoorEnable: true,             // 실내 맵 사용 가능 여부 설정
            locationButtonEnable: true,    // 위치 버튼 표시 여부 설정
          ),
          onMapReady: (controller) async {                // 지도 준비 완료 시 호출되는 콜백 함수
            mapControllerCompleter.complete(controller);  // Completer에 지도 컨트롤러 완료 신호 전송
            log("onMapReady", name: "onMapReady");

            final marker = NMarker(
              id: 'test',
              position:
                const NLatLng(37.506932467450326, 127.05578661133796));
            final marker1 = NMarker(
              id: 'test1',
              position:
                const NLatLng(37.606932467450326, 127.05578661133796));
            controller.addOverlayAll({marker, marker1});
            controller.setLocationTrackingMode(NLocationTrackingMode.follow);

            final onMarkerInfoWindow =
                NInfoWindow.onMarker(id: marker.info.id, text: "멋쟁이 사자처럼");
            marker.openInfoWindow(onMarkerInfoWindow);
            //경로선 추가
            //_addPathOverlay(controller);
          },
        ),
      ),
    );
  }
}



void _addPathOverlay(NaverMapController controller) {
  // 경로 좌표 설정
  final pathCoordinates = [
    NLatLng(37.57152, 126.97714),
    NLatLng(37.56607, 126.98268),
    NLatLng(37.56445, 126.97707),
    NLatLng(37.55855, 126.97822),
  ];

  // PathOverlay 생성
  final pathOverlay = NPolylineOverlay(
    id: 'path_1',
    coords: pathCoordinates, // 경로 좌표 추가
    color: Colors.red,            // 경로선 색상 설정
    width: 5,                     // 경로선 두께 설정
  );

  // 지도 위에 경로선 추가
  controller.addOverlay(pathOverlay);
}

void _permission() async {
  var status = await Permission.location.status;
  if (status.isGranted) {
    //print('허락됨');
  } else if (status.isDenied) {
    //print('거절됨');
    Permission.location.request();   // 현재 거절된 상태니 팝업창 띄워달라는 코드
  }
}
