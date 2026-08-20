import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../network/api_client.dart';
import '../../network/dio_http_transport.dart';
import '../../network/json_utils.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../utils/genesis_image_resource.dart';
import '../create/create_origin_draft_store.dart';
import 'origin_debug_draft_factory.dart';
import 'origin_debug_image_upload.dart';
import 'origin_draft_repository.dart';

typedef OriginDebugDraftGenerator =
    FutureOr<CreateOriginDraft> Function(
      BuildContext context,
      CreateOriginDraft currentDraft,
    );

OriginDebugDraftGenerator? createOriginDebugDraftGenerator() {
  if (!kDebugMode) return null;
  return (context, currentDraft) async {
    final generated = generateRandomCreateOriginDraft(currentDraft);
    return _uploadGeneratedImages(context, currentDraft, generated);
  };
}

OriginDebugDraftGenerator? editOriginDebugDraftGenerator(
  TextEditingController updateNotesController,
) {
  if (!kDebugMode) return null;
  return (context, currentDraft) async {
    final generated = await _uploadGeneratedImages(
      context,
      currentDraft,
      generateRandomEditOriginDraft(currentDraft),
    );
    if (!context.mounted) return generated;
    updateNotesController.text = 'Generated random test content in debug mode.';
    return generated;
  };
}

final Map<String, ApiClient> _debugImageDownloadClients = <String, ApiClient>{};

Future<CreateOriginDraft> _uploadGeneratedImages(
  BuildContext context,
  CreateOriginDraft current,
  CreateOriginDraft generated,
) {
  final services = AppServicesScope.read(context);
  final uploadApi = services.api.v1.upload;
  final debugProxy = services.config.debugProxy.trim();
  final downloadClient = _debugImageDownloadClients.putIfAbsent(
    debugProxy,
    () => ApiClient(
      baseUrl: 'https://localhost.invalid/',
      defaultHeaders: const <String, String>{'accept': 'image/*'},
      transport: DioHttpTransport(proxy: debugProxy),
      timeoutMs: 120000,
      retryPolicy: ApiRetryPolicy.safe,
    ),
  );
  return uploadGeneratedOriginDebugImages(
    current: current,
    generated: generated,
    downloadImage: (sourceUrl) async {
      if (!context.mounted) {
        throw StateError('Debug image generation was cancelled.');
      }
      final bytes = await downloadClient.downloadBytes(sourceUrl.toString());
      return Uint8List.fromList(bytes);
    },
    uploadImage: (image) async {
      if (!context.mounted) {
        throw StateError('Debug image generation was cancelled.');
      }
      final uploaded = await uploadApi.image(
        bytes: image.bytes,
        filename: image.filename,
        contentType: image.contentType,
      );
      final uploadedUrl = GenesisImageResourceRegistry.resolve(
        uploaded,
      ).displayUrl;
      if (uploadedUrl.trim().isEmpty) {
        throw StateError(
          'Upload returned an empty URL: ${asString(uploaded['object_key'])}',
        );
      }
      return uploadedUrl;
    },
  );
}

Widget? buildOriginDebugRandomContentButton({
  required OriginDraftRepository repository,
  required OriginDebugDraftGenerator? generator,
  required bool enabled,
  required Future<void> Function() onGenerated,
}) {
  if (!kDebugMode || generator == null) return null;
  return _OriginDebugRandomContentButton(
    repository: repository,
    generator: generator,
    enabled: enabled,
    onGenerated: onGenerated,
  );
}

class _OriginDebugRandomContentButton extends StatefulWidget {
  const _OriginDebugRandomContentButton({
    required this.repository,
    required this.generator,
    required this.enabled,
    required this.onGenerated,
  });

  final OriginDraftRepository repository;
  final OriginDebugDraftGenerator generator;
  final bool enabled;
  final Future<void> Function() onGenerated;

  @override
  State<_OriginDebugRandomContentButton> createState() =>
      _OriginDebugRandomContentButtonState();
}

class _OriginDebugRandomContentButtonState
    extends State<_OriginDebugRandomContentButton> {
  bool _isGenerating = false;

  Future<void> _generate() async {
    if (_isGenerating || !widget.enabled) return;
    setState(() => _isGenerating = true);
    try {
      final current = await widget.repository.loadSummaryDraft();
      if (!mounted) return;
      final generatedDraft = await widget.generator(context, current);
      if (!mounted) return;
      final generated = _markChangedDebugSectionsSaved(current, generatedDraft);
      await widget.repository.saveFinalDraft(generated);
      if (!mounted) return;
      await widget.onGenerated();
      if (!mounted) return;
      setState(() => _isGenerating = false);
      showGenesisToast(context, 'Random test content generated.');
    } catch (error, stackTrace) {
      debugPrint('[OriginEditor] debug draft generation failed: $error');
      debugPrint('[OriginEditor] stacktrace:\n$stackTrace');
      if (!mounted) return;
      setState(() => _isGenerating = false);
      showGenesisToast(context, 'Unable to generate random test content.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_isGenerating && widget.enabled;
    final accent = context.genesisColors.accentText;
    return Opacity(
      opacity: enabled || _isGenerating ? 1 : 0.45,
      child: Material(
        color: context.genesisColors.controlBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: context.genesisColors.textPrimary.withValues(alpha: 0.14),
          ),
        ),
        child: Tooltip(
          message: 'Generate random test content',
          child: InkWell(
            key: const ValueKey<String>('origin-debug-random-content-button'),
            onTap: enabled ? () => unawaited(_generate()) : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 30,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGenerating)
                      SizedBox.square(
                        dimension: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: accent,
                        ),
                      )
                    else
                      Icon(Icons.casino_outlined, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      'debug Random',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

CreateOriginDraft _markChangedDebugSectionsSaved(
  CreateOriginDraft current,
  CreateOriginDraft generated,
) {
  final currentDraft = current.normalized();
  final generatedDraft = generated.normalized();
  bool changed(Object currentValue, Object generatedValue) {
    return jsonEncode(currentValue) != jsonEncode(generatedValue);
  }

  return generatedDraft.copyWith(
    basicsSaved:
        generatedDraft.basicsSaved ||
        changed(currentDraft.basics.toJson(), generatedDraft.basics.toJson()),
    charactersSaved:
        generatedDraft.charactersSaved ||
        changed(
          currentDraft.characters.map((item) => item.toJson()).toList(),
          generatedDraft.characters.map((item) => item.toJson()).toList(),
        ),
    locationsSaved:
        generatedDraft.locationsSaved ||
        changed(
          currentDraft.locations.map((item) => item.toJson()).toList(),
          generatedDraft.locations.map((item) => item.toJson()).toList(),
        ),
    openingSaved:
        generatedDraft.openingSaved ||
        changed(currentDraft.opening.toJson(), generatedDraft.opening.toJson()),
    storyEventsSaved:
        generatedDraft.storyEventsSaved ||
        changed(
          currentDraft.storyEvents.map((item) => item.toJson()).toList(),
          generatedDraft.storyEvents.map((item) => item.toJson()).toList(),
        ),
  );
}
