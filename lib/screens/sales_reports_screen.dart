
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> {
  bool isMonthly = false;
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  String? loadError;

  double totalRevenue = 0;
  int transactionCount = 0;
  int itemsSold = 0;

  final Map<String, double> paymentTotals = {
    'cash': 0,
    'card': 0,
    'mobile_banking': 0,
  };

  final Map<String, int> paymentCounts = {
    'cash': 0,
    'card': 0,
    'mobile_banking': 0,
  };

  List<Map<String, dynamic>> itemSummaries = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  DateTime get _periodStart => isMonthly
      ? DateTime(selectedDate.year, selectedDate.month)
      : DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

  DateTime get _periodEnd => isMonthly
      ? DateTime(selectedDate.year, selectedDate.month + 1)
      : DateTime(selectedDate.year, selectedDate.month, selectedDate.day + 1);

  String get _periodLabel {
    if (isMonthly) {
      const months = [
        'January', 'February', 'March', 'April',
        'May', 'June', 'July', 'August',
        'September', 'October', 'November', 'December',
      ];
      return '${months[selectedDate.month - 1]} ${selectedDate.year}';
    }

    return '${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/'
        '${selectedDate.year}';
  }

  Future<void> _loadReport() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final startUtc = _periodStart.toUtc().toIso8601String();
      final endUtc = _periodEnd.toUtc().toIso8601String();
      final client = Supabase.instance.client;

      final sales = await client
          .from('sales')
          .select('id, created_at, payment_method, total_amount')
          .gte('created_at', startUtc)
          .lt('created_at', endUtc)
          .order('created_at', ascending: false);

      double revenue = 0;
      int quantityTotal = 0;

      final Map<String, double> newPaymentTotals = {
        'cash': 0,
        'card': 0,
        'mobile_banking': 0,
      };

      final Map<String, int> newPaymentCounts = {
        'cash': 0,
        'card': 0,
        'mobile_banking': 0,
      };

      final ids = <int>[];

      for (final row in sales) {
        final id = (row['id'] as num).toInt();
        final amount = (row['total_amount'] as num).toDouble();
        final method = row['payment_method'] as String;

        ids.add(id);
        revenue += amount;
        newPaymentTotals[method] =
            (newPaymentTotals[method] ?? 0) + amount;
        newPaymentCounts[method] =
            (newPaymentCounts[method] ?? 0) + 1;
      }

      final Map<String, Map<String, dynamic>> aggregatedItems = {};

      if (ids.isNotEmpty) {
        final lines = await client
            .from('sale_items')
            .select('sale_id, item_name, quantity, subtotal')
            .inFilter('sale_id', ids);

        for (final line in lines) {
          final name = line['item_name'] as String;
          final quantity = (line['quantity'] as num).toInt();
          final subtotal = (line['subtotal'] as num).toDouble();

          quantityTotal += quantity;

          final entry = aggregatedItems.putIfAbsent(
            name,
            () => {
              'name': name,
              'quantity': 0,
              'revenue': 0.0,
            },
          );

          entry['quantity'] =
              (entry['quantity'] as int) + quantity;
          entry['revenue'] =
              (entry['revenue'] as double) + subtotal;
        }
      }

      final sortedItems = aggregatedItems.values.toList()
        ..sort(
          (a, b) => (b['revenue'] as double)
              .compareTo(a['revenue'] as double),
        );

      if (!mounted) return;

      setState(() {
        totalRevenue = revenue;
        transactionCount = sales.length;
        itemsSold = quantityTotal;
        paymentTotals
          ..clear()
          ..addAll(newPaymentTotals);
        paymentCounts
          ..clear()
          ..addAll(newPaymentCounts);
        itemSummaries = sortedItems;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = error.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isMonthly ? 'Choose a date in the month' : 'Choose report date',
    );

    if (picked == null || !mounted) return;

    setState(() {
      selectedDate = picked;
    });

    await _loadReport();
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile_banking':
        return 'Mobile Banking';
      default:
        return method;
    }
  }

  String _money(double value) => 'SAR ${value.toStringAsFixed(2)}';

  String get _exportDateSuffix {
    final year = selectedDate.year.toString();
    final month = selectedDate.month.toString().padLeft(2, '0');
    final day = selectedDate.day.toString().padLeft(2, '0');

    return isMonthly ? '${year}_$month' : '${year}_${month}_$day';
  }

  Future<void> _exportCsv() async {
    if (isLoading) return;

    try {
      final rows = <List<dynamic>>[
        ['Coffee Shop Sales Report'],
        ['Report type', isMonthly ? 'Monthly' : 'Daily'],
        ['Period', _periodLabel],
        [],
        ['Summary'],
        ['Total sales (SAR)', totalRevenue.toStringAsFixed(2)],
        ['Transactions', transactionCount],
        ['Items sold', itemsSold],
        [],
        ['Payment method', 'Transactions', 'Revenue (SAR)'],
        ...paymentTotals.entries.map(
          (entry) => [
            _paymentLabel(entry.key),
            paymentCounts[entry.key] ?? 0,
            entry.value.toStringAsFixed(2),
          ],
        ),
        [],
        ['Item', 'Quantity sold', 'Revenue (SAR)'],
        ...itemSummaries.map(
          (item) => [
            item['name'],
            item['quantity'],
            (item['revenue'] as double).toStringAsFixed(2),
          ],
        ),
      ];

      final csvText = const CsvEncoder().convert(rows);

      // UTF-8 BOM helps spreadsheet programs recognize UTF-8 text.
      final bytes = Uint8List.fromList(
        utf8.encode('\uFEFF$csvText'),
      );

      await FileSaver.instance.saveFile(
        name: 'sales_report_$_exportDateSuffix',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.custom,
        customMimeType: 'text/csv',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV report exported.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV export failed: $error')),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (isLoading) return;

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pdfContext) => [
            pw.Text(
              'Coffee Shop Sales Report',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Report type: ${isMonthly ? 'Monthly' : 'Daily'}'),
            pw.Text('Period: $_periodLabel'),
            pw.SizedBox(height: 16),
            pw.Text(
              'Summary',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total sales (SAR)', totalRevenue.toStringAsFixed(2)],
                ['Transactions', '$transactionCount'],
                ['Items sold', '$itemsSold'],
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Payment Breakdown',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Payment method', 'Transactions', 'Revenue (SAR)'],
              data: paymentTotals.entries.map((entry) {
                return [
                  _paymentLabel(entry.key),
                  '${paymentCounts[entry.key] ?? 0}',
                  entry.value.toStringAsFixed(2),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Item-wise Sales',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Quantity', 'Revenue (SAR)'],
              data: itemSummaries.map((item) {
                return [
                  item['name'] as String,
                  '${item['quantity']}',
                  (item['revenue'] as double).toStringAsFixed(2),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
            pw.Text('Generated from saved sales records.'),
          ],
        ),
      );

      final bytes = await pdf.save();

      await FileSaver.instance.saveFile(
        name: 'sales_report_$_exportDateSuffix',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF report exported.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Download report',
            icon: const Icon(Icons.download),
            onSelected: (value) {
              if (value == 'csv') {
                _exportCsv();
              } else if (value == 'pdf') {
                _exportPdf();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Download PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'csv',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Download CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Refresh report',
            onPressed: isLoading ? null : _loadReport,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Daily'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Monthly'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {isMonthly},
                  onSelectionChanged: (selection) async {
                    setState(() {
                      isMonthly = selection.first;
                    });
                    await _loadReport();
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_periodLabel),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
                              const Icon(Icons.cloud_off, size: 44),
                              const SizedBox(height: 12),
                              const Text('Could not load the sales report.'),
                              const SizedBox(height: 8),
                              Text(
                                loadError!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _loadReport,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            isMonthly ? 'Monthly Summary' : 'Daily Summary',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _ReportMetric(
                            title: 'Total Sales',
                            value: _money(totalRevenue),
                            icon: Icons.payments_outlined,
                          ),
                          _ReportMetric(
                            title: 'Transactions',
                            value: '$transactionCount',
                            icon: Icons.receipt_long_outlined,
                          ),
                          _ReportMetric(
                            title: 'Items Sold',
                            value: '$itemsSold',
                            icon: Icons.shopping_bag_outlined,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Payment Breakdown',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: Column(
                              children: paymentTotals.entries.map((entry) {
                                return ListTile(
                                  title: Text(_paymentLabel(entry.key)),
                                  subtitle: Text(
                                    '${paymentCounts[entry.key]} '
                                    'transaction(s)',
                                  ),
                                  trailing: Text(
                                    _money(entry.value),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Item-wise Sales',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (itemSummaries.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'No sales recorded for this period.',
                                  ),
                                ),
                              ),
                            )
                          else
                            Card(
                              child: Column(
                                children: itemSummaries.map((item) {
                                  return ListTile(
                                    title: Text(item['name'] as String),
                                    subtitle: Text(
                                      '${item['quantity']} sold',
                                    ),
                                    trailing: Text(
                                      _money(item['revenue'] as double),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Report period: $_periodLabel',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'These figures reflect saved sales records. '
                            'No payment processing is performed.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
