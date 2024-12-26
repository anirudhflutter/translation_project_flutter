package com.example.translation;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.view.KeyEvent;
import android.util.Log;

public class MediaButtonReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        // Example usage of MainActivity.methodChannel
        KeyEvent keyEvent = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT);
        if (keyEvent != null && keyEvent.getAction() == KeyEvent.ACTION_DOWN) {
            String button = "Unknown";
            switch (keyEvent.getKeyCode()) {
                case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                    button = "Play/Pause";
                    break;
                // ... add more cases
            }
            if (MainActivity.methodChannel != null) {
                MainActivity.methodChannel.invokeMethod("onButtonPressed", button);
            }
        }
    }
}
