# Keep TensorFlow Lite classes
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }

# Keep the helper library classes
-keep class tflite_flutter_helper.** { *; }

# Keep necessary TFLite Flutter plugin classes
-keep class com.tfliteflutter.tflite_flutter_plugin.** { *; }
-keep class org.tensorflow.lite.flutter.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep metadata classes for TFLite
-keep @interface org.tensorflow.lite.annotations.UsedByReflection
-keep @org.tensorflow.lite.annotations.UsedByReflection class *

# Uncomment for release builds to strip debug information
# -assumenosideeffects class android.util.Log {
#    public static boolean isLoggable(java.lang.String, int);
#    public static int v(...);
#    public static int i(...);
#    public static int w(...);
#    public static int d(...);
# } 