import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum RankingFilter { total, weekly, monthly }

class FriendRankingScreen extends StatefulWidget {
  const FriendRankingScreen({super.key});

  @override
  State<FriendRankingScreen> createState() => _FriendRankingScreenState();
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> showPushNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'rank_channel_id',
    '랭킹 알림',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails details =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    details,
  );
}

class _FriendRankingScreenState extends State<FriendRankingScreen> {
  List<Map<String, dynamic>> _friendRankings = [];
  bool _isLoading = true;
  RankingFilter _selectedFilter = RankingFilter.total;

  @override
  void initState() {
    super.initState();
    _loadRankingFromCache(); // 🔥 캐시 먼저 보여줌
    _setupRealtimeRanking(); // 실시간으로 최신 랭킹 갱신
  }

  Future<void> _saveRankingToCache(List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data);
    await prefs.setString('cachedRanking_${_selectedFilter.name}', jsonStr);
  }

  Future<void> _loadRankingFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('cachedRanking_${_selectedFilter.name}');
    if (jsonStr == null) return;

    final List<dynamic> parsed = jsonDecode(jsonStr);
    final cached = parsed.cast<Map<String, dynamic>>();

    await _detectRankChanges(cached); // ✅ 여기 추가
    await _saveRankingToCache(cached);

    setState(() {
      _friendRankings = cached;
      _isLoading = false;
    });
  }

  Future<void> _detectRankChanges(List<Map<String, dynamic>> rankings) async {
    final prefs = await SharedPreferences.getInstance();
    final previousData =
        prefs.getString('last_rank_list_${_selectedFilter.name}');

    final currentNicknames =
        rankings.map((e) => e['nickname'].toString()).toList();
    final meIndex = currentNicknames.indexWhere((e) => e.contains('(나)'));

    // 기존 기록이 있다면 비교
    if (previousData != null) {
      final List<dynamic> prevList = jsonDecode(previousData);
      final prevNicknames = prevList
          .cast<Map<String, dynamic>>()
          .map((e) => e['nickname'].toString())
          .toList();
      final prevMeIndex = prevNicknames.indexWhere((e) => e.contains('(나)'));

      for (int i = 0; i < prevNicknames.length; i++) {
        final prevFriend = prevNicknames[i];
        if (prevFriend.contains('(나)')) continue;

        final prevPos = prevNicknames.indexOf(prevFriend);
        final nowPos = currentNicknames.indexOf(prevFriend);

        if (prevPos > prevMeIndex && nowPos < meIndex) {
          // 친구가 나를 추월한 경우!
          await showPushNotification(
            "🏃 ${prevFriend.replaceAll('(나)', '')}님이 당신을 추월했습니다!",
            "${nowPos + 1}위로 올라섰어요!",
          );
        }
      }
    }

    // 랭킹 저장
    await prefs.setString(
        'last_rank_list_${_selectedFilter.name}', jsonEncode(rankings));
  }

  Future<void> _setupRealtimeRanking() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final friendUids = List<String>.from(userDoc['friends'] ?? []);
    friendUids.add(uid); // 나 자신 포함

    final Set<String> trackedUids = friendUids.toSet();

    FirebaseFirestore.instance
        .collection('run_records')
        .where('userId', whereIn: trackedUids.toList())
        .snapshots()
        .listen((_) => _loadFriendRanking());

    _loadFriendRanking();
  }

  Future<void> _saveMyRankingIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('my_last_rank_${_selectedFilter.name}', index);
  }

  Future<int?> _loadMyPreviousRank() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('my_last_rank_${_selectedFilter.name}');
  }

  Future<void> _loadFriendRanking() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final friendUids = List<String>.from(doc['friends'] ?? []);
    friendUids.add(uid); // 🔥 나 자신 포함
    final Set<String> uniqueUids = friendUids.toSet();
    final List<Map<String, dynamic>> rankings = [];
    await _saveRankingToCache(rankings);

    // 내 현재 순위 구하기
    final myIndex =
        rankings.indexWhere((r) => r['nickname'].toString().contains('(나)'));

    // 이전 순위 불러오기
    final previousIndex = await _loadMyPreviousRank();

    if (previousIndex != null && myIndex > previousIndex) {
      // 순위가 떨어졌을 때 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("😢 ${myIndex + 1}위로 떨어졌어요! 친구가 당신을 추월했습니다."),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    // 저장 (처음이든 변화든 무조건 저장)
    await _saveMyRankingIndex(myIndex);

    for (final userUid in uniqueUids) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .get();
      final nickname = userDoc['nickname'] ?? '알 수 없음';
      final records = await fetchRunRecordsForUser(userUid);
      final totalDistance = _calculateDistance(records, _selectedFilter);

      rankings.add({
        'uid': userUid,
        'nickname': userUid == uid ? '$nickname (나)' : nickname,
        'totalDistance': totalDistance,
      });
    }

    rankings.sort((a, b) => b['totalDistance'].compareTo(a['totalDistance']));
    setState(() {
      _friendRankings = rankings;
      _isLoading = false;
    });
  }

  double _calculateDistance(
      List<Map<String, dynamic>> records, RankingFilter filter) {
    return records.fold(0.0, (total, r) {
      final dateStr = r['date'];
      final distance = r['distance'] ?? 0.0;
      final recordDate = DateTime.tryParse(dateStr);
      if (recordDate == null) return total;

      if (filter == RankingFilter.weekly && !_isInWeek(recordDate)) {
        return total;
      }
      if (filter == RankingFilter.monthly && !_isInMonth(recordDate)) {
        return total;
      }

      return total + distance;
    });
  }

  bool _isInWeek(DateTime date) {
    final now = DateTime.now();
    return now.difference(date).inDays < 7;
  }

  bool _isInMonth(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year && now.month == date.month;
  }

  void _changeFilter(RankingFilter filter) {
    setState(() {
      _selectedFilter = filter;
      _isLoading = true;
    });
    _loadFriendRanking();
  }

  String getRankIcon(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '${index + 1}';
    }
  }

  Color? getRankTileColor(int index) {
    if (index == 0) return Colors.amber[100];
    if (index == 1) return Colors.grey[300];
    if (index == 2) return Colors.brown[200];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏆 친구 거리 랭킹")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: const Text("전체"),
                      selected: _selectedFilter == RankingFilter.total,
                      selectedColor: Colors.redAccent,
                      onSelected: (_) => _changeFilter(RankingFilter.total),
                    ),
                    ChoiceChip(
                      label: const Text("주간"),
                      selected: _selectedFilter == RankingFilter.weekly,
                      selectedColor: Colors.redAccent,
                      onSelected: (_) => _changeFilter(RankingFilter.weekly),
                    ),
                    ChoiceChip(
                      label: const Text("월간"),
                      selected: _selectedFilter == RankingFilter.monthly,
                      selectedColor: Colors.redAccent,
                      onSelected: (_) => _changeFilter(RankingFilter.monthly),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _friendRankings.isEmpty
                      ? const Center(child: Text("랭킹 데이터가 없습니다."))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _friendRankings.length,
                          itemBuilder: (context, index) {
                            final friend = _friendRankings[index];
                            final isMe = friend['nickname'].contains('(나)');
                            final distance =
                                friend['totalDistance'].toStringAsFixed(2);
                            final tileColor = getRankTileColor(index);

                            return Card(
                              color: tileColor,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    getRankIcon(index),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                title: Text(
                                  friend['nickname'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? Colors.red : Colors.black,
                                  ),
                                ),
                                trailing: Text(
                                  '$distance km',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
