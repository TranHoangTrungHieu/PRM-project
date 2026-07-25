import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkResult {
  final String status;
  final String txnRef;
  DeepLinkResult({required this.status, required this.txnRef});
}

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Stream<DeepLinkResult> get onPaymentResult => _onPaymentResultController.stream;
  final StreamController<DeepLinkResult> _onPaymentResultController = StreamController<DeepLinkResult>.broadcast();

  void startListening() {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'pokemonapp' && uri.host == 'payment-result') {
        final status = uri.queryParameters['status'] ?? 'failed';
        final txnRef = uri.queryParameters['txnRef'] ?? '';
        _onPaymentResultController.add(DeepLinkResult(status: status, txnRef: txnRef));
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
    _onPaymentResultController.close();
  }
}