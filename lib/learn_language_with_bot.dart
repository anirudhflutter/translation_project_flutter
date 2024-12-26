import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatMessage {
  final String sender;
  final String chatbot;
  final String user;

  ChatMessage({required this.sender, required this.chatbot,required this.user});
}

class LearnLanguageWithBotPage extends StatefulWidget {
  @override
  _LearnLanguageWithBotPageState createState() => _LearnLanguageWithBotPageState();
}

class _LearnLanguageWithBotPageState extends State<LearnLanguageWithBotPage> {
  final stt.SpeechToText _speech = stt.SpeechToText(); // Speech recognition instance
  late WebSocketChannel _channel; // WebSocket instance
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  String _transcription = ""; // Transcription text
  bool _isListening = false; // Listening state
  String _selectedLanguage = "English"; // Default language to learn
  String _selectedLevel = "Beginner"; // Default level
  String _selectedCategory = "greetings"; // Selected category
  String _suggestedResponse = ""; // Suggested response text
  bool _isLoading = false; // Loading state for backend responses
  bool isStart = true;

  void _initializeTTS(String _suggestedResponse) async {
    await _flutterTts.setLanguage(_selectedLanguage == "English" ? "en-US" : "de-DE");
    await _flutterTts.setPitch(1.0); // Normal pitch
    await _flutterTts.setSpeechRate(0.5); // Normal speech rate
    _speak(_suggestedResponse);
  }

  void _speak(String text) async {
    await _flutterTts.setLanguage(_selectedLanguage == "English" ? "en-US" : "de-DE");
    print(text);
    await _flutterTts.speak(text);
  }

  void _stop() async {
    await _flutterTts.stop();
  }

  List extractSentences(String input) {
    // Regular expression to match sentences after "Yours Sentence:" and "My Sentence:"
    final regex = RegExp(r'Yours Sentence: (.*?)\s*My Sentence: (.*)');

    final match = regex.firstMatch(input);
    if (match != null) {
      // Extract groups 1 and 2 from the regex match
      String yoursSentence = match.group(2) ?? "";
      String mySentence = match.group(1) ?? "";

      print("Yours Sentence: $yoursSentence");
      print("My Sentence: $mySentence");
      return [yoursSentence,mySentence];
    } else {
      print("Sentences not found");
      return [];
    }
  }

