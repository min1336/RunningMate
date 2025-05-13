import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<File> jsonFiles = [];
  Set<DateTime> _attendanceDays = {}; // ✅ 출석 도장 표시 관련

  @override
  void initState() {
    super.initState();
    _loadJsonFiles(_selectedDay);
    _loadAttendanceDays(); // ✅ 출석 도장 불러오기
  }

  void _loadJsonFiles(DateTime date) async {
    final directory = await getApplicationDocumentsDirectory();
    final selectedDateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final files = await directory.list().toList();

    setState(() {
      jsonFiles = files.where((file) {
        if (file is File && file.path.endsWith(".json") && file.path.contains("run_$selectedDateString")) {
          return true;
        }
        return false;
      }).map((e) => e as File).toList();
    });
  }

  Future<void> _loadAttendanceDays() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = await directory.list().toList();

    final Set<DateTime> attendance = {};

    for (final file in files) {
      if (file is File && file.path.endsWith(".json") && file.path.contains("run_")) {
        final name = file.uri.pathSegments.last;
        final datePart = name.split('_')[1]; // run_YYYY-MM-DD_HH-MM-SS.json
        final parts = datePart.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2]);
          if (year != null && month != null && day != null) {
            attendance.add(DateTime(year, month, day));
          }
        }
      }
    }

    setState(() {
      _attendanceDays = attendance;
    });
  }

  List<NLatLng> _extractRoutePath(Map<String, dynamic> json) {
    final raw = json['routePath'];
    if (raw == null || raw is! List) return [];
    return raw.map<NLatLng>((e) => NLatLng(e['lat'], e['lng'])).toList();
  }

  String _formatTitle(String fileName) {
    final timePart = fileName.split('_')[2]; // HH-MM-SS
    final hour = timePart.split('-')[0];
    final minute = timePart.split('-')[1];
    return "${hour}시 ${minute}분 러닝 기록";
  }

  void _showRecordDialog(File jsonFile) async {
    final jsonContent = await jsonFile.readAsString();
    final summaryData = jsonDecode(jsonContent);
    final routePath = _extractRoutePath(summaryData);

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
              SizedBox(
                height: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: routePath.isNotEmpty ? routePath.first : const NLatLng(37.5665, 126.9780),
                        zoom: 15,
                      ),
                    ),
                    onMapReady: (controller) {
                      if (routePath.isNotEmpty) {
                        controller.addOverlay(NPathOverlay(
                          id: 'calendar_path',
                          coords: routePath,
                          color: Colors.orange,
                          width: 6,
                        ));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.directions_run, "거리", summaryData['distance']),
                    _buildInfoRow(Icons.access_time, "시간", summaryData['time']),
                    _buildInfoRow(Icons.speed, "평균 페이스", summaryData['pace']),
                    _buildInfoRow(Icons.local_fire_department, "칼로리 소모", summaryData['calories']),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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

  void _deleteRecord(File jsonFile) async {
    if (await jsonFile.exists()) {
      await jsonFile.delete();
      setState(() {
        jsonFiles.remove(jsonFile);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${jsonFile.path.split('/').last} 삭제 완료!')),
      );
      _loadAttendanceDays(); // ✅ 삭제 후 출석 도장 갱신
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록이 존재하지 않습니다.')),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 28),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('러닝 기록 캘린더', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
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
                _loadJsonFiles(selectedDay);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.5), shape: BoxShape.circle),
                weekendTextStyle: const TextStyle(color: Colors.redAccent),
                defaultTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                outsideDaysVisible: false,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, _) {
                  final hasRecord = _attendanceDays.any((d) =>
                  d.year == date.year && d.month == date.month && d.day == date.day);
                  if (hasRecord) {
                    return Positioned(
                      bottom: 1,
                      child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: jsonFiles.isNotEmpty
                ? ListView.builder(
              itemCount: jsonFiles.length,
              itemBuilder: (context, index) {
                final file = jsonFiles[index];
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
                    onTap: () => _showRecordDialog(file),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRecord(file),
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
        ],
      ),
    );
  }
}
