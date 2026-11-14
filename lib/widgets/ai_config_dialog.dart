import '../l10n/localized_material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../services/ai_coach_service.dart';
import '../theme/app_theme.dart';

enum _AiTestState { idle, testing, success, failure }

Future<void> showAiConfigDialog(
  BuildContext context,
  SettingsProvider settings,
) async {
  final initialProvider = aiProviderById(settings.aiProviderId);
  final endpointController = TextEditingController(text: settings.aiEndpoint);
  final modelController = TextEditingController(text: settings.aiModel);
  final keyController = TextEditingController(
    text: settings.apiKeyForProvider(initialProvider.id),
  );
  var providerId = initialProvider.id;
  var modelId = settings.aiModel;
  var reasoningEffort = settings.aiReasoningEffort;
  var obscureKey = true;
  var testing = false;
  var testState = _AiTestState.idle;
  String? statusMessage;

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
        const fieldLabelStyle = TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        );

        void clearTestResult() {
          testState = _AiTestState.idle;
          statusMessage = null;
        }

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
            final nextEndpoint =
                next.isCustom ? endpointController.text.trim() : next.endpoint;
            final preset = aiReasoningPreset(nextEndpoint, modelId);
            if (preset == null || !preset.supports(reasoningEffort)) {
              reasoningEffort = preset?.defaultId ?? 'default';
            }
            keyController.text = settings.apiKeyForProvider(next.id);
            clearTestResult();
          });
        }

        String selectedEndpoint() => provider.isCustom
            ? endpointController.text.trim()
            : provider.endpoint;
        String selectedModel() =>
            provider.isCustom ? modelController.text.trim() : modelId;
        final reasoningPreset = aiReasoningPreset(
          selectedEndpoint(),
          selectedModel(),
        );
        final activeReasoning =
            reasoningPreset != null && reasoningPreset.supports(reasoningEffort)
                ? reasoningEffort
                : (reasoningPreset?.defaultId ?? 'default');
        final reasoningPreview = _reasoningPreview(
          reasoningPreset,
          activeReasoning,
        );

        Future<void> runTest() async {
          final endpoint = selectedEndpoint();
          final model = selectedModel();
          if (endpoint.isEmpty || model.isEmpty) {
            setDialogState(() {
              testState = _AiTestState.failure;
              statusMessage = context.tr('请先选择提供商和模型');
            });
            return;
          }
          setDialogState(() {
            testing = true;
            testState = _AiTestState.testing;
            statusMessage = context.tr('正在连接…');
          });
          final reply = await AiCoachService.testConnection(
            endpoint: endpoint,
            model: model,
            apiKey: keyController.text,
            reasoningEffort: activeReasoning,
          );
          if (!context.mounted) return;
          setDialogState(() {
            testing = false;
            testState =
                reply.success ? _AiTestState.success : _AiTestState.failure;
            statusMessage = reply.success
                ? '${context.tr('连接成功')}：${reply.content}'
                : '${context.tr('连接失败')}：${reply.error ?? '未知错误'}';
          });
        }

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.of(context).size.height * .86,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('AI 配置'),
                          style: TextStyle(
                            color: spec.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: spec.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: SingleChildScrollView(
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
                          DropdownButtonFormField<String>(
                            key: ValueKey('provider-$providerId'),
                            initialValue: providerId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.tr('AI 提供商'),
                              labelStyle: fieldLabelStyle,
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
                            onChanged: testing ? null : selectProvider,
                          ),
                          if (!provider.isCustom) ...[
                            const SizedBox(height: 11),
                            DropdownButtonFormField<String>(
                              key: ValueKey('model-$providerId-$modelId'),
                              initialValue: models
                                      .any((item) => item.id == modelId)
                                  ? modelId
                                  : (models.isEmpty ? null : models.first.id),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.tr('模型'),
                                labelStyle: fieldLabelStyle,
                              ),
                              hint: Text(context.tr('选择模型')),
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
                              onChanged: testing
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setDialogState(() {
                                        modelId = value;
                                        final preset = aiReasoningPreset(
                                          provider.endpoint,
                                          value,
                                        );
                                        if (preset == null ||
                                            !preset.supports(reasoningEffort)) {
                                          reasoningEffort =
                                              preset?.defaultId ?? 'default';
                                        }
                                        clearTestResult();
                                      });
                                    },
                            ),
                          ],
                          if (provider.isCustom) ...[
                            const SizedBox(height: 11),
                            TextField(
                              controller: endpointController,
                              enabled: !testing,
                              decoration: InputDecoration(
                                labelText: context.tr('接口地址'),
                                hintText:
                                    'https://example.com/v1/chat/completions',
                              ),
                              onChanged: (_) => setDialogState(clearTestResult),
                            ),
                            const SizedBox(height: 11),
                            TextField(
                              controller: modelController,
                              enabled: !testing,
                              decoration: InputDecoration(
                                labelText: context.tr('模型 ID'),
                                hintText: context.tr('例如 gpt-4o-mini'),
                              ),
                              onChanged: (value) {
                                modelId = value.trim();
                                setDialogState(clearTestResult);
                              },
                            ),
                          ],
                          const SizedBox(height: 11),
                          if (reasoningPreset == null)
                            DropdownButtonFormField<String>(
                              initialValue: '__unsupported__',
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.tr('推理强度'),
                                labelStyle: fieldLabelStyle,
                                helperText: context.tr('当前模型没有可调节的推理强度参数'),
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: '__unsupported__',
                                  child: Text(
                                    context.tr('该模型不支持推理强度设置'),
                                  ),
                                ),
                              ],
                              onChanged: null,
                            )
                          else
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'reasoning-$providerId-${selectedModel()}-'
                                '${reasoningPreset.parameter}-$activeReasoning',
                              ),
                              initialValue: activeReasoning,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.tr('推理强度'),
                                labelStyle: fieldLabelStyle,
                                helperText: reasoningPreview,
                                helperMaxLines: 2,
                              ),
                              items: reasoningPreset.options
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option.id,
                                      child: Text(
                                        option.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: testing
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setDialogState(() {
                                        reasoningEffort = value;
                                        clearTestResult();
                                      });
                                    },
                            ),
                          const SizedBox(height: 11),
                          TextField(
                            controller: keyController,
                            obscureText: obscureKey,
                            enabled: !testing,
                            decoration: InputDecoration(
                              labelText: provider.requiresKey
                                  ? 'API Key'
                                  : 'API Key（可选）',
                              hintText: provider.requiresKey
                                  ? provider.keyHint
                                  : '${provider.keyHint}；留空使用免费通道',
                              suffixIcon: IconButton(
                                onPressed: () => setDialogState(
                                  () => obscureKey = !obscureKey,
                                ),
                                icon: Icon(
                                  obscureKey
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            onChanged: (_) => setDialogState(clearTestResult),
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
                          if (testState != _AiTestState.idle) ...[
                            const SizedBox(height: 12),
                            _TestStatusPanel(
                              state: testState,
                              message: statusMessage ?? '',
                              spec: spec,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: testing ? null : runTest,
                          child: testing
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: spec.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(context.tr('测试中…')),
                                  ],
                                )
                              : Text(context.tr('测试连接')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed:
                              testing ? null : () => Navigator.pop(context),
                          child: Text(context.tr('取消')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: testing
                              ? null
                              : () async {
                                  final endpoint = selectedEndpoint();
                                  final model = selectedModel();
                                  if (endpoint.isEmpty || model.isEmpty) {
                                    setDialogState(() {
                                      testState = _AiTestState.failure;
                                      statusMessage = context.tr(
                                        '请先选择提供商和模型',
                                      );
                                    });
                                    return;
                                  }
                                  await settings.setAiConfig(
                                    providerId: provider.id,
                                    endpoint: endpoint,
                                    model: model,
                                    apiKey: keyController.text,
                                    reasoningEffort: activeReasoning,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          child: Text(context.tr('保存')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  endpointController.dispose();
  modelController.dispose();
  keyController.dispose();
}

class _TestStatusPanel extends StatelessWidget {
  final _AiTestState state;
  final String message;
  final AppThemeSpec spec;

  const _TestStatusPanel({
    required this.state,
    required this.message,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    final isTesting = state == _AiTestState.testing;
    final isSuccess = state == _AiTestState.success;
    final color = isTesting
        ? spec.primary
        : isSuccess
            ? const Color(0xFF22C55E)
            : const Color(0xFFFF9500);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTesting)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              size: 17,
              color: color,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _reasoningPreview(AiReasoningPreset? preset, String optionId) {
  if (preset == null) return '当前模型没有可调节的推理强度参数';
  final option = preset.byId(optionId);
  final payload = option?.payload;
  if (payload == null || payload.isEmpty) {
    return '不发送推理参数，使用模型默认值';
  }
  final parts = payload.entries.map((entry) {
    final value = entry.value;
    if (value is Map) {
      final nested =
          value.entries.map((item) => '${item.key}: ${item.value}').join(', ');
      return '${entry.key}={$nested}';
    }
    return '${entry.key}=$value';
  }).join('，');
  return '实际发送：$parts';
}
