import 'package:flutter/material.dart';

import '../../network/api_exception.dart';
import '../../network/genesis_api.dart';
import 'create_basics_page.dart';
import 'create_characters_page.dart';
import 'create_locations_page.dart';
import 'create_origin_draft_store.dart';
import 'create_story_events_page.dart';

class CreateOriginPage extends StatefulWidget {
  const CreateOriginPage({super.key});

  @override
  State<CreateOriginPage> createState() => _CreateOriginPageState();
}

class _CreateOriginPageState extends State<CreateOriginPage> {
  final GenesisApi _api = GenesisApi();

  CreateOriginDraft _draft = CreateOriginDraft.empty();
  bool _isLoading = true;
  bool _isSubmitting = false;

  bool get _canCreate => !_isSubmitting && _draft.hasAllSectionsSaved;

  @override
  void initState() {
    super.initState();
    _reloadDraft();
  }

  Future<void> _reloadDraft() async {
    final draft = await CreateOriginDraftStore.load();
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
    final latest = await CreateOriginDraftStore.load();
    final errors = latest.validateForSubmit();
    if (errors.isNotEmpty) {
      _showError(errors.first);
      if (!mounted) return;
      setState(() => _draft = latest);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _draft = latest;
    });

    try {
      final result = await _api.createOrigin(
        payload: latest.toCreateOriginPayload(),
      );
      await CreateOriginDraftStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Created: ${result.worldviewId} (Oid ${result.oid})'),
          ),
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

  String _statusFor(bool saved) {
    return saved ? 'Completed' : 'Not started yet';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Create Origin',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 14),
              _UploadCard(onGenerate: () {}),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    _SectionRow(
                      icon: '🌐',
                      title: 'Basics',
                      status: _statusFor(_draft.basicsSaved),
                      onTap: () => _openSection(const CreateBasicsPage()),
                    ),
                    _SectionRow(
                      icon: '👤',
                      title: 'Characters',
                      status: _statusFor(_draft.charactersSaved),
                      onTap: () => _openSection(const CreateCharactersPage()),
                    ),
                    _SectionRow(
                      icon: '📍',
                      title: 'Locations (Optional)',
                      status: _statusFor(_draft.locationsSaved),
                      onTap: () => _openSection(const CreateLocationsPage()),
                    ),
                    _SectionRow(
                      icon: '📜',
                      title: 'Story Events (Optional)',
                      status: _statusFor(_draft.storyEventsSaved),
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
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _canCreate ? _onCreate : null,
            style: FilledButton.styleFrom(
              backgroundColor: _canCreate
                  ? const Color(0xFF198B64)
                  : const Color(0xFFE3E3E3),
              disabledBackgroundColor: const Color(0xFFE3E3E3),
              foregroundColor: _canCreate
                  ? Colors.white
                  : const Color(0xFF6F6F6F),
              disabledForegroundColor: const Color(0xFF6F6F6F),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(_isSubmitting ? 'Creating...' : 'Create'),
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFE7E7EA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.file_upload_outlined,
              size: 32,
              color: Color(0xFF198B64),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload context file',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'PDF, TXT or Markdown',
                  style: TextStyle(color: Color(0xFF6F6F6F), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 58,
            child: FilledButton(
              onPressed: onGenerate,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF198B64),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Text('Generate'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.title,
    required this.status,
    this.showDivider = true,
    this.onTap,
  });

  final String icon;
  final String title;
  final String status;
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: status == 'Completed'
                              ? const Color(0xFF198B64)
                              : const Color(0xFF6F6F6F),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
