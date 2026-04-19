import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
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
  static const double _scannerDialogHeight = 420;

  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  GoogleSignInAccount? _currentUser;
  String _statusMessage = "Presiona 'Iniciar sesión' para comenzar";
  bool _isLoading = false;
  XFile? _selectedPhoto;
  PlatformFile? _selectedPdf;
  bool _scannerOpen = false;

  final String folderId = "1FHUvS5YGNwlvLha5Ir-_kS7w8PpOsCfQ";

  bool get _hasFilesToUpload => _selectedPhoto != null || _selectedPdf != null;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    setState(() {
      _selectedPhoto = null;
      _selectedPdf = null;
    });
    _updateStatus("Sesión cerrada");
  }

  Future<void> _pickPhoto() async {
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
        setState(() {
          _selectedPhoto = image;
        });
        _updateStatus("✅ Foto lista para subir: ${image.name}");
      }
    } catch (e) {
      _updateStatus("❌ Error al tomar foto: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
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
        setState(() {
          _selectedPdf = result.files.single;
        });
        _updateStatus("✅ PDF listo para subir: ${result.files.single.name}");
      }
    } catch (e) {
      _updateStatus("❌ Error al seleccionar archivo: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFile(
    drive.DriveApi driveApi, {
    required String filePath,
    required String fileName,
    required String contentType,
  }) async {
    final file = File(filePath);
    final media = drive.Media(
      file.openRead(),
      await file.length(),
      contentType: contentType,
    );

    final driveFile = drive.File()
      ..name = fileName
      ..parents = [folderId];

    await driveApi.files.create(driveFile, uploadMedia: media);
  }

  Future<void> _uploadSelectedFiles() async {
    if (_currentUser == null) {
      _updateStatus("❌ Debes iniciar sesión primero");
      return;
    }

    if (!_hasFilesToUpload) {
      _updateStatus("❌ Primero selecciona una foto o un PDF");
      return;
    }

    GoogleAuthClient? client;

    try {
      setState(() => _isLoading = true);
      _updateStatus("☁️ Subiendo archivos a Google Drive...");

      final authHeaders = await _currentUser!.authHeaders;
      client = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(client);

      final uploadedNames = <String>[];

      if (_selectedPhoto != null) {
        await _uploadFile(
          driveApi,
          filePath: _selectedPhoto!.path,
          fileName: _selectedPhoto!.name,
          contentType: 'image/jpeg',
        );
        uploadedNames.add(_selectedPhoto!.name);
      }

      final pdfPath = _selectedPdf?.path;
      if (pdfPath != null) {
        await _uploadFile(
          driveApi,
          filePath: pdfPath,
          fileName: _selectedPdf!.name,
          contentType: 'application/pdf',
        );
        uploadedNames.add(_selectedPdf!.name);
      }

      setState(() {
        _selectedPhoto = null;
        _selectedPdf = null;
      });

      _updateStatus("✅ Subida completa: ${uploadedNames.join(', ')}");
    } catch (e) {
      _updateStatus("❌ Error al subir a Google Drive: $e");
    } finally {
      client?.close();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanBarcodeIntoSearch() async {
    if (_scannerOpen || _isLoading) {
      return;
    }

    setState(() => _scannerOpen = true);
    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    bool handledDetection = false;
    String? scannedCode;

    try {
      scannedCode = await showDialog<String>(
        context: context,
        builder: (context) {
          return Dialog(
            child: SizedBox(
              height: _scannerDialogHeight,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Escanear código",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text("Apunta la cámara al código de barras."),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: MobileScanner(
                      controller: scannerController,
                      onDetect: (capture) async {
                        if (handledDetection) {
                          return;
                        }

                        final barcode = capture.barcodes.firstOrNull?.rawValue;
                        if (barcode == null || barcode.trim().isEmpty) {
                          return;
                        }

                        handledDetection = true;
                        await scannerController.stop();
                        if (context.mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop(barcode.trim());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      await scannerController.dispose();
      if (mounted) {
        setState(() => _scannerOpen = false);
      } else {
        _scannerOpen = false;
      }
    }

    if (!mounted) {
      return;
    }

    if (scannedCode != null && scannedCode.isNotEmpty) {
      _searchController.text = scannedCode;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
      _updateStatus("✅ Código escaneado: $scannedCode");
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: "Buscar por código",
                          hintText: "Ej: 7501234567890",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _scanBarcodeIntoSearch,
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: "Escanear código de barras",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
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
                  onPressed: _isLoading ? null : _pickPhoto,
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
                  onPressed: _isLoading ? null : _pickFile,
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
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isLoading || !_hasFilesToUpload
                      ? null
                      : _uploadSelectedFiles,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("☁️ Subir a Google Drive"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
                  children: [
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
