import 'package:dio/dio.dart';
import '../utils/log_interceptor.dart' as app_logger;

class TestService {
  final Dio _dio = Dio();
  
  Future<void> testLogAndDio() async {
    app_logger.LogInterceptor.log('Testing imports and service functionality');
    
    try {
      // Just a simple test request
      final response = await _dio.get('https://jsonplaceholder.typicode.com/todos/1');
      app_logger.LogInterceptor.log('Response received: ${response.statusCode}');
    } catch (e) {
      app_logger.LogInterceptor.log('Error in test request: $e');
    }
  }
} 