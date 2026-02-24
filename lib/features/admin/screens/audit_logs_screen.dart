import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../models/audit_log.dart';
import '../../../shared/models/player.dart';

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
  
  String? _selectedAdminId;
  List<Player> _admins = [];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
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

  Future<void> _loadAdmins() async {
    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      final admins = await adminService.fetchAdmins();
      if (mounted) {
        setState(() {
          _admins = admins;
        });
      }
    } catch (e) {
      debugPrint('Error loading admins: $e');
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
        adminId: _selectedAdminId,
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurpleAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadLogs(refresh: true);
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
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black12,
            child: Column(
              children: [
                Row(
                  children: [
                    // Action Type Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedActionType,
                        decoration: const InputDecoration(
                          labelText: 'Acción',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todas')),
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
                    ),
                    const SizedBox(width: 10),
                    // Admin Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedAdminId,
                        decoration: const InputDecoration(
                          labelText: 'Admin',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todos')),
                          ..._admins.map((p) => DropdownMenuItem(
                            value: p.userId,
                            child: Text(p.name.isNotEmpty ? p.name : p.email),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedAdminId = value;
                          });
                          _loadLogs(refresh: true);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Date Range Filter
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_selectedDateRange == null
                            ? 'Seleccionar Fechas'
                            : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}'),
                        onPressed: _selectDateRange,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    if (_selectedDateRange != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _selectedDateRange = null;
                          });
                          _loadLogs(refresh: true);
                        },
                      ),
                  ],
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
                      'Admin: ${log.adminEmail ?? log.adminId ?? 'Sistema'} \nTarget: ${log.targetTable}',
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
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _prettyPrintJson(Map<String, dynamic> json) {
    var encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
