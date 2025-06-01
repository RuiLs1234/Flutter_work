import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart' as img_picker;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await geo.Geolocator.requestPermission();

  MapboxOptions.setAccessToken(
    "sk.eyJ1IjoicnVpdWEiLCJhIjoiY200bXM4czU5MDBwZDJrcjJsZW9qNzVjOCJ9.TlDHWxGJe7rdI03udVud3w",
  );

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
  Timer? _locationTimer;
  geo.Position? _currentPosition;
  bool _locationInitialized = false;
  bool _hasInitialPosition = false;
  final img_picker.ImagePicker _picker = img_picker.ImagePicker();

  static final Position defaultPosition = Position(-9.1393, 38.7223);
  Position _cameraPosition = Position(-9.1393, 38.7223);
  double _cameraZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _getInitialPosition();
  }

  Future<void> _getInitialPosition() async {
    try {
      geo.Position? lastPosition = await geo.Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        _updateCameraPosition(lastPosition);
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 5));

      _updateCameraPosition(position);
    } catch (e) {
      print("Initial position error: $e");
      setState(() {
        _hasInitialPosition = true;
      });
    }
  }

  void _updateCameraPosition(geo.Position position) {
    setState(() {
      _cameraPosition = Position(position.longitude, position.latitude);
      _cameraZoom = 15.0;
      _hasInitialPosition = true;
      _currentPosition = position;
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services disabled.");
      return;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.deniedForever) {
      print("Location permissions permanently denied.");
    }
  }

  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;
    await Future.delayed(const Duration(milliseconds: 500));
    _initializeLocationComponent();
  }

  Future<void> _initializeLocationComponent() async {
    if (mapboxMap == null) return;

    try {
      await mapboxMap?.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: Colors.blue.value,
          showAccuracyRing: true,
          puckBearing: PuckBearing.HEADING,
          puckBearingEnabled: true,
        ),
      );

      _startLocationUpdates();
      setState(() => _locationInitialized = true);
    } catch (e) {
      print("Error initializing location component: $e");
    }
  }

  void _startLocationUpdates() {
    _updateLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.best,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Location update error: $e");
    }
  }

  Future<void> _takePhoto() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguardando localização...')),
      );
      return;
    }

    try {
      final img_picker.XFile? photo = await _picker.pickImage(
        source: img_picker.ImageSource.camera,
      );

      if (photo != null) {
        _showMessageDialog(photo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na câmera: $e')),
      );
    }
  }

  void _showMessageDialog(img_picker.XFile photo) {
    TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Mensagem'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: 'Digite sua mensagem',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Digite uma mensagem')),
                );
                return;
              }

              Navigator.pop(context);
              await _savePhotoRecord(photo, messageController.text);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePhotoRecord(img_picker.XFile photo, String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/photos');
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'photo_$timestamp.jpg';
      final File imageFile = File('${photosDir.path}/$filename');
      await imageFile.writeAsBytes(await photo.readAsBytes());

      await FirebaseFirestore.instance.collection('photos').add({
        'imagePath': imageFile.path, // path local (ou URL se usar Imgur/Firebase Storage)
        'message': message,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto salva com sucesso no Firestore!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar foto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapa")),
      body: Stack(
        children: [
          if (_hasInitialPosition)
            MapWidget(
              key: const ValueKey("mapWidget"),
              styleUri: MapboxStyles.MAPBOX_STREETS,
              cameraOptions: CameraOptions(
                center: Point(coordinates: _cameraPosition),
                zoom: _cameraZoom,
              ),
              onMapCreated: _onMapCreated,
            )
          else
            const Center(child: CircularProgressIndicator()),

          if (_hasInitialPosition && !_locationInitialized)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              if (_currentPosition != null) {
                mapboxMap?.flyTo(
                  CameraOptions(
                    center: Point(
                      coordinates: Position(
                        _currentPosition!.longitude,
                        _currentPosition!.latitude,
                      ),
                    ),
                    zoom: 15.0,
                  ),
                  MapAnimationOptions(duration: 1000),
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _takePhoto,
            backgroundColor: Colors.amber,
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}
