/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:translation/speech_recognition_page.dart';

import 'learn_language_with_bot.dart';
//import 'package:google_sign_in/google_sign_in.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HachoVocho - Fun Language',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SignInPage(),
    );
  }
}

class SignInPage extends StatelessWidget {
  //final GoogleSignIn _googleSignIn = GoogleSignIn();

  void _handleSignIn(BuildContext context) async {
    try {
      //await _googleSignIn.signIn();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MenuPage()),
      );
    } catch (error) {
      print('Sign in failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "HachoVocho - Fun Language",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _handleSignIn(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
          child: const Text(
            "Sign in with Google",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class MenuPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "HachoVocho - Fun Language",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LearnLanguageWithBotPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text("Learn Language with a Bot",style: TextStyle(color: Colors.white),),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SpeechRecognitionPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text("Learn with Buddy who knows language",style: TextStyle(color: Colors.white),),
            ),
          ],
        ),
      ),
    );
  }
}
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Speech Recognition',
      home: SpeechRecognizerScreen(),
    );
  }
}

class SpeechRecognizerScreen extends StatefulWidget {
  @override
  _SpeechRecognizerScreenState createState() => _SpeechRecognizerScreenState();
}

class _SpeechRecognizerScreenState extends State<SpeechRecognizerScreen> {
  // 1. Define a MethodChannel with a unique name.
  static const platform = MethodChannel('com.example.speechrecognizer/channel');

  String _recognizedText = "No speech yet...";
  bool _isListening = false;

  @override
  void initState() {
    super.initState();

    // 2. Set a MethodCallHandler to receive recognized text from Android.
    platform.setMethodCallHandler(_nativeCallbackHandler);
  }

  // This function will handle method calls from the Android side.
  Future<dynamic> _nativeCallbackHandler(MethodCall call) async {
    switch (call.method) {
      case "onSpeechResult":
      // Update recognized text in the UI.
        final String text = call.arguments ?? "";
        setState(() {
          _recognizedText = text;
        });
        break;
    }
    return null;
  }

  // 3. Start continuous listening by invoking the native method.
  Future<void> _startListening() async {
    if (_isListening) return;
    try {
      await platform.invokeMethod('startListening');
      setState(() {
        _isListening = true;
      });
    } on PlatformException catch (e) {
      print("Error starting listening: $e");
    }
  }

  // 4. Stop continuous listening by invoking the native method.
  Future<void> _stopListening() async {
    if (!_isListening) return;
    try {
      await platform.invokeMethod('stopListening');
      setState(() {
        _isListening = false;
      });
    } on PlatformException catch (e) {
      print("Error stopping listening: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Native Speech Recognition'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Recognized Text:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _recognizedText,
              style: TextStyle(fontSize: 16),
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _startListening,
                  child: Text("Start Listening"),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _stopListening,
                  child: Text("Stop Listening"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

