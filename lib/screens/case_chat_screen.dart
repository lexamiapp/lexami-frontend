import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/case_message.dart';
import '../models/legal_case.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class CaseChatScreen extends StatefulWidget {
  final LegalCase legalCase;
  const CaseChatScreen({super.key, required this.legalCase});

  @override
  State<CaseChatScreen> createState() => _CaseChatScreenState();
}

class _CaseChatScreenState extends State<CaseChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final profile = await firestore.getUserProfile(auth.currentUserId!);

    final message = CaseMessage(
      id: '',
      senderId: auth.currentUserId!,
      senderName: profile?.fullName ?? 'User',
      text: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );

    await firestore.sendCaseMessage(widget.legalCase.id, message);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final firestore = Provider.of<FirestoreService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Case Discussion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.legalCase.title, style: const TextStyle(fontSize: 10)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CaseMessage>>(
              stream: firestore.streamCaseMessages(widget.legalCase.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.messagesSquare, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No messages yet. Start the discussion!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == auth.currentUserId;
                    return _buildChatBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(CaseMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(msg.senderName, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
            if (!isMe) const SizedBox(height: 4),
            Text(msg.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13, height: 1.4)),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.timestamp),
              style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, 
        right: 16, 
        top: 8, 
        bottom: MediaQuery.of(context).padding.bottom + 8
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Discuss case progress...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue.shade900,
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(LucideIcons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
