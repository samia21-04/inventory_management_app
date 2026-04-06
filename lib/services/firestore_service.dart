import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// FirestoreService acts as the single source of truth for all Firestore
/// operations. Widgets should NEVER interact with Firestore directly —
/// they call methods here and react to the returned streams/futures.
class FirestoreService {
  // Reference to the 'items' collection.
  final CollectionReference<Map<String, dynamic>> _itemsRef =
      FirebaseFirestore.instance.collection('items');

  // ─────────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────────

  /// Adds a new item document to Firestore.
  Future<void> addItem(Item item) async {
    await _itemsRef.add(item.toMap());
  }

  // ─────────────────────────────────────────────
  // READ (stream)
  // ─────────────────────────────────────────────

  /// Returns a live stream of all inventory items ordered by creation date.
  /// The UI layer listens to this stream via StreamBuilder — no manual
  /// refresh needed; Firestore pushes updates automatically.
  Stream<List<Item>> streamItems() {
    return _itemsRef
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Item.fromMap(d.id, d.data())).toList());
  }

  /// Returns a stream filtered to items in a specific category.
  /// Enhanced Feature #1 — category filtering.
  Stream<List<Item>> streamItemsByCategory(String category) {
    return _itemsRef
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Item.fromMap(d.id, d.data())).toList());
  }

  /// Returns a stream of items with quantity <= 5 (low stock).
  /// Enhanced Feature #2 — low-stock alerting.
  Stream<List<Item>> streamLowStockItems() {
    return _itemsRef
        .where('quantity', isLessThanOrEqualTo: 5)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Item.fromMap(d.id, d.data())).toList());
  }

  // ─────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────

  /// Updates an existing item document by its Firestore document ID.
  Future<void> updateItem(Item item) async {
    await _itemsRef.doc(item.id).update(item.toMap());
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────

  /// Permanently removes an item from Firestore by document ID.
  Future<void> deleteItem(String id) async {
    await _itemsRef.doc(id).delete();
  }
}