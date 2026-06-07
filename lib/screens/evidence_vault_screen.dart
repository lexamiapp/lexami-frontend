import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/google_drive_service.dart';
import '../widgets/google_drive_picker.dart';
import '../utils/app_localizations.dart';
import '../widgets/app_drawer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:googleapis/drive/v3.dart' as drive;

class EvidenceVaultScreen extends StatefulWidget {
  const EvidenceVaultScreen({super.key});

  @override
  State<EvidenceVaultScreen> createState() => _EvidenceVaultScreenState();
}

class _EvidenceVaultScreenState extends State<EvidenceVaultScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Photos', 'Documents', 'Recordings', 'Other'];
  bool _isUploading = false;

  void _uploadFile() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Upload Evidence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildUploadOption(LucideIcons.camera, 'Camera', Colors.orange, () => _pickImage(ImageSource.camera)),
                _buildUploadOption(LucideIcons.image, 'Gallery', Colors.blue, () => _pickImage(ImageSource.gallery)),
                _buildUploadOption(LucideIcons.fileText, 'File', Colors.green, _pickFile),
                _buildUploadOption(LucideIcons.fileDigit, 'GDrive', Colors.red, _pickFromGoogleDrive),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      _processSelectedFile(pickedFile.name, 'Photos', pickedFile.path, await pickedFile.readAsBytes());
    }
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.single;
      _processSelectedFile(file.name, 'Documents', file.path ?? '', file.bytes ?? (kIsWeb ? null : await io.File(file.path!).readAsBytes()));
    }
  }

  void _pickFromGoogleDrive() async {
    final drive.File? file = await showModalBottomSheet<drive.File>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GoogleDrivePicker(),
    );

    if (file != null && file.id != null) {
      setState(() => _isUploading = true);
      try {
        final driveService = Provider.of<GoogleDriveService>(context, listen: false);
        final bytes = await driveService.downloadFile(file.id!);
        
        if (bytes != null) {
          _processSelectedFile(file.name ?? 'GDrive_File', 'Documents', '', bytes);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to download file from Google Drive')));
          setState(() => _isUploading = false);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isUploading = false);
      }
    }
  }

  void _processSelectedFile(String fileName, String category, String path, Uint8List? bytes) async {
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File processing failed (no data)')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      
      final result = await firestore.uploadVaultBytes(auth.currentUserId!, category, fileName, bytes);
      final downloadUrl = result['url'];
      final storagePath = result['path'];
      
      await firestore.saveEvidence(auth.currentUserId!, {
        'name': fileName,
        'category': category,
        'url': downloadUrl,
        'storagePath': storagePath,
        'type': fileName.split('.').last.toUpperCase(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('File uploaded to Evidence Vault!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      final msg = e.toString();
      final friendlyMsg = msg.contains('object-not-found')
          ? 'Upload failed: Firebase Storage rules are blocking this upload. Please check Storage Rules in Firebase Console.'
          : msg.contains('unauthorized') || msg.contains('permission-denied')
              ? 'Upload failed: You do not have permission. Please check Firebase Storage rules.'
              : 'Upload failed: $msg';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyMsg),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('evidence_vault') ?? 'Evidence Vault', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isUploading)
            const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildCategoryFilter(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: firestore.streamEvidence(auth.currentUserId!, category: _selectedCategory),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading evidence:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                final evidence = snapshot.data ?? [];
                if (evidence.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.folderOpen, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No evidence found in this category', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: evidence.length,
                  itemBuilder: (context, index) {
                    final item = evidence[index];
                    return _buildEvidenceCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadFile,
        label: const Text('Add Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(LucideIcons.plus),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evidence Vault',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.translate('categorize_evidence') ?? 'Categorize your court evidence securely.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = cat),
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue.shade700,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey.shade100,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEvidenceCard(Map<String, dynamic> item) {
    IconData icon;
    Color color;
    switch (item['category']) {
      case 'Photos':
        icon = LucideIcons.image;
        color = Colors.orange;
        break;
      case 'Documents':
        icon = LucideIcons.fileText;
        color = Colors.green;
        break;
      case 'Recordings':
        icon = LucideIcons.mic;
        color = Colors.purple;
        break;
      default:
        icon = LucideIcons.file;
        color = Colors.blue;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), 
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => _showEvidenceOptions(item),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: item['category'] == 'Photos' && item['url'] != null
                    ? Image.network(
                        item['url'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(color: color.withOpacity(0.05), child: Center(child: CircularProgressIndicator(color: color, strokeWidth: 2))),
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withOpacity(0.05),
                          child: Center(child: Icon(icon, color: color, size: 40)),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        color: color.withOpacity(0.05),
                        child: Center(child: Icon(icon, color: color, size: 40)),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'File',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['type'] ?? '',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          if (item.containsKey('storagePath') || item['category'] == 'Photos')
                             const Padding(
                               padding: EdgeInsets.only(right: 4),
                               child: Icon(LucideIcons.scanLine, size: 14, color: Colors.indigo),
                             ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent),
                            onPressed: () => _deleteEvidence(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEvidenceOptions(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item['name'] ?? 'Evidence', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(LucideIcons.eye, color: Colors.blue),
              title: const Text('View File'),
              onTap: () {
                Navigator.pop(context);
                _viewFile(item['url']);
              },
            ),
            if (item.containsKey('storagePath') || item['category'] == 'Photos')
              ListTile(
                leading: const Icon(LucideIcons.scanLine, color: Colors.indigo),
                title: const Text('View Extracted Text (OCR)'),
                subtitle: const Text('Read text content using Vision AI'),
                onTap: () {
                  Navigator.pop(context);
                  _viewExtractedText(item);
                },
              ),
             ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: const Text('Delete Permanently'),
              onTap: () {
                Navigator.pop(context);
                _deleteEvidence(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewFile(String? url) async {
    if (url != null) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  void _viewExtractedText(Map<String, dynamic> item) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final storagePath = item['storagePath'] as String?;
    
    // If old items don't have storagePath, warn user
    if (storagePath == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This file was uploaded before OCR was enabled.')));
       return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: StreamBuilder(
            stream: firestore.streamOcrResult(storagePath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing document structure...'),
                  ],
                ));
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.hourglass, size: 48, color: Colors.orange.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'Processing...', 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cloud Vision AI is currently extracting text from this image. \nThis usually takes 10-20 seconds.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              
              final data = snapshot.data!.data() as Map<String, dynamic>;
              // The extension usually puts result in 'text' key inside 'payload' or directly 'text'
              // The standard extension format often has 'text' at root or inside 'annotation'
              // Let's dump the likely fields.
              final text = data['text'] ?? data['extractedText'] ?? 'No text extracted.';

              return ListView(
                controller: controller,
                children: [
                   const Text('Extracted Content', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.indigo)),
                   const SizedBox(height: 4),
                   const Text('AI-Digitized Version', style: TextStyle(fontSize: 12, color: Colors.grey)),
                   const Divider(height: 32),
                   SelectableText(
                     text,
                     style: const TextStyle(fontSize: 14, height: 1.5),
                   ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _deleteEvidence(Map<String, dynamic> item) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Evidence?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      await firestore.deleteEvidence(item['id'], item['url']);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evidence deleted.')));
    }
  }
}
