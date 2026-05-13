// lib/utils/app_provider.dart
// Estado global de la app equivalente a los useState/useMemo del App.tsx

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/linked_list.dart';
import '../services/firebase_service.dart';

class AppProvider extends ChangeNotifier {
  // ── Transacciones ─────────────────────────────────────────────────────────
  List<Transaction> _transactions = [];
  List<Transaction> get transactions => _transactions;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

  final TransactionLinkedList _linkedList = TransactionLinkedList();
  StreamSubscription? _sub;

  // ── Labels de columnas (renombrables) ─────────────────────────────────────
  Map<String, String> columnLabels = {
    'recordId': 'ID',
    'codigo': 'CODIGO',
    'cuenta': 'CUENTA',
    'descripcion': 'DESCRIPCION',
    'fecha': 'FECHA',
    'debito': 'DEBITO',
    'credito': 'CREDITO',
  };

  // ── Resumen financiero ────────────────────────────────────────────────────
  FinancialSummary get summary {
    final incomes =
        _transactions.fold<double>(0, (acc, t) => acc + t.credito);
    final expenses =
        _transactions.fold<double>(0, (acc, t) => acc + t.debito);
    // Totales por columna: `credito` → UI "créditos", `debito` → UI "débitos".
    // Balance capital = débitos − créditos (equiv. egresos/ingresos según el
    // journal: el saldo neto es total débito − total crédito).
    return FinancialSummary(
      totalIncomes: incomes,
      totalExpenses: expenses,
      balance: expenses - incomes,
      transactionCount: _transactions.length,
    );
  }

  // ── Suscripción a Firestore ───────────────────────────────────────────────
  void subscribeToTransactions(String userId) {
    _sub?.cancel();
    _currentUserId = userId;
    _sub = FirebaseService.subscribeToTransactions(userId).listen((data) {
      _transactions = data;
      _linkedList.fromList(data);
      notifyListeners();
    });
  }

  void cancelSubscription() {
    _sub?.cancel();
    _currentUserId = null;
    _transactions = [];
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<void> addTransaction(Transaction t) async {
    await FirebaseService.addTransaction(t);
  }

  Future<void> updateTransactionField(
      String id, Map<String, dynamic> data) async {
    await FirebaseService.updateTransaction(id, data);
  }

  Future<void> deleteTransaction(String id) async {
    await FirebaseService.deleteTransaction(id);
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  void renameColumn(String key, String value) {
    columnLabels[key] = value;
    notifyListeners();
  }

  /// Orden cronológico ascendente (las más antiguas arriba, como un libro
  /// contable). Cuando hay empate de fecha (varias filas del mismo día),
  /// se desempata por [Transaction.recordId] numérico ascendente para que la
  /// fila «1» quede sobre la «2» y la «3».
  List<Transaction> get sortedByDate {
    final list = List<Transaction>.from(_transactions);
    list.sort((a, b) {
      final da = DateTime.tryParse(a.fecha) ?? DateTime(0);
      final db = DateTime.tryParse(b.fecha) ?? DateTime(0);
      final byDate = da.compareTo(db);
      if (byDate != 0) return byDate;
      final ia = int.tryParse(a.recordId.trim()) ?? 1 << 30;
      final ib = int.tryParse(b.recordId.trim()) ?? 1 << 30;
      if (ia != ib) return ia.compareTo(ib);
      return a.recordId.compareTo(b.recordId);
    });
    return list;
  }

  /// Siguiente ID numérico para `recordId` (autoincremento local según filas existentes).
  int nextRecordId() {
    var max = 0;
    for (final t in _transactions) {
      final n = int.tryParse(t.recordId.trim());
      if (n != null && n > max) max = n;
    }
    return max + 1;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
