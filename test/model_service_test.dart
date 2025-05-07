import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../lib/services/model_service.dart';

@GenerateMocks([Interpreter, InterpreterOptions, File])
import 'model_service_test.mocks.dart';

// Mock class for PathProviderPlatform
class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  Future<String?> getApplicationDocumentsPath() async {
    return '/mock/path';
  }
}

void main() {
  late ModelService modelService;
  late MockFile mockFile;

  setUp(() {
    mockFile = MockFile();
    when(mockFile.exists()).thenAnswer((_) async => true);
    when(mockFile.length()).thenAnswer((_) async => 100 * 1024 * 1024); // 100MB
    when(mockFile.path).thenReturn('/mock/path/bert_zh_quant.tflite');

    // Replace the singleton instance for path provider
    PathProviderPlatform.instance = MockPathProviderPlatform();

    modelService = ModelService();
  });

  group('ModelService tests', () {
    test('Initial state should be loading', () {
      expect(modelService.modelStatus, equals(ModelState.loading));
      expect(modelService.isModelReady, isFalse);
      expect(modelService.modelError, isEmpty);
      expect(modelService.isModelEnabled, isTrue);
    });

    test('Disabling model should change status to disabled', () async {
      modelService.toggleModelEnabled(false);
      expect(modelService.modelStatus, equals(ModelState.disabled));
      expect(modelService.isModelReady, isFalse);
      expect(modelService.isModelEnabled, isFalse);
      expect(modelService.usingFallback, isTrue);
    });

    test('Fallback generator should work when model is disabled', () async {
      modelService.toggleModelEnabled(false);
      
      final result = await modelService.generateExercise(['学习', '工作', '生活']);
      expect(result, isNotEmpty);
      
      final Map<String, dynamic> exercise = await jsonDecode(result);
      expect(exercise['is_fallback'], isTrue);
      expect(exercise['options'].length, equals(4));
    });

    test('Fallback translation should work when model is disabled', () async {
      modelService.toggleModelEnabled(false);
      
      final result = await modelService.translate('你好');
      expect(result, isNotEmpty);
      
      final Map<String, dynamic> translation = await jsonDecode(result);
      expect(translation['is_fallback'], isTrue);
      expect(translation['original_text'], equals('你好'));
    });
  });

  group('Model error handling', () {
    test('Repeated errors should trigger fallback mode', () {
      // Simulate 3 errors
      for (int i = 0; i < 3; i++) {
        modelService._handleRepeatedErrors();
      }
      
      expect(modelService.usingFallback, isTrue);
    });
  });
} 