import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_service.dart';

/// Widget that displays the current status of the BERT model
class ModelStatusIndicator extends StatelessWidget {
  const ModelStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelService>(
      builder: (context, modelService, child) {
        return GestureDetector(
          onTap: () => _showModelStatusDetails(context, modelService),
          child: _buildStatusIcon(modelService),
        );
      },
    );
  }

  /// Build the status icon based on model state
  Widget _buildStatusIcon(ModelService modelService) {
    switch (modelService.modelStatus) {
      case ModelState.loading:
        return _buildLoadingIndicator(modelService.loadProgress);
      case ModelState.ready:
        return const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 24,
        );
      case ModelState.error:
        return const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 24,
        );
      case ModelState.disabled:
        return const Icon(
          Icons.flash_off,
          color: Colors.grey,
          size: 24,
        );
    }
  }

  /// Build a loading indicator with progress
  Widget _buildLoadingIndicator(double progress) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          Text(
            "${(progress * 100).toInt()}%",
            style: const TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  /// Show detailed model status information in a dialog
  void _showModelStatusDetails(BuildContext context, ModelService modelService) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _buildStatusIcon(modelService),
            const SizedBox(width: 8),
            const Text('BERT Model Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusDetail('State', _getStateText(modelService.modelStatus), theme),
            const SizedBox(height: 8),
            _buildStatusDetail('Using Fallback', modelService.usingFallback ? 'Yes' : 'No', theme),
            
            if (modelService.modelStatus == ModelState.error) ...[
              const SizedBox(height: 12),
              const Text('Error details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.red[900] : Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  modelService.modelError,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white : Colors.red[900],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            const Text('Troubleshooting tips:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildTroubleshootingTip(
              'Make sure the model file exists in assets/models/',
              theme,
            ),
            _buildTroubleshootingTip(
              'Run convert.bat to generate a compatible model',
              theme,
            ),
            _buildTroubleshootingTip(
              'Check logs for detailed error information',
              theme,
            ),
          ],
        ),
        actions: [
          if (modelService.modelStatus == ModelState.error || 
              modelService.modelStatus == ModelState.disabled)
            TextButton(
              onPressed: () {
                modelService.toggleModelEnabled(true);
                Navigator.of(context).pop();
              },
              child: const Text('Retry'),
            ),
          if (modelService.modelStatus == ModelState.error)
            TextButton(
              onPressed: () {
                modelService.toggleModelEnabled(false);
                Navigator.of(context).pop();
              },
              child: const Text('Use Fallback'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Build a status detail row with label and value
  Widget _buildStatusDetail(String label, String value, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: theme.primaryColor)),
      ],
    );
  }

  /// Build a troubleshooting tip with bullet
  Widget _buildTroubleshootingTip(String tip, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          Expanded(child: Text(tip, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  /// Convert model state enum to human-readable text
  String _getStateText(ModelState state) {
    switch (state) {
      case ModelState.loading:
        return 'Loading';
      case ModelState.ready:
        return 'Ready';
      case ModelState.error:
        return 'Error';
      case ModelState.disabled:
        return 'Disabled';
    }
  }
} 