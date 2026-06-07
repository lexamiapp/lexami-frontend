import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/channel.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/media_service.dart';
import 'package:share_plus/share_plus.dart';

class ChannelFeedScreen extends StatefulWidget {
  final Channel channel;

  const ChannelFeedScreen({super.key, required this.channel});

  @override
  State<ChannelFeedScreen> createState() => _ChannelFeedScreenState();
}

class _ChannelFeedScreenState extends State<ChannelFeedScreen> {
  final TextEditingController _commentController = TextEditingController();

  void _showQrCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan to Join Space', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 2),
              ),
              child: QrImageView(
                data: "https://lexami.app/space/@${widget.channel.handle}",
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text('@${widget.channel.handle}', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Share this QR code with others so they can easily find and follow your space.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    final contentController = TextEditingController();
     io.File? selectedImage;
     Uint8List? selectedImageBytes;
     bool isUploading = false;
     double uploadProgress = 0.0;
     String statusMessage = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create Post', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'What\'s on your mind?', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                
                if (selectedImage != null)
                  Stack(
                    children: [
                       ClipRRect(
                        borderRadius: BorderRadius.circular(8), 
                        child: selectedImageBytes != null 
                          ? Image.memory(selectedImageBytes!, height: 150, width: double.infinity, fit: BoxFit.cover)
                          : (!kIsWeb && selectedImage != null ? Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover) : const SizedBox(height: 150))
                      ),
                      Positioned(
                        right: 8, top: 8,
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.x, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                     OutlinedButton.icon(
                       onPressed: () async {
                         final picker = ImagePicker();
                         final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            final bytes = await pickedFile.readAsBytes();
                            setModalState(() {
                              selectedImage = io.File(pickedFile.path);
                              selectedImageBytes = bytes;
                            });
                          }
                       },
                       icon: const Icon(LucideIcons.image, size: 18),
                       label: const Text('Add Image'),
                     ),
                     OutlinedButton.icon(
                       onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video upload coming soon!')));
                       },
                       icon: const Icon(LucideIcons.video, size: 18),
                       label: const Text('Add Video'),
                     ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isUploading ? null : () async {
                      if (contentController.text.trim().isEmpty && selectedImage == null) return;
                      
                      setModalState(() {
                        isUploading = true;
                        statusMessage = "Preparing thumbnail...";
                      });
                      
                      try {
                        final firestore = Provider.of<FirestoreService>(context, listen: false);
                        final auth = Provider.of<AuthService>(context, listen: false);
                        final channel = widget.channel;

                        final postId = DateTime.now().millisecondsSinceEpoch.toString();
                        String? uploadedMediaUrl;
                        String? thumbnailUrl;
                        
                        if (selectedImage != null) {
                          // 1. Thumbnail
                          final thumb = await MediaService.generateThumbnail(selectedImage!, 'image');
                           if (thumb != null) {
                             setModalState(() => statusMessage = "Uploading thumbnail...");
                             thumbnailUrl = await firestore.uploadChannelPostMedia(
                               channel.id, 
                               '${postId}_thumb', 
                               thumb,
                               bytes: kIsWeb ? await thumb.readAsBytes() : null,
                             );
                           }

                          // 2. Full-Res
                          setModalState(() => statusMessage = "Compressing image...");
                          final compressed = await MediaService.compressImage(selectedImage!);
                          
                          setModalState(() {
                            statusMessage = "Uploading high-res...";
                            uploadProgress = 0.0;
                          });

                           uploadedMediaUrl = await firestore.uploadChannelPostMedia(
                             channel.id, 
                             postId, 
                             compressed ?? selectedImage!,
                             bytes: compressed != null ? (kIsWeb ? await compressed.readAsBytes() : null) : selectedImageBytes,
                             onProgress: (p) => setModalState(() => uploadProgress = p),
                           );
                        }

                        final newPost = ChannelPost(
                          id: postId,
                          channelId: channel.id,
                          authorId: auth.currentUserId!,
                          authorName: channel.name, 
                          authorImage: channel.profileImageUrl,
                          content: contentController.text.trim(),
                          mediaUrl: uploadedMediaUrl,
                          thumbnailUrl: thumbnailUrl,
                          createdAt: DateTime.now(),
                        );

                        await firestore.createChannelPost(newPost);
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        setModalState(() => isUploading = false);
                      }
                    },
                    child: isUploading 
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(value: uploadProgress, color: Colors.white, backgroundColor: Colors.white24),
                            const SizedBox(height: 4),
                            Text(statusMessage, style: const TextStyle(fontSize: 10, color: Colors.white)),
                          ],
                        )
                      : const Text('POST'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCommentsSheet(ChannelPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Expanded(
                child: StreamBuilder<List<ChannelComment>>(
                  stream: Provider.of<FirestoreService>(context).streamChannelComments(post.channelId, post.id),
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                     final comments = snapshot.data!;
                     if (comments.isEmpty) return const Center(child: Text('No comments yet.'));
                     
                     return ListView.separated(
                       controller: scrollController,
                       padding: const EdgeInsets.all(16),
                       itemCount: comments.length,
                       separatorBuilder: (_, _) => const SizedBox(height: 16),
                       itemBuilder: (context, index) {
                         final comment = comments[index];
                         return Row(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             CircleAvatar(radius: 16, backgroundColor: Colors.grey.shade200, child: Text(comment.userName[0])),
                             const SizedBox(width: 12),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Row(
                                     children: [
                                       Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                       const SizedBox(width: 8),
                                       Text(timeago.format(comment.createdAt, locale: 'en_short'), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                     ],
                                   ),
                                   const SizedBox(height: 4),
                                   Text(comment.content, style: const TextStyle(fontSize: 14)),
                                 ],
                               ),
                             ),
                           ],
                         );
                       },
                     );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16, 
                  right: 16, 
                  top: 16, 
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () async {
                        if (_commentController.text.trim().isEmpty) return;
                        final firestore = Provider.of<FirestoreService>(context, listen: false);
                        final auth = Provider.of<AuthService>(context, listen: false);
                        
                        final profile = await firestore.getUserProfile(auth.currentUserId!);
                        final myChannel = await firestore.getChannelByOwner(auth.currentUserId!);
                        final isHidden = myChannel?.isHidden ?? false;
                        
                        final newComment = ChannelComment(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          postId: post.id,
                          userId: auth.currentUserId!,
                          userName: isHidden ? 'Anonymous' : (profile?.displayName ?? 'User'),
                          content: _commentController.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        
                        await firestore.addChannelComment(post.channelId, newComment);
                        _commentController.clear();
                      },
                      icon: const Icon(LucideIcons.send, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditChannelDialog() {
    final nameController = TextEditingController(text: widget.channel.name);
    final descController = TextEditingController(text: widget.channel.description);
    final linkController = TextEditingController(text: widget.channel.externalLinks.isNotEmpty ? widget.channel.externalLinks.first : '');
    io.File? selectedImage;
    Uint8List? selectedImageBytes;
    bool isUploading = false;
    bool isHidden = widget.channel.isHidden;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Space', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      setDialogState(() {
                        selectedImage = io.File(image.path);
                        selectedImageBytes = bytes;
                      });
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                       image: selectedImageBytes != null 
                        ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover)
                        : (selectedImage != null && !kIsWeb 
                            ? DecorationImage(image: FileImage(selectedImage!), fit: BoxFit.cover)
                            : (widget.channel.profileImageUrl != null 
                                ? DecorationImage(image: NetworkImage(widget.channel.profileImageUrl!), fit: BoxFit.cover)
                                : null)),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: (selectedImage == null && widget.channel.profileImageUrl == null)
                      ? const Icon(LucideIcons.camera, color: Colors.blue)
                      : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Space Name')),
                const SizedBox(height: 8),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                TextField(
                  controller: linkController, 
                  decoration: const InputDecoration(
                    labelText: 'External Link',
                    prefixIcon: Icon(LucideIcons.link, size: 16),
                  )
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Hide My Space', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Operating anonymously in the community', style: TextStyle(fontSize: 11)),
                  value: isHidden,
                  onChanged: (val) => setDialogState(() => isHidden = val),
                  activeThumbColor: Colors.red,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                setDialogState(() => isUploading = true);
                try {
                  final firestore = Provider.of<FirestoreService>(context, listen: false);
                  
                  String? imageUrl = widget.channel.profileImageUrl;
                   if (selectedImage != null || selectedImageBytes != null) {
                     imageUrl = await firestore.uploadChannelProfilePicture(
                       widget.channel.id, 
                       selectedImage ?? io.File(''),
                       bytes: selectedImageBytes
                     );
                   }

                  final links = linkController.text.isNotEmpty ? [linkController.text] : <String>[];
                  
                  await firestore.createChannel(Channel(
                    id: widget.channel.id,
                    ownerId: widget.channel.ownerId,
                    name: nameController.text,
                    handle: widget.channel.handle,
                    description: descController.text,
                    profileImageUrl: imageUrl,
                    externalLinks: links,
                    createdAt: widget.channel.createdAt,
                    followersCount: widget.channel.followersCount,
                    isHidden: isHidden,
                  ));
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Space updated successfully!')));
                  setState(() {}); // Refresh UI
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  setDialogState(() => isUploading = false);
                }
              },
              child: isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context);
    final auth = Provider.of<AuthService>(context);
    final isOwner = widget.channel.ownerId == auth.currentUserId;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.channel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isOwner)
            IconButton(icon: const Icon(LucideIcons.settings), onPressed: _showEditChannelDialog),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.qrCode), 
                        onPressed: _showQrCode,
                        tooltip: 'Share QR Code',
                      ),
                       IconButton(
                        icon: const Icon(LucideIcons.share2), 
                        onPressed: () {
                           Clipboard.setData(ClipboardData(text: "Join my legal space on LexAni: https://lexami.app/space/@${widget.channel.handle}"));
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard!')));
                        },
                        tooltip: 'Copy Link',
                      ),
                    ],
                   ),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: widget.channel.profileImageUrl != null ? NetworkImage(widget.channel.profileImageUrl!) : null,
                    child: widget.channel.profileImageUrl == null ? const Icon(LucideIcons.tv, size: 32, color: Colors.blue) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(widget.channel.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text('@${widget.channel.handle}', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Text(widget.channel.description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
                  const SizedBox(height: 16),
                  
                  // External Links
                  if (widget.channel.externalLinks.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: widget.channel.externalLinks.map((link) => ActionChip(
                        avatar: Icon(link.contains('youtu') ? LucideIcons.youtube : LucideIcons.link, size: 16, color: Colors.red),
                        label: const Text('Visit Link', style: TextStyle(fontSize: 10)),
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $link...')));
                           // Implement launchUrl here if needed
                        },
                        backgroundColor: Colors.red.shade50,
                        side: BorderSide.none,
                      )).toList(),
                    ),
                  if (widget.channel.externalLinks.isNotEmpty) const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text('${widget.channel.followersCount}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          const Text('Followers', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 32),
                      if (!isOwner) 
                        ElevatedButton.icon(
                          onPressed: () => firestore.followChannel(auth.currentUserId!, widget.channel.id),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('FOLLOW'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                          ),
                        )
                      else
                         OutlinedButton.icon(
                          onPressed: _showEditChannelDialog,
                          icon: const Icon(LucideIcons.edit2, size: 16),
                          label: const Text('EDIT'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          StreamBuilder<List<ChannelPost>>(
            stream: firestore.streamChannelPosts(widget.channel.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              final posts = snapshot.data ?? [];
              
              if (posts.isEmpty) {
                 return SliverFillRemaining(
                   child: Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(LucideIcons.fileText, size: 64, color: Colors.grey.shade300),
                         const SizedBox(height: 16),
                         const Text('No posts yet'),
                       ],
                     ),
                   ),
                 );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = posts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blue.shade50,
                                backgroundImage: post.authorImage != null ? NetworkImage(post.authorImage!) : null,
                                child: post.authorImage == null ? const Icon(LucideIcons.tv, size: 16, color: Colors.blue) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.authorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (post.isRepost)
                                      Text(
                                        post.repostThoughts != null ? 'shared their thoughts' : 'reposted this',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              Text(timeago.format(post.createdAt, locale: 'en_short'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Reposter's Thoughts
                          if (post.repostThoughts != null) ...[
                            Text(post.repostThoughts!, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
                            const SizedBox(height: 16),
                          ],

                          // Main Content or Original Post Card
                          if (post.isRepost)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.user, size: 14, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        post.originalAuthorName ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (post.content.isNotEmpty)
                                    Text(
                                      post.content,
                                      style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade800),
                                      maxLines: post.repostThoughts != null ? 3 : null,
                                      overflow: post.repostThoughts != null ? TextOverflow.ellipsis : null,
                                    ),
                                  if (post.mediaUrl != null || post.thumbnailUrl != null) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: post.mediaUrl ?? post.thumbnailUrl!,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(height: 120, color: Colors.grey.shade100),
                                        errorWidget: (context, url, err) => const Icon(Icons.error),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else ...[
                            // Regular Post Content
                            if (post.content.isNotEmpty)
                              Text(post.content, style: const TextStyle(fontSize: 16, height: 1.5)),
                            
                            if (post.mediaUrl != null || post.thumbnailUrl != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12), 
                                child: CachedNetworkImage(
                                  imageUrl: post.mediaUrl ?? post.thumbnailUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => post.thumbnailUrl != null 
                                    ? Image.network(post.thumbnailUrl!, width: double.infinity, fit: BoxFit.cover)
                                    : Container(height: 200, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())),
                                  errorWidget: (context, url, err) => Container(height: 200, color: Colors.grey.shade100, child: const Icon(Icons.error)),
                                ),
                              ),
                            ],
                          ],

                          const SizedBox(height: 16),
                          // Interaction Stats
                          if (post.likesCount > 0 || post.commentsCount > 0 || post.repostsCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  if (post.likesCount > 0) ...[
                                    Icon(LucideIcons.thumbsUp, size: 14, color: Colors.blue.shade600),
                                    const SizedBox(width: 4),
                                    Text('${post.likesCount}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    const SizedBox(width: 16),
                                  ],
                                  if (post.commentsCount > 0) ...[
                                    Text('${post.commentsCount} comments', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    const SizedBox(width: 16),
                                  ],
                                  if (post.repostsCount > 0) ...[
                                    Text('${post.repostsCount} reposts', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  ],
                                ],
                              ),
                            ),
                          
                          // Divider
                          if (post.likesCount > 0 || post.commentsCount > 0 || post.repostsCount > 0)
                            Divider(color: Colors.grey.shade200, height: 1),
                          
                          // Interaction Buttons (LinkedIn-style)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Like Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () => firestore.likeChannelPost(widget.channel.id, post.id, auth.currentUserId!),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            post.likedBy.contains(auth.currentUserId) 
                                                ? LucideIcons.thumbsUp 
                                                : LucideIcons.thumbsUp, 
                                            size: 18,
                                            color: post.likedBy.contains(auth.currentUserId) ? Colors.blue : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Like',
                                            style: TextStyle(
                                              color: post.likedBy.contains(auth.currentUserId) ? Colors.blue : Colors.grey.shade700,
                                              fontWeight: post.likedBy.contains(auth.currentUserId) ? FontWeight.w600 : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Comment Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _showCommentsSheet(post),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(LucideIcons.messageSquare, size: 18, color: Colors.grey.shade600),
                                          const SizedBox(width: 6),
                                          Text('Comment', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Repost Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final myChannel = await firestore.getChannelByOwner(auth.currentUserId!);
                                      if (myChannel == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Create a Space first to repost!')),
                                        );
                                        return;
                                      }
                                      
                                      final alreadyReposted = post.repostedBy.contains(auth.currentUserId);
                                      
                                      if (alreadyReposted) {
                                        // Undo repost
                                        await firestore.undoRepost(
                                          widget.channel.id,
                                          post.id,
                                          auth.currentUserId!,
                                          myChannel.id,
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Repost removed')),
                                        );
                                      } else {
                                        // Show repost dialog
                                        final thoughtsController = TextEditingController();
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Repost to your Space?'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'This will share this post with your followers.',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller: thoughtsController,
                                                  maxLines: 3,
                                                  decoration: InputDecoration(
                                                    hintText: 'Add your thoughts... (optional)',
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                    contentPadding: const EdgeInsets.all(12),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.grey.shade200),
                                                  ),
                                                  child: Text(
                                                    post.content.length > 100 
                                                        ? '${post.content.substring(0, 100)}...' 
                                                        : post.content,
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  final thoughts = thoughtsController.text.trim().isEmpty ? null : thoughtsController.text.trim();
                                                  Navigator.pop(context);
                                                  await firestore.repostChannelPost(
                                                    widget.channel.id,
                                                    post.id,
                                                    auth.currentUserId!,
                                                    myChannel.id,
                                                    myChannel.name,
                                                    myChannel.profileImageUrl,
                                                    thoughts: thoughts,
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Reposted to your Space!')),
                                                  );
                                                },
                                                child: const Text('Repost'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            LucideIcons.repeat2,
                                            size: 18,
                                            color: post.repostedBy.contains(auth.currentUserId) ? Colors.green : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Repost',
                                            style: TextStyle(
                                              color: post.repostedBy.contains(auth.currentUserId) ? Colors.green : Colors.grey.shade700,
                                              fontWeight: post.repostedBy.contains(auth.currentUserId) ? FontWeight.w600 : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Send/Share Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      final shareText = '${post.content}\n\nShared from ${post.authorName} on LexAni\nhttps://lexami.app/space/@${widget.channel.handle}/post/${post.id}';
                                      Share.share(shareText);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(LucideIcons.send, size: 18, color: Colors.grey.shade600),
                                          const SizedBox(width: 6),
                                          Text('Send', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: posts.length,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: isOwner ? FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.red,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ) : null,
    );
  }
}
