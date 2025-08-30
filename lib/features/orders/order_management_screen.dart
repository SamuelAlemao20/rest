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
  final PrintingService _printingService = PrintingService();

  bool _isLoading = true;
  String? _errorMessage;
  String? _restaurantId;
  DocumentSnapshot? _restaurantSnapshot;

  // NOVO: Controle de sessão para permissão de áudio
  bool _isSessionActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _fetchRestaurantData();
  }

  Future<void> _fetchRestaurantData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _handleError("Usuário não autenticado.");
        return;
      }
      final restaurantDoc = await _restaurantService.getRestaurantByUser(
        user.uid,
      );
      if (mounted) {
        if (restaurantDoc != null && restaurantDoc.exists) {
          setState(() {
            _restaurantId = restaurantDoc.id;
            _restaurantSnapshot = restaurantDoc;
            _isLoading = false;
          });
          _listenForNewOrders();
        } else {
          _handleError("Nenhum restaurante encontrado para esta conta.");
        }
      }
    } catch (e) {
      _handleError("Ocorreu um erro ao buscar os dados do restaurante: $e");
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
      // Só toca o som se a sessão foi iniciada pelo usuário
      if (!_isSessionActive) return;

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
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    bool isOpen = _restaurantSnapshot != null
        ? (_restaurantSnapshot!.data() as Map<String, dynamic>)['isOpen'] ??
              false
        : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciador de Pedidos'),
        actions: [
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
      body: Stack(
        children: [
          Column(
            children: [
              // Barra de status Aberto/Fechado
              Container(
                color: Colors.black12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isOpen ? 'LOJA ABERTA' : 'LOJA FECHADA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOpen
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    Switch(
                      value: isOpen,
                      onChanged: (value) async {
                        await _restaurantService.updateRestaurantStatus(
                          _restaurantId!,
                          value,
                        );
                        _fetchRestaurantData(); // Recarrega os dados para atualizar a UI
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    OrderListTab(
                      status: 'pendente',
                      restaurantId: _restaurantId!,
                    ),
                    OrderListTab(
                      status: 'em preparo',
                      restaurantId: _restaurantId!,
                    ),
                    OrderListTab(
                      status: 'pronto',
                      restaurantId: _restaurantId!,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // NOVO: Overlay para iniciar a sessão
          if (!_isSessionActive)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Pronto para receber pedidos?',
                        style: TextStyle(color: Colors.white, fontSize: 22),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                        ),
                        onPressed: () {
                          // A primeira interação do usuário que habilita o som.
                          _audioPlayer.resume();
                          setState(() {
                            _isSessionActive = true;
                          });
                          // Toca um som de confirmação.
                          _playSound();
                        },
                        child: const Text('CLIQUE PARA INICIAR'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// O widget OrderListTab permanece o mesmo
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
  final OrderManagementService _orderService = OrderManagementService();
  final PrintingService _printingService = PrintingService();

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
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar pedidos: ${snapshot.error.toString()}',
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('Nenhum pedido na categoria "${widget.status}".'),
          );
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderData = order.data() as Map<String, dynamic>;
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
                    if (orderData['orderType'] == 'entrega')
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
                            onPressed: () => _orderService.updateOrderStatus(
                              order.id,
                              'rejeitado',
                            ),
                            child: const Text('REJEITAR'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              _printingService.printOrder(orderData);
                              _orderService.updateOrderStatus(
                                order.id,
                                'em preparo',
                              );
                            },
                            child: const Text('ACEITAR E IMPRIMIR'),
                          ),
                        ],
                        if (widget.status == 'em preparo')
                          FilledButton(
                            onPressed: () => _orderService.updateOrderStatus(
                              order.id,
                              'pronto',
                            ),
                            child: const Text('MARCAR COMO PRONTO'),
                          ),
                        if (widget.status == 'pronto')
                          FilledButton.tonal(
                            onPressed: () => _orderService.updateOrderStatus(
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
