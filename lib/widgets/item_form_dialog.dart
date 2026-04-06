import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/item.dart';
import '../services/firestore_service.dart';

/// Reusable dialog form for adding or editing an inventory item.
/// Pass an existing [item] to pre-fill fields for an edit operation;
/// leave [item] null to get a blank "add" form.
class ItemFormDialog extends StatefulWidget {
  final Item? item; // null = add mode, non-null = edit mode
  final FirestoreService service;

  const ItemFormDialog({super.key, this.item, required this.service});

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;

  bool _isSaving = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill controllers when editing an existing item.
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _categoryController =
        TextEditingController(text: widget.item?.category ?? '');
    _quantityController = TextEditingController(
        text: widget.item != null ? widget.item!.quantity.toString() : '');
    _priceController = TextEditingController(
        text: widget.item != null
            ? widget.item!.price.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks.
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ─── Validation ──────────────────────────────

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Item name cannot be empty.';
    if (v.trim().length < 2) return 'Name must be at least 2 characters.';
    return null;
  }

  String? _validateCategory(String? v) {
    if (v == null || v.trim().isEmpty) return 'Category cannot be empty.';
    return null;
  }

  String? _validateQuantity(String? v) {
    if (v == null || v.trim().isEmpty) return 'Quantity cannot be empty.';
    final parsed = int.tryParse(v.trim());
    if (parsed == null) return 'Quantity must be a whole number.';
    if (parsed < 0) return 'Quantity cannot be negative.';
    return null;
  }

  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'Price cannot be empty.';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Price must be a valid number (e.g. 9.99).';
    if (parsed < 0) return 'Price cannot be negative.';
    return null;
  }

  // ─── Submit ──────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        final updated = widget.item!.copyWith(
          name: _nameController.text.trim(),
          category: _categoryController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
          price: double.parse(_priceController.text.trim()),
        );
        await widget.service.updateItem(updated);
      } else {
        final newItem = Item(
          id: '', // Firestore auto-generates the ID on add
          name: _nameController.text.trim(),
          category: _categoryController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
          price: double.parse(_priceController.text.trim()),
          createdAt: DateTime.now(),
        );
        await widget.service.addItem(newItem);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Item' : 'Add New Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
              ),
              const SizedBox(height: 12),

              // Category
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _validateCategory,
              ),
              const SizedBox(height: 12),

              // Quantity — numeric keyboard, whole numbers only
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateQuantity,
              ),
              const SizedBox(height: 12),

              // Price — numeric keyboard, decimals allowed
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (\$)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: _validatePrice,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save Changes' : 'Add Item'),
        ),
      ],
    );
  }
}