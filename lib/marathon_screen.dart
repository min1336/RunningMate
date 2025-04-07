import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarathonScreen extends StatefulWidget {
  const MarathonScreen({super.key});

  @override
  State<MarathonScreen> createState() => _MarathonScreenState();
}

class _MarathonScreenState extends State<MarathonScreen> {
  final List<Map<String, dynamic>> marathonList = [
    {
      "title": "2025 서울 러닝 마라톤",
      "date": "2025년 5월 10일",
      "location": "여의도 한강공원",
      "distance": "5km / 10km / Half",
      "poster": "assets/images/marathon_poster.png",
    },
    {
      "title": "2025 부산 해운대 마라톤",
      "date": "2025년 6월 20일",
      "location": "해운대 해수욕장",
      "distance": "10km / Half / Full",
      "poster": "assets/images/busan_poster.png",
    },
    {
      "title": "2025 인천 송도 마라톤",
      "date": "2025년 8월 3일",
      "location": "송도 센트럴파크",
      "distance": "10km / Half",
      "poster": "assets/images/songdo_poster.png"
    },
    {
      "title": "2025 대구 도심 마라톤",
      "date": "2025년 9월 15일",
      "location": "대구 시내 일대",
      "distance": "5km / 10km",
      "poster": "assets/images/daegu_poster.png",
    },
  ];

  List<String> appliedTitles = [];

  @override
  void initState() {
    super.initState();
    _loadAppliedMarathons();
  }

  Future<void> _loadAppliedMarathons() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      appliedTitles = prefs.getStringList('appliedMarathons') ?? [];
    });
  }

  Future<void> _applyForMarathon(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      appliedTitles.add(title);
      prefs.setStringList('appliedMarathons', appliedTitles);
    });
  }

  Future<void> _cancelMarathon(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      appliedTitles.remove(title);
      prefs.setStringList('appliedMarathons', appliedTitles);
    });
  }

  void _showMarathonDialog(BuildContext context, Map<String, dynamic> marathon) {
    final now = DateTime.now();
    DateTime? parsedDate;
    try {
      parsedDate = DateFormat("yyyy년 M월 d일").parseStrict(marathon["date"]);
    } catch (e) {
      parsedDate = null;
    }
    final dDay = parsedDate != null ? parsedDate.difference(now).inDays : null;
    final bool isApplied = appliedTitles.contains(marathon['title']);

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Center(
                          child: dDay != null
                              ? Text(
                            "D-${dDay >= 0 ? dDay : 0}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          )
                              : const SizedBox(),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$value 기능은 준비 중입니다.')),
                          );
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(value: '공유하기', child: Text('공유하기')),
                          const PopupMenuItem(value: '대회규정', child: Text('대회규정')),
                          const PopupMenuItem(value: '공식사이트', child: Text('공식사이트')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(marathon["poster"], height: 200, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    marathon["title"],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(marathon["date"]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(marathon["location"]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.directions_run, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(marathon["distance"]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (isApplied) {
                        await _cancelMarathon(marathon["title"]);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("‘${marathon["title"]}’ 신청이 취소되었습니다.")),
                        );
                      } else {
                        await _applyForMarathon(marathon["title"]);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("‘${marathon["title"]}’ 신청 완료!")),
                        );
                      }
                    },
                    icon: Icon(
                      isApplied ? Icons.cancel : Icons.check_circle,
                      color: Colors.white,
                    ),
                    label: Text(isApplied ? "신청 취소하기" : "마라톤 신청하기"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApplied ? Colors.grey : Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appliedMarathons = marathonList.where((m) => appliedTitles.contains(m['title'])).toList();
    final availableMarathons = marathonList.where((m) => !appliedTitles.contains(m['title'])).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("🏁 마라톤 신청"), backgroundColor: Colors.redAccent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (appliedMarathons.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("✅ 참가중인 마라톤", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...appliedMarathons.map((m) => _buildMarathonCard(context, m, isApplied: true)),
                const SizedBox(height: 30),
              ],
            ),
          const Text("📋 신청 가능한 마라톤", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...availableMarathons.map((m) => _buildMarathonCard(context, m, isApplied: false)),
        ],
      ),
    );
  }

  Widget _buildMarathonCard(BuildContext context, Map<String, dynamic> marathon, {required bool isApplied}) {
    DateTime? parsedDate;
    try {
      parsedDate = DateFormat("yyyy년 M월 d일").parseStrict(marathon["date"]);
    } catch (e) {
      parsedDate = null;
    }
    final dDay = parsedDate != null ? parsedDate.difference(DateTime.now()).inDays : null;

    return GestureDetector(
      onTap: () => _showMarathonDialog(context, marathon),
      child: Card(
        color: isApplied ? Colors.grey[350] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(marathon["poster"], width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marathon["title"],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isApplied ? Colors.grey[700] : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${marathon["date"]} • ${marathon["location"]}",
                      style: TextStyle(
                        color: isApplied ? Colors.grey[600] : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (dDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dDay <= 3 ? Colors.red : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "D-${dDay >= 0 ? dDay : 0}",
                    style: TextStyle(
                      color: dDay <= 3 ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}