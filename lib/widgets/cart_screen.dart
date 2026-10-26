
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item.dart';

class CartScreen extends StatefulWidget {
  final Map<Item, int> initialCart;
  final ValueChanged<Map<Item, int>> onCartChanged;

  const CartScreen({
    super.key,
    required this.initialCart,
    required this.onCartChanged,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Map<Item, int> cart;
  String paymentMethod = 'cash';
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    cart = Map<Item, int>.from(widget.initialCart);
  }

  double get total => cart.entries.fold(
        0.0,
        (sum, entry) => sum + entry.key.price * entry.value,
      );

  int get totalQuantity =>
      cart.values.fold(0, (sum, quantity) => sum + quantity);

  void updateQuantity(Item item, int quantity) {
    if (isProcessing) return;

    setState(() {
      if (quantity <= 0) {
        cart.remove(item);
      } else {
        cart[item] = quantity;
      }
    });

    widget.onCartChanged(Map<Item, int>.from(cart));
  }

  Future<void> checkout() async {
    if (isProcessing) return;

    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }

    // Every menu item must have a database ID.
    if (cart.keys.any((item) => item.id == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A menu item is missing its database ID. Reload the menu and try again.'),
        ),
      );
      return;
    }

    // Send only item IDs and quantities.
    // The database function retrieves the current prices and calculates
    // the authoritative sale total.
    final saleItems = cart.entries.map((entry) {
      return <String, dynamic>{
        'item_id': entry.key.id,
        'quantity': entry.value,
      };
    }).toList();

    setState(() => isProcessing = true);

    try {
      final supabase = Supabase.instance.client;

      final result = await supabase.rpc(
        'record_sale',
        params: {
          'p_items': saleItems,
          'p_payment_method': paymentMethod,
        },
      );

      final saleId = (result as num).toInt();

      // Read back the saved total so the confirmation uses the
      // database-calculated amount rather than a possibly stale UI price.
      final sale = await supabase
          .from('sales')
          .select('total_amount')
          .eq('id', saleId)
          .single();

      final savedTotal = (sale['total_amount'] as num).toDouble();

      if (!mounted) return;

      setState(() {
        cart.clear();
        isProcessing = false;
      });

      widget.onCartChanged({});

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 48,
          ),
          title: const Text('Sale Saved Successfully'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sale ID: $saleId'),
              const SizedBox(height: 8),
              Text(
                'Total: SAR ${savedTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Payment method: ${paymentMethodLabel(paymentMethod)}'),
              const SizedBox(height: 8),
              const Text(
                'This records the sale only. No payment was processed.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save sale: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  String paymentMethodLabel(String value) {
    switch (value) {
      case 'card':
        return 'Card';
      case 'mobile_banking':
        return 'Mobile Banking';
      default:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          if (cart.isNotEmpty)
            TextButton.icon(
              onPressed: isProcessing
                  ? null
                  : () {
                      setState(() => cart.clear());
                      widget.onCartChanged({});
                    },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 72,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text('Go back and tap menu items to add them.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('Browse Menu'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Order Items ($totalQuantity)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...cart.entries.map((entry) {
                  final item = entry.key;
                  final quantity = entry.value;
                  final subtotal = item.price * quantity;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            child: Icon(
                              Icons.local_cafe,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'SAR ${item.price.toStringAsFixed(2)} each',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: isProcessing
                                          ? null
                                          : () => updateQuantity(
                                                item,
                                                quantity - 1,
                                              ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: isProcessing
                                          ? null
                                          : () => updateQuantity(
                                                item,
                                                quantity + 1,
                                              ),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'SAR ${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove item',
                                onPressed: isProcessing
                                    ? null
                                    : () => updateQuantity(item, 0),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: colors.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          decoration: const InputDecoration(
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
                          onChanged: isProcessing
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => paymentMethod = value);
                                  }
                                },
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Grand Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Text(
                              'SAR ${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: cart.isEmpty || isProcessing ? null : checkout,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.point_of_sale),
                  label: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      isProcessing ? 'Saving Sale...' : 'Checkout',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checkout records the sale only. '
                  'No payment is processed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
