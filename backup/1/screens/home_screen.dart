import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:parking_app/service/parking_api.dart'; // Import the API service

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late MapController _mapController;
  LatLng? _currentLocation;
  String _selectedTheme = 'Standard';
  List<Marker> _parkingMarkers = [];

  // Map themes with their respective tile URLs
  final Map<String, String> _mapThemes = {
    'Standard': 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Dark': 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
    'Light': 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _checkAndRequestLocationPermission();
    _loadCarparks(); // Fetch parking data
  }

  // Check and request location permission
  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission permanently denied')),
      );
      return;
    }
    _getCurrentLocation();
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation!, 15.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  // Load parking markers from API
  Future<void> _loadCarparks() async {
    try {
      final carparks = await ParkingApi.fetchCarparks();
      setState(() {
        _parkingMarkers = carparks.map((c) {
          return Marker(
            point: LatLng(c.latitude, c.longitude),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(c.nameTc),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("name: ${c.nameEn}"),
                        Text("Address: ${c.addressEn}"),
                        Text("Vacancy: ${c.vacancy ?? 'N/A'}"),
                        Text("Location: ${c.latitude}, ${c.longitude}"),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(
                Icons.local_parking,
                color: Colors.blue,
                size: 40,
              ),
            ),
          );
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading carparks: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Map'),
        actions: [
          DropdownButton<String>(
            value: _selectedTheme,
            items: _mapThemes.keys.map((String theme) {
              return DropdownMenuItem<String>(
                value: theme,
                child: Text(theme),
              );
            }).toList(),
            onChanged: (String? newTheme) {
              if (newTheme != null) {
                setState(() {
                  _selectedTheme = newTheme;
                });
              }
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation ?? const LatLng(22.3193, 114.1694), // Default to Hong Kong
          initialZoom: _currentLocation != null ? 15.0 : 11.0,
          minZoom: 0,
          maxZoom: 18,
          interactionOptions:
              const InteractionOptions(flags: ~InteractiveFlag.doubleTapZoom),
        ),
        children: [
          TileLayer(
            urlTemplate: _mapThemes[_selectedTheme]!,
            subdomains: const ['a', 'b', 'c'],
          ),
          CurrentLocationLayer(
            style: LocationMarkerStyle(
              markerSize: const Size(20, 20),
              markerDirection: MarkerDirection.heading,
              headingSectorColor: Colors.blue.withOpacity(0.5),
              headingSectorRadius: 60,
            ),
          ),
          MarkerLayer(markers: _parkingMarkers), // Parking markers from API
          const Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
            padding: EdgeInsets.all(20.0),
            child: TextSourceAttribution("OpenStreetMap contributors"),
          ),
        ),
      ],
        
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _getCurrentLocation();
          if (_currentLocation != null) {
            _mapController.move(_currentLocation!, 15.0);
          }
        },
        tooltip: 'Go to current location',
        child: const Icon(Icons.my_location),
      ),

    );
  }
}
