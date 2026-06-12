package com.example.mobile_app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Using FlutterFragmentActivity instead of FlutterActivity because the
 * health package's Health Connect permission launcher (ActivityResultLauncher)
 * must be registered during onCreate(), which requires Fragment support.
 */
class MainActivity : FlutterFragmentActivity()
