import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ 러닝 기록 업로드 함수
Future<void> uploadRunRecord({
  required String userId,
  required String date,
  required double distance,
  required String time,
  required double calories,
  required List<Map<String, dynamic>> route,
  String? routeImageBase64,
}) async {
  try {
    await FirebaseFirestore.instance.collection('run_records').add({
      'userId': userId,
      'date': date,
      'distance': distance,
      'time': time,
      'calories': calories,
      'route': route,
      'routeImage': routeImageBase64,
      'createdAt': FieldValue.serverTimestamp(), // 정렬용
    });
    print("✅ 러닝 기록 업로드 완료");
  } catch (e) {
    print("❌ 업로드 실패: $e");
  }
}

/// ✅ 다른 사람의 러닝 기록 조회 함수
Future<List<Map<String, dynamic>>> fetchRunRecordsForUser(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('run_records')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  } catch (e) {
    print("❌ 기록 불러오기 실패: $e");
    return [];
  }
}
