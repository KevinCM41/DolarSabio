// lib/models/transaction.dart
// Equivalente a src/types.ts

class Transaction {
  final String? id;
  final String userId;
  final String recordId;
  final String codigo;
  final String cuenta;
  final String descripcion;
  final String fecha;
  final double debito;
  final double credito;

  Transaction({
    this.id,
    required this.userId,
    this.recordId = '',
    this.codigo = '',
    this.cuenta = '',
    this.descripcion = '',
    required this.fecha,
    this.debito = 0,
    this.credito = 0,
  });

  factory Transaction.fromMap(Map<String, dynamic> map, String id) {
    return Transaction(
      id: id,
      userId: map['userId'] ?? '',
      recordId: map['recordId'] ?? '',
      codigo: map['codigo'] ?? '',
      cuenta: map['cuenta'] ?? '',
      descripcion: map['descripcion'] ?? '',
      fecha: map['fecha'] ?? '',
      debito: (map['debito'] as num?)?.toDouble() ?? 0.0,
      credito: (map['credito'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'recordId': recordId,
      'codigo': codigo,
      'cuenta': cuenta,
      'descripcion': descripcion,
      'fecha': fecha,
      'debito': debito,
      'credito': credito,
    };
  }

  Transaction copyWith({
    String? id,
    String? userId,
    String? recordId,
    String? codigo,
    String? cuenta,
    String? descripcion,
    String? fecha,
    double? debito,
    double? credito,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recordId: recordId ?? this.recordId,
      codigo: codigo ?? this.codigo,
      cuenta: cuenta ?? this.cuenta,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      debito: debito ?? this.debito,
      credito: credito ?? this.credito,
    );
  }
}

/// [totalIncomes] = Σ `credito` (tarjeta CRÉDITOS).
/// [totalExpenses] = Σ `debito` (tarjeta DÉBITOS).
/// [balance] = Σ débito − Σ crédito (capital / saldo neto en esta convención).
class FinancialSummary {
  final double totalIncomes;
  final double totalExpenses;
  final double balance;
  final int transactionCount;

  FinancialSummary({
    required this.totalIncomes,
    required this.totalExpenses,
    required this.balance,
    required this.transactionCount,
  });
}
