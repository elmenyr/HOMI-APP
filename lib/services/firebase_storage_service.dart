import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an image file to Firebase Storage
  static Future<String?> uploadImage(
    File? imageFile, {
    Function(double)? onProgress,
    String folder = 'property_images',
  }) async {
    if (imageFile == null) {
      throw Exception('Image file cannot be null');
    }

    if (!imageFile.existsSync()) {
      throw Exception('Image file does not exist');
    }

    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to upload images');
    }

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final ref = _storage.ref().child('$folder/$fileName');
      
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/${path.extension(imageFile.path).substring(1)}'),
      );

      // Listen to upload progress if callback is provided
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Uploads multiple images to Firebase Storage
  static Future<List<Map<String, String>>> uploadMultipleImages(
    List<File> imageFiles,
    List<String> imageNames,
    {String folder = 'properties'}
  ) async {
    if (imageFiles.isEmpty || imageNames.isEmpty) {
      throw Exception('Image files and names lists cannot be empty');
    }
    if (imageFiles.length != imageNames.length) {
      throw Exception('Number of image files must match number of image names');
    }

    final uploadedImages = <Map<String, String>>[];
    
    for (var i = 0; i < imageFiles.length; i++) {
      try {
        final imageUrl = await uploadImage(imageFiles[i]);
        if (imageUrl != null) {
          uploadedImages.add({
            'name': imageNames[i],
            'url': imageUrl,
          });
        }
      } catch (e) {
        throw Exception('Failed to upload image ${imageNames[i]}: $e');
      }
    }

    return uploadedImages;
  }

  /// Deletes an image from Firebase Storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }
}