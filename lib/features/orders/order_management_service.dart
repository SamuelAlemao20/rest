// lib/features/orders/order_management_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class OrderManagementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Método para atualizar o status de um pedido específico
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _db.collection('orders').doc(orderId).update({'status': newStatus});
    } catch (e) {
      // Em um app real, você poderia tratar esse erro de forma mais robusta
    }
  }
}
