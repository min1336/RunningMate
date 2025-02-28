import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'RunningStatsScreen.dart';

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

  List<Map<String, dynamic>> _runData = [];

  @override
  void initState() {
    super.initState();
    _loadImageFiles(_selectedDay);
  }

  void _loadRunData() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = await directory.list().toList();

    List<Map<String, dynamic>> tempRunData = [];

    for (var file in files) {
      if (file is File && file.path.endsWith('.json')) {
        if (await file.exists()) {  // ✅ 파일 존재 여부 확인
          try {
            final jsonContent = await file.readAsString(); // ✅ 비동기 방식으로 변경
            if (jsonContent.isNotEmpty) { // ✅ JSON이 비어있는 경우 대비
              final jsonData = jsonDecode(jsonContent);
              tempRunData.add({
                "date": file.path.split('/').last.substring(4, 14), // "run_YYYY-MM-DD.json"에서 날짜 추출
                "distance": double.tryParse(jsonData["distance"]?.toString() ?? "0") ?? 0.0,
                "time": double.tryParse(jsonData["time"]?.toString() ?? "0") ?? 0.0,
                "calories": double.tryParse(jsonData["calories"]?.toString() ?? "0") ?? 0.0,
              });
            }
          } catch (e) {
            print("JSON 파일 오류: ${file.path}, 오류 내용: $e");
          }
        } else {
          print("파일이 존재하지 않습니다: ${file.path}");
        }
      }
    }

    setState(() {
      _runData = tempRunData;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('러닝 기록 캘린더', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        actions: [
          // ✅ 추가: 그래프 보기 버튼
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RunningStatsScreen(runData: _runData),
                ),
              );
            },
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
