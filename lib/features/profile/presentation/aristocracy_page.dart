import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/api/saki_api_client.dart';
import '../../../core/config/app_config.dart';

class AristocracyPage extends StatefulWidget {
  const AristocracyPage({super.key});

  @override
  State<AristocracyPage> createState() => _AristocracyPageState();
}

class _AristocracyPageState extends State<AristocracyPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final token = await const SakiApiClient().token();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'يجب تسجيل الدخول أولًا');
      return;
    }
    final uri = Uri.parse(AppConfig.aristocracyUrl)
        .replace(queryParameters: {'access_token': token});
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF08090D))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            if (mounted) setState(() => _error = 'تعذر تحميل صفحة الاستقراطية');
          },
        ),
      )
      ..addJavaScriptChannel(
        'SakiBridge',
        onMessageReceived: (message) {
          if (message.message == 'aristocracy_updated' && mounted) {
            Navigator.of(context).pop(true);
          }
        },
      )
      ..loadRequest(uri);
    _ready = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090D),
      appBar: AppBar(
        title: const Text('الاستقراطية'),
        backgroundColor: const Color(0xFF08090D),
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.amber,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _loading = true;
                      });
                      _open();
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          : !_ready
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF5C85B)),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const LinearProgressIndicator(
                    color: Color(0xFFF5C85B),
                    backgroundColor: Colors.transparent,
                  ),
              ],
            ),
    );
  }
}
