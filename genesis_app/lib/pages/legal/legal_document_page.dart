import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../components/page_header.dart';

enum LegalDocument {
  terms(title: 'Terms of Service', url: 'https://worldo.ai/terms/'),
  privacy(title: 'Privacy Policy', url: 'https://worldo.ai/privacy/'),
  eula(title: 'End User License Agreement', url: 'https://worldo.ai/eula/');

  const LegalDocument({required this.title, required this.url});

  final String title;
  final String url;

  static LegalDocument fromRouteValue(String value) {
    return LegalDocument.values.firstWhere(
      (item) => item.name == value,
      orElse: () => LegalDocument.terms,
    );
  }
}

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  WebViewController? _controller;
  var _loadingProgress = 0;
  var _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _loadingProgress = progress);
            },
            onPageStarted: (_) {
              if (!mounted) return;
              setState(() {
                _hasError = false;
                _loadingProgress = 0;
              });
            },
            onPageFinished: (_) {
              if (!mounted) return;
              setState(() => _loadingProgress = 100);
            },
            onWebResourceError: (_) {
              if (!mounted) return;
              setState(() => _hasError = true);
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.document.url));
      _controller = controller;
    } catch (_) {
      _controller = null;
      _hasError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: GenesisBackAppBar(pageName: widget.document.title),
      body: SafeArea(
        child: Stack(
          children: [
            if (controller == null)
              _LegalWebErrorView(
                url: widget.document.url,
                onRetry: () {
                  setState(() => _hasError = false);
                  _initializeController();
                },
              )
            else
              WebViewWidget(controller: controller),
            if (controller != null && _loadingProgress < 100)
              LinearProgressIndicator(value: _loadingProgress / 100),
            if (controller != null && _hasError)
              _LegalWebErrorView(
                url: widget.document.url,
                onRetry: () {
                  setState(() => _hasError = false);
                  controller.reload();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LegalWebErrorView extends StatelessWidget {
  const _LegalWebErrorView({required this.url, required this.onRetry});

  final String url;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Load failed',
              style: TextStyle(fontSize: 16, color: Color(0xFF111111)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                url,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
