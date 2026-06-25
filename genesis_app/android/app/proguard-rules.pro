-keep class com.alibabacloud.rum.** { *; }
-keepclasseswithmembernames class com.alibabacloud.rum.** {
    native <methods>;
}

-dontwarn com.squareup.okhttp.**
-dontwarn com.tencent.smtt.**
-dontwarn org.chromium.net.**
-dontwarn io.flutter.plugins.webviewflutter.WebChromeClientHostApiImpl$SecureWebChromeClient
-dontwarn io.flutter.plugins.webviewflutter.WebChromeClientHostApiImpl$WebChromeClientImpl
