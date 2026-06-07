import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveReadonlyScope,
      'email',
    ],
  );

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      debugPrint('Google Sign-In Error: $error');
      return null;
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<List<drive.File>> listFiles() async {
    // Check if signed in, if not try silent sign in
    if (_googleSignIn.currentUser == null) {
      await _googleSignIn.signInSilently();
    }
    
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return [];

    final driveApi = drive.DriveApi(httpClient);
    final fileList = await driveApi.files.list(
      pageSize: 50,
      q: "mimeType != 'application/vnd.google-apps.folder' and trashed = false",
      $fields: "files(id, name, mimeType, webContentLink, thumbnailLink, size, iconLink, webViewLink)",
    );

    return fileList.files ?? [];
  }

  Future<Uint8List?> downloadFile(String fileId) async {
    if (_googleSignIn.currentUser == null) {
      await _googleSignIn.signInSilently();
    }

    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;

    final driveApi = drive.DriveApi(httpClient);
    
    try {
      final drive.File fileMetadata = await driveApi.files.get(fileId) as drive.File;
      
      // If it's a Google Doc/Sheet/Slide, we need to export it to PDF
      if (fileMetadata.mimeType?.startsWith('application/vnd.google-apps.') ?? false) {
        final drive.Media response = await driveApi.files.export(
          fileId, 
          'application/pdf', 
          downloadOptions: drive.DownloadOptions.fullMedia
        ) as drive.Media;
        
        final List<int> bytes = [];
        await for (var chunk in response.stream) {
          bytes.addAll(chunk);
        }
        return Uint8List.fromList(bytes);
      } else {
        // For binary files (PDF, JPEG, etc.), we get the media directly
        final drive.Media response = await driveApi.files.get(
          fileId, 
          downloadOptions: drive.DownloadOptions.fullMedia
        ) as drive.Media;
        
        final List<int> bytes = [];
        await for (var chunk in response.stream) {
          bytes.addAll(chunk);
        }
        return Uint8List.fromList(bytes);
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  bool get isSignedIn => _googleSignIn.currentUser != null;
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
