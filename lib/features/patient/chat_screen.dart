import 'package:hospital_app/providers/country_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hospital_app/core/theme/app_colors.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/services/gemini_ai_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? doctorId;
  final String? doctorName;
  const ChatScreen({super.key, this.doctorId, this.doctorName});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late final String _chatId;
  bool _isAIMode = false;
  final GeminiAIService _aiService = GeminiAIService();

  @override
  void initState() {
    super.initState();
    final String targetId = widget.doctorId ?? 'default_doctor';
    final List<String> ids = [_currentUserId, targetId]..sort();
    _chatId = ids.join('_');
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final text = _messageController.text.trim();
    _messageController.clear();

    if (_isAIMode) {
      // Direct AI Chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });

      _scrollToBottom();

      // Trigger AI Response
      final selectedCountry = ref.read(countryProvider);
      final analysis = await _aiService.analyzeSymptoms(text, country: selectedCountry);
      final aiResponse = "${analysis.summary}\n\n**Advice:**\n${analysis.advice.join('\n')}\n\n**Urgency:** ${analysis.urgency}";

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'text': aiResponse,
        'senderId': 'medicore_ai',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
      });
    } else {
      // Normal Doctor Chat
      final messageRef = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'lastMessage': text,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'participants': [_currentUserId, widget.doctorId ?? 'default_doctor'],
        'unreadCount_${widget.doctorId ?? 'default_doctor'}': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
    
    _scrollToBottom();
  }

  void _markMessagesAsRead() async {
    final unreadMessages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.update(FirebaseFirestore.instance.collection('chats').doc(_chatId), {
        'unreadCount_$_currentUserId': 0,
      });
      await batch.commit();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: isDark ? AppColors.backgroundDark : AppColors.background,
            ),
          ),
          
          Column(
            children: [
              _buildChatHeader(context, isDark),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(_chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    
                    final messages = snapshot.data!.docs;
                    
                    // Mark messages as read when new messages arrive
                    _markMessagesAsRead();
                    
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data() as Map<String, dynamic>;
                        final text = data['text'] ?? '';
                        final isMe = data['senderId'] == _currentUserId;
                        final isAI = data['senderId'] == 'medicore_ai';
                        final timestamp = data['timestamp'] as Timestamp?;
                        final time = timestamp?.toDate() ?? DateTime.now();
                        final timeStr = "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
                        
                        final isRead = data['isRead'] ?? true;
                        
                        return Column(
                          children: [
                            if (index == 0) _buildDateDivider(context, 'TODAY', isDark),
                            _buildMessageBubble(
                              context,
                              text,
                              isMe,
                              timeStr,
                              isDark,
                              isRead: isRead,
                              isAI: isAI,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _buildModernInputArea(context, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context, bool isDark) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 15, left: 10, right: 20),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.backgroundDark : Colors.white).withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage('https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=400'),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doctorName ?? 'Doctor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        color: isDark ? Colors.white : AppColors.textDeep,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.primary, 
                            fontSize: 12, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildHeaderAction(
                Icons.videocam_rounded, 
                isDark,
                onTap: () => _handleCall(context, 'Video Consultation'),
              ),
              const SizedBox(width: 10),
              _buildHeaderAction(
                Icons.call_rounded, 
                isDark,
                onTap: () => _handleCall(context, 'Voice Call'),
              ),
              const SizedBox(width: 10),
              _buildAIToggle(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIToggle(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() => _isAIMode = !_isAIMode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isAIMode ? 'Medicore AI Mode Activated' : 'Doctor Chat Mode Activated'),
            backgroundColor: _isAIMode ? AppColors.accent : AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isAIMode 
              ? AppColors.primary.withValues(alpha: 0.2) 
              : (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isAIMode ? AppColors.primary : (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          Icons.auto_awesome, 
          color: _isAIMode ? AppColors.primary : (isDark ? Colors.white : AppColors.textDeep), 
          size: 20
        ),
      ),
    ).animate(target: _isAIMode ? 1 : 0).shimmer(color: AppColors.primary.withValues(alpha: 0.3));
  }

  void _handleCall(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        borderRadius: 32,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'Voice Call' ? Icons.call_rounded : Icons.videocam_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start $type?',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will connect you with Dr. ${widget.doctorName ?? 'your doctor'} via a secure encrypted line.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Connecting to $type...'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: isDark ? Colors.white : AppColors.textDeep, size: 20),
      ),
    );
  }

  Widget _buildDateDivider(BuildContext context, String date, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            date,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? AppColors.secondary : AppColors.secondary, 
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, String message, bool isMe, String time, bool isDark, {bool isRead = true, bool isAI = false}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isMe 
                  ? AppColors.primary 
                  : isAI 
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : (isDark ? const Color(0xFF334155) : Colors.white),
              borderRadius: BorderRadius.circular(24).copyWith(
                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(24),
                bottomLeft: isMe ? const Radius.circular(24) : const Radius.circular(4),
              ),
              border: Border.all(
                color: isAI 
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05)
              ),
              boxShadow: [
                if (isMe) 
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                else if (isAI)
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                else if (!isDark)
                  BoxShadow(color: AppColors.textDeep.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAI) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Medicore AI',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    color: isMe ? Colors.white : (isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textDeep),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: isMe ? 0.2 : -0.2, curve: Curves.easeOutCubic),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.secondaryDark, fontSize: 10),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: isRead ? AppColors.primary : AppColors.secondaryDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildModernInputArea(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        border: Border(top: BorderSide(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05)),
            ),
            child: Icon(Icons.add_rounded, color: isDark ? Colors.white : AppColors.textDeep, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: (isDark ? Colors.white : AppColors.textDeep).withValues(alpha: 0.05)),
              ),
              child: TextField(
                controller: _messageController,
                onSubmitted: (_) => _sendMessage(),
                style: TextStyle(color: isDark ? Colors.white : AppColors.textDeep),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.secondaryDark, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
