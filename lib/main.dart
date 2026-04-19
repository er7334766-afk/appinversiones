import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inversiones Rodriguez - Bandejas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  GoogleSignInAccount? _currentUser;
  String _statusMessage = "Presiona 'Iniciar sesión' para comenzar";
  bool _isLoading = false;

  final String folderId = "1FHUvS5YGNwlvLha5Ir-_kS7w8PpOsCfQ";

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
      });
      if (_currentUser != null) {
        _updateStatus("✅ Sesión iniciada como ${_currentUser!.email}");
      }
    });
    _googleSignIn.signInSilently();
  }

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      _updateStatus("❌ Error al iniciar sesión: $error");
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.signOut();
    _updateStatus("Sesión cerrada");
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_currentUser == null) {
      _updateStatus("❌ Debes iniciar sesión primero");
      return;
    }

    try {
      setState(() => _isLoading = true);
      _updateStatus("📷 Tomando foto...");

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        _updateStatus("✅ Foto capturada: ${image.name}");
      }
    } catch (e) {
      _updateStatus("❌ Error al tomar foto: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_currentUser == null) {
      _updateStatus("❌ Debes iniciar sesión primero");
      return;
    }

    try {
      setState(() => _isLoading = true);
      _updateStatus("📂 Seleccionando archivo...");

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        _updateStatus("✅ Archivo seleccionado: ${result.files.single.name}");
      }
    } catch (e) {
      _updateStatus("❌ Error al seleccionar archivo: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          '📊 Inversiones Rodriguez',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_currentUser != null)
            TextButton(
              onPressed: _handleSignOut,
              child: const Text(
                "Cerrar sesión",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "📤 Subir archivos a Bandejas",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 40),
              if (_currentUser == null)
                ElevatedButton.icon(
                  onPressed: _handleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text("Iniciar sesión con Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickAndUploadPhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("📷 Tomar Foto"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickAndUploadFile,
                  icon: const Icon(Icons.file_present),
                  label: const Text("📄 Seleccionar PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
              if (_isLoading)
                Column(
                  children: const [
                    SizedBox(height: 40),
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Procesando..."),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
