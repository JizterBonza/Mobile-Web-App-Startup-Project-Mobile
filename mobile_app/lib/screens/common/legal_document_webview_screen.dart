import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../constants/constants.dart';

bool isAllowedLegalDocumentNavigation({
  required String requestedUrl,
  required String documentUrl,
}) {
  final requestedUri = Uri.tryParse(requestedUrl);
  final documentUri = Uri.tryParse(documentUrl);

  if (requestedUri == null || documentUri == null) return false;
  if (!_isHttpUri(requestedUri) || !_isHttpUri(documentUri)) return false;

  return requestedUri.scheme.toLowerCase() ==
          documentUri.scheme.toLowerCase() &&
      requestedUri.host.toLowerCase() == documentUri.host.toLowerCase() &&
      _effectivePort(requestedUri) == _effectivePort(documentUri) &&
      requestedUri.userInfo == documentUri.userInfo &&
      _normalizedDocumentPath(requestedUri.path) ==
          _normalizedDocumentPath(documentUri.path);
}

bool _isHttpUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return uri.hasAuthority &&
      uri.host.isNotEmpty &&
      (scheme == 'http' || scheme == 'https');
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
}

String _normalizedDocumentPath(String path) {
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}

class LegalDocumentWebViewScreen extends StatefulWidget {
  final String title;
  final String documentUrl;

  const LegalDocumentWebViewScreen({
    super.key,
    required this.title,
    required this.documentUrl,
  });

  @override
  State<LegalDocumentWebViewScreen> createState() =>
      _LegalDocumentWebViewScreenState();
}

class _LegalDocumentWebViewScreenState
    extends State<LegalDocumentWebViewScreen> {
  static const _disableInteractiveNavigationScript = r'''
    (() => {
      if (window.__legalViewerNavigationLocked) return;
      window.__legalViewerNavigationLocked = true;

      const blockInteractiveNavigation = (event) => {
        const target = event.target instanceof Element
          ? event.target.closest(
              'a, button, [role="button"], input[type="button"], input[type="submit"]'
            )
          : null;

        if (!target) return;

        event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
      };

      document.addEventListener('click', blockInteractiveNavigation, true);
      document.addEventListener('auxclick', blockInteractiveNavigation, true);
      document.addEventListener('submit', (event) => {
        event.preventDefault();
        event.stopPropagation();
        event.stopImmediatePropagation();
      }, true);
      window.open = () => null;
    })();
  ''';

  late final WebViewController _controller;
  late final Uri _documentUri;

  bool _isLoading = true;
  bool _hasError = false;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _documentUri = Uri.parse(widget.documentUrl);
    _controller = WebViewController()
      // The staging legal page is client-rendered. Navigation remains locked
      // down by the delegate below even though its scripts are enabled.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
              _loadingProgress = 0;
            });
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onPageFinished: (_) async {
            try {
              await _controller.runJavaScript(
                _disableInteractiveNavigationScript,
              );
            } catch (_) {
              // The URL allowlist below remains active if injection fails.
            }

            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _loadingProgress = 100;
            });
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || url == 'about:blank') return;

            if (!isAllowedLegalDocumentNavigation(
              requestedUrl: url,
              documentUrl: widget.documentUrl,
            )) {
              _controller.loadRequest(_documentUri);
            }
          },
          onNavigationRequest: (request) {
            return isAllowedLegalDocumentNavigation(
              requestedUrl: request.url,
              documentUrl: widget.documentUrl,
            )
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(_documentUri);
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
      _loadingProgress = 0;
    });
    _controller.loadRequest(_documentUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load ${widget.title}.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading && !_hasError)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: _loadingProgress == 0 ? null : _loadingProgress / 100,
                color: AppColors.brandPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
