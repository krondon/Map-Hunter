import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/player.dart';

class RaceTrackWidget extends StatelessWidget {
  final List<Player> leaderboard; // Esta lista DEBE venir de 'event_leaderboard' (donde totalXP = pistas completadas)
  final String currentPlayerId;   // ID para identificarte
  final int totalClues;           // Meta del evento (Total de pistas)
  final VoidCallback? onSurrender;

  const RaceTrackWidget({
    super.key,
    required this.leaderboard,
    required this.currentPlayerId,
    required this.totalClues,
    this.onSurrender,
  });

  @override
  Widget build(BuildContext context) {
    // Lógica principal: Seleccionar quién aparece en la carrera basado ESTRICTAMENTE en progreso del evento
    final activeRacers = _selectRacersToShow();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                   Text(
                    '🏁 CARRERA EN VIVO',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  _LiveIndicator(),
                ],
              ),
              if (onSurrender != null)
                GestureDetector(
                  onTap: onSurrender,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withOpacity(0.1),
                      border: Border.all(color: AppTheme.dangerRed.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'RENDIRSE',
                      style: TextStyle(
                        color: AppTheme.dangerRed,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // --- PISTA DE CARRERAS ---
          SizedBox(
            height: 90, 
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double trackWidth = constraints.maxWidth;
                
                return Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none, 
                  children: [
                    // 1. Línea de carrera base
                    Center(
                      child: Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [Colors.grey[800]!, Colors.grey[700]!],
                          ),
                        ),
                      ),
                    ),
                    
                    // Marcas de distancia (start, 50%, finish)
                    const Positioned(left: 0, top: 50, child: Text("START", style: TextStyle(fontSize: 8, color: Colors.white30))),
                    const Positioned(right: 0, top: 50, child: Text("META", style: TextStyle(fontSize: 8, color: Colors.white30))),

                    // Bandera de Meta
                    const Positioned(
                      right: -8,
                      top: 10,
                      child: Icon(Icons.flag_circle, color: AppTheme.accentGold, size: 36),
                    ),

                    // 2. Renderizar corredores seleccionados
                    ...activeRacers.map((racer) {
                      // CÁLCULO CRÍTICO:
                      // Usamos racer.player.totalXP porque en el GameProvider (línea 87 aprox)
                      // mapeamos el conteo de pistas de la DB a este campo.
                      // NO usamos XP global, usamos "Pistas completadas en ESTE evento".
                      final int pistasCompletadas = racer.player.totalXP;
                      
                      // Evitamos división por cero
                      final double progress = totalClues > 0 
                          ? (pistasCompletadas / totalClues).clamp(0.0, 1.0) 
                          : 0.0;
                      
                      return _buildRacerAvatar(
                        context: context,
                        player: racer.player,
                        progress: progress,
                        trackWidth: trackWidth,
                        offsetY: racer.laneOffset,
                        isMe: racer.isMe,
                        isLeader: racer.isLeader,
                        pistas: pistasCompletadas,
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          
          // Leyenda inferior dinámica
          const SizedBox(height: 8),
          Center(
            child: Text(
              _getMotivationText(activeRacers, totalClues),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE SELECCIÓN (Corregida para Datos de Evento) ---
  List<_RacerDisplayInfo> _selectRacersToShow() {
    final List<_RacerDisplayInfo> result = [];
    final Set<String> addedIds = {};

    // 1. Buscar al usuario actual DENTRO del leaderboard del evento.
    // IMPORTANTE: No usamos el perfil global del usuario, porque ese tendría XP global.
    // Queremos el objeto que vino de la DB con el conteo de pistas del evento.
    final myIndex = leaderboard.indexWhere((p) => p.id == currentPlayerId);
    
    Player meInEvent;
    
    if (myIndex != -1) {
      // El usuario ya ha completado al menos 1 pista y está en el ranking
      meInEvent = leaderboard[myIndex];
    } else {
      // El usuario tiene 0 pistas o no está en el top 50 cargado.
      // Creamos un "dummy" con 0 pistas para que aparezca en la salida.
      meInEvent = Player(
        id: currentPlayerId,
        name: 'Tú',
        email: '',
        avatarUrl: '', // Se intentará cargar, si no icono por defecto
        totalXP: 0, // 0 Pistas completadas en este evento
        stats: {},
        profession: 'Novice',
        level: 1,
        coins: 0,
      );
    }

    // 2. Siempre agregar al Top 1 (El Líder del Evento)
    if (leaderboard.isNotEmpty) {
      final leader = leaderboard.first;
      result.add(_RacerDisplayInfo(
        player: leader, 
        laneOffset: -35, // Carril superior
        isLeader: true, 
        isMe: leader.id == currentPlayerId
      ));
      addedIds.add(leader.id);
    }

    // 3. Agregar al usuario actual (si no fue agregado como líder)
    if (!addedIds.contains(meInEvent.id)) {
      result.add(_RacerDisplayInfo(
        player: meInEvent, 
        laneOffset: 0, // Carril central
        isLeader: false, 
        isMe: true
      ));
      addedIds.add(meInEvent.id);
    }

    // 4. Agregar rivales cercanos BASADOS EN EL RANKING DEL EVENTO
    if (myIndex != -1) {
      // Rival justo adelante (alguien con más pistas o mismo # pero mejor tiempo)
      if (myIndex > 0) {
        final ahead = leaderboard[myIndex - 1];
        if (!addedIds.contains(ahead.id)) {
          result.add(_RacerDisplayInfo(
            player: ahead, 
            laneOffset: 35, // Carril inferior
            isLeader: false, 
            isMe: false
          ));
          addedIds.add(ahead.id);
        }
      } else if (leaderboard.length > 2) {
         // Si yo soy el segundo, mostrar al tercero para tener contexto atrás
         final behind = leaderboard[myIndex + 1];
         if (!addedIds.contains(behind.id)) {
           result.add(_RacerDisplayInfo(
             player: behind, 
             laneOffset: 25, 
             isLeader: false, 
             isMe: false
           ));
           addedIds.add(behind.id);
         }
      }
    } else {
      // Si tengo 0 pistas (no estoy en el ranking), mostrar al último del ranking visible
      // para motivar al usuario a alcanzarlo.
      if (leaderboard.isNotEmpty) {
        final lastVisible = leaderboard.last;
        if (!addedIds.contains(lastVisible.id)) {
           result.add(_RacerDisplayInfo(
            player: lastVisible, 
            laneOffset: 30, 
            isLeader: false, 
            isMe: false
          ));
        }
      }
    }

    return result;
  }

  String _getMotivationText(List<_RacerDisplayInfo> racers, int total) {
    // Buscamos al usuario en la lista procesada
    final me = racers.firstWhere((r) => r.isMe, orElse: () => racers.first);
    final pistas = me.player.totalXP;
    
    if (pistas == 0) return "¡La carrera comienza! Completa tu primera pista 🏃💨";
    if (pistas >= total) return "¡FELICIDADES! Has llegado a la meta 🎉";
    
    if (me.isLeader) return "¡Vas en PRIMER LUGAR! Mantén el ritmo 🏆";
    
    return "Llevas $pistas de $total pistas. ¡Sigue así! 🚀";
  }

  Widget _buildRacerAvatar({
    required BuildContext context,
    required Player player,
    required double progress,
    required double trackWidth,
    required double offsetY,
    required bool isMe,
    required bool isLeader,
    required int pistas,
  }) {
    final double avatarSize = isMe ? 40 : 32;
    // Ajuste para que el centro del avatar esté en el punto exacto, sin salirse del ancho
    final double maxScroll = trackWidth - avatarSize; 
    
    return Positioned(
      left: maxScroll * progress,
      top: 45 + offsetY - (avatarSize/2), // Centrado verticalmente respecto a la pista
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador de posición (triángulo)
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Icon(Icons.arrow_drop_down, color: AppTheme.accentGold, size: 20),
            ),

          // Avatar
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isMe ? AppTheme.accentGold : (isLeader ? Colors.amber : Colors.white30),
                width: isMe ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isMe ? AppTheme.accentGold.withOpacity(0.4) : Colors.black26,
                  blurRadius: isMe ? 12 : 4,
                  spreadRadius: 1,
                )
              ],
            ),
            child: CircleAvatar(
              backgroundColor: isMe ? AppTheme.primaryPurple : Colors.grey[800],
              backgroundImage: (player.avatarUrl.isNotEmpty && player.avatarUrl.startsWith('http')) 
                  ? NetworkImage(player.avatarUrl) 
                  : null,
              child: (player.avatarUrl.isEmpty || !player.avatarUrl.startsWith('http'))
                  ? Text(
                      player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMe ? 16 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          
          // Etiqueta de Nombre y Pistas
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.accentGold : Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: isMe ? null : Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? 'TÚ' : (isLeader ? 'TOP 1' : _getShortName(player.name)),
                  style: TextStyle(
                    color: isMe ? Colors.black : Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$pistas pts', // Muestra "pts" o "pistas"
                  style: TextStyle(
                    color: isMe ? Colors.black87 : Colors.white70,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getShortName(String fullName) {
    if (fullName.isEmpty) return 'J';
    final parts = fullName.split(' ');
    if (parts.isNotEmpty) return parts[0];
    return fullName.substring(0, 3);
  }
}

class _RacerDisplayInfo {
  final Player player;
  final double laneOffset; 
  final bool isLeader;
  final bool isMe;

  _RacerDisplayInfo({
    required this.player,
    required this.laneOffset,
    required this.isLeader,
    required this.isMe,
  });
}

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
             BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 6)
          ]
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}