import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/google_drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleDrivePicker extends StatefulWidget {
  const GoogleDrivePicker({super.key});

  @override
  State<GoogleDrivePicker> createState() => _GoogleDrivePickerState();
}

class _GoogleDrivePickerState extends State<GoogleDrivePicker> {
  bool _isLoading = true;
  List<drive.File> _files = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final driveService = Provider.of<GoogleDriveService>(context, listen: false);
    
    try {
      if (!driveService.isSignedIn) {
        final account = await driveService.signIn();
        if (account == null) {
          if (mounted) Navigator.pop(context);
          return;
        }
      }

      final files = await driveService.listFiles();
      if (mounted) {
        setState(() {
          _files = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(LucideIcons.fileDigit, color: Colors.blue),
                const SizedBox(width: 12),
                const Text('Google Drive', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text('Error: $_error')))
          else if (_files.isEmpty)
            const Expanded(child: Center(child: Text('No files found in your Drive')))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return ListTile(
                    leading: file.thumbnailLink != null 
                        ? Image.network(file.thumbnailLink!, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(LucideIcons.file))
                        : const Icon(LucideIcons.file),
                    title: Text(file.name ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(file.mimeType ?? 'Unknown type', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16),
                    onTap: () async {
                      Navigator.pop(context, file);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
