import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../models/settings_model.dart';
import '../providers/settings_provider.dart';
import '../services/exercise_service_facade.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Секция выбора темы
            Text(
              'theme'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ThemeSelector(
              currentThemeMode: settingsProvider.themeMode,
              onThemeSelected: settingsProvider.setThemeMode,
            ),
            
            const SizedBox(height: 24),
            
            // Секция выбора языка
            Text(
              'language'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            LanguageSelector(
              currentLanguage: settingsProvider.language,
              onLanguageSelected: settingsProvider.setLanguage,
            ),

            const SizedBox(height: 24),

            // Секция выбора сервиса перевода
            Text(
              'translation_service'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TranslationServiceSelector(
              currentService: settingsProvider.translationService,
              onServiceSelected: settingsProvider.setTranslationService,
            ),

            const SizedBox(height: 24),

            // Секция выбора сервиса генерации упражнений
            Text(
              'exercise_service'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ExerciseServiceSelector(
              currentService: settingsProvider.exerciseService,
              onServiceSelected: settingsProvider.setExerciseService,
            ),

            const SizedBox(height: 24),
            
            // Новая секция - выбор сложности упражнений
            Text(
              'exercise_complexity'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ExerciseComplexitySelector(
              currentComplexity: settingsProvider.exerciseComplexity,
              onComplexitySelected: settingsProvider.setExerciseComplexity,
            ),

            const SizedBox(height: 24),
            
            // Секция настроек сервера
            Text(
              'server_settings'.tr(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ServerSettings(
              serverAddress: settingsProvider.serverAddress ?? "http://localhost:8000",
              offlineMode: settingsProvider.offlineMode,
              onServerAddressChanged: settingsProvider.setServerAddress,
              onOfflineModeChanged: settingsProvider.setOfflineMode,
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeSelector extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeSelected;

  const ThemeSelector({
    Key? key,
    required this.currentThemeMode,
    required this.onThemeSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<ThemeMode>(
          title: Text('light_mode'.tr(context)),
          value: ThemeMode.light,
          groupValue: currentThemeMode,
          onChanged: (value) => onThemeSelected(value!),
        ),
        RadioListTile<ThemeMode>(
          title: Text('dark_mode'.tr(context)),
          value: ThemeMode.dark,
          groupValue: currentThemeMode,
          onChanged: (value) => onThemeSelected(value!),
        ),
        RadioListTile<ThemeMode>(
          title: Text('system_mode'.tr(context)),
          value: ThemeMode.system,
          groupValue: currentThemeMode,
          onChanged: (value) => onThemeSelected(value!),
        ),
      ],
    );
  }
}

class LanguageSelector extends StatelessWidget {
  final AppLanguage currentLanguage;
  final Function(AppLanguage) onLanguageSelected;

  const LanguageSelector({
    Key? key,
    required this.currentLanguage,
    required this.onLanguageSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<AppLanguage>(
          title: Text('english'.tr(context)),
          value: AppLanguage.english,
          groupValue: currentLanguage,
          onChanged: (value) => onLanguageSelected(value!),
        ),
        RadioListTile<AppLanguage>(
          title: Text('russian'.tr(context)),
          value: AppLanguage.russian,
          groupValue: currentLanguage,
          onChanged: (value) => onLanguageSelected(value!),
        ),
      ],
    );
  }
}

class TranslationServiceSelector extends StatelessWidget {
  final TranslationServiceType currentService;
  final Function(TranslationServiceType) onServiceSelected;

  const TranslationServiceSelector({
    Key? key,
    required this.currentService,
    required this.onServiceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<TranslationServiceType>(
          title: Text('bkrs_parser'.tr(context)),
          subtitle: Text('bkrs_parser_desc'.tr(context)),
          value: TranslationServiceType.bkrsParser,
          groupValue: currentService,
          onChanged: (value) => onServiceSelected(value!),
        ),
        RadioListTile<TranslationServiceType>(
          title: Text('helsinki_translation'.tr(context)),
          subtitle: Text('helsinki_translation_desc'.tr(context)),
          value: TranslationServiceType.helsinkiTranslation,
          groupValue: currentService,
          onChanged: (value) => onServiceSelected(value!),
        ),
      ],
    );
  }
}

class ExerciseServiceSelector extends StatelessWidget {
  final ExerciseGenerationService currentService;
  final Function(ExerciseGenerationService) onServiceSelected;

  const ExerciseServiceSelector({
    Key? key,
    required this.currentService,
    required this.onServiceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<ExerciseGenerationService>(
          title: Text('gemma3_bert_wwm'.tr(context)),
          subtitle: Text('gemma3_bert_wwm_desc'.tr(context)),
          value: ExerciseGenerationService.gemma3BertWwm,
          groupValue: currentService,
          onChanged: (value) => onServiceSelected(value!),
        ),
      ],
    );
  }
}

class ServerSettings extends StatefulWidget {
  final String serverAddress;
  final bool offlineMode;
  final Function(String) onServerAddressChanged;
  final Function(bool) onOfflineModeChanged;

  const ServerSettings({
    Key? key,
    required this.serverAddress,
    required this.offlineMode,
    required this.onServerAddressChanged,
    required this.onOfflineModeChanged,
  }) : super(key: key);

  @override
  _ServerSettingsState createState() => _ServerSettingsState();
}

class _ServerSettingsState extends State<ServerSettings> {
  late TextEditingController _serverAddressController;
  bool _isTesting = false;
  bool? _isConnected;
  String? _testResult;
  Map<String, bool>? _serverModules;
  List<String>? _availableModels;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _serverAddressController = TextEditingController(text: widget.serverAddress);
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ServerSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverAddress != widget.serverAddress) {
      _serverAddressController.text = widget.serverAddress;
    }
  }

  // Тестирование соединения с сервером
  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _isConnected = null;
      _testResult = 'testing_connection'.tr(context);
      _serverModules = null;
      _availableModels = null;
    });

    try {
      // Для собственного сервера используем расширенный тест
      final url = Uri.parse('${_serverAddressController.text}/health');
      final response = await http.get(url).timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Получаем информацию о доступных модулях сервера
        Map<String, dynamic> data = {};
        
        try {
          data = json.decode(response.body);
        } catch (e) {
          data = {'status': 'ok'};
        }
        
        // Сохраняем статус модулей
        _serverModules = {
          'translator': data['translator_enabled'] ?? false,
          'validator': data['validator_enabled'] ?? false,
          'lm_studio': data['lm_studio_enabled'] ?? false,
        };
        
        // Если LM Studio подключен, получаем список моделей
        if (_serverModules!['lm_studio'] == true) {
          _availableModels = List<String>.from(data['available_models'] ?? []);
        }
        
        setState(() {
          _isConnected = true;
          _testResult = 'connection_successful'.tr(context);
        });
      } else {
        setState(() {
          _isConnected = false;
          _testResult = 'connection_failed'.tr(context) + ': ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _testResult = 'connection_error'.tr(context) + ': $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  // Очистка кэша упражнений
  Future<void> _clearExerciseCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      final exerciseService = ExerciseServiceFacade(Provider.of<SettingsProvider>(context, listen: false));
      await exerciseService.clearExerciseCache();
      
      // Показываем уведомление об успешной очистке
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('cache_cleared'.tr(context)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Показываем уведомление об ошибке
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('cache_clear_error'.tr(context) + ': $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isClearingCache = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Настройка адреса сервера
            Text(
              'server_address'.tr(context),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _serverAddressController,
              decoration: InputDecoration(
                hintText: 'http://localhost:5000',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                // Сброс результатов теста при изменении адреса
                setState(() {
                  _isConnected = null;
                  _testResult = null;
                  _serverModules = null;
                  _availableModels = null;
                });
              },
              onSubmitted: (value) {
                // Обновляем адрес сервера
                widget.onServerAddressChanged(value);
              },
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Обновляем адрес сервера
                      widget.onServerAddressChanged(_serverAddressController.text);
                    },
                    child: Text('save'.tr(context)),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Настройка режима офлайн
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    title: Text('offline_mode'.tr(context)),
                    value: widget.offlineMode,
                    onChanged: widget.onOfflineModeChanged,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
              
            SizedBox(height: 16),
            
            // Кнопки управления
            Row(
              children: [
                // Кнопка проверки соединения
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: Icon(Icons.cloud),
                    label: Text('test_connection'.tr(context)),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // Кнопка очистки кэша
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isClearingCache ? null : _clearExerciseCache,
                    icon: Icon(Icons.cleaning_services),
                    label: Text('clear_cache'.tr(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
              
            // Результат проверки
            if (_testResult != null)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isConnected == true
                      ? Colors.green.withOpacity(0.1)
                      : _isConnected == false
                          ? Colors.red.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isConnected == true
                        ? Colors.green
                        : _isConnected == false
                            ? Colors.red
                            : Colors.grey,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected == true
                              ? Icons.check_circle
                              : _isConnected == false
                                  ? Icons.error
                                  : Icons.hourglass_empty,
                          color: _isConnected == true
                              ? Colors.green
                              : _isConnected == false
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(_testResult!),
                        ),
                      ],
                    ),
                    
                    // Show available models if connected
                    if (_isConnected == true && _serverModules != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'server_modules'.tr(context) + ':',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      _buildModuleStatus(
                        'translator'.tr(context), 
                        _serverModules!['translator'] ?? false
                      ),
                      _buildModuleStatus(
                        'validator'.tr(context), 
                        _serverModules!['validator'] ?? false
                      ),
                      _buildModuleStatus(
                        'LM Studio', 
                        _serverModules!['lm_studio'] ?? false
                      ),
                    ],
                    
                    // Show available models if LM Studio is connected
                    if (_isConnected == true && 
                        _serverModules != null && 
                        _serverModules!['lm_studio'] == true &&
                        _availableModels != null && 
                        _availableModels!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        'available_models'.tr(context) + ':',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      ...(_availableModels!.map((model) => Padding(
                        padding: EdgeInsets.only(left: 8, top: 2, bottom: 2),
                        child: Text('• $model'),
                      ))),
                    ]
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModuleStatus(String name, bool isEnabled) {
    return Padding(
      padding: EdgeInsets.only(left: 8, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.check_circle : Icons.cancel,
            color: isEnabled ? Colors.green : Colors.red,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(name),
        ],
      ),
    );
  }
}

// Добавляем новый класс для выбора сложности упражнений
class ExerciseComplexitySelector extends StatelessWidget {
  final String currentComplexity;
  final Function(String) onComplexitySelected;

  const ExerciseComplexitySelector({
    Key? key,
    required this.currentComplexity,
    required this.onComplexitySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildComplexityOption(
            context, 
            'simple', 
            'simple_complexity'.tr(context),
            'simple_complexity_desc'.tr(context),
            Icons.speed_outlined,
          ),
          Divider(height: 1),
          _buildComplexityOption(
            context, 
            'normal', 
            'normal_complexity'.tr(context),
            'normal_complexity_desc'.tr(context),
            Icons.speed,
          ),
          Divider(height: 1),
          _buildComplexityOption(
            context, 
            'complex', 
            'complex_complexity'.tr(context),
            'complex_complexity_desc'.tr(context),
            Icons.speed,
          ),
        ],
      ),
    );
  }

  Widget _buildComplexityOption(
    BuildContext context, 
    String complexity, 
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = currentComplexity == complexity;
    
    return InkWell(
      onTap: () => onComplexitySelected(complexity),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Theme.of(context).unselectedWidgetColor,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }
} 