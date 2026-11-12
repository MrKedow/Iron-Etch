import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../services/ai_coach_service.dart';

Future<void> showAiConfigDialog(
  BuildContext context,
  SettingsProvider settings,
) async {
  final initialProvider = aiProviderById(settings.aiProviderId);
  final endpointController = TextEditingController(text: settings.aiEndpoint);
  final modelController = TextEditingController(text: settings.aiModel);
  final keyController = TextEditingController(
      text: settings.apiKeyForProvider(initialProvider.id));
  var providerId = initialProvider.id;
  var modelId = settings.aiModel;
  var obscureKey = true;
  var testing = false;
  String? result;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final spec = context.watch<ThemeProvider>().currentSpec;
        final provider = aiProviderById(providerId);
        final models = List<AiModelPreset>.of(provider.models);
        if (!provider.isCustom &&
            modelId.isNotEmpty &&
            !models.any((item) => item.id == modelId)) {
          models.insert(
            0,
            AiModelPreset(modelId, '当前模型 · $modelId'),
          );
        }
        final smallLabelStyle = TextStyle(
          fontSize: 11.5,
          color: spec.textSecondary,
          fontWeight: FontWeight.w600,
        );

        void selectProvider(String? id) {
          if (id == null) return;
          final next = aiProviderById(id);
          setDialogState(() {
            providerId = next.id;
            modelId = next.isCustom
                ? modelController.text.trim()
                : (next.models.isEmpty ? '' : next.models.first.id);
            if (!next.isCustom) {
              endpointController.text = next.endpoint;
            }
            keyController.text = settings.apiKeyForProvider(next.id);
            result = null;
          });
        }

        String selectedEndpoint() => provider.isCustom
            ? endpointController.text.trim()
            : provider.endpoint;
        String selectedModel() =>
            provider.isCustom ? modelController.text.trim() : modelId;

        return AlertDialog(
          title: const Text('AI 配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: spec.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '选择提供商和模型后，只需填写对应 API Key。接口地址会自动配置，'
                    'Key 会按提供商独立保存，切换时自动带出。',
                    style: TextStyle(
                      color: spec.textSecondary,
                      fontSize: 11.5,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('AI 提供商', style: smallLabelStyle),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  key: ValueKey('provider-$providerId'),
                  initialValue: providerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '提供商',
                  ),
                  items: builtInAiProviders
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: selectProvider,
                ),
                if (!provider.isCustom) ...[
                  const SizedBox(height: 11),
                  Text('模型', style: smallLabelStyle),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<String>(
                    key: ValueKey('model-$providerId-$modelId'),
                    initialValue: models.any((item) => item.id == modelId)
                        ? modelId
                        : (models.isEmpty ? null : models.first.id),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '模型',
                    ),
                    hint: const Text('选择模型'),
                    items: models
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        modelId = value;
                        result = null;
                      });
                    },
                  ),
                ],
                if (provider.isCustom) ...[
                  const SizedBox(height: 11),
                  TextField(
                    controller: endpointController,
                    decoration: const InputDecoration(
                      labelText: '接口地址',
                      hintText: 'https://example.com/v1/chat/completions',
                    ),
                  ),
                  const SizedBox(height: 11),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: '模型 ID',
                      hintText: '例如 gpt-4o-mini',
                    ),
                    onChanged: (value) => modelId = value.trim(),
                  ),
                ],
                const SizedBox(height: 11),
                TextField(
                  controller: keyController,
                  obscureText: obscureKey,
                  decoration: InputDecoration(
                    labelText: provider.requiresKey ? 'API Key' : 'API Key（可选）',
                    hintText: provider.requiresKey
                        ? provider.keyHint
                        : '${provider.keyHint}；留空使用免费通道',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setDialogState(() => obscureKey = !obscureKey),
                      icon: Icon(
                        obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  provider.isCustom
                      ? provider.description
                      : '${provider.description} 接口地址已自动配置。',
                  style: TextStyle(
                    color: spec.textSecondary,
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    result!,
                    style: TextStyle(
                      fontSize: 12,
                      color: result!.startsWith('连接成功')
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      final endpoint = selectedEndpoint();
                      final model = selectedModel();
                      if (endpoint.isEmpty || model.isEmpty) {
                        setDialogState(() => result = '请先选择提供商和模型');
                        return;
                      }
                      setDialogState(() {
                        testing = true;
                        result = '正在连接…';
                      });
                      final reply = await AiCoachService.testConnection(
                        endpoint: endpoint,
                        model: model,
                        apiKey: keyController.text,
                      );
                      if (!context.mounted) return;
                      setDialogState(() {
                        testing = false;
                        result = reply.success
                            ? '连接成功：${reply.content}'
                            : (reply.error ?? '连接失败');
                      });
                    },
              child: Text(testing ? '测试中…' : '测试连接'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final endpoint = selectedEndpoint();
                final model = selectedModel();
                if (endpoint.isEmpty || model.isEmpty) {
                  setDialogState(() => result = '请先选择提供商和模型');
                  return;
                }
                await settings.setAiConfig(
                  providerId: provider.id,
                  endpoint: endpoint,
                  model: model,
                  apiKey: keyController.text,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    ),
  );
  endpointController.dispose();
  modelController.dispose();
  keyController.dispose();
}
