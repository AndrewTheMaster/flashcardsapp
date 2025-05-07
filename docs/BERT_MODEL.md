# BERT Model Integration

This document describes the integration of the Chinese BERT model in the Flashcards application, including setup, validation, and troubleshooting.

## Model Information

- **Model**: BERT-base-Chinese (quantized)
- **Format**: TensorFlow Lite (INT8 quantized)
- **Size**: ~80-150MB
- **Input Shape**: [1, 512]
- **Location**: `assets/models/bert_zh_quant.tflite`

## Setup Process

### 1. Convert and Quantize Model

#### Option A: Using a Local Pre-downloaded Model (Recommended for Windows)

If you already have the model downloaded (e.g., at `C:\Users\PC\Downloads\chinese_wwm_ext_L-12_H-768_A-12`), use:

```bash
# Navigate to project root
cd path/to/project

# Run the conversion batch file
tools\convert_model.bat
```

Or specify a custom path:

```bash
tools\convert_model.bat "C:\path\to\your\bert\model"
```

#### Option B: Downloading and Converting in One Step

For automatic download and conversion:

```bash
# Navigate to project root
cd path/to/project

# Run the conversion script
python tools/convert_bert_model.py
```

### 2. Requirements

The conversion process requires:

- Python 3.7+
- TensorFlow 2.5+
- Transformers library

These can be installed with:

```bash
pip install tensorflow transformers
```

### 3. Verify in pubspec.yaml

Ensure the model is included in your assets:

```yaml
assets:
  - assets/models/bert_zh_quant.tflite
```

### 4. Run the application

The application will automatically validate and load the model on startup.

## Status Indicators

The application uses visual indicators to show the model status:

| Status | Icon | Color | Description |
|--------|------|-------|-------------|
| Loading | ⏳ | Yellow | Model is being loaded and validated |
| Ready | ✅ | Green | Model loaded successfully and ready to use |
| Error | ❗ | Red | Error loading or using the model |
| Disabled | ⚠️ | Gray | Operating in fallback mode without AI |

## Troubleshooting

### Common Error Messages

#### Input tensor shape mismatch

```
[ERROR] Model initialization failed: 
  - Cause: Input tensor shape mismatch
  - Expected: [1,512], Actual: [1,256]
  - Action: Регенерировать модель с правильными параметрами
```

**Solution**: Regenerate the model using the conversion script.

#### File size warnings

```
[WARNING] BERT_MODEL: Unexpected file size: 60.45MB. Expected: 80-150MB
```

**Solution**: Check if the model was properly quantized. Try running the conversion script again.

#### High latency warnings

```
[W] BERT_MODEL: High latency (620ms) - consider further optimization
```

**Solution**: Consider using a smaller model or additional quantization techniques.

#### Model conversion fails on Windows

If you encounter issues with the original conversion script on Windows, try the local model conversion approach with `convert_model.bat`.

## Fallback Mechanism

When the BERT model fails to load or encounters repeated errors, the application automatically switches to a simplified fallback generator. This ensures the app remains functional even when AI capabilities are limited.

The fallback mode:
- Uses pre-defined templates instead of BERT-generated content
- Provides basic translation capabilities
- Indicates the fallback status through the UI

## Advanced Configuration

You can configure the model behavior in the settings:
- Enable/disable AI features
- Force fallback mode for testing
- View model information and statistics 