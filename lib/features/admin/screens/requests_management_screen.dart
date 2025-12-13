import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/providers/game_request_provider.dart';
import '../../game/providers/event_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/game_request.dart';
import '../../../shared/models/player.dart';

class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({super.key});

  @override
  State<RequestsManagementScreen> createState() =>
      _RequestsManagementScreenState();
}

class _RequestsManagementScreenState extends State<RequestsManagementScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedEventId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      Provider.of<GameRequestProvider>(context, listen: false)
          .fetchAllRequests(),
      Provider.of<EventProvider>(context, listen: false).fetchEvents(),
      Provider.of<PlayerProvider>(context, listen: false).fetchAllPlayers(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = Provider.of<GameRequestProvider>(context);
    final eventProvider = Provider.of<EventProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);

    // Filtrado de solicitudes de juego
    final filteredGameRequests = requestProvider.requests.where((req) {
      final matchesName = (req.playerName ?? '')
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final matchesEvent =
          _selectedEventId == null || req.eventId == _selectedEventId;
      return matchesName && matchesEvent;
    }).toList();

    // Filtrado de usuarios pendientes
    final pendingUsers = playerProvider.allPlayers.where((player) {
      final matchesName = player.name
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      return matchesName && player.status == PlayerStatus.pending;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.mark_email_unread, color: Colors.white),
            SizedBox(width: 10),
            Text("Gestión de Solicitudes"),
          ],
        ),
        backgroundColor: AppTheme.darkBg,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPurple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: "Eventos"),
            Tab(text: "Nuevos Usuarios"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: Solicitudes de Eventos
            Column(
              children: [
                // Filtros
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      // Buscador por nombre
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Buscar jugador...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.5)),
                              prefixIcon: const Icon(Icons.search,
                                  color: AppTheme.primaryPurple),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Dropdown de Eventos
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedEventId,
                              hint: const Text("Filtrar por Evento",
                                  style: TextStyle(color: Colors.white54)),
                              dropdownColor: const Color(0xFF1A1F3D),
                              icon: const Icon(Icons.filter_list,
                                  color: AppTheme.secondaryPink),
                              isExpanded: true,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text("Todos los eventos"),
                                ),
                                ...eventProvider.events.map((event) {
                                  return DropdownMenuItem<String>(
                                    value: event.id,
                                    child: Text(
                                      event.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedEventId = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de resultados
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredGameRequests.isEmpty
                          ? const Center(
                              child: Text(
                                "No se encontraron solicitudes",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: filteredGameRequests.length,
                              itemBuilder: (context, index) {
                                final request = filteredGameRequests[index];
                                return _RequestCard(request: request);
                              },
                            ),
                ),
              ],
            ),

            // TAB 2: Nuevos Usuarios
            Column(
              children: [
                // Buscador simple para usuarios
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario pendiente...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.search,
                            color: AppTheme.primaryPurple),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : pendingUsers.isEmpty
                          ? const Center(
                              child: Text(
                                "No hay usuarios pendientes",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: pendingUsers.length,
                              itemBuilder: (context, index) {
                                final player = pendingUsers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  color: AppTheme.cardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                        color: Colors.orange, width: 1),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      backgroundImage:
                                          player.avatarUrl.isNotEmpty
                                              ? NetworkImage(player.avatarUrl)
                                              : null,
                                      child: player.avatarUrl.isEmpty
                                          ? Text(
                                              player.name.isNotEmpty
                                                  ? player.name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      player.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      player.email,
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    trailing: ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          await Provider.of<PlayerProvider>(
                                                  context,
                                                  listen: false)
                                              .toggleBanUser(player.id, false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Usuario aprobado exitosamente')),
                                            );
                                            _loadData();
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.check,
                                          color: Colors.white),
                                      label: const Text("Aprobar"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final GameRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final requestProvider =
        Provider.of<GameRequestProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: request.statusColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.playerName ?? 'Usuario Desconocido',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: request.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: request.statusColor),
                  ),
                  child: Text(
                    request.statusText,
                    style: TextStyle(
                      color: request.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${request.playerEmail ?? "N/A"}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Evento: ${request.eventTitle ?? "ID: ${request.eventId}"}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Fecha: ${request.createdAt.toString().split('.')[0]}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (request.isPending) ...[
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await requestProvider.rejectRequest(request.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Solicitud rechazada')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Rechazar',
                        style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await requestProvider.approveRequest(request.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Solicitud aprobada')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
