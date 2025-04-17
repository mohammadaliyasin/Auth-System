import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:login_ui/apiKey.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final String apiKey = GeminiApiKey.api_key;
  bool _isLoading = false;

  Future<bool> _isMedicalQuestion(String message) async {
    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "contents": [{
            "parts": [{
              "text": "Analyze if this question is strictly about medical/health topics. "
                      "Reply ONLY with 'true' or 'false':\n\n$message"
            }]
          }]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseText = data['candidates'][0]['content']['parts'][0]['text']
            .toLowerCase().trim();
        return responseText == 'true';
      }
      return false;
    } catch (e) {
      debugPrint('Medical check error: $e');
      return false;
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add({'type': 'user', 'message': message});
      _isLoading = true;
    });

    try {
      final isMedical = await _isMedicalQuestion(message);
      if (!isMedical) {
        _addBotMessage("❌ I specialize in medical topics only. Please ask health-related questions.");
        return;
      }

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "contents": [{
            "parts": [{
              "text": "You are a medical expert assistant. Provide concise, accurate medical information. "
                      "If a question is not medical-related, say so.\n\nUser: $message"
            }]
          }]
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        _addBotMessage(data['candidates'][0]['content']['parts'][0]['text']);
      } else {
        _addBotMessage("❌ Error: Failed to get AI response");
      }
    } catch (error) {
      _addBotMessage("❌ Connection error. Please try again.");
      debugPrint('API error: $error');
    } finally {
      _scrollToBottom();
    }
  }

  void _addBotMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add({'type': 'bot', 'message': message});
      _isLoading = false;
      _controller.clear();
    });
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

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['type'] == 'user';
    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Color(0xffd6fc51) : Color.fromRGBO(255, 255, 255, 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message['message'] ?? '',
          style: TextStyle(fontSize: 16,color: isUser ? Colors.black : Colors.white,),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff11151E),
      appBar: AppBar(
        title: const Text('🩺 AI Chat Assistant',style: TextStyle(color: Colors.white),),
        centerTitle: true,
        backgroundColor: Color(0xff11151E),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (_, index) => _buildMessage(_messages[index]),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color:  Color(0xff4361EE),),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    cursorColor: const Color(0xffd6fc51),
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask a medical question...',
                      hintStyle: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.6),),
                      filled: true,
                      fillColor: Color(0xff151A23),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xffd6fc51),),borderRadius: BorderRadius.circular(20),),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xffd6fc51),),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color.fromRGBO(255, 255, 255, 0.4),),
                  onPressed: () => _sendMessage(_controller.text.trim()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}