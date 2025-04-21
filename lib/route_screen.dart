import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'route_detail_screen.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  List<Map<String, dynamic>> _routes = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation().then((_) {
      _loadRoutes();
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _loadRoutes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shared_routes')
        .orderBy('createdAt', descending: true)
        .get();

    final List<Map<String, dynamic>> loaded = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawRoute = data['route'];

      if (rawRoute != null && rawRoute is List && rawRoute.isNotEmpty && _currentPosition != null) {
        final start = rawRoute.first;
        final distanceToStart = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          start['lat'],
          start['lng'],
        );

        data['distanceToStart'] = distanceToStart;
      }

      loaded.add(data);
    }

    setState(() => _routes = loaded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏃 추천 루트 공유'), backgroundColor: Colors.redAccent),
      body: _routes.isEmpty
          ? const Center(child: Text('공유된 경로가 없습니다.'))
          : ListView.builder(
        itemCount: _routes.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final route = _routes[index];
          final name = route['title'] ?? '이름 없음';
          final distance = route['distance'] ?? 0;
          final time = route['estimatedTime'] ?? '알 수 없음';
          final rating = route['rating'] ?? 0.0;
          final ratingCount = route['ratingCount'] ?? 0;
          final distanceToStart = route['distanceToStart'];

          final distanceDisplay = (distanceToStart != null)
              ? '${(distanceToStart / 1000).toStringAsFixed(1)} km 앞'
              : '--- 앞';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 4,
            child: ListTile(
              leading: const Icon(Icons.directions, color: Colors.red),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$distance m ($time)'),
                  Row(
                    children: [
                      Text('${rating.toStringAsFixed(1)} ★'),
                      const SizedBox(width: 10),
                      Text('▸ $distanceDisplay', style: const TextStyle(color: Colors.blue)),
                    ],
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RouteDetailScreen(route: route),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
