import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Coloca o teu token Mapbox AQUI
  MapboxOptions.setAccessToken("sk.eyJ1IjoicnVpdWEiLCJhIjoiY200bXM4czU5MDBwZDJrcjJsZW9qNzVjOCJ9.TlDHWxGJe7rdI03udVud3w");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapa Teste',
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

  void _onMapCreated(MapboxMap controller) {
    mapboxMap = controller;
    print('Mapa criado com sucesso!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapa")),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(-9.1393, 38.7223)), // Lisboa
          zoom: 12.0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
