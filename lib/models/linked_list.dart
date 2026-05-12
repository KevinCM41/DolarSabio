// lib/models/linked_list.dart
// Equivalente a src/lib/linkedList.ts
// Estructura de datos: lista enlazada para gestión interna de transacciones

import 'transaction.dart';

class _Node {
  Transaction value;
  _Node? next;

  _Node(this.value);
}

class TransactionLinkedList {
  _Node? _head;
  int size = 0;

  void add(Transaction transaction) {
    final newNode = _Node(transaction);
    if (_head == null) {
      _head = newNode;
    } else {
      _Node current = _head!;
      while (current.next != null) {
        current = current.next!;
      }
      current.next = newNode;
    }
    size++;
  }

  List<Transaction> toList() {
    final result = <Transaction>[];
    _Node? current = _head;
    while (current != null) {
      result.add(current.value);
      current = current.next;
    }
    return result;
  }

  void fromList(List<Transaction> transactions) {
    _head = null;
    size = 0;
    for (final t in transactions) {
      add(t);
    }
  }

  void delete(String id) {
    if (_head == null) return;
    if (_head!.value.id == id) {
      _head = _head!.next;
      size--;
      return;
    }
    _Node? current = _head;
    while (current?.next != null && current!.next!.value.id != id) {
      current = current.next;
    }
    if (current?.next != null) {
      current!.next = current.next!.next;
      size--;
    }
  }

  void update(String id, Transaction updated) {
    _Node? current = _head;
    while (current != null) {
      if (current.value.id == id) {
        current.value = updated;
        return;
      }
      current = current.next;
    }
  }
}
