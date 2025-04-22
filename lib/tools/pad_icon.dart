import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Load the original image
  final originalImage = img.decodeImage(File('assets/icon/pulse_logo.png').readAsBytesSync())!;
  
  // Create a new image with padding (1024x1024)
  final paddedImage = img.Image(width: 1024, height: 1024);
  
  // Fill with transparent background
  img.fill(paddedImage, color: img.ColorRgba8(255, 255, 255, 0));
  
  // Calculate the size for the centered image (70% of the total size)
  final newSize = (1024 * 0.7).round();
  
  // Resize the original image
  final resizedImage = img.copyResize(
    originalImage,
    width: newSize,
    height: newSize,
    interpolation: img.Interpolation.cubic,
  );
  
  // Calculate the position to center the image
  final offset = ((1024 - newSize) / 2).round();
  
  // Composite the resized image onto the padded image
  img.compositeImage(
    paddedImage,
    resizedImage,
    dstX: offset,
    dstY: offset,
  );
  
  // Save the result
  File('assets/icon/pulse_logo_foreground.png').writeAsBytesSync(img.encodePng(paddedImage));
  
  print('Padded icon created at assets/icon/pulse_logo_foreground.png');
}
