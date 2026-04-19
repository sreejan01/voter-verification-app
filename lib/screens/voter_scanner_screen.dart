import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'voter_details_screen.dart';

class VoterScannerScreen extends StatefulWidget {
  final String officerId;
  const VoterScannerScreen({super.key, required this.officerId});

  @override
  State<VoterScannerScreen> createState() => _VoterScannerScreenState();
}

class _VoterScannerScreenState extends State<VoterScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Position Voter ID card inside the frame';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) return;
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      setState(() => _statusMessage = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning...';
    });
    try {
      final XFile photo = await _cameraController!.takePicture();
      await _processImage(photo.path);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Capture failed. Try again.';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning...';
    });
    await _processImage(image.path);
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      final String fullText = recognizedText.text;
      final extracted = _extractVoterDetails(fullText);

      if (!mounted) return;

      if (extracted['voterId'] == null && extracted['name'] == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage =
              'Could not read card. Try again with better lighting.';
        });
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VoterDetailsScreen(
            extractedData: extracted,
            imagePath: imagePath,
            officerId: widget.officerId,
          ),
        ),
      ).then((_) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Position Voter ID card inside the frame';
        });
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Scan failed. Try again.';
      });
    }
  }

  Map<String, String?> _extractVoterDetails(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    String? voterId;
    String? name;
    String? dob;

    final voterIdRegex = RegExp(r'\b[A-Z]{3}[0-9]{7}\b');
    final voterIdMatch = voterIdRegex.firstMatch(text);
    if (voterIdMatch != null) voterId = voterIdMatch.group(0);

    final dobRegex = RegExp(r'\b(\d{2}[\/\-]\d{2}[\/\-]\d{4})\b');
    final dobMatch = dobRegex.firstMatch(text);
    if (dobMatch != null) dob = dobMatch.group(0);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('name') && i + 1 < lines.length) {
        final nextLine = lines[i + 1];
        if (!nextLine.toLowerCase().contains('name') &&
            nextLine.length > 2 &&
            !nextLine.contains(':')) {
          name = nextLine;
          break;
        }
        if (lines[i].contains(':')) {
          final parts = lines[i].split(':');
          if (parts.length > 1 && parts[1].trim().isNotEmpty) {
            name = parts[1].trim();
            break;
          }
        }
      }
    }

    return {'voterId': voterId, 'name': name, 'dob': dob, 'rawText': text};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isCameraInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Dark overlay with cutout
          Positioned.fill(child: CustomPaint(painter: _ScanOverlayPainter())),

          // Animated scan frame
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Container(
                  width: 300,
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(_pulseAnim.value),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      ..._buildCorners(),
                      if (_isProcessing)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.accent.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Title badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'SCAN VOTER ID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Flash
                  GestureDetector(
                    onTap: () async {
                      if (_cameraController == null) return;
                      final current = _cameraController!.value.flashMode;
                      await _cameraController!.setFlashMode(
                        current == FlashMode.off
                            ? FlashMode.torch
                            : FlashMode.off,
                      );
                      setState(() {});
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: Icon(
                        _cameraController?.value.flashMode == FlashMode.torch
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instruction text below frame
          Center(
            child: Transform.translate(
              offset: const Offset(0, 120),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 44),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery
                  GestureDetector(
                    onTap: _isProcessing ? null : _pickFromGallery,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.photo_library_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  // Capture
                  GestureDetector(
                    onTap: _isProcessing ? null : _captureAndScan,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProcessing ? Colors.grey : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2.5,
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: AppTheme.primary,
                              size: 30,
                            ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thickness = 3.0;
    const color = Colors.white;
    return [
      Positioned(
        top: 0,
        left: 0,
        child: _corner(size, thickness, color, top: true, left: true),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: _corner(size, thickness, color, top: true, left: false),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: _corner(size, thickness, color, top: false, left: true),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: _corner(size, thickness, color, top: false, left: false),
      ),
    ];
  }

  Widget _corner(
    double size,
    double thickness,
    Color color, {
    required bool top,
    required bool left,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          thickness: thickness,
          top: top,
          left: left,
        ),
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    const cutoutWidth = 300.0;
    const cutoutHeight = 190.0;
    final cutoutLeft = (size.width - cutoutWidth) / 2;
    final cutoutTop = (size.height - cutoutHeight) / 2;
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cutoutLeft, cutoutTop, cutoutWidth, cutoutHeight),
      const Radius.circular(12),
    );
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutoutRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top;
  final bool left;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
