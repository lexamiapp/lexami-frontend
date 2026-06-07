import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/forum_question.dart';
import '../models/user_profile.dart';
import '../models/blog_post.dart';
import '../models/channel.dart';
import 'channel_feed_screen.dart';
import '../services/media_service.dart';
import '../models/forum_comment.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedForumFilter = 'All Questions';
  final _questionTitleController = TextEditingController();
  final _questionDescController = TextEditingController();
  final _blogTitleController = TextEditingController();
  final _blogContentController = TextEditingController();
  final _channelNameController = TextEditingController();
  final _channelDescController = TextEditingController();

  bool _isAnonymous = false;

  final List<String> _filters = ['All Questions', 'Divorce', 'Child Custody', 'Alimony', 'Legal Aid'];
  UserProfile? _currentUserProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    if (auth.currentUserId != null) {
      final profile = await firestore.getUserProfile(auth.currentUserId!);
      if (mounted) {
        setState(() {
          _currentUserProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } else {
      setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionTitleController.dispose();
    _questionDescController.dispose();
    super.dispose();
  }

  void _createPost() {
    io.File? selectedMedia;
    Uint8List? selectedMediaBytes;
    String? mediaType;
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
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create New Post', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Post Anonymously', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: _isAnonymous,
                        onChanged: (v) => setModalState(() => _isAnonymous = v),
                        activeThumbColor: Colors.blue.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _questionTitleController, decoration: const InputDecoration(labelText: 'Title (e.g. Divorce timeline in Mumbai)')),
                  const SizedBox(height: 16),
                  TextField(controller: _questionDescController, maxLines: 4, decoration: const InputDecoration(labelText: 'Describe your situation')),
                  const SizedBox(height: 24),
                  
                  // Media Selection
                  const Text('ATTACH MEDIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMediaButton(
                        icon: LucideIcons.image,
                        label: 'Image',
                        color: Colors.blue,
                        onTap: () async {
                          final picker = ImagePicker();
                          final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (img != null) {
                            final bytes = await img.readAsBytes();
                            setModalState(() {
                              selectedMedia = io.File(img.path);
                              selectedMediaBytes = bytes;
                              mediaType = 'image';
                            });
                          }
                        }
                      ),
                      const SizedBox(width: 12),
                      _buildMediaButton(
                        icon: LucideIcons.video,
                        label: 'Video',
                        color: Colors.red,
                        onTap: () async {
                          final picker = ImagePicker();
                          final vid = await picker.pickVideo(source: ImageSource.gallery);
                          if (vid != null) {
                            final bytes = await vid.readAsBytes();
                            setModalState(() {
                              selectedMedia = io.File(vid.path);
                              selectedMediaBytes = bytes;
                              mediaType = 'video';
                            });
                          }
                        }
                      ),
                    ],
                  ),
                  
                  if (selectedMedia != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            image: mediaType == 'image' 
                                ? (selectedMediaBytes != null ? DecorationImage(image: MemoryImage(selectedMediaBytes!), fit: BoxFit.cover) : (kIsWeb ? null : DecorationImage(image: FileImage(selectedMedia!), fit: BoxFit.cover)))
                                : null,
                          ),
                          child: mediaType == 'video' 
                                ? const Center(child: Icon(LucideIcons.playCircle, size: 48, color: Colors.red))
                                : null,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: GestureDetector(
                            onTap: () => setModalState(() {
                              selectedMedia = null;
                              mediaType = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: isUploading ? null : () async {
                        if (_questionTitleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
                          return;
                        }

                        setModalState(() {
                          isUploading = true;
                          statusMessage = "Preparing post...";
                        });

                        try {
                          final auth = Provider.of<AuthService>(context, listen: false);
                          final firestore = Provider.of<FirestoreService>(context, listen: false);

                          if (auth.currentUserId == null) {
                            throw Exception('You must be logged in to post.');
                          }

                          final profile = await firestore.getUserProfile(auth.currentUserId!);
                          final myChannel = await firestore.getChannelByOwner(auth.currentUserId!);
                          final forceAnonymous = myChannel?.isHidden ?? false;
                          final isAnon = _isAnonymous || forceAnonymous;

                          String? mediaUrl;
                          String? thumbnailUrl;

                          if (selectedMedia != null) {
                            final postId = DateTime.now().millisecondsSinceEpoch.toString();

                            // 1. Generate & Upload Thumbnail
                            setModalState(() => statusMessage = "Uploading thumbnail...");
                            final thumbnailFile = await MediaService.generateThumbnail(selectedMedia!, mediaType!);
                            if (thumbnailFile != null) {
                              thumbnailUrl = await firestore.uploadForumMedia(
                                '${postId}_thumb',
                                thumbnailFile,
                                bytes: kIsWeb ? await thumbnailFile.readAsBytes() : null,
                              );
                            }

                            // 2. Process & Upload High-Res Media
                            setModalState(() => statusMessage = "Processing media...");
                            dynamic processedMedia;
                            if (mediaType == 'image') {
                              processedMedia = await MediaService.compressImage(selectedMedia!);
                            } else if (mediaType == 'video') {
                              final sub = (MediaService.videoCompressionProgress as Stream<double>).listen((progress) {
                                setModalState(() {
                                  uploadProgress = progress / 100;
                                  statusMessage = "Compressing video: ${progress.toStringAsFixed(0)}%";
                                });
                              });
                              processedMedia = await MediaService.compressVideo(selectedMedia!);
                              sub.cancel();
                            }

                            final uploadFile = processedMedia ?? selectedMedia!;
                            final uploadBytes = (processedMedia != null && kIsWeb) ? await (processedMedia as dynamic).readAsBytes() : selectedMediaBytes;

                            setModalState(() {
                              statusMessage = "Uploading media...";
                              uploadProgress = 0.0;
                            });

                            mediaUrl = await firestore.uploadForumMedia(
                              postId,
                              uploadFile,
                              bytes: uploadBytes,
                              onProgress: (progress) {
                                setModalState(() => uploadProgress = progress);
                              },
                            );
                          }

                          setModalState(() => statusMessage = "Publishing post...");

                          await firestore.addForumQuestion(ForumQuestion(
                            id: '',
                            userId: auth.currentUserId!,
                            authorName: isAnon ? 'Anonymous' : (profile?.fullName ?? 'User'),
                            title: _questionTitleController.text.trim(),
                            description: _questionDescController.text.trim(),
                            tags: [_selectedForumFilter == 'All Questions' ? 'General' : _selectedForumFilter],
                            createdAt: DateTime.now(),
                            mediaUrl: mediaUrl,
                            thumbnailUrl: thumbnailUrl,
                            mediaType: mediaType,
                          ));

                          if (context.mounted) Navigator.pop(context);
                          _questionTitleController.clear();
                          _questionDescController.clear();
                          setState(() => _isAnonymous = false);
                        } catch (e) {
                          setModalState(() {
                            isUploading = false;
                            statusMessage = '';
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to post: ${e.toString().replaceAll('Exception: ', '')}'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.blueGrey.shade900,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 20),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: isUploading 
                        ? Column(
                            children: [
                              LinearProgressIndicator(value: uploadProgress, color: Colors.white, backgroundColor: Colors.white24),
                              const SizedBox(height: 8),
                              Text(statusMessage, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          )
                        : const Text('POST TO COMMUNITY', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Community Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildForumTab(),
                _buildChannelsTab(),
                _buildBlogTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0 
        ? FloatingActionButton.extended(
            onPressed: _createPost,
            backgroundColor: Colors.blueGrey.shade900,
            icon: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
            label: const Text('CREATE POST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
          )
        : _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showCreateChannelDialog,
              backgroundColor: Colors.red,
              icon: const Icon(LucideIcons.tv, color: Colors.white, size: 20),
              label: const Text('START SPACE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            )
          : null,
    );
  }

  void _showCreateChannelDialog() {
    final channelHandleController = TextEditingController();
    final channelLinkController = TextEditingController(); 
    bool isCheckingHandle = false;
    String? handleErrorText;
    io.File? selectedImage;
    Uint8List? selectedImageBytes;
    bool isUploading = false;
    bool isHidden = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Space', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      image: selectedImageBytes != null 
                        ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover)
                        : (selectedImage != null && !kIsWeb ? DecorationImage(image: FileImage(selectedImage!), fit: BoxFit.cover) : null),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: selectedImage == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.camera, color: Colors.blue),
                            Text('ADD ICON', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        )
                      : null,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(controller: _channelNameController, decoration: const InputDecoration(labelText: 'Space Name')),
                const SizedBox(height: 8),
                TextField(
                  controller: channelHandleController, 
                  decoration: InputDecoration(
                    labelText: 'Handle (e.g. legal_eagle)', 
                    prefixText: '@',
                    errorText: handleErrorText,
                    suffixIcon: isCheckingHandle ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  ),
                  onChanged: (val) {
                    if (handleErrorText != null) {
                      setDialogState(() => handleErrorText = null);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: _channelDescController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                TextField(
                  controller: channelLinkController, 
                  decoration: const InputDecoration(
                    labelText: 'External Link (YouTube/Instagram)',
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
                if (_channelNameController.text.isEmpty || channelHandleController.text.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Handle are required!')));
                   return;
                }

                setDialogState(() => isCheckingHandle = true);
                final firestore = Provider.of<FirestoreService>(context, listen: false);
                final desiredHandle = channelHandleController.text.trim().toLowerCase();
                
                final exists = await firestore.checkChannelHandle(desiredHandle);
                
                if (exists) {
                  final randomSuffix = DateTime.now().millisecond.toString();
                  setDialogState(() {
                    isCheckingHandle = false;
                    handleErrorText = 'Handle taken. Try: $desiredHandle$randomSuffix';
                  });
                  return;
                }

                setDialogState(() {
                   isCheckingHandle = false;
                   isUploading = true;
                });

                final auth = Provider.of<AuthService>(context, listen: false);
                
                if (auth.currentUserId != null) {
                  final links = channelLinkController.text.isNotEmpty ? [channelLinkController.text] : <String>[];
                  
                  final channelId = DateTime.now().millisecondsSinceEpoch.toString();
                  String? imageUrl;

                  if (selectedImage != null || selectedImageBytes != null) {
                    imageUrl = await firestore.uploadChannelProfilePicture(
                      channelId, 
                      selectedImage ?? io.File(''),
                      bytes: selectedImageBytes
                    );
                  }

                  await firestore.createChannel(Channel(
                    id: channelId,
                    ownerId: auth.currentUserId!,
                    name: _channelNameController.text,
                    handle: desiredHandle,
                    description: _channelDescController.text,
                    profileImageUrl: imageUrl,
                    externalLinks: links,
                    createdAt: DateTime.now(),
                    isHidden: isHidden,
                  ));
                }
                Navigator.pop(context);
                _channelNameController.clear();
                _channelDescController.clear();
              },
              child: isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          labelColor: Colors.blueGrey.shade900,
          unselectedLabelColor: Colors.grey.shade500,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          tabs: const [
            Tab(text: 'Community Feed'),
            Tab(text: 'Legal Spaces'),
            Tab(text: 'Expert Blogs'),
          ],
        ),
      ),
    );
  }

  Widget _buildForumTab() {
    final firestore = Provider.of<FirestoreService>(context);
    
    return StreamBuilder<List<ForumQuestion>>(
      stream: firestore.streamForumQuestions(tag: _selectedForumFilter == 'All Questions' ? null : _selectedForumFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final questions = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildForumFilters(),
              const SizedBox(height: 32),
              if (questions.isEmpty)
                 const Center(child: Padding(padding: EdgeInsets.all(64), child: Text('No questions found. Be the first to ask!', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center,))),
              ...questions.map((q) => _buildQuestionCard(q)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildForumFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) => _buildFilterChip(filter)).toList(),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool active = _selectedForumFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedForumFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.blueGrey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.transparent : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.blueGrey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(ForumQuestion q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/community/user/${q.userId}'),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Center(
                    child: Text(q.authorName.isNotEmpty ? q.authorName[0] : 'U', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.push('/community/user/${q.userId}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.authorName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    Text('${DateTime.now().difference(q.createdAt).inHours}h ago', style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              if (Provider.of<AuthService>(context, listen: false).currentUserId != q.userId)
                IconButton(
                  icon: const Icon(LucideIcons.userPlus, size: 18, color: Colors.blue),
                  onPressed: () {
                    final auth = Provider.of<AuthService>(context, listen: false);
                    Provider.of<FirestoreService>(context, listen: false).sendFriendRequest(auth.currentUserId!, q.userId);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
                  },
                ),
              Icon(LucideIcons.moreHorizontal, size: 16, color: Colors.grey.shade300),
            ],
          ),
          if (q.isRepost) ...[
            if (q.repostThoughts != null) ...[
              Text(q.repostThoughts!, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.user, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        q.originalAuthorName ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(q.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(q.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (q.mediaUrl != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: q.mediaUrl ?? q.thumbnailUrl ?? '', 
                        height: 120, 
                        width: double.infinity, 
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Text(q.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, height: 1.3)),
            const SizedBox(height: 8),
            Text(q.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
            if (q.mediaUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                     CachedNetworkImage(
                      imageUrl: q.mediaUrl ?? q.thumbnailUrl ?? '', 
                      height: 200, 
                      width: double.infinity, 
                      fit: BoxFit.cover,
                      placeholder: (context, url) => q.thumbnailUrl != null 
                        ? Image.network(q.thumbnailUrl!, width: double.infinity, height: 200, fit: BoxFit.cover)
                        : Container(height: 200, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())),
                      errorWidget: (context, url, error) => Container(height: 200, color: Colors.grey.shade100, child: const Icon(Icons.error)),
                    ),
                    if (q.mediaType == 'video')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.play, color: Colors.white, size: 24),
                      ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              ...q.tags.map((tag) => _buildTag(tag)),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // Statistics Summary (Visible to Everyone)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Likes Count
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: q.likedBy.isEmpty ? Colors.grey.shade200 : Colors.blue, 
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    LucideIcons.thumbsUp, 
                    size: 10, 
                    color: q.likedBy.isEmpty ? Colors.grey.shade500 : Colors.white
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${q.likedBy.length}', 
                  style: TextStyle(
                    color: q.likedBy.isEmpty ? Colors.grey.shade400 : Colors.grey.shade700, 
                    fontSize: 12, 
                    fontWeight: FontWeight.bold
                  )
                ),
                const Spacer(),
                // Comments Count
                Text(
                  '${q.commentsCount} comments', 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)
                ),
                Text(' • ', style: TextStyle(color: Colors.grey.shade600)),
                // Reposts Count
                Text(
                  '${q.repostsCount} reposts', 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade100, height: 1),
          // Interaction Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLinkedInButton(
                  icon: q.likedBy.contains(Provider.of<AuthService>(context, listen: false).currentUserId)
                      ? LucideIcons.thumbsUp
                      : LucideIcons.thumbsUp,
                  label: 'Like',
                  color: q.likedBy.contains(Provider.of<AuthService>(context, listen: false).currentUserId)
                      ? Colors.blue
                      : Colors.grey.shade700,
                  onTap: () {
                    final auth = Provider.of<AuthService>(context, listen: false);
                    Provider.of<FirestoreService>(context, listen: false).likeForumQuestion(q.id, auth.currentUserId!);
                  },
                ),
                _buildLinkedInButton(
                  icon: LucideIcons.messageSquare,
                  label: 'Comment',
                  onTap: () => _showForumCommentsSheet(q),
                ),
                _buildLinkedInButton(
                  icon: LucideIcons.repeat2,
                  label: 'Repost',
                  color: q.repostedBy.contains(Provider.of<AuthService>(context, listen: false).currentUserId)
                      ? Colors.green
                      : null,
                  onTap: () => _repostForumQuestion(q),
                ),
                _buildLinkedInButton(
                  icon: LucideIcons.send,
                  label: 'Send',
                  onTap: () {
                    final shareText = 'Check out this legal query on LexAni: ${q.title}\n\n${q.description}\n\n#LexAni #LegalAid';
                    Share.share(shareText);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedInButton({required IconData icon, required String label, Color? color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: color ?? Colors.grey.shade700, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _showForumCommentsSheet(ForumQuestion q) {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const Spacer(),
                    Text('${q.commentsCount} total', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ForumComment>>(
                  stream: Provider.of<FirestoreService>(context).streamForumComments(q.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final comments = snapshot.data!;
                    if (comments.isEmpty) return const Center(child: Text('No comments yet. Be the first!'));
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 18, backgroundColor: Colors.blue.shade50, child: Text(c.authorName[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Text(c.content, style: const TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 4),
                                      child: Text(timeago.format(c.createdAt, locale: 'en_short'), style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatefulBuilder(
                      builder: (ctx, setSendState) {
                        bool isSending = false;
                        return IconButton(
                          onPressed: isSending ? null : () async {
                            final text = commentController.text.trim();
                            if (text.isEmpty) return;
                            setSendState(() => isSending = true);
                            try {
                              final auth = Provider.of<AuthService>(context, listen: false);
                              final firestore = Provider.of<FirestoreService>(context, listen: false);
                              final profile = await firestore.getUserProfile(auth.currentUserId ?? '');
                              await firestore.addForumComment(ForumComment(
                                id: '', // Firestore will auto-assign
                                postId: q.id,
                                userId: auth.currentUserId ?? '',
                                authorName: _isAnonymous ? 'Anonymous' : (profile?.fullName ?? 'User'),
                                content: text,
                                createdAt: DateTime.now(),
                              ));
                              commentController.clear();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to post comment. Please try again.')),
                                );
                              }
                            } finally {
                              setSendState(() => isSending = false);
                            }
                          },
                          icon: isSending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(LucideIcons.send, color: Colors.blue),
                        );
                      },
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

  void _repostForumQuestion(ForumQuestion q) {
    final thoughtsController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repost to Feed?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this question with the community.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: thoughtsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add your thoughts... (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                q.title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthService>(context, listen: false);
              final firestore = Provider.of<FirestoreService>(context, listen: false);
              final profile = await firestore.getUserProfile(auth.currentUserId!);
              final thoughts = thoughtsController.text.trim().isEmpty ? null : thoughtsController.text.trim();
              
              await firestore.repostForumQuestion(q.id, auth.currentUserId!, profile?.fullName ?? 'User', thoughts: thoughts);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post Reposted!')));
            },
            child: const Text('Repost'),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
    );
  }

  Widget _buildInteractionStat(IconData icon, String count, {Color? color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(count, style: TextStyle(fontSize: 12, color: color ?? Colors.grey.shade500, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChannelsTab() {
    final firestore = Provider.of<FirestoreService>(context);
    final auth = Provider.of<AuthService>(context);

    return StreamBuilder<List<Channel>>(
      stream: firestore.streamChannels(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final allChannels = snapshot.data ?? [];
        final userId = auth.currentUserId;
        final channels = allChannels.where((c) => !c.isHidden || c.ownerId == userId).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // "Your Mode" Prompt
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.tv, color: Colors.red, size: 32),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start your own Space', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                         Text('Share legal knowledge, upload videos, and build a following.', style: TextStyle(color: Colors.brown, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showCreateChannelDialog, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('CREATE'),
                  ),
                ],
              ),
            ),
            
            const Text('RECOMMENDED SPACES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.grey)),
            const SizedBox(height: 16),
            
            ...channels.map((c) => GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFeedScreen(channel: c))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.isHidden ? Colors.red.shade100 : Colors.grey.shade100),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: c.profileImageUrl != null ? NetworkImage(c.profileImageUrl!) : null,
                          child: c.profileImageUrl == null ? const Icon(LucideIcons.tv, size: 20, color: Colors.blue) : null,
                        ),
                        if (c.isHidden)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.eyeOff, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              if (c.isHidden) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('HIDDEN', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ],
                          ),
                          Text('${c.followersCount} subscribers', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(c.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 20, color: Colors.grey.shade300),
                  ],
                ),
              ),
            )),
          ],
        );
      },
    );
  }

  Widget _buildBlogTab() {
    final firestore = Provider.of<FirestoreService>(context);
    final auth = Provider.of<AuthService>(context);

    return Column(
      children: [
        _buildBlogHeader(auth, firestore),
        Expanded(
          child: StreamBuilder<List<BlogPost>>(
            stream: firestore.streamApprovedBlogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final blogs = snapshot.data ?? [];

              if (blogs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No verified blogs available yet.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _buildSampleBlogCard(),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: blogs.length,
                itemBuilder: (context, index) {
                  final blog = blogs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // Additional blog content layout continues
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(color: Colors.grey.shade100, height: 160, width: double.infinity, child: const Icon(LucideIcons.image, color: Colors.grey)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(LucideIcons.shieldCheck, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(blog.authorName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(blog.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(blog.content, style: TextStyle(color: Colors.grey.shade600, height: 1.5, fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBlogHeader(AuthService auth, FirestoreService firestore) {
    if (_isLoadingProfile) return const SizedBox(height: 24);
    if (_currentUserProfile == null) return const SizedBox.shrink();

    // EXTREMELY STRICT CHECK
    final String userEmail = _currentUserProfile?.email.trim().toLowerCase() ?? '';
    final bool isAdminEmail = AppConstants.adminEmails.any((e) => e.trim().toLowerCase() == userEmail);
    final bool isAdminFlag = _currentUserProfile?.isAdmin == true;
    final bool isVerifiedExpert = _currentUserProfile?.isVerifiedAdvisor == true;

    // Only allow for genuine admins or verified advisors
    if (isAdminEmail || isAdminFlag || isVerifiedExpert) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCreateBlogDialog,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('WRITE AN ARTICLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              side: BorderSide(color: Colors.blue.shade100),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      );
    }
    
    // Default: Return nothing for general viewers
    return const SizedBox.shrink();
  }





  void _showCreateBlogDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create Blog Post', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              TextField(controller: _blogTitleController, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 16),
              TextField(controller: _blogContentController, maxLines: 5, decoration: const InputDecoration(labelText: 'Content')),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final auth = Provider.of<AuthService>(context, listen: false);
                    final firestore = Provider.of<FirestoreService>(context, listen: false);
                    final profile = await firestore.getUserProfile(auth.currentUserId ?? '');
                    
                    if (auth.currentUserId != null) {
                      // Check if user has a Space (Channel) to use as identity
                      final myChannel = await firestore.getChannelByOwner(auth.currentUserId!);
                      
                      await firestore.addBlogPost(BlogPost(
                        id: '',
                        authorId: auth.currentUserId!,
                        authorName: myChannel != null ? myChannel.name : (profile?.fullName ?? 'Verified Expert'),
                        title: _blogTitleController.text,
                        content: _blogContentController.text,
                        createdAt: DateTime.now(),
                      ));
                    }
                    Navigator.pop(context);
                    _blogTitleController.clear();
                    _blogContentController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blog submitted for admin approval!')));
                  },
                  child: const Text('SUBMIT FOR APPROVAL'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  // Sample blog card widget
  Widget _buildSampleBlogCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('BBC News Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('A concise summary of the BBC article goes here. This is a placeholder verified blog post visible to all users.', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