  // Establish WebSocket connection
  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://1734-2001-9e8-707-700-e513-77a7-54fd-389b.ngrok-free.app/ws/'),
    );
    _channel.stream.listen((data) {
      final response = jsonDecode(data);
      List Sentences = [];
      print("Received from backend: $response");
        setState(() {
          Sentences = extractSentences(response['suggestion']);
          _suggestedResponse = response['suggestion'] ?? "";
          _isLoading = false;
          _messages.add(ChatMessage(
            sender: "bot",
            chatbot: Sentences[1],
            user: Sentences[0]
          ));
        });
        if(Sentences.isNotEmpty && isStart) {
          _initializeTTS("Welcome to my world. Lets begin. ${Sentences[1]}. Now tap on that button so I can listen to you and speak ${Sentences[0]}");
        }
        else{
          _initializeTTS(Sentences[1]);
        }
      //_startListening();
    });
  }

  // Start speech recognition
  void _startListening() async {
    _connectWebSocket();
    if (!await Permission.microphone.isGranted) {
      await Permission.microphone.request();
    }
    isStart = false;
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Status: $status');
      },
      onError: (error) => print('Error: ${error.errorMsg}'),
      finalTimeout: const Duration(seconds: 1),
    );
    print("available $available");
    if (available) {
      setState(() {
        _isListening = true;
      });
      print("available123 $available");
      _speech.listen(
        onResult: (result) {
          print("Transcription: ${result.recognizedWords}");
          // Send data when speech recognition detects a final result
          if (result.finalResult) {
            _sendDataToWebSocket(isStart,result.recognizedWords);
          }
        },
        localeId: _selectedLanguage == "English" ? "en-US" : "de_DE",
        partialResults: true,
        cancelOnError: false,
        listenFor: const Duration(seconds: 30),
      );
    } else {
      print("Speech recognition not available");
    }
  }

  // Stop speech recognition
  void _stopListening() {
    setState(() {
      _isListening = false;
    });
    _speech.stop();
    _channel.sink.close();
  }

  // Send transcription data to backend via WebSocket
  void _sendDataToWebSocket(bool isStart,String text) {
    _connectWebSocket();
    setState(() {
      _isLoading = true;
    });
    final data = {
      'action': 'start_conversation',
      'language': _selectedLanguage,
      'level': _selectedLevel,
      'category': _selectedCategory,
      'is_translation' : false,
      'is_start' : isStart,
      'text' : text
    };

    _channel.sink.add(jsonEncode(data));
    print("Data sent to WebSocket: $data");
  }

  @override
  void dispose() {
    super.dispose();
    _speech.stop();
    _channel.sink.close();
  }

  List<ChatMessage> _messages = [];

  void _listenAndMatch(String text, Function(int) onWordMatched) async {
    if (!await _speech.initialize()) return;

    List<String> words = text.split(" ");
    int wordIndex = 0;

    _speech.listen(
      onResult: (result) {
        String spoken = result.recognizedWords.trim();
        List<String> spokenWords = spoken.split(" ");

        if (wordIndex < words.length && spokenWords.contains(words[wordIndex])) {
          onWordMatched(wordIndex);
          wordIndex++;
        }

        if (wordIndex >= words.length) {
          _speech.stop(); // Stop listening once all words are matched
        }
      },
      localeId: "en-US", // Set to "de-DE" for German
    );
  }

  Widget _buildColorChangingText(String text) {
    List<String> words = text.split(" ");
    List<Color> colors = List<Color>.filled(words.length, Colors.black);

    return StatefulBuilder(
      builder: (context, setState) {
        //_listenAndMatch(text, (index) {
        //  setState(() {
        //    colors[index] = Colors.green; // Highlight the matched word
        //  });
        //});

        return Wrap(
          spacing: 4,
          children: List.generate(words.length, (index) {
            return Text(
              words[index],
              style: TextStyle(color: colors[index], fontSize: 16),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "HachoVocho - Learn Language",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Language to Learn:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedLanguage,
                underline: SizedBox(),
                items: [
                  const DropdownMenuItem(
                    value: "English",
                    child: Text("English"),
                  ),
                  const DropdownMenuItem(
                    value: "German",
                    child: Text("German"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Select Level:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedLevel,
                underline: SizedBox(),
                items: [
                  const DropdownMenuItem(
                    value: "Beginner",
                    child: Text("Beginner"),
                  ),
                  const DropdownMenuItem(
                    value: "Intermediate",
                    child: Text("Intermediate"),
                  ),
                  const DropdownMenuItem(
                    value: "Advanced",
                    child: Text("Advanced"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Select Conversation Category:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedCategory.isEmpty ? null : _selectedCategory,
                underline: SizedBox(),
                hint: const Text("Select a category"),
                items: const [
                  DropdownMenuItem(
                    value: "greetings",
                    child: Text("Greetings"),
                  ),
                  DropdownMenuItem(
                    value: "travel",
                    child: Text("Travel"),
                  ),
                  DropdownMenuItem(
                    value: "introduction",
                    child: Text("Introduction"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () => _sendDataToWebSocket(isStart,''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("Start Conversation",style: TextStyle(color: Colors.white),),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final message = _messages[index];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Chatbot message on the right
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message.chatbot,
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),
                      ),
                      // User message on the left with a speaker button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildColorChangingText(message.user),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up, color: Colors.grey),
                              onPressed: () => _speak(message.user),
                            ),
                            IconButton(
                              onPressed: _startListening,
                              icon: const Icon(Icons.speaker, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
