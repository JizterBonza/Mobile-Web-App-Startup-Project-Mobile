import 'package:flutter/foundation.dart';

import '../models/farm_checkout.dart';
import '../models/gamefowl_request_draft.dart';
import '../services/farm_checkout_service.dart';

class FarmCheckoutController extends ChangeNotifier {
  FarmCheckoutController(this.service);
  final FarmCheckoutService service;
  List<FarmCartItem> items = [];
  bool _initializing = false;
  bool _requiresReview = false;
  FarmQuote? quote;
  FarmOrder? order;
  Map<String, dynamic>? recovery;
  List<List<FarmBirdDetails>> birds = [];
  Map<String, String> errors = {};
  String fulfillment = 'delivery';
  int? addressId;
  String? message;
  bool loading = false;
  bool submitting = false;
  bool _alive = true;
  int _revision = 0;
  String? paymentState;
  String? paymentUrl;
  String paymentPurpose = 'deposit';

  bool get _paymentComplete =>
      order != null &&
      (order!.closed ||
          (paymentPurpose == 'balance'
              ? order!.data['payment_status'] == 'paid'
              : order!.depositPaid));

  bool get hasAttempt => recovery?['body'] is Map;
  bool get locked => hasAttempt || order != null;
  bool get canQuote =>
      !locked &&
      !_initializing &&
      !_requiresReview &&
      items.isNotEmpty &&
      items.every((item) => item.available) &&
      (fulfillment == 'pickup' || addressId != null);
  bool get canSubmit =>
      !loading &&
      !submitting &&
      !locked &&
      quote != null &&
      !quote!.expired &&
      canQuote &&
      birds.length == items.length &&
      List.generate(items.length, (i) => birds[i].length == items[i].birdCount)
          .every((matches) => matches);
  bool get paymentUncertain =>
      ['creating', 'creation_unknown'].contains(paymentState);

  void _notify() {
    if (_alive) notifyListeners();
  }

  Future<void> initialize({GamefowlRequestDraft? request, int? orderId}) async {
    _initializing = true;
    _requiresReview = false;
    ++_revision;
    quote = null;
    items = [];
    birds = [];
    loading = true;
    message = null;
    _notify();
    try {
      recovery = await service.loadRecovery();
      if (!_alive) return;
      final savedOrderId = farmInt(recovery?['order_id']);
      if (orderId != null || savedOrderId > 0) {
        final id = orderId ?? savedOrderId;
        if (savedOrderId == id) {
          paymentPurpose =
              recovery?['payment_purpose'] == 'balance' ? 'balance' : 'deposit';
          paymentState = recovery?['payment_state']?.toString();
          paymentUrl = recovery?['checkout_url']?.toString();
        }
        order = await service.order(id);
        if (_paymentComplete) {
          await _clearOwnRecovery();
          paymentState = null;
          paymentUrl = null;
        }
        if (order!.balancePayable && paymentPurpose != 'balance') {
          paymentPurpose = 'balance';
          paymentState = null;
          paymentUrl = null;
        }
      } else if (hasAttempt) {
        message =
            'A previous order submission needs to be resolved. Retry it safely before starting another checkout.';
      } else {
        if (request == null ||
            request.farmId <= 0 ||
            request.items.isEmpty ||
            request.items
                .any((entry) => entry.listingId <= 0 || entry.quantity <= 0) ||
            request.items.map((entry) => entry.listingId).toSet().length !=
                request.items.length) {
          throw const FarmApiException(
              'This listing is missing its farm or listing ID. Reopen it from the farm.');
        }
        final loaded = <FarmCartItem>[];
        for (final entry in request.items) {
          final item =
              await service.prepareCart(entry.listingId, request.farmId);
          if (!_alive) return;
          if (item.farmId != request.farmId ||
              item.listingId != entry.listingId) {
            throw const FarmApiException('Select listings from the same farm.');
          }
          loaded.add(item);
          if (item.quantity != entry.quantity ||
              item.birdCount != entry.birds.length) {
            _requiresReview = true;
          }
        }
        items = loaded;
        birds = request.items
            .map((entry) => List<FarmBirdDetails>.of(entry.birds))
            .toList();
        if (_requiresReview) {
          message =
              'The cart quantity changed. Return to Order Request to review each bird.';
        }
        if (items.any((item) => !item.available)) {
          message =
              'A listing is no longer available. Return to Order Request.';
        }
      }
    } catch (e) {
      message = e.toString();
    } finally {
      _initializing = false;
      loading = false;
      _notify();
    }
    if (_alive && canQuote) await refreshQuote();
  }

  void setBird(int itemIndex, int index, FarmBirdDetails bird) {
    if (locked ||
        submitting ||
        itemIndex < 0 ||
        itemIndex >= birds.length ||
        index < 0 ||
        index >= birds[itemIndex].length) return;
    birds[itemIndex][index] = bird;
    errors = FarmBirdDetails.validateItems(birds);
    _notify();
  }

