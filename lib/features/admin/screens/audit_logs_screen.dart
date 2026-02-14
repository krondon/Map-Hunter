import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/admin_service.dart';
import '../models/audit_log.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<AuditLog> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  // Filters
  String? _selectedActionType;
  final List<String> _actionTypes = [
    'INSERT', 'UPDATE', 'DELETE', 'PLAYER_ACCEPTED', 'UPDATE_SENSITIVE'
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      if (refresh) {
        _logs.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final newLogs = await adminService.getAuditLogs(
        limit: _limit,
        offset: _offset,
        actionType: _selectedActionType,
      );

      setState(() {
        _logs.addAll(newLogs);
        _offset += newLogs.length;
        if (newLogs.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando logs: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE')) return Colors.red.shade200;
    if (action.contains('INSERT') || action.contains('CREATE')) return Colors.green.shade200;
    if (action.contains('UPDATE')) return Colors.orange.shade200;
    if (action.contains('ACCEPTED')) return Colors.blue.shade200;
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría de Acciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadLogs(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('Filtrar por Acción: '),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedActionType,
                  hint: const Text('Todos'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ..._actionTypes.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedActionType = value;
                    });
                    _loadLogs(refresh: true);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _logs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _logs.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final log = _logs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getActionColor(log.actionType),
                      child: Icon(
                        _getIconForAction(log.actionType),
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                    title: Text(log.actionType, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Admin: ${log.adminEmail ?? log.adminId ?? 'Sistema'} \nTarget: ${log.targetTable} (${log.targetId})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      _formatDate(log.createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SelectableText(
                            _prettyPrintJson(log.details),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
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
    );
  }

  IconData _getIconForAction(String action) {
    if (action.contains('DELETE')) return Icons.delete;
    if (action.contains('INSERT') || action.contains('CREATE')) return Icons.add_circle;
    if (action.contains('UPDATE')) return Icons.edit;
    if (action.contains('ACCEPTED')) return Icons.check_circle;
    return Icons.info;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  String _prettyPrintJson(Map<String, dynamic> json) {
    var encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
