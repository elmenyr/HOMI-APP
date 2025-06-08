import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatbotPage extends StatefulWidget {
  final String apiKey;
  
  const ChatbotPage({required this.apiKey, Key? key}) : super(key: key);

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late final GenerativeModel _model;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _chatDocumentId;

  static const String _realEstateExpertPrompt = '''
{
  "name": "RealEstateAssistant",
  "description": "أنت مساعد عقاري ذكي ومتخصص في كل ما يتعلق بالعقارات. تقدم إجابات دقيقة وواضحة حول شراء وبيع العقارات، الإيجار، أسعار المناطق، نصائح الاستثمار العقاري، وأنواع العقارات المختلفة. تتواصل مع المستخدم باللغة العربية فقط.",
  "instructions": "عندما يسأل المستخدم عن موضوع متعلق بالعقارات (مثل شراء شقة، استئجار منزل، مقارنة بين مناطق، نصائح استثمار، أنواع الشقق أو الفيلات، الخ)، قدم إجابة واضحة، مفيدة، ومختصرة باللغة العربية. إذا كان السؤال خارج مجال العقارات، اعتذر بأدب ووضح أنك متخصص فقط في الأمور العقارية.",
  "example_inputs": [
    "أرغب في شراء شقة في القاهرة، ما هي أفضل المناطق؟",
    "ما الفرق بين الشقة والدوبلكس؟",
    "كم يبلغ سعر المتر في التجمع الخامس؟",
    "هل الاستثمار في العقارات السكنية أفضل أم التجارية؟",
    "ما هي شروط استئجار شقة في مصر؟"
  ],
  "example_outputs": [
    "من أفضل مناطق القاهرة لشراء شقة: التجمع الخامس، مدينة نصر، مصر الجديدة. حسب ميزانيتك يمكنك الاختيار.",
    "الشقة تكون في دور واحد، بينما الدوبلكس يتكون من دورين متصلين داخلياً.",
    "يبلغ متوسط سعر المتر في التجمع الخامس حوالي 20,000 إلى 35,000 جنيه حسب الموقع والخدمات.",
    "الاستثمار في العقارات التجارية عادة يحقق عوائد أعلى، لكنه يحتاج رأس مال أكبر مقارنة بالعقارات السكنية.",
    "عادة تحتاج إلى عقد موثق، إثبات هوية، ودفع مقدم تأمين يعادل شهرين إلى ثلاثة أشهر من الإيجار."
  ]
}

ملاحظة هامة: أنت مساعد عقاري متخصص. ترد دائماً باللغة العربية فقط، وتبقي إجاباتك دقيقة، مفيدة، ومختصرة.
''';

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: widget.apiKey,
    );
    _createOrLoadChatSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // Create a new chat session or load an existing one
  Future<void> _createOrLoadChatSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Try to find the most recent chat session
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chatSessions')
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        // Load existing chat session
        final doc = querySnapshot.docs.first;
        _chatDocumentId = doc.id;
        
        // Load previous messages
        final messagesSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('chatSessions')
            .doc(_chatDocumentId)
            .collection('messages')
            .orderBy('timestamp')
            .get();
        
        if (mounted) {
          setState(() {
            _messages.clear();
            for (var messageDoc in messagesSnapshot.docs) {
              final data = messageDoc.data();
              _messages.add(ChatMessage(
                text: data['text'] as String? ?? '',
                isUser: data['isUser'] as bool? ?? true,
              ));
            }
          });
        }
      } else {
        // Create a new chat session
        final docRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('chatSessions')
            .add({
              'createdAt': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp(),
              'title': 'مُحادثة عقارية جديدة',
            });
        
        _chatDocumentId = docRef.id;
      }
    } catch (e) {
      debugPrint('Error creating/loading chat session: $e');
    }
  }
  
  // Save message to Firestore
  Future<void> _saveMessageToFirestore(ChatMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _chatDocumentId == null) return;
    
    try {
      // Add message to the messages subcollection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chatSessions')
          .doc(_chatDocumentId)
          .collection('messages')
          .add({
            'text': message.text,
            'isUser': message.isUser,
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      // Update the last updated timestamp of the chat session
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('chatSessions')
          .doc(_chatDocumentId)
          .update({
            'lastUpdated': FieldValue.serverTimestamp(),
            // Update title based on first user message if it's the first message
            if (_messages.length <= 2 && message.isUser)
              'title': message.text.length > 30 
                  ? '${message.text.substring(0, 30)}...' 
                  : message.text,
          });
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<String> _generateResponse(String prompt) async {
    try {
      final content = [Content.text("$_realEstateExpertPrompt\n\nسؤال المستخدم: $prompt")];
      final response = await _model.generateContent(content);
      return response.text ?? "عذراً، لم أتمكن من توليد إجابة في الوقت الحالي.";
    } catch (e) {
      debugPrint('Error generating response: $e');
      return "عذراً، حدث خطأ أثناء معالجة طلبك. حاول مرة أخرى لاحقاً.";
    }
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    final userMessage = ChatMessage(
      text: text,
      isUser: true,
    );
    
    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });
    
    // Save user message to Firestore
    await _saveMessageToFirestore(userMessage);

    try {
      final responseText = await _generateResponse(text);

      if (!mounted) return;
      
      final botMessage = ChatMessage(
        text: responseText,
        isUser: false,
      );
      
      setState(() {
        _isTyping = false;
        _messages.add(botMessage);
      });
      
      // Save bot response to Firestore
      await _saveMessageToFirestore(botMessage);
      
    } catch (e) {
      if (!mounted) return;
      
      final errorMessage = ChatMessage(
        text: 'عذراً، حدث خطأ أثناء معالجة طلبك. حاول مرة أخرى لاحقاً.',
        isUser: false,
      );
      
      setState(() {
        _isTyping = false;
        _messages.add(errorMessage);
      });
      
      // Save error message to Firestore
      await _saveMessageToFirestore(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.blue.shade600,
              Colors.blue.shade400,
              Colors.blue.shade200,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'مساعد هومي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages.reversed.toList()[index];
                  return FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: ChatBubble(
                      message: message.text,
                      isUser: message.isUser,
                    ),
                  );
                },
              ),
            ),
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'جاري الكتابة...',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك هنا...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: () => _handleSubmitted(_messageController.text),
                    backgroundColor: Colors.blue.shade700,
                    child: const Icon(Iconsax.send_1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.blue.shade700,
                child: const Icon(Iconsax.message_text_1, color: Colors.white),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue.shade700 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: Colors.blue.shade200,
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
} 