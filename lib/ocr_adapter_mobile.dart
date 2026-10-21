import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrAdapter {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  Future<String?> captureText() async {
    final picked = await _picker.pickImage(source: ImageSource.camera,
        imageQuality: 92, preferredCameraDevice: CameraDevice.rear);
    if (picked == null) return null;
    final result = await _recognizer.processImage(InputImage.fromFilePath(picked.path));
    return result.text;
  }
  void close() { _recognizer.close(); }
}
