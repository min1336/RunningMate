import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarathonCalendarScreen extends StatefulWidget {
  const MarathonCalendarScreen({super.key});

  @override
  State<MarathonCalendarScreen> createState() => _MarathonCalendarScreenState();
}

class _MarathonCalendarScreenState extends State<MarathonCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _marathonEvents = {};

  @override
  void initState() {
    super.initState();
    _fetchMarathons();
  }

  Future<void> _fetchMarathons() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance.collection('marathons').get();
    final Map<DateTime, List<Map<String, dynamic>>> eventMap = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      if (!participants.contains(uid)) continue; // 🔥 참가자 아니면 스킵

      final String dateStr = data['date'];
      try {
        final date = _parseDate(dateStr);
        if (!eventMap.containsKey(date)) eventMap[date] = [];
        eventMap[date]!.add({...data, 'id': doc.id});
      } catch (_) {}
    }

    setState(() {
      _marathonEvents = eventMap;
    });
  }

  DateTime _parseDate(String str) {
    // "2025년 5월 10일" → DateTime
    final parts = str.replaceAll('일', '').split(RegExp(r'[년월]')).map((e) => e.trim()).toList();
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _marathonEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏃 마라톤 일정')),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2026, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            eventLoader: _getEventsForDay,
          ),
          const SizedBox(height: 12),
          if (_selectedDay != null)
            ..._getEventsForDay(_selectedDay!).map((m) => ListTile(
              title: Text(m['title']),
              subtitle: Text(m['location']),
              leading: const Icon(Icons.flag),
            )),
        ],
      ),
    );
  }
}
