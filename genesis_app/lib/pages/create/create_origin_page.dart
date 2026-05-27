import 'package:flutter/material.dart';

import '../../components/page_header.dart';
import '../../network/api_exception.dart';
import '../../ui/genesis_ui.dart';
import 'create_basics_page.dart';
import 'create_characters_page.dart';
import 'create_locations_page.dart';
import 'create_origin_draft_store.dart';
import 'create_story_events_page.dart';
import '../../app/bootstrap/app_services_scope.dart';

class CreateOriginPage extends StatefulWidget {
  const CreateOriginPage({super.key});

  @override
  State<CreateOriginPage> createState() => _CreateOriginPageState();
}

class _CreateOriginPageState extends State<CreateOriginPage> {
  CreateOriginDraft _draft = CreateOriginDraft.empty();
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reloadDraft();
  }

  Future<void> _reloadDraft() async {
    final draft = await CreateOriginDraftStore.loadFinal();
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _isLoading = false;
    });
  }

  Future<void> _openSection(Widget page) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
    if (changed == true) {
      await _reloadDraft();
    }
  }

  Future<void> _onCreate() async {
    final latest = await CreateOriginDraftStore.loadFinal();
    if (!mounted) return;
    final errors = latest.validateForSubmit();
    if (errors.isNotEmpty) {
      _showError(errors.first);
      setState(() => _draft = latest);
      return;
    }

    final api = AppServicesScope.read(context).api;
    setState(() {
      _isSubmitting = true;
      _draft = latest;
    });

    try {
      final result = await api.createOrigin(
        payload: latest.toCreateOriginPayload(),
      );
      await CreateOriginDraftStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Origin created successfully: ${result.oid}')),
        );
      setState(() {
        _draft = CreateOriginDraft.empty();
        _isSubmitting = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Create failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const GenesisBackAppBar(pageName: 'Create Origin'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 14),
              // _UploadCard(onGenerate: () {}),
              // const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    _SectionRow(
                      icon: '🌐',
                      title: 'Basics',
                      summary: _basicsSummary(_draft),
                      completed: _draft.basicsSaved,
                      onTap: () => _openSection(const CreateBasicsPage()),
                    ),
                    _SectionRow(
                      icon: '👤',
                      title: 'Characters',
                      summary: _charactersSummary(_draft),
                      completed: _draft.charactersSaved,
                      onTap: () => _openSection(const CreateCharactersPage()),
                    ),
                    _SectionRow(
                      icon: '📍',
                      title: 'Locations',
                      summary: _locationsSummary(_draft),
                      completed: _draft.locationsSaved,
                      onTap: () => _openSection(const CreateLocationsPage()),
                    ),
                    _SectionRow(
                      icon: '📜',
                      title: 'Story Events (Optional)',
                      summary: _storyEventsSummary(_draft),
                      completed: _draft.storyEventsSaved,
                      showDivider: false,
                      onTap: () => _openSection(const CreateStoryEventsPage()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: GenesisPrimaryButton(
          label: _isSubmitting ? 'Saving...' : 'Save',
          onPressed: _isSubmitting ? null : _onCreate,
          backgroundColor: const Color(0xFF198B64),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE3E3E3),
          disabledForegroundColor: const Color(0xFF6F6F6F),
        ),
      ),
    );
  }

  String _basicsSummary(CreateOriginDraft draft) {
    if (!draft.basicsSaved) return 'Not started yet';
    final basics = draft.basics;
    return [
      'World Name: ${_summaryValue(basics.originName)}',
      'World View: ${_summaryValue(basics.worldView)}',
      'World Logic: ${_summaryValue(basics.worldLogic, maxLength: 36)}',
      'Cover Image: ${basics.coverImageUrl.trim().isEmpty ? 'Not uploaded' : 'Uploaded'}',
    ].join('\n');
  }

  String _charactersSummary(CreateOriginDraft draft) {
    if (!draft.charactersSaved) return 'Not started yet';
    final names = draft.characters
        .map((item) => item.name.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return '${names.length} characters: ${_summaryValue(names.join(', '), maxLength: 42)}';
  }

  String _locationsSummary(CreateOriginDraft draft) {
    if (!draft.locationsSaved) return 'Not started yet';
    final names = draft.locations
        .map((item) => item.name.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return '${names.length} locations: ${_summaryValue(names.join(', '), maxLength: 42)}';
  }

  String _storyEventsSummary(CreateOriginDraft draft) {
    if (!draft.storyEventsSaved) return 'Not started yet';
    final count = draft.storyEvents
        .map((item) => item.event.trim())
        .where((item) => item.isNotEmpty)
        .length;
    return '$count Events';
  }

  String _summaryValue(String value, {int maxLength = 48}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }
}

// class _UploadCard extends StatelessWidget {
//   const _UploadCard({required this.onGenerate});

//   final VoidCallback onGenerate;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF1F1F3),
//         borderRadius: BorderRadius.circular(18),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 74,
//             height: 74,
//             decoration: BoxDecoration(
//               color: const Color(0xFFE7E7EA),
//               borderRadius: BorderRadius.circular(18),
//             ),
//             child: const Icon(
//               Icons.file_upload_outlined,
//               size: 32,
//               color: Color(0xFF198B64),
//             ),
//           ),
//           const SizedBox(width: 14),
//           const Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Upload context file',
//                   style: TextStyle(
//                     color: Colors.black,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   'PDF, TXT or Markdown',
//                   style: TextStyle(color: Color(0xFF6F6F6F), fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 10),
//           SizedBox(
//             height: 58,
//             child: FilledButton(
//               onPressed: onGenerate,
//               style: FilledButton.styleFrom(
//                 backgroundColor: Colors.white,
//                 foregroundColor: const Color(0xFF198B64),
//                 textStyle: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w700,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 elevation: 0,
//               ),
//               child: const Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 18),
//                 child: Text('Generate'),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.completed,
    this.showDivider = true,
    this.onTap,
  });

  final String icon;
  final String title;
  final String summary;
  final bool completed;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final line in summary.split('\n'))
                        Text(
                          line,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6F6F6F),
                            fontSize: 12,
                            height: 1.18,
                          ),
                        ),
                    ],
                  ),
                ),
                if (completed) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check, size: 28, color: Color(0xFF00834C)),
                ],
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Color(0xFFD0D0D0),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
      ],
    );
  }
}
