
import 'package:flutter/material.dart';
import '../models/item.dart';

class SaleDialog extends StatefulWidget {
  final Item item;

  const SaleDialog({
    super.key,
    required this.item,
  });

  @override
  State<SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<SaleDialog> {
  int quantity = 1;
  String paymentMethod = 'cash';

  @override
  Widget build(BuildContext context) {
    final total = widget.item.price * quantity;

    return AlertDialog(
      title: Text('Add Sale - ${widget.item.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit price: SAR ${widget.item.price.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantity'),
              Row(
                children: [
                  IconButton(
                    onPressed: quantity > 1
                        ? () => setState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$quantity',
                    style: const TextStyle(fontSize: 18),
                  ),
                  IconButton(
                    onPressed: () => setState(() => quantity++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment method',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'cash',
                child: Text('Cash'),
              ),
              DropdownMenuItem(
                value: 'card',
                child: Text('Card'),
              ),
              DropdownMenuItem(
                value: 'mobile_banking',
                child: Text('Mobile Banking'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => paymentMethod = value);
              }
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Total: SAR ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'UI test only. Sale has not been saved.',
                ),
              ),
            );
          },
          child: const Text('Record Sale'),
        ),
      ],
    );
  }
}
