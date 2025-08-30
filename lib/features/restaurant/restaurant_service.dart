import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Busca o documento do restaurante com base no UID do usuário proprietário.
  Future<DocumentSnapshot?> getRestaurantByUser(String ownerUid) async {
    try {
      final querySnapshot = await _db
          .collection('restaurants')
          .where('ownerUid', isEqualTo: ownerUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first;
      }
      return null;
    } catch (e) {
      print("Erro ao buscar restaurante por usuário: $e");
      return null;
    }
  }

  /// Atualiza o status de "aberto/fechado" do restaurante no Firestore.
  Future<void> updateRestaurantStatus(String restaurantId, bool isOpen) {
    return _db.collection('restaurants').doc(restaurantId).update({
      'isOpen': isOpen,
    });
  }
}
