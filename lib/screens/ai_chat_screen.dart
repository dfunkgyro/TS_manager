import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:track_sections_manager/services/enhanced_ai_agent.dart';
import 'package:track_sections_manager/services/voice_recognition_service.dart';
import 'package:intl/intl.dart';

/// AI Chat Screen with voice recognition support
class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final EnhancedAIAgent _aiAgent = EnhancedAIAgent();
  late VoiceRecognitionService _voiceService;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceRecognitionService();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    setState(() => _isLoading = true);
    await _aiAgent.initialize();
    setState(() => _isLoading = false);

    // Add welcome message
    _addAssistantMessage(_getWelcomeMessage());
  }

  String _getWelcomeMessage() {
    return '''👋 Hello! I'm your Railway Track Sections Manager AI Assistant.

${_aiAgent.getStatusString()}

I can help you with:
🔍 Finding track sections and LCS codes
🧭 Navigating app features
⚠️  Managing TSRs
⚡ Batch operations
📥 Data export
❓ Answering questions

Try saying or typing: "Find District line track sections" or "How do I create a TSR?"

💬 **Voice Input Available!** Tap the microphone button to speak.''';
  }

  void _addAssistantMessage(String content) {
    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String content) {
    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: content,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    _addUserMessage(message);
    _messageController.clear();

    setState(() => _isLoading = true);

    try {
      final response = await _aiAgent.chat(
        message,
        context: _buildContext(),
      );

      _addAssistantMessage(response);
    } catch (e) {
      _addAssistantMessage('❌ Sorry, I encountered an error: $e\n\nPlease try again or rephrase your question.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _buildContext() {
    return {
      'screen': 'ai_chat',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _startVoiceInput() async {
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
      return;
    }

    await _voiceService.startListening(
      onResult: (text) {
        setState(() {
          _messageController.text = text;
        });

        // Auto-send if confidence is high and it's a final result
        if (_voiceService.confidence > 0.7 && text.trim().isNotEmpty) {
          _sendMessage(text);
        }
      },
    );
  }

  Future<void> _speakMessage(String text) async {
    if (_isSpeaking) {
      await _voiceService.stopSpeaking();
      setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    await _voiceService.speak(text);
    setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          // AI Status Indicator
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                _aiAgent.getStatusString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          // Clear Chat
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Chat',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat?'),
                  content: const Text('This will delete all messages in this conversation.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _aiAgent.clearHistory();
                        });
                        Navigator.pop(context);
                        _addAssistantMessage(_getWelcomeMessage());
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Banner
          if (!_aiAgent.isApiConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Using Local AI (API not connected). Responses may be limited.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildLoadingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Voice Recognition Indicator
          if (_voiceService.isListening)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Listening... "${_voiceService.lastWords}"',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Voice Input Button
                if (_voiceService.speechAvailable)
                  IconButton(
                    icon: Icon(
                      _voiceService.isListening ? Icons.mic_off : Icons.mic,
                      color: _voiceService.isListening ? Colors.red : Colors.blue,
                    ),
                    onPressed: _startVoiceInput,
                    tooltip: _voiceService.isListening ? 'Stop Listening' : 'Voice Input',
                  ),

                // Text Input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type or speak your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    enabled: !_isLoading,
                  ),
                ),

                const SizedBox(width: 8),

                // Send Button
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading
                      ? null
                      : () => _sendMessage(_messageController.text),
                  color: Theme.of(context).primaryColor,
                  disabledColor: Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a Conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about track sections,\nLCS codes, TSRs, or app features!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.smart_toy, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (!isUser && _voiceService.ttsAvailable) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _speakMessage(message.content),
                        child: Icon(
                          _isSpeaking ? Icons.volume_off : Icons.volume_up,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Icon(Icons.person, color: Theme.of(context).primaryColor),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    super.dispose();
  }
}
