import 'package:flutter/foundation.dart';

import '../models/customer_order_entry.dart';
import '../models/farm_checkout.dart';
import '../services/api_service.dart';
import '../services/farm_checkout_service.dart';

/// Customer-only enrichment; the shared item/rider order provider stays intact.
class CustomerFarmOrders extends ChangeNotifier {
  CustomerFarmOrders(
      {FarmCheckoutService? service, Future<String?> Function()? userLoader})
      : _suppliedService = service,
        _userLoader = userLoader ?? ApiService.getUserId;
  final FarmCheckoutService? _suppliedService;
  final Future<String?> Function() _userLoader;
  FarmCheckoutService? _service;
  FarmCheckoutService get service =>
      _service ??= _suppliedService ?? FarmCheckoutService();
  final Map<int, FarmOrder> orders = {};
  final Map<int, FarmOrderDetailState> detailStates = {};
  final Map<int, String> detailErrors = {};
  Map<String, dynamic>? recovery;
  String? error;
  String? _customer;
  bool loading = false;
  bool _alive = true;
  int _generation = 0;

  void _notify() {
    if (_alive) notifyListeners();
  }

  void _clear() {
    orders.clear();
    detailStates.clear();
    detailErrors.clear();
    recovery = null;
    error = null;
  }

  Future<bool> _current(int generation, String? customer) async {
    if (!_alive || generation != _generation) return false;
    final current = await _userLoader();
    if (!_alive || generation != _generation) return false;
    if (current != customer) {
      _clear();
      _customer = current;
      _service = null;
      return false;
    }
    return true;
  }

  Future<void> load() async {
    final generation = ++_generation;
    detailStates
        .removeWhere((_, state) => state == FarmOrderDetailState.loading);
    loading = true;
    error = null;
    _notify();
    try {
      final customer = await _userLoader();
      if (!_alive || generation != _generation) return;
      if (customer != _customer) {
        _clear();
        _customer = customer;
        _service = null;
      }
      if (customer == null || customer.isEmpty) {
        _clear();
        return;
      }
      List<FarmOrder>? loaded;
      Map<String, dynamic>? saved;
      String? listError;
      String? recoveryError;
      final api = service;
      await Future.wait([
        (() async {
          try {
            loaded = await api.fetchOrders();
          } catch (e) {
            listError = e.toString();
          }
        })(),
        (() async {
          try {
            saved = await api.loadRecovery();
          } catch (e) {
            recoveryError = e.toString();
          }
        })(),
      ]);
      if (!await _current(generation, customer)) return;
      if (loaded != null) {
        final old = Map<int, FarmOrder>.of(orders);
        orders.clear();
        for (final order in loaded!) {
          final previous = old[order.id];
          orders[order.id] =
              order.data['items'] is! List && previous?.data['items'] is List
                  ? FarmOrder({...order.data, 'items': previous!.data['items']})
                  : order;
        }
      }
      if (recoveryError == null) recovery = saved;
      error = [listError, recoveryError].whereType<String>().join('\n');
      if (error!.isEmpty) error = null;
      final savedId = farmInt(recovery?['order_id']);
      if (savedId > 0 && !orders.containsKey(savedId)) {
        try {
          final order = await api.order(savedId);
          if (!await _current(generation, customer)) return;
          orders[savedId] = order;
        } catch (e) {
          if (await _current(generation, customer)) error = e.toString();
        }
      }
    } catch (e) {
      if (_alive && generation == _generation) error = e.toString();
    } finally {
      if (_alive && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> ensureDetails(int id, {bool retry = false}) async {
    if (!_alive ||
        id <= 0 ||
        detailStates[id] == FarmOrderDetailState.loading) {
      return;
    }
    if (!retry &&
        (orders[id]?.data['items'] is List || detailStates.containsKey(id))) {
      return;
    }
    final generation = _generation;
    final customer = _customer;
    if (customer == null) return;
    detailStates[id] = FarmOrderDetailState.loading;
    detailErrors.remove(id);
    _notify();
    try {
      final order = await service.order(id);
      if (!await _current(generation, customer)) return;
      orders[id] = order;
      detailStates[id] = order.data['items'] is List
          ? FarmOrderDetailState.loaded
          : FarmOrderDetailState.unavailable;
    } catch (e) {
      if (await _current(generation, customer)) {
        detailStates[id] = FarmOrderDetailState.failed;
        detailErrors[id] = e.toString();
      }
    } finally {
      if (_alive && generation == _generation) {
        if (detailStates[id] == FarmOrderDetailState.loading) {
          detailStates.remove(id);
        }
        _notify();
      }
    }
  }

  void update(FarmOrder order) {
    if (!_alive) return;
    orders[order.id] = order;
    detailErrors.remove(order.id);
    detailStates[order.id] = order.data['items'] is List
        ? FarmOrderDetailState.loaded
        : FarmOrderDetailState.unavailable;
    _notify();
  }

  List<CustomerOrderEntry> merge(List<Map<String, dynamic>> basic) =>
      CustomerOrderEntry.merge(basic, orders.values,
          states: detailStates, errors: detailErrors);

  @override
  void dispose() {
    _alive = false;
    ++_generation;
    super.dispose();
  }
}
