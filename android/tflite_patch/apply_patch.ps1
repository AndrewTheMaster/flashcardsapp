Write-Host "Patching tflite_flutter plugin..."

# Get the location of the tflite_flutter plugin
$tflitePluginPath = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\tflite_flutter-0.9.0\android"
$tflitePluginJavaPath = "$tflitePluginPath\src\main\java\com\tfliteflutter\tflite_flutter_plugin"
$tfliteTensorPath = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\tflite_flutter-0.9.0\lib\src"

if (!(Test-Path $tflitePluginPath)) {
    Write-Host "tflite_flutter plugin not found at $tflitePluginPath"
    exit 1
}

# Create a backup of the original build.gradle
$backupPath = "$tflitePluginPath\build.gradle.backup"
if (!(Test-Path $backupPath)) {
    Copy-Item "$tflitePluginPath\build.gradle" -Destination $backupPath
    Write-Host "Created backup of original build.gradle"
}

# Create a backup of the Java file
$backupJavaPath = "$tflitePluginJavaPath\TfliteFlutterPlugin.java.backup"
if (!(Test-Path $backupJavaPath) -and (Test-Path "$tflitePluginJavaPath\TfliteFlutterPlugin.java")) {
    Copy-Item "$tflitePluginJavaPath\TfliteFlutterPlugin.java" -Destination $backupJavaPath
    Write-Host "Created backup of original TfliteFlutterPlugin.java"
}

# Create a backup of the tensor.dart file
$backupTensorPath = "$tfliteTensorPath\tensor.dart.backup"
if (!(Test-Path $backupTensorPath) -and (Test-Path "$tfliteTensorPath\tensor.dart")) {
    Copy-Item "$tfliteTensorPath\tensor.dart" -Destination $backupTensorPath
    Write-Host "Created backup of original tensor.dart"
}

# Copy our patched build.gradle to the plugin
$sourceFile = Join-Path $PSScriptRoot "build.gradle"
Copy-Item $sourceFile -Destination "$tflitePluginPath\build.gradle" -Force

# Copy our patched Java file to the plugin
$sourceJavaFile = Join-Path $PSScriptRoot "TfliteFlutterPlugin.java"
if (!(Test-Path $tflitePluginJavaPath)) {
    New-Item -ItemType Directory -Path $tflitePluginJavaPath -Force | Out-Null
}
Copy-Item $sourceJavaFile -Destination "$tflitePluginJavaPath\TfliteFlutterPlugin.java" -Force

# Copy our simplified tensor.dart patch to the plugin
$sourceTensorFile = Join-Path $PSScriptRoot "tensor_simple_patch.dart"
Copy-Item $sourceTensorFile -Destination "$tfliteTensorPath\tensor.dart" -Force

Write-Host "Successfully patched tflite_flutter plugin"

# Return success
exit 0 