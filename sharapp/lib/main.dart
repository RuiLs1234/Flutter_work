import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';


void main() => runApp(const Sharapp());

class Sharapp extends StatelessWidget {
  const Sharapp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sharapp GPS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? mapboxMap;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  void _requestLocationPermission() async {
    // Handle permissions here
  }

  // Single onMapCreated definition
  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        puckBearing: PuckBearing.HEADING,
        showAccuracyRing: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sharapp Map')),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,  // Fixed reference
        styleUri: MapboxStyles.MAPBOX_STREETS,
        cameraOptions: CameraOptions(
          center: Point(
            coordinates: Position(-77.0339, 38.9072),
          ),  // Direct Point instance
          zoom: 14.0,
        ),
      ),
    );
  }
}