  Future<void> selectFulfillment(String value) async {
    if (locked ||
        submitting ||
        loading ||
        !['delivery', 'pickup'].contains(value)) return;
    fulfillment = value;
    await refreshQuote();
  }

  Future<void> selectAddress(int? id) async {
    if (locked || submitting) return;
    addressId = id;
    await refreshQuote();
  }

  Future<void> refreshQuote() async {
    final revision = ++_revision;
    quote = null;
    errors = {};
    if (!canQuote) {
      if (!_initializing) loading = false;
      _notify();
      return;
    }
    loading = true;
    message = null;
    _notify();
    try {
      final result = await service.quote(
          List<FarmCartItem>.of(items), fulfillment, addressId);
      if (!_alive || revision != _revision) return;
      final quoted = {
        for (final entry in result.items) farmInt(entry['listing_id']): entry
      };
      if (result.items.length != items.length ||
          quoted.length != items.length ||
          items.any((item) {
            final entry = quoted[item.listingId];
            return entry == null ||
                farmInt(entry['bird_count']) != item.birdCount ||
                farmInt(entry['quantity']) != item.quantity;
          }) ||
          farmInt(result.data['bird_count']) !=
              items.fold<int>(0, (sum, item) => sum + item.birdCount)) {
        throw const FarmApiException(
            'The cart changed. Return to Order Request to review the current quantity.');
      }
      quote = result;
    } catch (e) {
      if (_alive && revision == _revision) message = e.toString();
    } finally {
      if (_alive && revision == _revision) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> changeQuantity(int itemIndex, int quantity) async {
    if (locked ||
        _requiresReview ||
        loading ||
        submitting ||
        itemIndex < 0 ||
        itemIndex >= items.length ||
        quantity < 1 ||
        quantity > 100000) return;
    ++_revision;
    quote = null;
    loading = true;
    message = null;
    _notify();
    try {
      final updated = await service.setQuantity(items[itemIndex], quantity);
      if (!_alive) return;
      if (updated.farmId != items[itemIndex].farmId ||
          updated.listingId != items[itemIndex].listingId) {
        throw const FarmApiException(
            'The cart changed. Return to Order Request.');
      }
      items[itemIndex] = updated;
      birds[itemIndex] = List.generate(
          updated.birdCount,
          (i) => i < birds[itemIndex].length
              ? birds[itemIndex][i]
              : const FarmBirdDetails());
    } catch (e) {
      message = e.toString();
    } finally {
      loading = false;
      _notify();
    }
    if (_alive && canQuote && message == null) await refreshQuote();
  }

  Future<void> submit() async {
    if (submitting || order != null) return;
    if (!hasAttempt) {
      if (!canSubmit) {
        if (quote?.expired == true) {
          await refreshQuote();
          message =
              'Your quote expired. Review the refreshed amounts before placing the order.';
          _notify();
        }
        return;
      }
      errors = FarmBirdDetails.validateItems(birds);
      if (errors.isNotEmpty) {
        message = 'Check the bird details below.';
        _notify();
        return;
      }
    }
    submitting = true;
    message = null;
    _notify();
    try {
      if (!hasAttempt) {
        if (await service.loadRecovery() != null) {
          throw const FarmApiException(
              'Resolve your pending checkout from Orders before submitting another one.');
        }
        final record = <String, dynamic>{
          'key': service.newKey(),
          'body': {
            'quote_token': quote!.token,
            'items': [
              for (var i = 0; i < items.length; i++)
                {
                  'listing_id': items[i].listingId,
                  'birds': birds[i].map((b) => b.toJson()).toList()
                }
            ]
          },
        };
        // A durable write must complete BEFORE any order creation request.
        await service.saveRecovery(record);
        recovery = record;
      }
      order = await service.createOrder(
          recovery!['key'] as String, farmMap(recovery!['body']));
      await service.saveRecovery({'order_id': order!.id});
      recovery = {'order_id': order!.id};
      paymentState = null;
      quote = null;
      if (order!.depositPaid) await _clearOwnRecovery();
    } on FarmApiException catch (e) {
      message =
          '${e.message}${e.retryAfter == null ? '' : ' Retry after ${e.retryAfter}.'}';
      errors = e.errors.map((key, value) =>
          MapEntry(key, value is List ? value.join('\n') : value.toString()));
      // An explicit validation/rejected-quote response is not an uncertain creation.
      final lowerMessage = e.message.toLowerCase();
      final rejectedQuote = e.statusCode == 409 &&
          !lowerMessage.contains('idempotency') &&
          [
            'quote',
            'inventory',
            'stock',
            'price',
            'availability',
            'quantity',
            'address'
          ].any(lowerMessage.contains);
      if (e.statusCode == 422 || rejectedQuote) {
        try {
          await service.clearRecovery();
          recovery = null;
          quote = null;
        } catch (storageError) {
          message = '$message\n$storageError';
        }
      }
    } catch (e) {
      message = e.toString();
    } finally {
      submitting = false;
      _notify();
    }
  }

  Future<void> refreshOrder({String? purpose}) async {
    if (order == null || submitting) return;
    if (purpose != null && purpose != paymentPurpose) {
      paymentPurpose = purpose;
      paymentState = null;
      paymentUrl = null;
    }
    submitting = true;
    message = null;
    _notify();
    try {
      // Balance verification uses the authoritative order response. A deposit
      // reconciliation must never restore a deposit URL as a balance session.
      final status = paymentPurpose == 'balance'
          ? <String, dynamic>{}
          : await service.reconcile(order!.id);
      order = await service.order(order!.id);
      if (_paymentComplete) {
        await _clearOwnRecovery();
        paymentState = null;
        paymentUrl = null;
      } else {
        final data = farmMap(status['data']);
        final payment = farmMap(status['payment'] ?? data['payment']);
        final session = FarmPaymentSession(
            payment.isNotEmpty
                ? payment
                : data.isNotEmpty
                    ? data
                    : status,
            200);
        if (['failed', 'expired', 'cancelled', 'canceled', 'creation_failed']
            .contains(session.state)) {
          paymentState = session.state;
          paymentUrl = null;
          await _savePayment(paymentState!);
          return;
        }
        if (session.checkoutUrl != null && !session.unresolved) {
          paymentState = session.state;
          paymentUrl = session.checkoutUrl;
          await _savePayment(paymentState!, url: paymentUrl);
          return;
        }
        if (paymentUncertain) {
          message =
              'Payment session status is still being verified. Refresh status later; do not place another order.';
        }
      }
    } catch (e) {
      message = e.toString();
    } finally {
      submitting = false;
      _notify();
    }
  }

  Future<String?> startDeposit() => _startPayment('deposit');

  Future<String?> startBalance() => _startPayment('balance');

  Future<String?> _startPayment(String purpose) async {
    if (order == null ||
        (purpose == 'balance' ? !order!.balancePayable : order!.depositPaid) ||
        order!.closed ||
        submitting) return null;
    if (paymentPurpose != purpose) {
      paymentPurpose = purpose;
      paymentState = null;
      paymentUrl = null;
    }
    if (paymentUncertain) return null;
    if (paymentUrl != null) return paymentUrl;
    submitting = true;
    message = null;
    _notify();
    try {
      // Unknown after a crash/timeout must remain unknown, never create another session.
      await _savePayment('creating');
      paymentState = 'creating';
      final session = purpose == 'balance'
          ? await service.balanceSession(order!.id)
          : await service.depositSession(order!.id);
      paymentState = session.unresolved ? 'creation_unknown' : session.state;
      paymentUrl = session.unresolved ? null : session.checkoutUrl;
      if (paymentUrl == null &&
          !session.unresolved &&
          session.state != 'creation_failed') {
        paymentState = 'creation_unknown';
      }
      await _savePayment(paymentState!, url: paymentUrl);
      if (session.unresolved) {
        message = 'Payment session is being verified. Use Refresh Status.';
      }
      return paymentUrl;
    } on FarmApiException catch (e) {
      message = e.toString();
      if (e.statusCode == 503 && e.data['status'] == 'creation_failed') {
        paymentState = 'creation_failed';
        try {
          await _savePayment(paymentState!);
        } catch (storageError) {
          message = '$message\n$storageError';
        }
      }
      return null;
    } catch (e) {
      message = e.toString();
      return null;
    } finally {
      submitting = false;
      _notify();
    }
  }

  Future<void> _savePayment(String state, {String? url}) async {
    // Never overwrite another unresolved checkout when resuming an older order.
    final saved = await service.loadRecovery();
    if (saved != null &&
        (saved['body'] is Map ||
            (farmInt(saved['order_id']) > 0 &&
                farmInt(saved['order_id']) != order!.id))) {
      throw const FarmApiException(
          'Resolve your other pending checkout from Orders first.');
    }
    await service.saveRecovery({
      'order_id': order!.id,
      'payment_state': state,
      'payment_purpose': paymentPurpose,
      if (url != null) 'checkout_url': url
    });
    recovery = {
      'order_id': order!.id,
      'payment_state': state,
      'payment_purpose': paymentPurpose,
      if (url != null) 'checkout_url': url
    };
  }

  Future<void> _clearOwnRecovery() async {
    final saved = await service.loadRecovery();
    if (farmInt(saved?['order_id']) == order?.id) {
      await service.clearRecovery();
      recovery = null;
    }
  }

  @override
  void dispose() {
    _alive = false;
    ++_revision;
    super.dispose();
  }
}
