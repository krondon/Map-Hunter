import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../services/betting_service.dart';
import '../../../shared/models/player.dart';

class BettingModal extends StatefulWidget {
  final String eventId;

  const BettingModal({
    super.key,
    required this.eventId,
  });

  @override
  State<BettingModal> createState() => _BettingModalState();
}

class _BettingModalState extends State<BettingModal> {
  late BettingService _bettingService;
  List<String> _myBetRacerIds = [];
  Set<String> _selectedRacerIds = {};
  int _ticketPrice = 100; // Default fallback
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bettingService = BettingService(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.userId;

    // 1. Fetch Event Price
    try {
      final eventData = await Supabase.instance.client
          .from('events')
          .select('bet_ticket_price')
          .eq('id', widget.eventId)
          .maybeSingle();
      
      if (eventData != null && eventData['bet_ticket_price'] != null) {
        _ticketPrice = eventData['bet_ticket_price'] as int;
      }
    } catch (e) {
      debugPrint('Error fetching ticket price: $e');
    }

    // 2. Fetch User Bets
    if (userId != null) {
      final bets = await _bettingService.fetchUserBets(widget.eventId, userId);
      
      if (mounted) {
        setState(() {
          _myBetRacerIds = bets.map((b) => b['racer_id'].toString()).toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String racerId) {
    if (_myBetRacerIds.contains(racerId)) return; // Already bet

    setState(() {
      if (_selectedRacerIds.contains(racerId)) {
        _selectedRacerIds.remove(racerId);
      } else {
        _selectedRacerIds.add(racerId);
      }
    });
  }

  Future<void> _placeBets() async {
    if (_selectedRacerIds.isEmpty) return;

    setState(() => _isSubmitting = true);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final userId = playerProvider.currentPlayer?.userId;

    if (userId == null) return;

    final result = await _bettingService.placeBetsBatch(
      eventId: widget.eventId,
      userId: userId,
      racerIds: _selectedRacerIds.toList(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      
      if (result['success'] == true) {
        _selectedRacerIds.clear();
        await _loadData(); // Refresh bets
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ¡Apuestas realizadas con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh player balance (clovers)
        // Ideally PlayerProvider should listen to profile changes, but we can force fetch if needed.
        // Assuming Realtime updates handle it or user will see it update eventually.
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result['message'] ?? 'Falló la apuesta'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    // Use leaderboard as the list of active players.
    // Ensure we filter out those who are not strictly playing if necessary, 
    // but leaderboard usually contains active players.
    final players = gameProvider.leaderboard; 

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Realizar Apuestas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentGreen),
                  ),
                  child: Row(
                    children: [
                      Text('🎫 ', style: TextStyle(fontSize: 16)),
                      Text(
                        '$_ticketPrice 🍀',
                        style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 10),
          Divider(color: Colors.white12),
          
          // Players List
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
              : players.isEmpty
                ? Center(child: Text('No hay corredores disponibles', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: players.length,
                    padding: EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final player = players[index];
                      // Use userId as racerId to link with profiles table
                      final racerId = player.userId; 
                      
                      final isAlreadyBet = _myBetRacerIds.contains(racerId);
                      final isSelected = _selectedRacerIds.contains(racerId);
                      
                      return Card(
                        color: isSelected 
                            ? AppTheme.primaryPurple.withOpacity(0.2) 
                            : Colors.white.withOpacity(0.05),
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected 
                              ? BorderSide(color: AppTheme.primaryPurple) 
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          onTap: isAlreadyBet ? null : () => _toggleSelection(racerId),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Robust Avatar Logic
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[800],
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Builder(
                                      builder: (context) {
                                        final avatarId = player.avatarId;
                                        
                                        // 1. Prioridad: Avatar Local
                                        if (avatarId != null && avatarId.isNotEmpty) {
                                          return Image.asset(
                                            'assets/images/avatars/$avatarId.png',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 24)),
                                          );
                                        }
                                        
                                        // 2. Fallback: Foto de perfil (URL)
                                        if (player.avatarUrl.isNotEmpty && player.avatarUrl.startsWith('http')) {
                                          return Image.network(
                                            player.avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 24)),
                                          );
                                        }
                                        
                                        // 3. Fallback: Icono genérico (y para cadenas vacías)
                                        return const Center(child: Icon(Icons.person, color: Colors.white70, size: 24));
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Pistas: ${player.completedCluesCount}',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Status / Checkbox
                                if (isAlreadyBet)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Text(
                                      'APOSTADO',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    isSelected 
                                        ? Icons.check_circle 
                                        : Icons.circle_outlined,
                                    color: isSelected 
                                        ? AppTheme.primaryPurple 
                                        : Colors.white24,
                                    size: 28,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Footer
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Total a pagar:',
                         style: TextStyle(color: Colors.white54, fontSize: 12),
                       ),
                       Text(
                         '${_selectedRacerIds.length * _ticketPrice} 🍀',
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.bold,
                           fontSize: 20,
                         ),
                       ),
                     ],
                   ),
                   SizedBox(width: 20),
                   Expanded(
                     child: ElevatedButton(
                       onPressed: (_selectedRacerIds.isEmpty || _isSubmitting) 
                           ? null 
                           : _placeBets,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.accentGreen,
                         foregroundColor: Colors.black,
                         padding: EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                         disabledBackgroundColor: Colors.white10,
                         disabledForegroundColor: Colors.white30,
                       ),
                       child: _isSubmitting
                           ? SizedBox(
                               height: 20, 
                               width: 20, 
                               child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                             )
                           : Text(
                               'APOSTAR (${_selectedRacerIds.length})',
                               style: TextStyle(fontWeight: FontWeight.bold),
                             ),
                     ),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
