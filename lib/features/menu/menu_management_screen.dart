import 'package:app_restaurante/features/menu/add_edit_menu_item_screen.dart';
import 'package:app_restaurante/features/menu/menu_item_model.dart';
import 'package:app_restaurante/features/menu/menu_management_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final MenuManagementService _service = MenuManagementService();
  String? _restaurantId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRestaurantId();
  }

  Future<void> _fetchRestaurantId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('ownerUid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (mounted && querySnapshot.docs.isNotEmpty) {
        setState(() {
          _restaurantId = querySnapshot.docs.first.id;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToAddEditScreen([MenuItem? item]) {
    if (_restaurantId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AddEditMenuItemScreen(menuItem: item, restaurantId: _restaurantId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Cardápio')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _restaurantId == null
          ? const Center(child: Text('Restaurante não encontrado.'))
          : StreamBuilder<List<MenuItem>>(
              stream: _service.getMenuItems(_restaurantId!),
              builder: (context, snapshot) {
                // Logs de diagnóstico no console.
                debugPrint("Estado da Conexão: ${snapshot.connectionState}");
                if (snapshot.hasError) {
                  debugPrint("ERRO NO STREAM: ${snapshot.error}");
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Lógica de erro para exibir detalhes na tela.
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Ocorreu um erro ao carregar o cardápio.\n\nDetalhes do Erro:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Nenhum item no cardápio. Adicione um!'),
                  );
                }

                final menuItems = snapshot.data!;

                return ListView.builder(
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          item.name,
                          style: TextStyle(
                            decoration: item.isAvailable
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          "${item.category} - ${item.description}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('R\$ ${item.price.toStringAsFixed(2)}'),
                            Switch(
                              value: item.isAvailable,
                              onChanged: (value) {
                                _service.updateAvailability(item.id!, value);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _navigateToAddEditScreen(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmation(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditScreen(),
        tooltip: 'Adicionar Item',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(MenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('APAGAR'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _service.deleteMenuItem(item.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${item.name}" foi apagado.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao apagar o item: $e')));
        }
      }
    }
  }
}
