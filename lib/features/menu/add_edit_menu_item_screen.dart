import 'package:app_restaurante/features/menu/menu_item_model.dart';
import 'package:app_restaurante/features/menu/menu_management_service.dart';
import 'package:flutter/material.dart';

class AddEditMenuItemScreen extends StatefulWidget {
  final MenuItem?
  menuItem; // Se for nulo, é um novo item. Se não, está editando.
  final String restaurantId;

  const AddEditMenuItemScreen({
    super.key,
    this.menuItem,
    required this.restaurantId,
  });

  @override
  State<AddEditMenuItemScreen> createState() => _AddEditMenuItemScreenState();
}

class _AddEditMenuItemScreenState extends State<AddEditMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.menuItem != null) {
      // Se estiver editando, preenche os campos com os dados existentes.
      _nameController.text = widget.menuItem!.name;
      _descriptionController.text = widget.menuItem!.description;
      _priceController.text = widget.menuItem!.price.toStringAsFixed(2);
      _categoryController.text = widget.menuItem!.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      final menuItem = MenuItem(
        id: widget.menuItem?.id,
        name: _nameController.text,
        description: _descriptionController.text,
        price:
            double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0,
        category: _categoryController.text,
        restaurantId: widget.restaurantId,
        isAvailable: widget.menuItem?.isAvailable ?? true,
      );

      final service = MenuManagementService();
      try {
        if (widget.menuItem == null) {
          await service.addMenuItem(menuItem);
        } else {
          await service.updateMenuItem(menuItem);
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao salvar o item: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.menuItem == null ? 'Adicionar Item' : 'Editar Item'),
        actions: [
          if (!_isSaving)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveItem),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Prato',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Preço (Ex: 25,50)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Campo obrigatório';
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Preço inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoria (Ex: Prato Principal)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Campo obrigatório' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
