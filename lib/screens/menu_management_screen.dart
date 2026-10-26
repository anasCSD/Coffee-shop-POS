import 'package:flutter/material.dart';
import '../models/item.dart';

class MenuManagementScreen extends StatefulWidget {
  final List<Item> items;
  final void Function(Item) onAdd;
  final void Function(Item) onEdit;
  final void Function(Item) onToggleActive;

  const MenuManagementScreen({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  Future<void> showItemForm({Item? item}) async {
    final result = await showDialog<Item>(
      context: context,
      builder: (dialogContext) => _ItemFormDialog(item: item),
    );

    if (result == null || !mounted) return;

    if (item == null) {
      widget.onAdd(result);
    } else {
      widget.onEdit(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Menu Management'),
      content: SizedBox(
        width: 480,
        height: 400,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => showItemForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];

                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.category} • SAR ${item.price.toStringAsFixed(2)}'
                      '${item.isActive ? '' : ' • Inactive'}',
                    ),
                    leading: const Icon(Icons.coffee),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          showItemForm(item: item);
                        } else if (value == 'toggle') {
                          widget.onToggleActive(item);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            item.isActive ? 'Deactivate' : 'Activate',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ItemFormDialog extends StatefulWidget {
  final Item? item;

  const _ItemFormDialog({this.item});

  @override
  State<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<_ItemFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _categoryController = TextEditingController(
      text: widget.item?.category ?? 'Coffee',
    );
    _priceController = TextEditingController(
      text: widget.item != null ? widget.item!.price.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final price = double.tryParse(_priceController.text.trim());

    if (name.isEmpty || category.isEmpty || price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid item details.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      Item(
        id: widget.item?.id,
        name: name,
        category: category,
        price: price,
        isActive: widget.item?.isActive ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Menu Item' : 'Edit Menu Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
              ),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
            ),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Price (SAR)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

