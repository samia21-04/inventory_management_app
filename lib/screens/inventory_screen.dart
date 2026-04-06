import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/firestore_service.dart';
import '../widgets/item_form_dialog.dart';

/// Primary screen — shows the live inventory list with search and low-stock tab.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();

  // ── Enhanced Feature #1: Search / filter ──────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Enhanced Feature #2: Low-stock tab via TabBar ──────────────────────
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  List<Item> _applySearch(List<Item> items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((item) {
      return item.name.toLowerCase().contains(_searchQuery) ||
          item.category.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => ItemFormDialog(service: _service),
    );
  }

  void _showEditDialog(Item item) {
    showDialog(
      context: context,
      builder: (_) => ItemFormDialog(item: item, service: _service),
    );
  }

  Future<void> _confirmDelete(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.name}" deleted.')),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'All Items'),
            Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Low Stock'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Enhanced Feature #1: Search bar ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or category…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ),

          // ── Tab views ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllItemsTab(
                  service: _service,
                  applySearch: _applySearch,
                  onEdit: _showEditDialog,
                  onDelete: _confirmDelete,
                ),
                _LowStockTab(
                  service: _service,
                  onEdit: _showEditDialog,
                  onDelete: _confirmDelete,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Tab 1 — All Items with StreamBuilder
// ──────────────────────────────────────────────────────────────────────────────

class _AllItemsTab extends StatelessWidget {
  final FirestoreService service;
  final List<Item> Function(List<Item>) applySearch;
  final void Function(Item) onEdit;
  final void Function(Item) onDelete;

  const _AllItemsTab({
    required this.service,
    required this.applySearch,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Item>>(
      stream: service.streamItems(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final allItems = snapshot.data ?? [];
        final items = applySearch(allItems);

        // Empty state
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  allItems.isEmpty
                      ? 'No items yet.\nTap + to add your first item.'
                      : 'No results match your search.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) => _ItemCard(
            item: items[i],
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Tab 2 — Low Stock (Enhanced Feature #2)
// ──────────────────────────────────────────────────────────────────────────────

class _LowStockTab extends StatelessWidget {
  final FirestoreService service;
  final void Function(Item) onEdit;
  final void Function(Item) onDelete;

  const _LowStockTab({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Item>>(
      stream: service.streamLowStockItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.green.shade400),
                const SizedBox(height: 12),
                const Text(
                  'All items are well-stocked!',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${items.length} item(s) need restocking (qty ≤ 5)',
                style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (_, i) => _ItemCard(
                  item: items[i],
                  onEdit: onEdit,
                  onDelete: onDelete,
                  highlight: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared Item Card
// ──────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Item item;
  final void Function(Item) onEdit;
  final void Function(Item) onDelete;
  final bool highlight;

  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: highlight ? Colors.orange.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlight
            ? BorderSide(color: Colors.orange.shade300)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: item.isLowStock
              ? Colors.orange.shade100
              : theme.colorScheme.primaryContainer,
          child: Icon(
            item.isLowStock
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_outlined,
            color: item.isLowStock
                ? Colors.orange.shade800
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${item.category}'),
            Row(
              children: [
                Text('Qty: ${item.quantity}  •  '),
                Text('\$${item.price.toStringAsFixed(2)}'),
                if (item.isLowStock) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LOW STOCK',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => onEdit(item),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: theme.colorScheme.error),
              tooltip: 'Delete',
              onPressed: () => onDelete(item),
            ),
          ],
        ),
      ),
    );
  }
}