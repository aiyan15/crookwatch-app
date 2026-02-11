import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DangerMap extends StatefulWidget {
  const DangerMap({super.key});

  @override
  State<DangerMap> createState() => _DangerMapState();
}

class _DangerMapState extends State<DangerMap> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Marker> _dangerMarkers = [];
  LatLng _mapCenter = LatLng(23.8103, 90.4125); // Dhaka
  double _zoom = 13.0;
  Position? _currentPosition;
  // --- severity logic ---
  final double _dangerRadiusMeters = 100; // how far to group reports

  Map<String, dynamic> _getSeverity(
    LatLng point,
    List<QueryDocumentSnapshot> docs,
  ) {
    final now = DateTime.now();
    int count = 0;

    for (var doc in docs) {
      final ts = (doc['timestamp'] as Timestamp?)?.toDate();
      if (ts == null) continue;

      // ignore old markers (>3 days)
      if (now.difference(ts) > const Duration(days: 3)) continue;

      final lat = doc['latitude'] as double;
      final lon = doc['longitude'] as double;
      final distance = Distance().as(LengthUnit.Meter, LatLng(lat, lon), point);

      if (distance <= _dangerRadiusMeters) count++;
    }

    Color color;
    double size;

    if (count >= 20) {
      color = Colors.red; // high danger
      size = 50;
    } else if (count >= 10) {
      color = Colors.yellow; // medium danger
      size = 40;
    } else {
      color = Colors.grey; // default
      size = 30;
    }

    return {'color': color, 'size': size, 'count': count};
  }

  void getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() => _currentPosition = position);

    _mapController.move(LatLng(position.latitude, position.longitude), _zoom);
  }

  @override
  @override
  void initState() {
    super.initState();
    _loadDangerMarkers();
    getUserLocation();
  }

  /// Fetch danger points from Firebase
  /// Fetch danger points from Firebase
  void _loadDangerMarkers() {
    FirebaseFirestore.instance.collection('danger_zones').snapshots().listen((
      snapshot,
    ) {
      final now = DateTime.now();
      List<Marker> newMarkers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) continue;

        // keep only last 2 hours
        if (now.difference(ts) > const Duration(hours: 2)) continue;

        final lat = data['latitude'] as double;
        final lon = data['longitude'] as double;
        final description = data['description'] ?? 'Danger';
        final point = LatLng(lat, lon);

        // 🔥 Count how many reports are within dangerRadius
        int count = 0;
        for (var other in snapshot.docs) {
          final ts2 = (other['timestamp'] as Timestamp?)?.toDate();
          if (ts2 == null) continue;
          if (now.difference(ts2) > const Duration(hours: 2)) continue;

          final olat = other['latitude'] as double;
          final olon = other['longitude'] as double;
          final distance = Distance().as(
            LengthUnit.Meter,
            LatLng(olat, olon),
            point,
          );
          if (distance <= _dangerRadiusMeters) count++;
        }

        // 🔥 Decide severity color + size
        Color color;
        double size;
        if (count >= 20) {
          color = Colors.red;
          size = 50;
        } else if (count >= 10) {
          color = Colors.yellow;
          size = 40;
        } else {
          color = Colors.grey;
          size = 30;
        }

        newMarkers.add(
          Marker(
            point: point,
            width: size,
            height: size,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Danger'),
                    content: Text(description),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(Icons.warning, color: color, size: size),
            ),
          ),
        );
      }

      setState(() => _dangerMarkers = newMarkers);
    });
  }

  /// Search locations using Nominatim restricted to Bangladesh
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&countrycodes=BD&format=json&addressdetails=1&limit=5";
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'FlutterMapApp (yourname@example.com)'},
    );

    if (response.statusCode == 200) {
      final List results = json.decode(response.body);
      setState(() {
        _searchResults = results.map((place) {
          return {
            'display_name': place['display_name'],
            'lat': double.parse(place['lat']),
            'lon': double.parse(place['lon']),
          };
        }).toList();
      });
    }
  }

  /// Move map to selected location
  void _goToLocation(double lat, double lon) {
    setState(() {
      _mapCenter = LatLng(lat, lon);
      _zoom = 15.0;
      _searchResults.clear();
      _searchController.text = '';
    });
    _mapController.move(_mapCenter, _zoom);
  }

  /// Add danger marker manually (you can hook to a button later)
  void _addDangerPoint(String description) {
    final user = FirebaseAuth.instance.currentUser; // ✅ get current user
    if (user == null) {
      Get.snackbar("Error", "You must be logged in to report danger.");
      return;
    }
    final newMarker = Marker(
      point: _mapCenter,
      width: 40,
      height: 40,
      child: Icon(Icons.warning, color: Colors.red, size: 40),
    );
    setState(() {
      _dangerMarkers.add(newMarker);
    });

    // Push to Firestore
    FirebaseFirestore.instance.collection('danger_zones').add({
      'latitude': _mapCenter.latitude,
      'longitude': _mapCenter.longitude,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Danger Map")),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Ask user for danger description
          String? dangerText = await showDialog<String>(
            context: context,
            builder: (context) {
              TextEditingController controller = TextEditingController();
              return AlertDialog(
                title: Text('Report Danger'),
                content: TextField(
                  controller: controller,
                  decoration: InputDecoration(hintText: 'Describe the danger'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), // Cancel
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: Text('Add'),
                  ),
                ],
              );
            },
          );

          if (dangerText != null && dangerText.isNotEmpty) {
            _addDangerPoint(dangerText); // pass description
          }
        },
        child: const Icon(Icons.add_location_alt),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _zoom,
              onTap: (tapPosition, point) async {
                // Ask user for danger description
                String? dangerText = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    TextEditingController controller = TextEditingController();
                    return AlertDialog(
                      title: Text('Report Danger'),
                      content: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Describe the danger',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context), // Cancel
                          child: Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          child: Text('Add'),
                        ),
                      ],
                    );
                  },
                );

                if (dangerText != null && dangerText.isNotEmpty) {
                  // Save to Firestore
                  FirebaseFirestore.instance.collection('danger_zones').add({
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                    'description': dangerText,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  // Update local state to show immediately
                  setState(() {
                    _dangerMarkers.add(
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Danger'),
                                content: Text(dangerText),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Icon(
                            Icons.warning,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ),
                    );
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName:
                    "CrookWatchApp/1.0 (ebolachan2233@gmail.com)",
              ),
              MarkerLayer(
                markers: [
                  ..._dangerMarkers, // <-- existing danger markers
                  if (_currentPosition !=
                      null) // <-- only if location is available
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search location...',
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    onChanged: _searchLocation,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Colors.black26),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(result['display_name']),
                          onTap: () =>
                              _goToLocation(result['lat'], result['lon']),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
