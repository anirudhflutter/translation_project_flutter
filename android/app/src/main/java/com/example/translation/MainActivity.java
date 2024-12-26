package com.example.translation;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.speech.SpeechRecognizer;
import android.speech.RecognizerIntent;
import android.speech.RecognitionListener;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import java.util.ArrayList;

public class MainActivity extends FlutterActivity {
    // Make it public static for access in MediaButtonReceiver
    public static MethodChannel methodChannel;

    private SpeechRecognizer speechRecognizer;
    private Intent recognizerIntent;
    private boolean isListening = false;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Initialize the MethodChannel (use your own channel name)
        methodChannel = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                "com.example.translation/button"
        );

        // Initialize SpeechRecognizer
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
        speechRecognizer.setRecognitionListener(new ContinuousRecognitionListener());

        // Configure the recognizer intent (adjust language as needed)
        recognizerIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        // e.g., recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US");

        // Handle method calls from Flutter
        methodChannel.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "startListening":
                    startListening();
                    result.success(null);
                    break;
                case "stopListening":
                    stopListening();
                    result.success(null);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private void startListening() {
        if (!isListening) {
            isListening = true;
            speechRecognizer.startListening(recognizerIntent);
            Log.d("MainActivity", "Speech recognition started");
        }
    }

    private void stopListening() {
        if (isListening) {
            isListening = false;
            speechRecognizer.stopListening();
            Log.d("MainActivity", "Speech recognition stopped");
        }
    }

    private class ContinuousRecognitionListener implements RecognitionListener {
        @Override
        public void onReadyForSpeech(Bundle params) { }

        @Override
        public void onBeginningOfSpeech() {
            Log.d("ContinuousRecog", "User started speaking");
        }

        @Override
        public void onRmsChanged(float rmsdB) { }

        @Override
        public void onBufferReceived(byte[] buffer) { }

        @Override
        public void onEndOfSpeech() {
            Log.d("ContinuousRecog", "onEndOfSpeech");
            // Restart if still listening for continuous mode
            if (isListening) {
                speechRecognizer.startListening(recognizerIntent);
            }
        }

        @Override
        public void onError(int error) {
            Log.e("ContinuousRecog", "Error: " + error);
            // Restart on error if still set to listening
            if (isListening) {
                speechRecognizer.cancel();
                speechRecognizer.startListening(recognizerIntent);
            }
        }

        @Override
        public void onResults(Bundle results) {
            ArrayList<String> matches =
                    results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            if (matches != null && !matches.isEmpty()) {
                String recognizedText = matches.get(0);
                // Send recognized text to Flutter
                if (MainActivity.methodChannel != null) {
                    MainActivity.methodChannel.invokeMethod(
                            "onButtonPressed", recognizedText
                    );
                }
            }
        }

        @Override
        public void onPartialResults(Bundle partialResults) { }

        @Override
        public void onEvent(int eventType, Bundle params) { }
    }
}
