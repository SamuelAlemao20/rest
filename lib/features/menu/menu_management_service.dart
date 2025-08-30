import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_restaurante/features/menu/menu_item_model.dart';

class MenuManagementService {
  final CollectionReference _menuCollection = FirebaseFirestore.instance
      .collection('menuItems');

  // Busca os itens do cardápio, agora ordenados por categoria.
  Stream<List<MenuItem>> getMenuItems(String restaurantId) {
    return _menuCollection
        .where('restaurantId', isEqualTo: restaurantId)
        //.orderBy('category') // LINHA ADICIONADA PARA ORDENAR
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MenuItem.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> addMenuItem(MenuItem item) {
    return _menuCollection.add(item.toMap());
  }

  Future<void> updateMenuItem(MenuItem item) {
    if (item.id == null) {
      throw Exception("O ID do item não pode ser nulo para uma atualização.");
    }
    return _menuCollection.doc(item.id).update(item.toMap());
  }

  Future<void> deleteMenuItem(String itemId) {
    return _menuCollection.doc(itemId).delete();
  }

  Future<void> updateAvailability(String itemId, bool isAvailable) {
    return _menuCollection.doc(itemId).update({'isAvailable': isAvailable});
  }
}
