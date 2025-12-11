import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all'; // 'all', 'active', 'banned'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    await Provider.of<PlayerProvider>(context, listen: false).fetchAllPlayers();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPlayers = Provider.of<PlayerProvider>(context).allPlayers;

    // Lógica de filtrado
    final filteredPlayers = allPlayers.where((player) {
      final searchTerm = _searchController.text.toLowerCase();
      final matchesSearch = player.name.toLowerCase().contains(searchTerm) ||
          player.email.toLowerCase().contains(searchTerm);

      // Excluir usuarios pendientes (se gestionan en Solicitudes)
      if (player.status == PlayerStatus.pending) return false;

      bool matchesStatus = true;
      if (_filterStatus == 'active') {
        matchesStatus = player.status == PlayerStatus.active;
      } else if (_filterStatus == 'banned') {
        matchesStatus = player.status == PlayerStatus.banned;
      }

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.people, color: Colors.white),
            SizedBox(width: 10),
            Text("Gestión de Usuarios"),
          ],
        ),
        backgroundColor: AppTheme.darkBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Column(
          children: [
            // Sección de Filtros
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Buscador (Nombre/Email)
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
                          hintText: 'Buscar usuario...',
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
                  const SizedBox(width: 16),
                  // Filtro de Estado
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
                          value: _filterStatus,
                          dropdownColor: const Color(0xFF1A1F3D),
                          icon: const Icon(Icons.filter_list,
                              color: AppTheme.secondaryPink),
                          isExpanded: true,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w500),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text("Todos"),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text("Activos",
                                  style: TextStyle(color: Colors.greenAccent)),
                            ),
                            DropdownMenuItem(
                              value: 'banned',
                              child: Text("Baneados",
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _filterStatus = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Usuarios
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPlayers.isEmpty
                      ? const Center(
                          child: Text(
                            "No se encontraron usuarios",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filteredPlayers.length,
                          itemBuilder: (context, index) {
                            final player = filteredPlayers[index];
                            return _UserCard(player: player);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Player player;

  const _UserCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final isBanned = player.status == PlayerStatus.banned;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBanned ? Colors.red : Colors.green.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[800],
              backgroundImage: player.avatarUrl.isNotEmpty
                  ? NetworkImage(player.avatarUrl)
                  : null,
              child: player.avatarUrl.isEmpty
                  ? Text(
                      player.name.isNotEmpty
                          ? player.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name.isNotEmpty ? player.name : 'Sin Nombre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    player.email,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBanned
                          ? Colors.red.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isBanned ? 'BANEADO' : 'ACTIVO',
                      style: TextStyle(
                        color: isBanned ? Colors.red : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isBanned ? Icons.lock_open : Icons.block,
                color: isBanned ? Colors.green : Colors.orange,
              ),
              tooltip: isBanned ? 'Desbanear Usuario' : 'Banear Usuario',
              onPressed: () => _confirmBanAction(context, player),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Eliminar Usuario',
              onPressed: () => _confirmDeleteAction(context, player),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAction(BuildContext context, Player player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Eliminar Usuario',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que deseas ELIMINAR DEFINITIVAMENTE a ${player.name}?\n\nEsta acción borrará su cuenta, progreso y autenticación. No se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Provider.of<PlayerProvider>(context, listen: false)
                    .deleteUser(player.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Usuario eliminado correctamente')),
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
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBanAction(BuildContext context, Player player) {
    final isBanned = player.status == PlayerStatus.banned;
    final action = isBanned ? 'desbanear' : 'banear';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Confirmar acción',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que deseas $action a ${player.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Provider.of<PlayerProvider>(context, listen: false)
                    .toggleBanUser(player.id, !isBanned);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Usuario ${isBanned ? 'desbaneado' : 'baneado'} exitosamente')),
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
            child: Text(
              isBanned ? 'Desbanear' : 'Banear',
              style: TextStyle(color: isBanned ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
