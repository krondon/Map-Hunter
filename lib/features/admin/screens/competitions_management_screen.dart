import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/providers/event_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/event.dart';
import 'competition_detail_screen.dart';

class CompetitionsManagementScreen extends StatefulWidget {
  const CompetitionsManagementScreen({super.key});

  @override
  State<CompetitionsManagementScreen> createState() =>
      _CompetitionsManagementScreenState();
}

class _CompetitionsManagementScreenState
    extends State<CompetitionsManagementScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    await Provider.of<EventProvider>(context, listen: false).fetchEvents();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent(GameEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Eliminar Competencia',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${event.title}"?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Provider.of<EventProvider>(context, listen: false)
            .deleteEvent(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Competencia eliminada correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = Provider.of<EventProvider>(context).events;

    // Solo retornamos el contenido, el Dashboard provee el Scaffold y Header
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.darkGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la Sección (Opcional, ya está en las pestañas, pero ayuda al contexto)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Gestionar Competencias",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _isLoading ? null : _loadEvents,
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy,
                                size: 64, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            const Text(
                              "No hay competencias activas",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: events.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Card(
                            elevation: 4,
                            color: AppTheme.cardBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.all(20),
                                  leading: Hero(
                                    tag: 'event_${event.id}',
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: event.imageUrl.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                    event.imageUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        color: AppTheme.primaryPurple
                                            .withOpacity(0.2),
                                      ),
                                      child: event.imageUrl.isEmpty
                                          ? const Icon(
                                              Icons.confirmation_number,
                                              color: AppTheme.primaryPurple)
                                          : null,
                                    ),
                                  ),
                                  title: Text(
                                    event.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.location_on,
                                                size: 14,
                                                color: Colors.white54),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                event.locationName ??
                                                    'Sin ubicación',
                                                style: const TextStyle(
                                                    color: Colors.white54),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.calendar_today,
                                                    size: 14,
                                                    color: Colors.white54),
                                                const SizedBox(width: 4),
                                                Text(
                                                  event.date
                                                      .toString()
                                                      .split(' ')[0],
                                                  style: const TextStyle(
                                                      color: Colors.white54),
                                                ),
                                              ],
                                            ),
                                            if (event.latitude != null &&
                                                event.longitude != null)
                                              Text(
                                                '(${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)})',
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 12),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    onPressed: () => _deleteEvent(event),
                                    tooltip: "Eliminar Evento",
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(16)),
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CompetitionDetailScreen(
                                                  event: event),
                                        ),
                                      ).then((_) => _loadEvents()); // Refresh on return
                                    },
                                    icon:
                                        const Icon(Icons.visibility, size: 18),
                                    label: const Text(
                                        "Ver Detalles y Solicitudes"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.accentGold,
                                      side: const BorderSide(
                                          color: AppTheme.accentGold,
                                          width: 0.5),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
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
}
