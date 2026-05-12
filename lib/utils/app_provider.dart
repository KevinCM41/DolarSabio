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

  // ── Filtro ────────────────────────────────────────────────────────────────
  String filterType = 'all'; // 'all' | 'income' | 'expense'

  List<Transaction> get filteredTransactions {
    if (filterType == 'income') {
      return _transactions.where((t) => t.credito > 0).toList();
    } else if (filterType == 'expense') {
      return _transactions.where((t) => t.debito > 0).toList();
    }
    return _transactions;
  }

  // ── Resumen financiero ────────────────────────────────────────────────────
  FinancialSummary get summary {
    final incomes =
        _transactions.fold<double>(0, (acc, t) => acc + t.credito);
    final expenses =
        _transactions.fold<double>(0, (acc, t) => acc + t.debito);
    return FinancialSummary(
      totalIncomes: incomes,
      totalExpenses: expenses,
      balance: incomes - expenses,
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
  void setFilter(String type) {
    filterType = type;
    notifyListeners();
  }

  void renameColumn(String key, String value) {
    columnLabels[key] = value;
    notifyListeners();
  }

  List<Transaction> get sortedByDate {
    final list = List<Transaction>.from(_transactions);
    list.sort((a, b) {
      final da = DateTime.tryParse(a.fecha) ?? DateTime(0);
      final db = DateTime.tryParse(b.fecha) ?? DateTime(0);
      return db.compareTo(da);
    });
    return list;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
