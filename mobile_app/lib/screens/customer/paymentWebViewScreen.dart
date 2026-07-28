import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../constants/constants.dart';
import '../../services/payment_service.dart';

enum PaymentResult { success, failed, cancelled }

class PaymentWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String orderId;
  final String? successUrlPattern;
  final String? failedUrlPattern;
  final String? cancelUrlPattern;

  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.orderId,
    this.successUrlPattern,
    this.failedUrlPattern,
    this.cancelUrlPattern,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isCheckingStatus = false;
  bool _hasError = false;
  String? _errorMessage;
  int _loadingProgress = 0;

  static const _defaultSuccessPatterns = [
    '/payment/success',
    '/checkout/success',
    'status=paid',
    'status=succeeded',
    '/thank-you',
    '/order-confirmed',
  ];

  static const _defaultFailedPatterns = [
    '/payment/failed',
    '/checkout/failed',
    'status=failed',
    'status=expired',
  ];

  static const _defaultCancelPatterns = [
    '/payment/cancel',
    '/checkout/cancel',
    'status=cancelled',
    'status=canceled',
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            final result = _detectPaymentResult(url);
            if (result != null) {
              Navigator.of(context).pop(result);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  PaymentResult? _detectPaymentResult(String url) {
    final successPatterns = widget.successUrlPattern != null
        ? [widget.successUrlPattern!]
        : _defaultSuccessPatterns;

    final failedPatterns = widget.failedUrlPattern != null
        ? [widget.failedUrlPattern!]
        : _defaultFailedPatterns;

    final cancelPatterns = widget.cancelUrlPattern != null
        ? [widget.cancelUrlPattern!]
        : _defaultCancelPatterns;

    for (final pattern in successPatterns) {
      if (url.contains(pattern.toLowerCase())) return PaymentResult.success;
    }
    for (final pattern in failedPatterns) {
      if (url.contains(pattern.toLowerCase())) return PaymentResult.failed;
    }
    for (final pattern in cancelPatterns) {
      if (url.contains(pattern.toLowerCase())) return PaymentResult.cancelled;
    }
    return null;
  }

  Future<void> _onClosePressed() async {
    if (_isCheckingStatus) return;

    setState(() => _isCheckingStatus = true);

    try {
      final statusResult = await _paymentService.getPaymentStatus(
        orderId: widget.orderId,
      );

      if (!mounted) return;

      if (statusResult['success'] == true &&
          (statusResult['is_paid'] == true ||
              statusResult['payment_status']?.toLowerCase() == 'paid')) {
        Navigator.of(context).pop(PaymentResult.success);
        return;
      }

      Navigator.of(context).pop(PaymentResult.cancelled);
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(PaymentResult.cancelled);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            SizedBox(width: 12),
            Text('Cancel Payment?'),
          ],
        ),
        content: Text(
          'Are you sure you want to leave? Your payment may not be completed.',
          style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Stay',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Leave',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      Navigator.of(context).pop(PaymentResult.cancelled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Complete Payment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.grey[700]),
          leading: IconButton(
            icon: _isCheckingStatus
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey[700],
                    ),
                  )
                : Icon(Icons.close),
            onPressed: _isCheckingStatus ? null : _onClosePressed,
          ),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            if (_hasError)
              _buildErrorState()
            else
              WebViewWidget(controller: _controller),
            if (_isCheckingStatus)
              Container(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 48,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Failed to load payment page',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(PaymentResult.failed),
                  icon: Icon(Icons.arrow_back, size: 18),
                  label: Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _isLoading = true;
                    });
                    _controller.loadRequest(Uri.parse(widget.checkoutUrl));
                  },
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
