# Create directory for the patch
mkdir -p android/tflite_patch
cd android/tflite_patch

# Create the build.gradle file with namespace
cat > build.gradle << 'EOF'
android {
    namespace "org.tensorflow.lite.flutter"
}
EOF

# Create a symbolic link or copy this to the TFLite Flutter plugin
cd .. 