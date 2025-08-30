import 'package:cloud_firestore/cloud_firestore.dart';

// Representa um único item no cardápio.
class MenuItem {
  final String? id; // ID do documento no Firestore
  final String name;
  final String description;
  final double price;
  final String category;
  final bool isAvailable; // Controla se o item está disponível ou não
  final String restaurantId; // Liga o item ao restaurante

  MenuItem({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.isAvailable = true, // Por padrão, um item novo está sempre disponível
    required this.restaurantId,
  });

  // Converte um objeto MenuItem em um formato compatível com o Firestore (Map).
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'isAvailable': isAvailable,
      'restaurantId': restaurantId,
    };
  }

  // Cria um objeto MenuItem a partir de um documento do Firestore.
  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      restaurantId: data['restaurantId'] ?? '',
    );
  }
}
