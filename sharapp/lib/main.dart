import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart' as img_picker;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

  Position _cameraPosition = Position(-9.1393, 38.7223);
  double _cameraZoom = 12.0;
  
  // Novas variáveis para fotos
  List<Map<String, dynamic>> _savedPhotos = [];
  bool _showingSavedPhotos = false;

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
      debugPrint("Initial position error: $e");
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
      debugPrint("Location services disabled.");
      return;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.deniedForever) {
      debugPrint("Location permissions permanently denied.");
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
          pulsingColor: 0xFF2196F3,
          showAccuracyRing: true,
          puckBearing: PuckBearing.HEADING,
          puckBearingEnabled: true,
        ),
      );

      _startLocationUpdates();
      setState(() => _locationInitialized = true);
    } catch (e) {
      debugPrint("Error initializing location component: $e");
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
      debugPrint("Location update error: $e");
    }
  }

  Future<void> _takePhoto() async {
    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aguardando localização...')),
        );
      }
      return;
    }

    try {
      final img_picker.XFile? photo = await _picker.pickImage(
        source: img_picker.ImageSource.camera,
      );

      if (photo != null && mounted) {
        _showMessageDialog(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na câmera: $e')),
        );
      }
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
              final message = messageController.text.trim();
              
              if (message.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Digite uma mensagem')),
                  );
                }
                return;
              }

              if (mounted) {
                Navigator.pop(context);
                await _savePhotoRecord(photo, message);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePhotoRecord(img_picker.XFile photo, String message) async {
    if (!mounted) return;
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/photos');
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'photo_$timestamp.jpg';
      final File imageFile = File('${photosDir.path}/$filename');
      await imageFile.writeAsBytes(await photo.readAsBytes());

      final String imageUrl = await _uploadImageToImgur(imageFile);

      await FirebaseFirestore.instance.collection('photos').add({
        'imageUrl': imageUrl,
        'imagePath': imageFile.path,
        'message': message,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'fileSize': await imageFile.length(),
        'filename': filename,
        'uploadService': 'imgur',
      });

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto salva com sucesso no Imgur!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _uploadImageToImgur(File imageFile) async {
    try {
      const String clientId = '89528b049eb7c05';
      
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {
          'Authorization': 'Client-ID $clientId',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image,
          'type': 'base64',
          'title': 'Sharapp Photo',
          'description': 'Uploaded from Sharapp',
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final imageUrl = jsonResponse['data']['link'];
        
        debugPrint('Upload Imgur concluído: $imageUrl');
        return imageUrl;
      } else {
        throw Exception('Imgur upload failed: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('Erro no upload Imgur: $e');
      throw Exception('Falha no upload da imagem para Imgur: $e');
    }
  }

  // métodos para carregar e exibir fotos guardadas
  Future<void> _loadSavedPhotos() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('photos')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final List<Map<String, dynamic>> photos = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _savedPhotos = photos;
        _showingSavedPhotos = true;
      });

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      await _addPhotoMarkersToMap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${photos.length} fotos carregadas!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar fotos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addPhotoMarkersToMap() async {
    if (mapboxMap == null || _savedPhotos.isEmpty) return;

    try {
      for (int i = 0; i < _savedPhotos.length; i++) {
        final photo = _savedPhotos[i];
        final latitude = photo['latitude']?.toDouble();
        final longitude = photo['longitude']?.toDouble();

        if (latitude != null && longitude != null) {
          await mapboxMap?.annotations.createPointAnnotationManager().then((manager) async {
            await manager.create(
              PointAnnotationOptions(
                geometry: Point(coordinates: Position(longitude, latitude)),
                textField: '📷 ${i + 1}',
                textSize: 12.0,
                textColor: 0xFF1976D2,
                iconSize: 1.5,
              ),
            );
          });
        }
      }
      debugPrint('${_savedPhotos.length} marcadores adicionados ao mapa');
    } catch (e) {
      debugPrint('Erro ao adicionar marcadores: $e');
    }
  }

  void _clearSavedPhotos() {
    setState(() {
      _savedPhotos.clear();
      _showingSavedPhotos = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fotos removidas do mapa')),
    );
  }

  void _showPhotoDetails(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Foto - ${photo['filename'] ?? 'Sem nome'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo['imageUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  photo['imageUrl'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, size: 50),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text('📝 Mensagem: ${photo['message'] ?? 'Sem mensagem'}'),
            const SizedBox(height: 8),
            Text('📍 Localização: ${photo['latitude']?.toStringAsFixed(6)}, ${photo['longitude']?.toStringAsFixed(6)}'),
            const SizedBox(height: 8),
            if (photo['timestamp'] != null)
              Text('📅 Data: ${_formatTimestamp(photo['timestamp'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _flyToPhotoLocation(photo);
            },
            child: const Text('Ir para Local'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
      }
      return 'Data não disponível';
    } catch (e) {
      return 'Data não disponível';
    }
  }

  void _flyToPhotoLocation(Map<String, dynamic> photo) {
    final latitude = photo['latitude']?.toDouble();
    final longitude = photo['longitude']?.toDouble();

    if (latitude != null && longitude != null && mapboxMap != null) {
      mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(longitude, latitude)),
          zoom: 18.0,
        ),
        MapAnimationOptions(duration: 2000),
      );
    }
  }

  void _showPhotosList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '📷 Fotos Guardadas (${_savedPhotos.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _savedPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = _savedPhotos[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photo['imageUrl'] != null
                            ? NetworkImage(photo['imageUrl'])
                            : null,
                        child: photo['imageUrl'] == null ? const Icon(Icons.photo) : null,
                      ),
                      title: Text(photo['message'] ?? 'Sem mensagem'),
                      subtitle: Text(_formatTimestamp(photo['timestamp'])),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pop(context);
                        _showPhotoDetails(photo);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapa"),
        actions: [
          IconButton(
            onPressed: _showingSavedPhotos ? _clearSavedPhotos : _loadSavedPhotos,
            icon: Icon(_showingSavedPhotos ? Icons.clear : Icons.photo_library),
            tooltip: _showingSavedPhotos ? 'Limpar Fotos' : 'Carregar Fotos',
          ),
        ],
      ),
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

          if (_showingSavedPhotos && _savedPhotos.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📷 ${_savedPhotos.length} fotos no mapa',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_showingSavedPhotos && _savedPhotos.isNotEmpty)
            FloatingActionButton(
              onPressed: _showPhotosList,
              heroTag: "photosList",
              backgroundColor: Colors.purple,
              child: const Icon(Icons.list),
            ),
          const SizedBox(height: 16),
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
            heroTag: "myLocation",
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _takePhoto,
            heroTag: "camera",
            backgroundColor: Colors.amber,
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}