import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as webview_windows;
import 'package:flutter/foundation.dart'; // For defaultTargetPlatform
import 'package:flutter/gestures.dart'; // For EagerGestureRecognizer
import 'package:url_launcher/url_launcher.dart';

class PaymentWebViewModal extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewModal({super.key, required this.paymentUrl});

  @override
  State<PaymentWebViewModal> createState() => _PaymentWebViewModalState();
}

class _PaymentWebViewModalState extends State<PaymentWebViewModal> {
  late final WebViewController _controller;
  // Windows specific controller
  final _windowsController = webview_windows.WebviewController();
  
  bool _isLoading = true;
  bool _isWindows = false;
  bool _webLaunchStarted = false;
  String? _webLaunchError;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _launchPaymentInBrowser();
        }
      });
      return;
    }

    _isWindows = defaultTargetPlatform == TargetPlatform.windows;
    if (_isWindows) {
      _initWindowsController();
    } else {
      _initController();
    }
  }

  Future<void> _launchPaymentInBrowser() async {
    if (_webLaunchStarted) return;
    _webLaunchStarted = true;

    final Uri uri = Uri.parse(widget.paymentUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        final fallbackLaunched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );

        if (!fallbackLaunched && mounted) {
          setState(() {
            _webLaunchError =
                'No se pudo abrir automáticamente la pasarela. Usa el botón para reintentar.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _webLaunchError =
              'No se pudo abrir la pasarela en una nueva pestaña. Usa el botón para reintentar.';
        });
      }
      debugPrint('Web launch error: $e');
    }
  }
  
  Future<void> _initWindowsController() async {
    try {
      await _windowsController.initialize();
      
      // Load URL directly without modification
      await _windowsController.loadUrl(widget.paymentUrl);
      
      // Listen for loading state
      _windowsController.loadingState.listen((state) {
        if (mounted) {
           setState(() => _isLoading = state == webview_windows.LoadingState.loading);
        }
      });

      if (mounted) setState(() {});
    } catch(e) {
      debugPrint("Windows WebView Error: $e");
    }
  }

  void _initController() {
    // Load URL directly without modification
    final String initialUrl = widget.paymentUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
             if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
             if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
             debugPrint('WebView Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);

            // FIX CRÍTICO: Manejo de Rutas Relativas
            // Si la pasarela navega a '/charges/...' (sin esquema/host)
            if (!uri.hasScheme || !uri.hasAuthority) {
                // Obtenemos el dominio base directamente de la URL inicial (paymentUrl)
                // Esto asegura que usemos el dominio correcto que nos dio la API (ej: pagos.pagoapago.com o sandbox...)
                final initialUri = Uri.parse(widget.paymentUrl);
                final String baseUrl = '${initialUri.scheme}://${initialUri.authority}'; 
                
                final String path = request.url.startsWith('/') ? request.url : '/${request.url}';
                final String fixedUrl = '$baseUrl$path';

                debugPrint("Redireccionando ruta relativa detectada: $request.url -> $fixedUrl");
                
                // Cargamos manualmente la URL corregida
                _controller.loadRequest(Uri.parse(fixedUrl));

                // PREVENIMOS que Flutter/GoRouter intente manejar esta ruta
                return NavigationDecision.prevent;
            }

            // CASO 2: Navegación estándar (HTTPS)
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pago Seguro',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'La pasarela de pagos se abre en una pestaña nueva por seguridad del navegador.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    if (_webLaunchError != null) ...[
                      Text(
                        _webLaunchError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton(
                      onPressed: _launchPaymentInBrowser,
                      child: const Text('Abrir pasarela de pago'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Ya completé mi pago'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Altura controlada por el ModalBottomsheet pero aseguramos estructura
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header "Pago Seguro"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Pago Seguro",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Botón de Cerrar (X) retorna true para forzar verificación de saldo
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context, true), 
                ),
              ],
            ),
          ),
          
          // WebView Content
          Expanded(
            child: Stack(
              children: [
                _isWindows 
                  ? (_windowsController.value.isInitialized
                      ? webview_windows.Webview(_windowsController)
                      : const Center(child: Text("Inicializando motor de pagos...")))
                  : WebViewWidget(
                      controller: _controller,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    ),
                
                if (_isLoading)
                  Container(
                    color: Colors.white.withOpacity(0.8),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
