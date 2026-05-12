// lib/services/firebase_service.dart
// Equivalente a src/services/firebaseService.ts

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/transaction.dart' as my_models;

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential?> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Transacciones ─────────────────────────────────────────────────────────
  static Stream<List<my_models.Transaction>> subscribeToTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => my_models.Transaction.fromMap(doc.data(), doc.id))
            .toList());
  }

  static Future<void> addTransaction(my_models.Transaction t) async {
    try {
      await _db.collection('transactions').add(t.toMap());
    } catch (e) {
      _handleError(e, 'create', 'transactions');
    }
  }

  static Future<void> updateTransaction(
      String id, Map<String, dynamic> data) async {
    try {
      await _db.collection('transactions').doc(id).update(data);
    } catch (e) {
      _handleError(e, 'update', 'transactions/$id');
    }
  }

  static Future<void> deleteTransaction(String id) async {
    try {
      await _db.collection('transactions').doc(id).delete();
    } catch (e) {
      _handleError(e, 'delete', 'transactions/$id');
    }
  }

  static void _handleError(Object e, String op, String path) {
    throw Exception('Firestore [$op] en $path: $e');
  }
}
