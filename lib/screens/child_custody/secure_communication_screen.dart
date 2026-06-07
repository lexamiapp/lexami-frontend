import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:timeago/timeago.dart' as timeago;

class SecureCommunicationScreen extends StatefulWidget {
  const SecureCommunicationScreen({super.key});

  @override
  State<SecureCommunicationScreen> createState() => _SecureCommunicationScreenState();
}

class _SecureCommunicationScreenState extends State<SecureCommunicationScreen> {
  final _msgCtrl = TextEditingController();
  final _partnerEmailCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _roomId;
  String? _partnerUid;
  bool _isConnecting = false;
  bool _isSending = false;
  bool _aiModerationOn = true;
  bool _isLoadingRoom = true;

  // Hostile keywords (client-side pre-filter; also AI-checked on send)
  static const _hostileWords = [
    'hate', 'kill', 'stupid', 'idiot', 'worthless', 'useless',
    'shut up', 'divorce', 'lawyer', 'court', 'sue',
    'gadha', 'bewakoof', 'chup', 'besharam',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingRoom();
  }

  Future<void> _loadExistingRoom() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final uid = auth.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingRoom = false);
      return;
    }
    try {
      final roomId = await firestore.getExistingCoParentRoom(uid);
      if (mounted) {
        setState(() {
          _roomId = roomId;
          _isLoadingRoom = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRoom = false);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _partnerEmailCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Connect to co-parent by UID ────────────────────────────────────────────
  Future<void> _connectToPartner(String partnerUid) async {
    setState(() { _isConnecting = true; });
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final myUid = auth.currentUserId;
    if (myUid == null) { setState(() => _isConnecting = false); return; }

    try {
      final roomId = await firestore.getOrCreateCoParentRoom(myUid, partnerUid);
      setState(() {
        _partnerUid = partnerUid;
        _roomId = roomId;
        _isConnecting = false;
      });
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) _showError('Could not connect: ${e.toString()}');
    }
  }

  // ── Send a message with AI moderation ─────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _roomId == null) return;

    // Client-side hostile word check
    if (_aiModerationOn) {
      final lower = text.toLowerCase();
      final blocked = _hostileWords.any((w) => lower.contains(w));
      if (blocked) {
        _showModerationDialog(
          'Message Blocked',
          'Your message contains language that may escalate conflict.\n\n'
          'Focus on: logistics, child welfare, health, and education.\n'
          'Avoid: personal attacks, legal threats, or emotional topics.',
        );
        return;
      }
    }

    setState(() => _isSending = true);
    _msgCtrl.clear();

    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final myUid = auth.currentUserId ?? '';

    // AI moderation check (async, non-blocking — flag after send)
    if (_aiModerationOn) {
      _checkAIModeration(text);
    }

    try {
      await firestore.sendCoParentMessage(_roomId!, {
        'senderId': myUid,
        'text': text,
        'flagged': false,
        'type': 'text',
      });
    } catch (e) {
      if (mounted) _showError('Failed to send message. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  // Run AI moderation check in background
  void _checkAIModeration(String text) async {
    final gemini = Provider.of<GeminiService>(context, listen: false);
    try {
      final result = await gemini.generateWithFallback([
        Content.text(
          'You are a child-focused communication moderator. '
          'Analyze this co-parenting message and respond ONLY with: SAFE or HOSTILE\n\n'
          'Message: "$text"'
        ),
      ]);
      if (result.contains('HOSTILE') && _roomId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade700,
            content: const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('AI flagged your last message as potentially hostile. Please keep focus on the child.')),
              ],
            ),
          ),
        );
      }
    } catch (_) { /* AI moderation is best-effort */ }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Colors.red.shade700,
      content: Text(msg),
    ));
  }

  void _showModerationDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.shieldAlert, color: Colors.orange.shade700, size: 22),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConnectDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              const Text('Connect with Co-Parent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                'Enter your co-parent\'s User ID (they can find it in their Profile screen).',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _partnerEmailCtrl,
                decoration: InputDecoration(
                  labelText: 'Co-Parent User ID',
                  hintText: 'e.g. abc123xyz',
                  prefixIcon: const Icon(LucideIcons.user),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final uid = _partnerEmailCtrl.text.trim();
                    if (uid.isEmpty) return;
                    Navigator.pop(context);
                    _connectToPartner(uid);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Co-Parent Communication'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_aiModerationOn ? LucideIcons.shieldCheck : LucideIcons.shieldOff),
            tooltip: 'AI Moderation ${_aiModerationOn ? "ON" : "OFF"}',
            onPressed: () => setState(() => _aiModerationOn = !_aiModerationOn),
          ),
          if (_roomId == null)
            IconButton(
              icon: const Icon(LucideIcons.userPlus),
              tooltip: 'Connect co-parent',
              onPressed: _showConnectDialog,
            ),
        ],
      ),
      body: _isLoadingRoom
          ? const Center(child: CircularProgressIndicator())
          : _roomId == null ? _buildConnectState() : _buildChatView(),
    );
  }

  // ── Connect State ─────────────────────────────────────────────────────────

  Widget _buildConnectState() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final myUid = auth.currentUserId ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildAIBanner(),
          const SizedBox(height: 24),

          // My UID card (co-parent needs this)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your User ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                const SizedBox(height: 6),
                SelectableText(myUid, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Share this ID with your co-parent so they can connect with you.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildProtocolsList(),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isConnecting ? null : _showConnectDialog,
              icon: _isConnecting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.messageSquare),
              label: Text(_isConnecting ? 'Connecting...' : 'Start Secure Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat View ─────────────────────────────────────────────────────────────

  Widget _buildChatView() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final myUid = auth.currentUserId ?? '';

    return Column(
      children: [
        if (_aiModerationOn)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.teal.shade800,
            child: const Row(
              children: [
                Icon(LucideIcons.shieldCheck, color: Colors.greenAccent, size: 14),
                SizedBox(width: 8),
                Text(
                  'AI Moderation Active — Focus on child logistics, health & education',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestore.streamCoParentMessages(_roomId!),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snap.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.messageCircle, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No messages yet.\nKeep it focused on the child.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                    ],
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg['senderId'] == myUid;
                  final ts = msg['timestamp'];
                  final timeStr = ts != null ? timeago.format(ts.toDate()) : '';

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.teal.shade700 : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['text'] ?? '',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(timeStr, style: TextStyle(
                                color: isMe ? Colors.white60 : Colors.grey.shade400,
                                fontSize: 10,
                              )),
                              if (msg['flagged'] == true) ...[
                                const SizedBox(width: 6),
                                Icon(LucideIcons.alertTriangle, size: 10, color: Colors.orange.shade300),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(LucideIcons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.shieldCheck, color: Colors.greenAccent, size: 20),
              SizedBox(width: 10),
              Text('AI Moderation Enabled', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Messages are screened to keep communication child-focused.\n'
            'Focus on: Logistics • Health • Education • Schedule',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolsList() {
    final protocols = [
      (LucideIcons.shieldAlert, 'Hostility Filter', 'Messages with aggressive or emotionally charged language are flagged before sending.'),
      (LucideIcons.fileClock, 'Accountability Log', 'All messages are timestamped and preserved — admissible as evidence if required.'),
      (LucideIcons.baby, 'Child-Centered Focus', 'AI reminds you to keep all communication about the child\'s welfare.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Communication Protocols', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...protocols.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(p.$1, color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(p.$3, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
