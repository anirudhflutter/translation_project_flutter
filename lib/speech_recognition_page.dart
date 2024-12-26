import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechRecognitionPage extends StatefulWidget {
  @override
  _SpeechRecognitionPageState createState() => _SpeechRecognitionPageState();
}

class _SpeechRecognitionPageState extends State<SpeechRecognitionPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  late WebSocketChannel _channel;
  final ScrollController _scrollController = ScrollController();

  String _transcription = ""; // Transcribed text
  String _preferredLanguage = "en-US"; // Default preferred language
  String _buddyLanguage = "de-DE"; // Default buddy language
  String _selectedCategory = "greetings"; // Default category
  String _suggestedResponse = ""; // Suggested response
  String _translatedText = ""; // Translated text
  bool _isLoading = false; // Loading indicator
  bool _isListening = false; // Track the listening state
  final FlutterTts _flutterTts = FlutterTts();
  List<Map<String, String>> _messages = [
    {'sender': 'Buddy', 'message': 'German: Tippen Sie auf das Mikrofon, um das Gespräch zu beginnen! \n English: Tap the mic to start the conversation!'}
  ];

  void processSuggestion(String suggestion) {
    final deRegex = RegExp(r'de:\s*(.*?)\s*en:', dotAll: true, caseSensitive: false);
    final enRegex = RegExp(r'en:\s*(.*?)(?=\s*de:|$)', dotAll: true, caseSensitive: false);
    final deMatches = deRegex.allMatches(suggestion);
    final enMatches = enRegex.allMatches(suggestion);
    List<String> deTexts = [];
    List<String> enTexts = [];

    for (final match in deMatches) {
      print("de_match ${match}");
      print("de_match.group(1) ${match.group(1)}");
      deTexts.add(match.group(1) ?? "");
    }
    for (final match in enMatches) {
      print("en_match ${match}");
      enTexts.add(match.group(1) ?? "");
    }

    setState(() {
      if (_messages.isNotEmpty &&
          _messages[0]['message'] == 'German: Tippen Sie auf das Mikrofon, um das Gespräch zu beginnen! \n English: Tap the mic to start the conversation!') {
        _messages.removeAt(0);
      }
      _messages.removeWhere((message) =>
      message['sender'] == 'Buddy' && message['message']?.isEmpty == true);
      print("_preferredLanguage ${_preferredLanguage} ${_translatedText}");
      print("_buddyLanguage ${_buddyLanguage} ${_transcription}");
      _messages.add({'sender': 'Buddy', 'message': "${_buddyLanguage == "de-DE" ? "German: " : "English: " }$_transcription\n${_preferredLanguage == "de-DE" ? "German: " : "English: " }$_translatedText"});
      // Add the extracted texts to the chat messages
      String germanMessage = deTexts.join("\n"); // Combine all German texts into one string
      String englishMessage = enTexts.join("\n"); // Combine all English texts into one string
// Add a single message with combined German and English texts
      _messages.add({
        'sender': 'You',
        'message': "German: $germanMessage\nEnglish: $englishMessage",
      });
      _messages.add({'sender': 'Buddy', 'message': ""});
      // Scroll to the bottom of the list
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://c841-2001-9e8-70f-300-687c-d3d1-9b26-d9ff.ngrok-free.app/ws/'),
    );
    _channel.stream.listen((data) {
      final response = jsonDecode(data);
      print("Received from backend: $response");

      setState(() {
        _translatedText = response['translation'] ?? "";
        _suggestedResponse = response['suggestion'] ?? "";
        _isLoading = false;

        processSuggestion(_suggestedResponse); // Process the suggestion here
      });
    });
  }

  void _startListening(String language,bool _isListening) async {
    if (_isListening) return; // Don't start if already listening

    if (!await Permission.microphone.isGranted) {
      await Permission.microphone.request();
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if(status == 'notListening'){
          _isListening = false;
          _startListening("German",_isListening);
        }
        print('Status: $status');
      },
      onError: (error) => print('Error: ${error.errorMsg}'),
    );

    if (available) {
      setState(() {
        _isListening = true; // Update state to show active listening
      });

      _speech.listen(
        onResult: (result) {
          setState(() {
            _transcription = result.recognizedWords; // Update the transcription
          });
        },
        localeId: language == "en-US" ? "en-US" : "de_DE", // Set language
        //listenFor: Duration.zero, // Listen indefinitely
        pauseFor: Duration(seconds: 10)
      );
    } else {
      print("Speech recognition not available");
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false; // Reset the listening state
      });
      _sendDataToWebSocket();
    }
  }

  void _sendDataToWebSocket() {
    final data = {
      'action': 'conversation',
      'text': _transcription,
      'preferred_language': _preferredLanguage == 'en-US' ? "en" : "de",
      'buddy_language': _buddyLanguage == 'en-US' ? "en" : "de",
      'category': _selectedCategory,
      'is_translation' : true,
      'action':'send_data'
    };

    _channel.sink.add(jsonEncode(data));
    print("Data sent to WebSocket: $data");

  }

  @override
  void dispose() {
    _speech.stop();
    _channel.sink.close();
    super.dispose();
    _initializeTTS();
  }

  void _initializeTTS() async {
    await _flutterTts.setPitch(1.0); // Normal pitch
    await _flutterTts.setSpeechRate(0.5); // Normal speech rate
  }

  void _speak(String text,String language) async {
    await _flutterTts.setPitch(1.0); // Normal pitch
    await _flutterTts.setSpeechRate(0.5); // Normal speech rate
    await _flutterTts.setLanguage(language == "English" ? "en-US" : "de-DE");
    print(text);
    await _flutterTts.speak(text);
  }

  Widget richText(List words,String language){
    return Expanded(
      child: RichText(
        text: TextSpan(
          children: words.map((word) {
            return TextSpan(
              text: "$word ", // Add the word with a space
              style:  TextStyle(
                fontSize: 16,
                color: language == "English" ? Colors.red : Colors.black, // Normal sentence styling
                fontWeight: FontWeight.w600
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  _speak(word,language); // Speak the tapped word
                },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HachoVocho - Learn Language"),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select Your Preferred Language:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _preferredLanguage,
                  items: [
                    DropdownMenuItem(value: "en-US", child: Text("English")),
                    DropdownMenuItem(value: "de-DE", child: Text("German")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _preferredLanguage = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  "Select Buddy's Language:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _buddyLanguage,
                  items: [
                    DropdownMenuItem(value: "en-US", child: Text("English")),
                    DropdownMenuItem(value: "de-DE", child: Text("German")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _buddyLanguage = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  "Select Conversation Category:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory,
                  items: [
                    DropdownMenuItem(value: "greetings", child: Text("Greetings")),
                    DropdownMenuItem(value: "travel", child: Text("Travel")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              controller: _scrollController,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isBuddy = message['sender'] == 'Buddy';
                final messageText = message['message'] ?? "";
                // Split the message into German and English parts
                final germanText = RegExp(r'German:\s*(.*?)\n')
                    .firstMatch(messageText)
                    ?.group(1)
                    ?.trim() ?? "";
                final englishText = RegExp(r'English:\s*(.*)')
                    .firstMatch(messageText)
                    ?.group(1)
                    ?.trim() ?? "";

                final germanWords = germanText.split(' '); // Split the text into words
                final englishWords = englishText.split(' '); // Split the text into words
                return Align(
                  alignment:
                  isBuddy ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: isBuddy
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: message['message'] == "" ? Container() : Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isBuddy ? Colors.green[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Text(
                                          "German: ",
                                          style: TextStyle(fontSize: 16,color: Colors.black,fontWeight: FontWeight.w600),
                                        ),
                                        richText(germanWords,"German")
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up, color: Colors.black),
                                    onPressed: () {
                                      _speak(germanText, "German");
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // English text with icon
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Text(
                                          "English: ",
                                          style: TextStyle(fontSize: 16,color: Colors.red,fontWeight: FontWeight.bold),
                                        ),
                                        richText(englishWords,"English")
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.volume_up, color: Colors.black),
                                    onPressed: () {
                                      _speak(englishText, "English");
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isBuddy) // Buddy's side
                        IconButton(
                          icon: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.green),
                          onPressed: _isListening ? _stopListening : () => _startListening(_buddyLanguage,_isListening),
                        ),
                    ],
                  ),
                );
              }
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
