import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<File> imageFiles = [];
  String selectedGraph = "distance"; // 🔹 기본값: 거리 그래프

  @override
  void initState() {
    super.initState();
    _loadImageFiles(_selectedDay);
  }


// 날짜 선택 시 해당 날짜의 이미지 불러오기
  void _loadImageFiles(DateTime date) async {
    final directory = await getApplicationDocumentsDirectory();
    final selectedDateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final files = await directory.list().toList();

    // 선택한 날짜와 일치하는 파일만 가져오기
    setState(() {
      imageFiles = files.where((file) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          if (fileName.endsWith(".png") && fileName.startsWith("run_")) {
            // 🔍 파일명에서 날짜 부분을 정확히 추출
            final regex = RegExp(r'run_(\d{4}-\d{2}-\d{2})');
            final match = regex.firstMatch(fileName);
            if (match != null) {
              final fileDate = match.group(1);
              return fileDate == selectedDateString;
            }
          }
        }
        return false;
      }).map((file) => file as File).toList();
    });

    print("🖼️ $selectedDateString의 이미지 파일 로딩 완료: ${imageFiles.length}개");
  }

  String _formatTitle(String fileName) {
    // 파일명 형식: run_YYYY-MM-DD_HH-MM-SS.png
    final timePart = fileName.split('_')[2]; // HH-MM-SS
    final hour = timePart.split('-')[0];
    final minute = timePart.split('-')[1];
    return "${hour}시 ${minute}분 러닝 기록";
  }


  void _showImageDialog(File imageFile) async {
    final summaryFile = File(imageFile.path.replaceAll('.png', '.json'));
    Map<String, dynamic>? summaryData;

    if (await summaryFile.exists()) {
      final jsonContent = await summaryFile.readAsString();
      summaryData = jsonDecode(jsonContent);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  // 이미지 클릭 시 확대 다이얼로그 실행
                  _showFullScreenImage(imageFile);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(imageFile, fit: BoxFit.cover, height: 250),
                ),
              ),

              const SizedBox(height: 20),

              // 🏃 러닝 정보 패널
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: summaryData != null
                      ? [
                    _buildInfoRow(Icons.directions_run, "거리", summaryData['distance']),
                    _buildInfoRow(Icons.access_time, "시간", summaryData['time']),
                    //_buildInfoRow(Icons.speed, "평균 페이스", summaryData['pace']),
                    _buildInfoRow(Icons.local_fire_department, "칼로리 소모", summaryData['calories']),
                  ]
                      : [
                    const Text(
                      "📂 해당 이미지의 요약 정보가 없습니다.",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 닫기 버튼
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("닫기", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🖼️ 이미지를 클릭하면 확대 다이얼로그 실행
  void _showFullScreenImage(File imageFile) {
    showDialog(
      context: context,
      barrierDismissible: true, // 🔍 바깥 클릭 시 닫힘 허용
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        insetPadding: const EdgeInsets.all(30), // 🔍 다이얼로그 가장자리 여백 추가
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: InteractiveViewer(
            maxScale: 5.0, // 최대 5배 확대
            child: Image.file(imageFile, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // 요약 정보 행 생성 함수
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 28),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // 이미지 삭제 함수
  Future<void> _deleteImage(File imageFile) async {
    if (await imageFile.exists()) {
      await imageFile.delete();
      setState(() {
        imageFiles.remove(imageFile);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imageFile.path.split('/').last} 삭제 완료!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지가 존재하지 않습니다.')),
      );
    }
  }

  void _showGraphModal() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() => selectedGraph = "distance");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedGraph == "distance" ? Colors.blue : Colors.grey,
                        ),
                        child: const Text("거리"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() => selectedGraph = "time");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedGraph == "time" ? Colors.green : Colors.grey,
                        ),
                        child: const Text("시간"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setModalState(() => selectedGraph = "calories");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedGraph == "calories" ? Colors.red : Colors.grey,
                        ),
                        child: const Text("칼로리"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildGraph(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGraph() {
    List<FlSpot> spots;
    Color graphColor;
    String graphTitle;

    // 🔹 선택된 그래프에 따라 데이터 변경
    switch (selectedGraph) {
      case "time":
        spots = _getTimeSpots();
        graphColor = Colors.green;
        graphTitle = "러닝 시간";
        break;
      case "calories":
        spots = _getCaloriesSpots();
        graphColor = Colors.red;
        graphTitle = "칼로리 소모";
        break;
      default:
        spots = _getDistanceSpots();
        graphColor = Colors.blue;
        graphTitle = "러닝 거리";
    }

    List<String> times = imageFiles.map((file) {
      String fileName = file.path.split('/').last;
      String timePart = fileName.split('_')[2]; // HH-MM-SS 추출
      List<String> timeParts = timePart.split('-');
      return "${timeParts[0]}:${timeParts[1]}"; // HH:MM 형식
    }).toList();

    return Column(
      children: [
        Text(
          graphTitle, // 🔹 그래프 제목 변경
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              minY: 0, // 🔹 최소값 지정하여 축 자동 변경 방지
              maxY: 300,
              gridData: FlGridData(show: false), // 🔹 눈금 제거
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= 0 && index < times.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            times[index], // X축에 HH:MM 표시
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  axisNameWidget: const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                  ),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: graphColor,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double parseTimeString(String timeString) {
    final regex = RegExp(r'(\d+)분\s*(\d+)초'); // "X분 Y초" 형태에서 숫자 추출
    final match = regex.firstMatch(timeString);

    if (match != null) {
      final minutes = int.parse(match.group(1)!); // 분
      final seconds = int.parse(match.group(2)!); // 초
      return (minutes * 60 + seconds).toDouble(); // 총 초로 변환
    }

    final secondsRegex = RegExp(r'(\d+)초'); // "Y초" 만 있는 경우
    final secondsMatch = secondsRegex.firstMatch(timeString);
    if (secondsMatch != null) {
      return double.parse(secondsMatch.group(1)!);
    }

    return 0.0; // 변환 실패 시 기본값
  }

  List<FlSpot> _getDistanceSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final summaryFile = File(imageFiles[i].path.replaceAll('.png', '.json'));
      if (summaryFile.existsSync()) {
        final jsonContent = jsonDecode(summaryFile.readAsStringSync());
        final distance = double.tryParse(jsonContent['distance'] ?? '0') ?? 0;
        spots.add(FlSpot(i.toDouble(), distance));
        print(jsonContent['distance']);
      }
    }
    return spots;
  }

  List<FlSpot> _getTimeSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final summaryFile = File(imageFiles[i].path.replaceAll('.png', '.json'));

      if (summaryFile.existsSync()) {
        final jsonContent = jsonDecode(summaryFile.readAsStringSync());

        print("📂 JSON 데이터 확인: $jsonContent");

        if (jsonContent.containsKey('time')) {
          try {
            final time = parseTimeString(jsonContent['time'].toString());
            print("⏳ 변환된 시간 데이터 (초): $time");
            spots.add(FlSpot(i.toDouble(), time));
          } catch (e) {
            print("❌ 시간 데이터 변환 오류: ${jsonContent['time']}");
          }
        }
      }
    }
    return spots;
  }

  List<FlSpot> _getCaloriesSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final summaryFile = File(imageFiles[i].path.replaceAll('.png', '.json'));
      if (summaryFile.existsSync()) {
        final jsonContent = jsonDecode(summaryFile.readAsStringSync());
        final calories = double.tryParse(jsonContent['calories'] ?? '0') ?? 0;
        spots.add(FlSpot(i.toDouble(), calories));
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('러닝 기록 캘린더', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart, color: Colors.white),
            onPressed: _showGraphModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // 🗓️ 스타일 변경된 TableCalendar 위젯
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadImageFiles(selectedDay);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: const TextStyle(color: Colors.redAccent),
                defaultTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                outsideDaysVisible: false,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 🖼️ 이미지 리스트 출력
          Expanded(
            child: imageFiles.isNotEmpty
                ? ListView.builder(
              itemCount: imageFiles.length,
              itemBuilder: (context, index) {
                final file = imageFiles[index];
                final fileName = file.path.split('/').last;

                final title = _formatTitle(fileName);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.directions_run, color: Colors.red),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _showImageDialog(file),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteImage(file),
                    ),
                  ),
                );
              },
            )
                : const Center(
              child: Text(
                "저장된 기록이 없습니다",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}