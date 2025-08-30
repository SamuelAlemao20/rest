import 'dart:async';
import 'package:app_restaurante/auth/login_screen.dart';
import 'package:app_restaurante/core/services/printing_service.dart';
import 'package:app_restaurante/features/menu/menu_management_screen.dart';
import 'package:app_restaurante/features/orders/order_management_service.dart';
import 'package:app_restaurante/features/restaurant/restaurant_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _ordersSubscription;
  final RestaurantService _restaurantService = RestaurantService();

  bool _isLoading = true;
  String? _errorMessage;
  String? _restaurantId;
  bool _isStoreOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _fetchRestaurantIdAndStatus();
  }

  Future<void> _fetchRestaurantIdAndStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) _handleError("Usuário não autenticado.");
      return;
    }

    try {
      final restaurantDoc = await _restaurantService.getRestaurantByUser(
        user.uid,
      );

      if (mounted) {
        if (restaurantDoc != null && restaurantDoc.exists) {
          final data = restaurantDoc.data() as Map<String, dynamic>?;
          setState(() {
            _restaurantId = restaurantDoc.id;
            _isStoreOpen = data?['isOpen'] ?? false;
            _isLoading = false;
          });
          _listenForNewOrders();
        } else {
          _handleError("Nenhum restaurante encontrado para esta conta.");
        }
      }
    } catch (e) {
      _handleError("Ocorreu um erro ao buscar os dados do restaurante.");
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  void _listenForNewOrders() {
    if (_restaurantId == null) return;
    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantId', isEqualTo: _restaurantId)
        .where('status', isEqualTo: 'pendente')
        .orderBy('timestamp', descending: true);

    _ordersSubscription = query.snapshots().listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          _playSound();
        }
      }
    });
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/notification.mp3'));
    } catch (e) {
      debugPrint("Erro detalhado ao tocar o som: $e");
    }
  }

  Future<void> _toggleStoreStatus(bool value) async {
    if (_restaurantId == null) return;
    setState(() => _isStoreOpen = value);
    try {
      await _restaurantService.updateRestaurantStatus(_restaurantId!, value);
    } catch (e) {
      // Reverte em caso de erro
      setState(() => _isStoreOpen = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar o status da loja.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text("Voltar para o Login"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciador de Pedidos'),
        actions: [
          Tooltip(
            message: _isStoreOpen ? 'Loja Aberta' : 'Loja Fechada',
            child: Switch(
              value: _isStoreOpen,
              onChanged: _toggleStoreStatus,
              activeColor: Colors.green,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Gerenciar Cardápio',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MenuManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'NOVOS'),
            Tab(text: 'EM PREPARO'),
            Tab(text: 'PRONTOS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OrderListTab(status: 'pendente', restaurantId: _restaurantId!),
          OrderListTab(status: 'em preparo', restaurantId: _restaurantId!),
          OrderListTab(status: 'pronto', restaurantId: _restaurantId!),
        ],
      ),
    );
  }
}

class OrderListTab extends StatefulWidget {
  final String status;
  final String restaurantId;

  const OrderListTab({
    super.key,
    required this.status,
    required this.restaurantId,
  });

  @override
  State<OrderListTab> createState() => _OrderListTabState();
}

class _OrderListTabState extends State<OrderListTab> {
  late final Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    final query = FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantId', isEqualTo: widget.restaurantId)
        .where('status', isEqualTo: widget.status)
        .orderBy('timestamp', descending: true);
    _ordersStream = query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final service = OrderManagementService();
    final printingService = PrintingService();

    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('Nenhum pedido na categoria "${widget.status}".'),
          );
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Erro ao carregar os pedidos.'));
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderData = order.data() as Map<String, dynamic>;
            orderData['id'] = order.id;

            final items = (orderData['items'] as List)
                .cast<Map<String, dynamic>>();
            final timestamp = orderData['timestamp'] as Timestamp?;
            final date = timestamp?.toDate();
            final formattedDate = date != null
                ? DateFormat('dd/MM/yyyy \'às\' HH:mm').format(date)
                : 'Data indisponível';

            return Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido de $formattedDate',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    ...items.map(
                      (item) => ListTile(
                        title: Text(item['name']),
                        leading: Text('x${item['quantity']}'),
                        trailing: Text(
                          'R\$ ${item['price'].toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                    const Divider(),
                    Text(
                      'Total: R\$ ${orderData['totalAmount'].toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (orderData['orderType'] == 'entrega' &&
                        orderData['deliveryAddress'] != null)
                      Text(
                        'Endereço: ${orderData['deliveryAddress']['street']}, ${orderData['deliveryAddress']['number']}',
                      ),
                    if (orderData['orderType'] == 'retirada')
                      const Text(
                        'Tipo: Retirada no local',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.status == 'pendente') ...[
                          TextButton(
                            onPressed: () => service.updateOrderStatus(
                              order.id,
                              'rejeitado',
                            ),
                            child: const Text('REJEITAR'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              printingService.printOrder(orderData);
                              service.updateOrderStatus(order.id, 'em preparo');
                            },
                            child: const Text('ACEITAR E IMPRIMIR'),
                          ),
                        ],
                        if (widget.status == 'em preparo')
                          FilledButton(
                            onPressed: () =>
                                service.updateOrderStatus(order.id, 'pronto'),
                            child: const Text('MARCAR COMO PRONTO'),
                          ),
                        if (widget.status == 'pronto')
                          FilledButton.tonal(
                            onPressed: () => service.updateOrderStatus(
                              order.id,
                              'finalizado',
                            ),
                            child: const Text('FINALIZAR'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
