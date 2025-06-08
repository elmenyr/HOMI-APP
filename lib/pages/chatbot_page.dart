import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:homi/models/property.dart';
import 'package:homi/pages/property_details_page.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:math';

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
  
  // Placeholders for property display
  List<Property> _lastQueriedProperties = [];
  bool _showPropertyCards = false;
  
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
    _loadRealEstateFAQs();
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

  // Query properties based on location, price range, or property type
  Future<List<Map<String, dynamic>>> _queryProperties({
    String? location,
    double? minPrice,
    double? maxPrice,
    String? propertyType,
    int? limit = 5
  }) async {
    try {
      Query query = _firestore.collection('properties');
      
      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }
      
      if (propertyType != null && propertyType.isNotEmpty) {
        query = query.where('type', isEqualTo: propertyType);
      }
      
      if (minPrice != null) {
        query = query.where('price', isGreaterThanOrEqualTo: minPrice);
      }
      
      if (maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: maxPrice);
      }
      
      // Add limit and sort by price
      query = query.orderBy('price').limit(limit!);
      
      final snapshot = await query.get();
      
      // Store the queried properties as Property objects for display
      _lastQueriedProperties = snapshot.docs
          .map((doc) => Property.fromFirestore(doc))
          .toList();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final property = Property.fromFirestore(doc);
        
        // Calculate distance to university
        final distanceToUniversity = _calculateDistanceToUniversity(
          property.latitude, 
          property.longitude
        );
        
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'price': data['price'] ?? 0.0,
          'location': data['location'] ?? '',
          'type': data['type'] ?? '',
          'bedrooms': data['bedrooms'] ?? 0,
          'bathrooms': data['bathrooms'] ?? 0,
          'imageUrl': data['imageUrl'] ?? '',
          'description': data['description'] ?? '',
          'hasWifi': data['hasWifi'] ?? false,
          'airCond': data['airCond'] ?? false,
          'gender': data['gender'] ?? '',
          'hasInsurance': data['hasInsurance'] ?? 0,
          'distanceToUniversity': distanceToUniversity,
          'rating': data['rating'] ?? 0.0,
          'ratingCount': data['ratingCount'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error querying properties: $e');
      return [];
    }
  }
  
  // Calculate distance to Sina University
  double _calculateDistanceToUniversity(double lat, double lng) {
    // Sina University coordinates
    const double universityLat = 30.879281936554452;
    const double universityLng = 32.37214142149693;
    
    return _calculateDistance(lat, lng, universityLat, universityLng);
  }
  
  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
  
  // Check if message is asking about property details
  bool _isAskingAboutPropertyDetails(String message) {
    final detailsPatterns = [
      'تفاصيل', 'المسافة', 'وصف', 'خدمات', 'مميزات', 'الويفي', 'التكييف',
      'details', 'distance', 'description', 'amenities', 'features', 'wifi', 'AC'
    ];
    
    int matchCount = 0;
    for (final pattern in detailsPatterns) {
      if (message.toLowerCase().contains(pattern.toLowerCase())) {
        matchCount++;
      }
    }
    
    return matchCount >= 1;
  }
  
  // Check if message is asking to navigate to property details page
  bool _isAskingToNavigateToProperty(String message) {
    final navigationPatterns = [
      'افتح', 'اذهب', 'انتقل', 'أرني الصفحة', 'عرض الصفحة', 'صفحة التفاصيل',
      'open', 'go to', 'navigate', 'show page', 'details page', 'view', 'see the page'
    ];
    
    int matchCount = 0;
    for (final pattern in navigationPatterns) {
      if (message.toLowerCase().contains(pattern.toLowerCase())) {
        matchCount++;
      }
    }
    
    return matchCount >= 1;
  }

  // Find property by ID or closest match to the requested details
  Future<Map<String, dynamic>?> _findPropertyByDetails(String message) async {
    // First try to find a property ID in the message
    final idRegex = RegExp(r'ID[:\s]*([a-zA-Z0-9]+)');
    final idMatch = idRegex.firstMatch(message);
    
    if (idMatch != null && idMatch.groupCount >= 1) {
      final propertyId = idMatch.group(1);
      try {
        final doc = await _firestore.collection('properties').doc(propertyId ?? '').get();
        if (doc.exists) {
          final property = Property.fromFirestore(doc);
          final distanceToUniversity = _calculateDistanceToUniversity(
            property.latitude, 
            property.longitude
          );
          
          final data = doc.data();
          if (data != null) {
            return {
              'id': doc.id,
              'title': data['title'] as String? ?? '',
              'price': (data['price'] as num?)?.toDouble() ?? 0.0,
              'location': data['location'] as String? ?? '',
              'type': data['type'] as String? ?? '',
              'bedrooms': (data['bedrooms'] as num?)?.toInt() ?? 0,
              'bathrooms': (data['bathrooms'] as num?)?.toInt() ?? 0,
              'imageUrl': data['imageUrl'] as String? ?? '',
              'description': data['description'] as String? ?? '',
              'hasWifi': data['hasWifi'] as bool? ?? false,
              'airCond': data['airCond'] as bool? ?? false,
              'gender': data['gender'] as String? ?? '',
              'hasInsurance': (data['hasInsurance'] as num?)?.toInt() ?? 0,
              'distanceToUniversity': distanceToUniversity,
              'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
              'ratingCount': (data['ratingCount'] as num?)?.toInt() ?? 0,
            };
          }
        }
      } catch (e) {
        debugPrint('Error finding property by ID: $e');
      }
    }
    
    // If no ID found or property not found by ID, try to find by extracting details
    final location = _extractLocation(message);
    final propertyType = _extractPropertyType(message);
    final priceRange = _extractPriceRange(message: message);
    
    // Query properties based on extracted information
    final properties = await _queryProperties(
      location: location,
      propertyType: propertyType,
      minPrice: priceRange?['min'],
      maxPrice: priceRange?['max'],
      limit: 1, // Just get the closest match
    );
    
    return properties.isNotEmpty ? properties.first : null;
  }

  // Extract location keywords from user message
  String? _extractLocation(String message) {
    final List<String> locationKeywords = [
      'القاهرة', 'التجمع', 'مدينة نصر', 'المعادي', 'الإسكندرية', 
      'الجيزة', 'الشيخ زايد', 'أكتوبر', '6 أكتوبر'
    ];
    
    for (final location in locationKeywords) {
      if (message.contains(location)) {
        return location;
      }
    }
    return null;
  }
  
  // Extract property type from user message
  String? _extractPropertyType(String message) {
    final List<String> typeKeywords = [
      'شقة', 'فيلا', 'دوبلكس', 'ستوديو', 'بنتهاوس'
    ];
    
    for (final type in typeKeywords) {
      if (message.contains(type)) {
        return type;
      }
    }
    return null;
  }
  
  // Extract price range from user message
  Map<String, double>? _extractPriceRange({required String message}) {
    // Simple regex to find numbers that might be prices
    final RegExp priceRegex = RegExp(r'(\d+)[^\d]*(الف|مليون|k|K|M|m)');
    final matches = priceRegex.allMatches(message);
    
    if (matches.isEmpty) return null;
    
    double? minPrice;
    double? maxPrice;
    
    for (final match in matches) {
      final number = double.parse(match.group(1)!);
      final unit = match.group(2);
      
      double value = number;
      if (unit == 'الف' || unit == 'k' || unit == 'K') {
        value = number * 1000;
      } else if (unit == 'مليون' || unit == 'm' || unit == 'M') {
        value = number * 1000000;
      }
      
      if (minPrice == null || value < minPrice) {
        minPrice = value;
      }
      
      if (maxPrice == null || value > maxPrice) {
        maxPrice = value;
      }
    }
    
    if (minPrice != null && maxPrice != null) {
      return {'min': minPrice, 'max': maxPrice};
    } else if (minPrice != null) {
      return {'min': minPrice};
    } else if (maxPrice != null) {
      return {'max': maxPrice};
    }
    
    return null;
  }

  // Cached FAQ data to avoid repeated Firestore queries
  List<Map<String, String>> _realEstateFAQs = [];

  // Load frequently asked real estate questions and answers from Firestore
  Future<void> _loadRealEstateFAQs() async {
    try {
      final snapshot = await _firestore.collection('realEstateFAQs').get();
      
      // If collection is empty, populate with sample data
      if (snapshot.docs.isEmpty) {
        await _populateSampleFAQs();
        // Query again after populating
        final newSnapshot = await _firestore.collection('realEstateFAQs').get();
        snapshot.docs.addAll(newSnapshot.docs);
      }
      
      final faqs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'question': data['question'] as String? ?? '',
          'answer': data['answer'] as String? ?? '',
          'category': data['category'] as String? ?? 'general',
        };
      }).toList();
      
      setState(() {
        _realEstateFAQs = List<Map<String, String>>.from(faqs);
      });
      
      debugPrint('Loaded ${_realEstateFAQs.length} FAQs from Firestore');
    } catch (e) {
      debugPrint('Error loading real estate FAQs: $e');
    }
  }
  
  // Populate sample FAQs if collection is empty
  Future<void> _populateSampleFAQs() async {
    final batch = _firestore.batch();
    
    final sampleFAQs = [
      {
        'question': 'ما هي أفضل المناطق للاستثمار العقاري في مصر؟',
        'answer': 'من أفضل المناطق للاستثمار العقاري في مصر: العاصمة الإدارية الجديدة، القاهرة الجديدة، الشيخ زايد، السادس من أكتوبر، والساحل الشمالي. تختلف العوائد الاستثمارية حسب المنطقة والمشروع.',
        'category': 'investment'
      },
      {
        'question': 'كيف أعرف سعر المتر في منطقة معينة؟',
        'answer': 'يمكنك معرفة سعر المتر في منطقة معينة من خلال: متابعة الإعلانات العقارية، التواصل مع وسطاء عقاريين، استخدام المواقع الإلكترونية المتخصصة، أو الاستعانة بخبير تقييم عقاري.',
        'category': 'pricing'
      },
      {
        'question': 'ما هو الفرق بين الدوبلكس والتاون هاوس؟',
        'answer': 'الدوبلكس هو شقة من طابقين متصلين بسلم داخلي. أما التاون هاوس فهو منزل صغير مستقل يكون ضمن مجمع سكني، ويتكون غالباً من طابقين أو ثلاثة ويتضمن حديقة خاصة.',
        'category': 'types'
      },
      {
        'question': 'ما هي أنواع التشطيبات المختلفة للشقق؟',
        'answer': 'أنواع التشطيبات الشائعة هي: بدون تشطيب (على العظم)، نصف تشطيب، تشطيب عادي، تشطيب فاخر (سوبر لوكس)، وتشطيب فاخر جداً (ألترا لوكس).',
        'category': 'construction'
      },
      {
        'question': 'ما هي المستندات المطلوبة لشراء شقة؟',
        'answer': 'المستندات المطلوبة لشراء شقة تشمل: صورة بطاقة الرقم القومي، شهادة عدم وجود سجل جنائي، صحيفة الحالة الجنائية، كشف حساب بنكي، وإثبات مصدر الدخل.',
        'category': 'legal'
      },
      {
        'question': 'ما هي مميزات وعيوب السكن في الأدوار العليا؟',
        'answer': 'مميزات السكن في الأدوار العليا: إطلالات أفضل، هواء نقي، إضاءة طبيعية، هدوء أكبر. عيوب السكن في الأدوار العليا: الاعتماد على المصاعد، صعوبة الوصول في حالات انقطاع الكهرباء، ارتفاع تكلفة نقل الأثاث والمستلزمات.',
        'category': 'living'
      },
      {
        'question': 'كيف أتأكد من سلامة العقار قبل الشراء؟',
        'answer': 'للتأكد من سلامة العقار قبل الشراء: تحقق من تراخيص البناء، استعن بمهندس لفحص العقار، تأكد من عدم وجود مخالفات بناء، تحقق من أصول ملكية العقار، اسأل عن تاريخ بناء العقار وحالته الإنشائية.',
        'category': 'safety'
      },
      {
        'question': 'ما هي أنظمة السداد المتاحة عند شراء شقة؟',
        'answer': 'أنظمة السداد عند شراء شقة تشمل: الدفع النقدي الكامل (كاش)، التقسيط المباشر من المطور العقاري، التمويل العقاري من البنوك، نظام التأجير المنتهي بالتمليك.',
        'category': 'financing'
      },
      {
        'question': 'متى يكون الوقت المناسب لشراء عقار؟',
        'answer': 'الوقت المناسب لشراء عقار يعتمد على: حالة السوق العقاري (ركود أو انتعاش)، توفر السيولة المالية لديك، الحاجة الفعلية للسكن أو الاستثمار، توقعات تغير أسعار العقارات في المستقبل القريب.',
        'category': 'timing'
      },
      {
        'question': 'ما هي أهم النقاط التي يجب مراعاتها عند اختيار الشقة؟',
        'answer': 'عند اختيار الشقة يجب مراعاة: الموقع والمنطقة، المساحة ومناسبتها لاحتياجاتك، الاتجاه والتهوية، جودة التشطيب، الخدمات المتوفرة في المبنى والمنطقة المحيطة، سهولة المواصلات، مدى قرب الخدمات الأساسية مثل المدارس والمستشفيات.',
        'category': 'buying'
      }
    ];
    
    for (final faq in sampleFAQs) {
      final docRef = _firestore.collection('realEstateFAQs').doc();
      batch.set(docRef, {
        'question': faq['question'],
        'answer': faq['answer'],
        'category': faq['category'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    debugPrint('Created sample FAQs in Firestore');
  }
  
  // Find relevant FAQs from our knowledge base
  List<Map<String, String>> _findRelevantFAQs(String userMessage, {int limit = 3}) {
    if (_realEstateFAQs.isEmpty) return [];
    
    // Simple keyword matching - could be enhanced with NLP/embedding similarity
    final List<String> keywords = [
      'سعر', 'شقة', 'منزل', 'فيلا', 'إيجار', 'بيع', 'شراء', 'استثمار',
      'عقار', 'تمويل', 'قرض', 'رهن', 'عقاري', 'مساحة', 'غرف', 'موقع',
      'مناطق', 'وسيط', 'سمسار', 'عقد', 'دوبلكس', 'ستوديو'
    ];
    
    // Score each FAQ based on keyword matches in the question
    final scoredFAQs = _realEstateFAQs.map((faq) {
      int score = 0;
      for (final keyword in keywords) {
        if (userMessage.contains(keyword)) {
          if (faq['question']!.contains(keyword)) {
            score += 2;
          }
          if (faq['answer']!.contains(keyword)) {
            score += 1;
          }
        }
      }
      return {'faq': faq, 'score': score};
    }).toList();
    
    // Sort by score and take top matches
    scoredFAQs.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    return scoredFAQs
        .take(limit)
        .where((item) => (item['score'] as int) > 0)
        .map((item) => item['faq'] as Map<String, String>)
        .toList();
  }

  // Check if message is asking to see or show properties
  bool _isAskingToShowProperties(String message) {
    final showPropertyPatterns = [
      'أرني', 'أظهر', 'شقق', 'عرض', 'العقارات', 'المتاحة', 'الشقق',
      'show', 'display', 'available', 'properties', 'see', 'view',
      'عقارات', 'في', 'متاحة', 'شوف', 'شاهد', 'look', 'find'
    ];
    
    int matchCount = 0;
    for (final pattern in showPropertyPatterns) {
      if (message.toLowerCase().contains(pattern.toLowerCase())) {
        matchCount++;
      }
    }
    
    // If at least 2 patterns match, it's likely asking to show properties
    return matchCount >= 2;
  }

  // Navigate to a specific property details page
  void _navigateToPropertyDetailsPage(String propertyId) async {
    try {
      final doc = await _firestore.collection('properties').doc(propertyId).get();
      if (doc.exists) {
        final property = Property.fromFirestore(doc);
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FeatureDiscovery(
                child: PropertyDetailsPage(property: property),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error navigating to property details page: $e');
    }
  }

  Future<String> _generateResponse(String prompt) async {
    try {
      // Check if asking to show properties
      final isAskingForProperties = _isAskingToShowProperties(prompt);
      // Check if asking about property details
      final isAskingAboutDetails = _isAskingAboutPropertyDetails(prompt);
      // Check if asking to navigate to property page
      final isAskingToNavigate = _isAskingToNavigateToProperty(prompt);
      
      // Extract property search parameters from user message
      final location = _extractLocation(prompt);
      final propertyType = _extractPropertyType(prompt);
      final priceRange = _extractPriceRange(message: prompt);
      
      // Handle navigation request
      if (isAskingToNavigate) {
        // Look for property ID in message or context
        final idRegex = RegExp(r'ID[:\s]*([a-zA-Z0-9]+)');
        final idMatch = idRegex.firstMatch(prompt);
        
        String? propertyId;
        if (idMatch != null && idMatch.groupCount >= 1) {
          propertyId = idMatch.group(1);
        } else if (_lastQueriedProperties.isNotEmpty) {
          // Use the first property from last query if available
          propertyId = _lastQueriedProperties.first.id;
        }
        
        if (propertyId != null) {
          // Schedule navigation after response is displayed
          Future.delayed(const Duration(milliseconds: 500), () {
            _navigateToPropertyDetailsPage(propertyId!);
          });
          
          return "سأقوم بفتح صفحة تفاصيل العقار الآن. انتظر لحظة من فضلك...";
        }
      }
      
      // Get detailed property information if asking about specific details
      Map<String, dynamic>? specificProperty;
      String detailedPropertyInfo = '';
      bool hasShownPropertyDetails = false;
      
      if (isAskingAboutDetails) {
        specificProperty = await _findPropertyByDetails(prompt);
        if (specificProperty != null) {
          hasShownPropertyDetails = true;
          final bool hasWifi = specificProperty['hasWifi'] as bool? ?? false;
          final bool hasAirCond = specificProperty['airCond'] as bool? ?? false;
          final int insuranceAmount = specificProperty['hasInsurance'] as int? ?? 0;
          
          detailedPropertyInfo = '''
معلومات تفصيلية عن العقار: ${specificProperty['title']}

الموقع: ${specificProperty['location']}
السعر: ${specificProperty['price']} جنيه
النوع: ${specificProperty['type']}
عدد الغرف: ${specificProperty['bedrooms']}
عدد الحمامات: ${specificProperty['bathrooms']}
الجنس المفضل: ${specificProperty['gender']}
المسافة إلى الجامعة: ${specificProperty['distanceToUniversity'].toStringAsFixed(2)} كم
واي فاي: ${hasWifi ? 'متوفر' : 'غير متوفر'}
تكييف: ${hasAirCond ? 'متوفر' : 'غير متوفر'}
تأمين: ${insuranceAmount > 0 ? '$insuranceAmount جنيه' : 'لا يوجد'}
التقييم: ${specificProperty['rating'].toStringAsFixed(1)}/5 (${specificProperty['ratingCount']} تقييم)

الوصف:
${specificProperty['description']}

إذا كنت ترغب في رؤية صفحة تفاصيل العقار كاملة، يمكنك كتابة "افتح صفحة العقار" أو "أرني الصفحة".
''';
        }
      }
      
      // Query Firestore for matching properties
      final properties = await _queryProperties(
        location: location,
        propertyType: propertyType,
        minPrice: priceRange?['min'],
        maxPrice: priceRange?['max'],
      );
      
      // Determine if we should show property cards
      setState(() {
        _showPropertyCards = (isAskingForProperties || (!hasShownPropertyDetails && properties.isNotEmpty)) 
            && _lastQueriedProperties.isNotEmpty;
      });
      
      // Find relevant FAQs from our knowledge base
      final relevantFAQs = _findRelevantFAQs(prompt);
      
      // Prepare property data to include in the prompt
      String propertyData = '';
      if (properties.isNotEmpty) {
        propertyData = 'بناءً على بياناتنا، وجدنا العقارات التالية التي قد تناسب احتياجاتك:\n';
        for (var i = 0; i < properties.length; i++) {
          final property = properties[i];
          propertyData += '''
${i+1}. ${property['title']} - ${property['location']} (ID: ${property['id']})
   السعر: ${property['price']} جنيه
   النوع: ${property['type']}
   عدد الغرف: ${property['bedrooms']}
   عدد الحمامات: ${property['bathrooms']}
   المسافة إلى الجامعة: ${property['distanceToUniversity'].toStringAsFixed(2)} كم
   
''';
        }
        
        // If user is asking to show properties, add a note to check below
        if (isAskingForProperties) {
          propertyData += '\nيمكنك الاطلاع على العقارات أدناه والضغط عليها لمزيد من التفاصيل. أو يمكنك أن تكتب "أرني تفاصيل العقار الأول" للحصول على المزيد من المعلومات.\n';
        }
      }
      
      // Add detailed property info if available
      if (detailedPropertyInfo.isNotEmpty) {
        propertyData += '\n$detailedPropertyInfo\n';
      }
      
      // Prepare FAQ data
      String faqData = '';
      if (relevantFAQs.isNotEmpty) {
        faqData = 'معلومات قد تكون مفيدة للإجابة على هذا السؤال:\n';
        for (var i = 0; i < relevantFAQs.length; i++) {
          final faq = relevantFAQs[i];
          faqData += '''
س: ${faq['question']}
ج: ${faq['answer']}

''';
        }
      }
      
      final combinedPrompt = '''
$_realEstateExpertPrompt

معلومات العقارات المتاحة:
$propertyData

$faqData

سؤال المستخدم: $prompt
''';
      
      final content = [Content.text(combinedPrompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "عذراً، لم أتمكن من توليد إجابة في الوقت الحالي.";
    } catch (e) {
      debugPrint('خطأ أثناء توليد الرد: $e');
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
      // Reset property cards when sending a new message
      _showPropertyCards = false;
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
                itemCount: _messages.length + (_showPropertyCards ? 1 : 0),
                itemBuilder: (context, index) {
                  // Add property cards after the last message
                  if (_showPropertyCards && index == 0) {
                    return _buildPropertyCardsSection();
                  }
                  
                  final adjustedIndex = _showPropertyCards ? index - 1 : index;
                  final message = _messages.reversed.toList()[adjustedIndex];
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
  
  // Build the property cards section
  Widget _buildPropertyCardsSection() {
    if (_lastQueriedProperties.isEmpty) {
      return Container();
    }
    
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text(
              'العقارات المتاحة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _lastQueriedProperties.length,
              itemBuilder: (context, index) {
                final property = _lastQueriedProperties[index];
                return _buildPropertyCard(property);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Build a single property card
  Widget _buildPropertyCard(Property property) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FeatureDiscovery(
                child: PropertyDetailsPage(property: property),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: property.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Iconsax.gallery,
                      size: 40,
                      color: Color(0xFF26A69A),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.location,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${property.price} جنيه',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.bed_outlined,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${property.bedrooms}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.bathtub_outlined,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${property.bathrooms}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
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

  // Query properties by type for trending section
  Future<List<Property>> _getTrendingProperties(String type, {int limit = 3}) async {
    try {
      final snapshot = await _firestore
          .collection('properties')
          .where('type', isEqualTo: type)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs.map((doc) => Property.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting trending properties: $e');
      return [];
    }
  }
  
  // Handle a specific request for properties by type
  Future<void> _handleTypeSpecificRequest(String type) async {
    try {
      final properties = await _getTrendingProperties(type);
      
      setState(() {
        _lastQueriedProperties = properties;
        _showPropertyCards = properties.isNotEmpty;
      });
      
    } catch (e) {
      debugPrint('Error handling type specific request: $e');
    }
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