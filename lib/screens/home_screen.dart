import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item.dart';
import 'menu_management_screen.dart';
import 'sales_reports_screen.dart';
import '../widgets/item_card.dart';
import '../widgets/cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Item> items = [];
  bool isLoading = true;
  String? loadError;

  Map<Item, int> cart = {};
  String selectedCategory = 'All';
  String searchQuery = '';

  double todayRevenue = 0.0;
  int todayItemsSold = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadTodayStats();
  }

  Future<void> _loadItems({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final data = await Supabase.instance.client
          .from('items')
          .select('id, name, category, price, is_active')
          .order('name');

      final loadedItems = data
          .map((row) => Item.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      if (!mounted) return;

      setState(() {
        items
          ..clear()
          ..addAll(loadedItems);
        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loadError = error.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadTodayStats() async {
    try {
      final now = DateTime.now();
      final startOfDay =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay =
          DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();

      final client = Supabase.instance.client;
      final sales = await client
          .from('sales')
          .select('id, total_amount')
          .gte('created_at', startOfDay)
          .lt('created_at', endOfDay);

      double revenue = 0.0;
      final saleIds = <int>[];
      for (final row in sales) {
        revenue += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
        final id = (row['id'] is num)
            ? (row['id'] as num).toInt()
            : int.tryParse(row['id']?.toString() ?? '');
        if (id != null) {
          saleIds.add(id);
        }
      }

      int itemsCount = 0;
      if (saleIds.isNotEmpty) {
        final lineItems = await client
            .from('sale_items')
            .select('quantity')
            .inFilter('sale_id', saleIds);

        for (final line in lineItems) {
          itemsCount += (line['quantity'] is num)
              ? (line['quantity'] as num).toInt()
              : int.tryParse(line['quantity']?.toString() ?? '') ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          todayRevenue = revenue;
          todayItemsSold = itemsCount;
        });
      }
    } catch (_) {
      // Keep previous values if fetch encounters an error
    }
  }

  int get cartQuantity =>
      cart.values.fold(0, (sum, quantity) => sum + quantity);

  double get cartTotal => cart.entries.fold(
    0.0,
    (sum, entry) => sum + entry.key.price * entry.value,
  );

  void addToCart(Item item) {
    setState(() {
      cart[item] = (cart[item] ?? 0) + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart'),
        duration: const Duration(milliseconds: 700),
        action: SnackBarAction(label: 'VIEW CART', onPressed: openCart),
      ),
    );
  }

  Future<void> openCart() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          initialCart: Map<Item, int>.from(cart),
          onCartChanged: (updatedCart) {
            if (mounted) {
              setState(() {
                cart = Map<Item, int>.from(updatedCart);
              });
            }
          },
        ),
      ),
    );

    if (mounted) {
      _loadTodayStats();
    }
  }

  void openMenuManagement() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuilderContext, setDialogState) {
          return MenuManagementScreen(
            items: items,

            // Add a new item to Supabase.
            onAdd: (item) async {
              try {
                await Supabase.instance.client.from('items').insert({
                  'name': item.name,
                  'category': item.category,
                  'price': item.price,
                  'is_active': item.isActive,
                });

                await _loadItems(showLoading: false);

                if (dialogContext.mounted) {
                  setDialogState(() {});
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} added successfully.'),
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not add item: $error'),
                    ),
                  );
                }
              }
            },

            // Update an existing item in Supabase.
            onEdit: (updatedItem) async {
              try {
                if (updatedItem.id == null) {
                  throw Exception('This item has no database ID.');
                }

                await Supabase.instance.client
                    .from('items')
                    .update({
                      'name': updatedItem.name,
                      'category': updatedItem.category,
                      'price': updatedItem.price,
                      'is_active': updatedItem.isActive,
                    })
                    .eq('id', updatedItem.id!);

                await _loadItems(showLoading: false);

                if (dialogContext.mounted) {
                  setDialogState(() {});
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${updatedItem.name} updated successfully.'),
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not update item: $error'),
                    ),
                  );
                }
              }
            },

            // Activate or deactivate an item in Supabase.
            onToggleActive: (item) async {
              try {
                if (item.id == null) {
                  throw Exception('This item has no database ID.');
                }

                final newActiveStatus = !item.isActive;

                await Supabase.instance.client
                    .from('items')
                    .update({'is_active': newActiveStatus})
                    .eq('id', item.id!);

                await _loadItems(showLoading: false);

                if (dialogContext.mounted) {
                  setDialogState(() {});
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${item.name} ${newActiveStatus ? 'activated' : 'deactivated'} successfully.',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not change item status: $error'),
                    ),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        setState(() => cart.clear());
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = items.where((item) => item.isActive).toList();

    final categories = activeItems
        .map((item) => item.category)
        .toSet()
        .toList()
      ..sort();

    categories.insert(0, 'All');

    final filteredItems = activeItems.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;

      final matchesSearch =
          item.name.toLowerCase().contains(searchQuery.trim().toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee Shop POS'),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(
                      Icons.coffee,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Coffee Shop POS',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Text(
                      'Sales Management',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Shopping Cart
              ListTile(
                leading: Badge(
                  isLabelVisible: cartQuantity > 0,
                  label: Text('$cartQuantity'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                title: const Text('Cart'),
                onTap: () {
                  Navigator.pop(context);
                  openCart();
                },
              ),

              // Sales Reports
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Sales Reports'),
                onTap: () async {
                  Navigator.pop(context);

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SalesReportsScreen(),
                    ),
                  );

                  if (mounted) {
                    _loadTodayStats();
                  }
                },
              ),

              // Menu Management
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('Menu Management'),
                onTap: () {
                  Navigator.pop(context);
                  openMenuManagement();
                },
              ),

              const Divider(),

              // Logout
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                iconColor: Theme.of(context).colorScheme.error,
                textColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.payments_outlined,
                      label: "Today's Sales",
                      value: 'SAR ${todayRevenue.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Items Sold',
                      value: '$todayItemsSold',
                    ),
                  ),
                ],
              ),
            ),
            // Search menu items
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search menu items...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Category filters
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];

                  return ChoiceChip(
                    label: Text(category),
                    selected: selectedCategory == category,
                    onSelected: (_) {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                  );
                },
              ),
            ),

            // Menu heading
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedCategory == 'All'
                          ? 'Menu Items'
                          : selectedCategory,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${filteredItems.length} items',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Filtered menu grid
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off, size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  'Could not load menu items.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  loadError!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _loadItems,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_off,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('No matching menu items found.'),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        searchQuery = '';
                                        selectedCategory = 'All';
                                      });
                                    },
                                    child: const Text('Clear filters'),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 240,
                                mainAxisExtent: 232,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];

                                return ItemCard(
                                  item: item,
                                  onTap: () => addToCart(item),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: cartQuantity > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: openCart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('View Cart ($cartQuantity items)'),
                        ),
                        Text('SAR ${cartTotal.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
