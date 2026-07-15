import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/location_service.dart';

class ArScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ArScreen({super.key, required this.cameras});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  CameraController? _cameraController;
  Position? _currentPosition;
  
  StreamSubscription? _compassSubscription;
  StreamSubscription? _gpsSubscription;

  double _deviceHeading = 0.0; 
  double _devicePitch = 0.0;   

  List<Note> _notes = [];
  Note? _selectedNote;

  // Gesture placement variables
  bool _isHoldingAndDragging = false;
  double _placementDistance = 0.0; 
  double _dragStartValue = 0.0;

  // Form Controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  IconData _selectedIcon = Icons.sticky_note_2;
  NotePrivacy _selectedPrivacy = NotePrivacy.public;
  NoteVisibility _selectedVisibility = NoteVisibility.always;

  final List<IconData> _availableIcons = [
    Icons.sticky_note_2,
    Icons.star,
    Icons.favorite,
    Icons.warning,
    Icons.info,
    Icons.home,
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initSensorsAndGPS();
    _loadPersistedNotes(); // Load saved notes on launch
  }

  void _initCamera() {
    if (widget.cameras.isEmpty) return;
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _cameraController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _initSensorsAndGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    _compassSubscription = magnetometerEventStream().listen((MagnetometerEvent event) {
      if (mounted) {
        double heading = math.atan2(event.y, event.x) * (180 / math.pi);
        if (heading < 0) heading += 360;
        setState(() {
          _deviceHeading = heading;
          _devicePitch = 0.0; 
        });
      }
    });
  }

  // --- LOCAL PERSISTENCE SYSTEM ---
  Future<void> _loadPersistedNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJsonString = prefs.getString('saved_nodity_notes');
    if (notesJsonString != null) {
      final List<dynamic> decodedList = jsonDecode(notesJsonString);
      setState(() {
        _notes = decodedList.map((item) => Note.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveNotesToDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> notesMapList = _notes.map((n) => n.toJson()).toList();
    await prefs.setString('saved_nodity_notes', jsonEncode(notesMapList));
  }

  // Opens dialog, then triggers the final save
  void _openNoteDetailsDialog(double targetDistance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      targetDistance == 0.0 
                          ? "Drop Note at Your Location" 
                          : "Drop Note at ${targetDistance.toStringAsFixed(1)}m",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Title",
                        labelStyle: TextStyle(color: Colors.grey),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                      ),
                    ),
                    TextField(
                      controller: _contentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Content",
                        labelStyle: TextStyle(color: Colors.grey),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Icon Styling:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _availableIcons.map((icon) {
                        return IconButton(
                          icon: Icon(icon, color: _selectedIcon == icon ? Colors.amberAccent : Colors.white),
                          onPressed: () => setModalState(() => _selectedIcon = icon),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Privacy Level:", style: TextStyle(color: Colors.grey)),
                        DropdownButton<NotePrivacy>(
                          value: _selectedPrivacy,
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          items: NotePrivacy.values.map((val) {
                            return DropdownMenuItem(value: val, child: Text(val.name.toUpperCase()));
                          }).toList(),
                          onChanged: (val) => setModalState(() => _selectedPrivacy = val!),
                        )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Visibility Limit:", style: TextStyle(color: Colors.grey)),
                        DropdownButton<NoteVisibility>(
                          value: _selectedVisibility,
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          items: NoteVisibility.values.map((val) {
                            return DropdownMenuItem(value: val, child: Text(val.name.toUpperCase()));
                          }).toList(),
                          onChanged: (val) => setModalState(() => _selectedVisibility = val!),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        _saveAndDropNote(targetDistance);
                        Navigator.pop(context);
                      },
                      child: const Text("Drop Note", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _saveAndDropNote(double targetDistance) {
    if (_currentPosition == null) return;

    // Calculate dynamic offset coordinates based on the direction when placed
    final offsetGps = LocationService.getOffsetCoordinate(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetDistance,
      _deviceHeading,
    );

    final newNote = Note(
      id: const Uuid().v4(),
      title: _titleController.text.isEmpty ? "Untitled Note" : _titleController.text,
      content: _contentController.text,
      latitude: offsetGps['latitude']!,
      longitude: offsetGps['longitude']!,
      altitude: _currentPosition!.altitude,
      icon: _selectedIcon,
      privacy: _selectedPrivacy,
      visibility: _selectedVisibility,
      distancePlaced: targetDistance,
    );

    setState(() {
      _notes.add(newNote);
      _selectedNote = null;
    });

    _saveNotesToDevice(); // Save updated list natively onto disk

    // Reset inputs
    _titleController.clear();
    _contentController.clear();
    _placementDistance = 0.0;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _compassSubscription?.cancel();
    _gpsSubscription?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        // TAP ANYWHERE: Place note at current location (distance = 0)
        onTap: () {
          if (!_isHoldingAndDragging) {
            _openNoteDetailsDialog(0.0);
          }
        },
        // HOLD AND DRAG: Adjust spatial distance live on drag
        onLongPressStart: (details) {
          setState(() {
            _isHoldingAndDragging = true;
            _dragStartValue = details.localPosition.dy;
            _placementDistance = 1.0; // Start placing at 1 meter away
          });
        },
        onLongPressMoveUpdate: (details) {
          double deltaY = _dragStartValue - details.localPosition.dy; // dragging UP increases distance
          setState(() {
            // Map dragging length to a scale of 1 to 100 meters
            _placementDistance = (deltaY / 5.0).clamp(1.0, 100.0);
          });
        },
        onLongPressEnd: (details) {
          setState(() {
            _isHoldingAndDragging = false;
          });
          _openNoteDetailsDialog(_placementDistance);
        },
        child: Stack(
          children: [
            // Background Camera Feed
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),

            // Spatial Coordinates Projection Layer
            if (_currentPosition != null)
              Positioned.fill(
                child: _buildArOverlay(size),
              ),

            // Targeting Reticle
            Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedNote != null ? Colors.amberAccent : Colors.white70,
                    width: 2.5,
                  ),
                ),
              ),
            ),

            // HUD UI: Realtime feedback when actively holding/dragging
            if (_isHoldingAndDragging)
              Positioned(
                top: size.height * 0.4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      "Dragging Distance: ${_placementDistance.toStringAsFixed(1)}m",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

            // Top HUD: Simple instructional text
            if (!_isHoldingAndDragging)
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Tap to drop here | Hold & Drag UP to drop at distance",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ),

            // HUD Card detailing active focused note
            if (_selectedNote != null && !_isHoldingAndDragging)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: _buildDetailsCard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArOverlay(Size size) {
    List<Widget> children = [];
    Note? highlightedNote;

    for (var note in _notes) {
      double bearing = LocationService.getBearing(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        note.latitude,
        note.longitude,
      );

      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        note.latitude,
        note.longitude,
      );

      if (note.visibility == NoteVisibility.closeOnly && distance > 15.0) continue;
      if (note.visibility == NoteVisibility.farOnly && distance <= 15.0) continue;

      double deltaHeading = bearing - _deviceHeading;
      if (deltaHeading > 180) deltaHeading -= 360;
      if (deltaHeading < -180) deltaHeading += 360;

      const double horizontalFOV = 60.0;
      const double verticalFOV = 60.0;

      if (deltaHeading.abs() < (horizontalFOV / 2)) {
        double x = (size.width / 2) + (deltaHeading / (horizontalFOV / 2)) * (size.width / 2);
        double y = (size.height / 2) - (_devicePitch / (verticalFOV / 2)) * (size.height / 2);

        double distFromCenter = math.sqrt(math.pow(x - (size.width / 2), 2) + math.pow(y - (size.height / 2), 2));
        bool isTargeted = distFromCenter < 45;

        if (isTargeted) {
          highlightedNote = note;
        }

        children.add(
          Positioned(
            left: x - 30,
            top: y - 30,
            child: AnimatedScale(
              scale: isTargeted ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isTargeted ? Colors.amberAccent : Colors.blueAccent.withOpacity(0.85),
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
                    ),
                    child: Icon(note.icon, color: isTargeted ? Colors.black : Colors.white, size: 28),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      "${distance.toStringAsFixed(1)}m",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedNote != highlightedNote) {
        setState(() {
          _selectedNote = highlightedNote;
        });
      }
    });

    return Stack(children: children);
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 10,
      color: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.amberAccent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_selectedNote!.icon, color: Colors.amberAccent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedNote!.title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedNote!.privacy.name.toUpperCase(),
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
            Text(
              _selectedNote!.content,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Lat: ${_selectedNote!.latitude.toStringAsFixed(5)}  |  Lon: ${_selectedNote!.longitude.toStringAsFixed(5)}",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                Text(
                  "Altitude: ${_selectedNote!.altitude.toStringAsFixed(1)}m",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}