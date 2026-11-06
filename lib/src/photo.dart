import 'dart:convert';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'theme.dart';

const int _maxUploadBytes = 8 * 1024 * 1024;
const String kDefaultPhoto = '#EC8B10';

const List<String> kProfileColors = <String>[
  '#1B1C1E',
  '#B2A4A1',
  '#EC8B10',
  '#EB4315',
  '#253D5B',
  '#192532',
];

bool isStoredPhoto(String raw) => raw.startsWith('data:image/jpeg;base64,');

Uint8List? storedPhotoBytes(String raw) {
  if (!isStoredPhoto(raw)) {
    return null;
  }
  try {
    return base64Decode(raw.substring(raw.indexOf(',') + 1));
  } on FormatException {
    return null;
  }
}

String encodeProfileJpeg(Uint8List cropped) {
  final img.Image? decoded = img.decodeImage(cropped);
  if (decoded == null) {
    throw StateError('Could not read that photo.');
  }
  final img.Image square = img.copyResizeCropSquare(decoded, size: 512);
  Uint8List jpg = img.encodeJpg(square, quality: 82);
  if (jpg.length > 280000) {
    jpg = img.encodeJpg(square, quality: 58);
  }
  return 'data:image/jpeg;base64,${base64Encode(jpg)}';
}

/// Gallery or camera, then a square crop. Returns null when the person cancels.
Future<String?> captureProfilePhoto(
  BuildContext context,
  ImageSource source,
) async {
  final ImagePicker picker = ImagePicker();
  final XFile? file;
  try {
    file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
  } on PlatformException catch (error) {
    throw StateError(_accessMessage(source, error));
  }
  if (file == null || !context.mounted) {
    return null;
  }
  final Uint8List bytes = await file.readAsBytes();
  _assertImage(bytes);
  if (!context.mounted) {
    return null;
  }
  final Uint8List? cropped = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute<Uint8List>(
      builder: (BuildContext context) => CropPhotoPage(bytes: bytes),
    ),
  );
  if (cropped == null) {
    return null;
  }
  return encodeProfileJpeg(cropped);
}

void _assertImage(Uint8List bytes) {
  if (bytes.length > _maxUploadBytes) {
    throw StateError('Choose an image under 8 MB.');
  }
  if (img.decodeImage(bytes) == null) {
    throw StateError('Use a JPEG, PNG, or WebP photo.');
  }
}

String _accessMessage(ImageSource source, PlatformException error) {
  final String code = error.code.toLowerCase();
  if (code.contains('denied') || code.contains('access') || code.contains('permission')) {
    if (source == ImageSource.camera) {
      return 'Camera permission was denied. Allow the camera to take a profile photo.';
    }
    return 'Photo access was denied. Allow photos to choose a profile picture.';
  }
  return 'Could not open that photo.';
}

class CropPhotoPage extends StatefulWidget {
  const CropPhotoPage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<CropPhotoPage> createState() => _CropPhotoPageState();
}

class _CropPhotoPageState extends State<CropPhotoPage> {
  final CropController _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) {
      return;
    }
    if (result is CropSuccess) {
      Navigator.of(context).pop(result.croppedImage);
      return;
    }
    setState(() => _cropping = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not crop that photo.'),
        backgroundColor: kInk,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kInk,
      appBar: AppBar(
        backgroundColor: kInk,
        foregroundColor: kPaper,
        elevation: 0,
        title: const Text(
          'Crop photo',
          style: TextStyle(
            fontFamily: kDisplay,
            fontVariations: kReading,
            fontSize: 22,
            letterSpacing: 0.6,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Crop(
              image: widget.bytes,
              controller: _controller,
              aspectRatio: 1,
              withCircleUi: true,
              baseColor: kInk,
              maskColor: const Color(0xB3000000),
              onCropped: _onCropped,
              progressIndicator: const Center(
                child: CircularProgressIndicator(color: kPaper),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kMint,
                    foregroundColor: kInk,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _cropping
                      ? null
                      : () {
                          setState(() => _cropping = true);
                          _controller.crop();
                        },
                  child: Text(
                    _cropping ? 'Cropping' : 'Use photo',
                    style: const TextStyle(
                      fontFamily: kFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photo,
    required this.initials,
    required this.radius,
    this.onTap,
  });

  final String photo;
  final String initials;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = storedPhotoBytes(photo);
    final Color background = _fallbackColor(photo);
    final Color foreground = background.computeLuminance() < 0.45
        ? kPaper
        : kInk;
    final Widget face = CircleAvatar(
      radius: radius,
      backgroundColor: background,
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes != null
          ? null
          : Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                color: foreground,
                fontFamily: kDisplay,
                fontVariations: kReading,
                fontSize: radius * 0.72,
                letterSpacing: 0.4,
              ),
            ),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kLine, width: 2),
      ),
      child: onTap == null
          ? face
          : GestureDetector(onTap: onTap, child: face),
    );
  }
}

Color _fallbackColor(String raw) {
  String text = raw.trim();
  if (text.startsWith('#')) {
    text = text.substring(1);
  }
  if (text.length == 6) {
    text = 'FF$text';
  }
  final int? value = int.tryParse(text, radix: 16);
  if (value == null) {
    return kGold;
  }
  return Color(value);
}
