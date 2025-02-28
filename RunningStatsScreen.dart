import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class RunningStatsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> runData;

  const RunningStatsScreen({Key? key, required this.runData}) : super(key: key);

  @override
  _RunningStatsScreenState createState() => _RunningStatsScreenState();
}

class _RunningStatsScreenState extends State<RunningStatsScreen> {
  String _selectedMetric = "distance"; // 기본 값: 거리

  // ✅ 날짜별 데이터를 막대 그래프로 변환
  List<BarChartGroupData> _generateChartData() {
    return widget.runData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final value = data[_selectedMetric] as double;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Colors.redAccent,
            width: 16,
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("러닝 통계"),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          // ✅ "거리 / 시간 / 칼로리" 선택 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _metricButton("distance", "거리"),
              _metricButton("time", "시간"),
              _metricButton("calories", "칼로리"),
            ],
          ),

          // ✅ 그래프 표시
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxY(), // Y축 최대값 설정
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40, // Y축 간격 확보
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32, // X축 간격 확보
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < widget.runData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                widget.runData[index]["date"].substring(5), // "MM-DD" 형식
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: _generateChartData(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 선택한 지표에 따라 최대 Y축 값을 설정 (더 보기 쉽게 조정)
  double _getMaxY() {
    double maxValue = widget.runData
        .map((data) => data[_selectedMetric] as double)
        .fold(0.0, (prev, curr) => curr > prev ? curr : prev);
    return maxValue * 1.2; // 최대값의 120%로 설정하여 여유 공간 확보
  }

  // ✅ "거리 / 시간 / 칼로리" 버튼 위젯
  Widget _metricButton(String metric, String label) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedMetric = metric;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedMetric == metric ? Colors.redAccent : Colors.grey[300],
      ),
      child: Text(label, style: TextStyle(color: _selectedMetric == metric ? Colors.white : Colors.black)),
    );
  }
}
