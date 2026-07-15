import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/ar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error retrieving system camera descriptions: $e');
  }
  
  runApp(NodityApp(cameras: cameras));
}

class NodityApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const NodityApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NODITY',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0D47A1),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.amberAccent,
        ),
      ),
      home: ArScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}
