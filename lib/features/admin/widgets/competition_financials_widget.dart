import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../game/models/event.dart';
import '../../../core/theme/app_theme.dart';
import '../services/admin_service.dart';
import '../../game/services/betting_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class CompetitionFinancialsWidget extends StatefulWidget {
  final GameEvent event;

  const CompetitionFinancialsWidget({Key? key, required this.event})
      : super(key: key);

  @override
  State<CompetitionFinancialsWidget> createState() =>
      _CompetitionFinancialsWidgetState();
}

class _CompetitionFinancialsWidgetState
    extends State<CompetitionFinancialsWidget> {
  // Stream for live bets (used as trigger for refresh)
  late final Stream<List<Map<String, dynamic>>> _betsStream;
  
  // Enriched bets data (with names)
  List<Map<String, dynamic>> _enrichedBets = [];
  bool _isLoadingEnriched = false;
  late BettingService _bettingService;

  // Future for finished event results
  Future<Map<String, dynamic>>? _financialResultsFuture;

  @override
  void initState() {
    super.initState();
    _bettingService = BettingService(Supabase.instance.client);
    _setupStreams();
  }

  void _setupStreams() {
    _betsStream = Supabase.instance.client
        .from('bets')
        .stream(primaryKey: ['id'])
        .eq('event_id', widget.event.id)
        .order('created_at', ascending: false)
        .map((maps) => maps);

    if (widget.event.status == 'completed') {
       _loadFinancialResults();
    }
  }

  /// Fetches enriched bets using the RPC (with bettor & racer names).
  Future<void> _loadEnrichedBets() async {
    if (_isLoadingEnriched) return;
    _isLoadingEnriched = true;
    try {
      final enriched = await _bettingService.fetchEnrichedEventBets(widget.event.id);
      if (mounted) {
        setState(() {
          _enrichedBets = enriched;
          _isLoadingEnriched = false;
        });
      }
    } catch (e) {
      debugPrint('💰 Error loading enriched bets: $e');
      if (mounted) {
        setState(() => _isLoadingEnriched = false);
      }
    }
  }

  void _loadFinancialResults() {
     setState(() {
       _financialResultsFuture = Provider.of<AdminService>(context, listen: false)
          .getEventFinancialResults(widget.event.id);
     });
  }
  
  @override
  void didUpdateWidget(CompetitionFinancialsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.status != widget.event.status) {
       if (widget.event.status == 'completed') {
         _loadFinancialResults();
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('💰 CompetitionFinancialsWidget: Building for event ${widget.event.id}');
    debugPrint('💰 Event Status: ${widget.event.status}');

    // 1. If Event is Active (or Pending/Paused) -> Show Live Stream
    if (widget.event.status != 'completed') {
      debugPrint('💰 Showing Live Bets View');
      return _buildLiveBetsView();
    }

    // 2. If Event is Finished -> Show Final Results
    debugPrint('💰 Showing Final Results View');
    return _buildFinalResultsView();
  }

  Widget _buildLiveBetsView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _betsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('💰 Stream Error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          debugPrint('💰 Stream Waiting for data...');
          return const Center(child: CircularProgressIndicator());
        }

        final rawBets = snapshot.data!;
        debugPrint('💰 Stream received ${rawBets.length} bets');

        // Trigger enriched data load when stream changes
        if (_enrichedBets.length != rawBets.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadEnrichedBets());
        }
        
        // Calculate Total Pot from stream
        final totalPot = rawBets.fold<int>(0, (sum, bet) => sum + (bet['amount'] as num).toInt());

        // Group enriched bets by bettor (user_id)
        final Map<String, _BettorGroup> bettorGroups = {};
        final betsToDisplay = _enrichedBets.isNotEmpty ? _enrichedBets : rawBets;

        for (var bet in betsToDisplay) {
          final userId = bet['user_id'] as String;
          final bettorName = bet['bettor_name'] as String? ?? 'Apostador';
          final bettorAvatarId = bet['bettor_avatar_id'] as String?;
          final amount = (bet['amount'] as num).toInt();

          if (!bettorGroups.containsKey(userId)) {
            bettorGroups[userId] = _BettorGroup(
              userId: userId,
              name: bettorName,
              avatarId: bettorAvatarId,
            );
          }

          bettorGroups[userId]!.totalBet += amount;
          bettorGroups[userId]!.bets.add(bet);
        }

        final sortedBettors = bettorGroups.values.toList()
          ..sort((a, b) => b.totalBet.compareTo(a.totalBet));

        // Count unique bettors
        final uniqueBettors = bettorGroups.length;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryPurple.withOpacity(0.3), AppTheme.cardBg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'POTE DE APUESTAS EN VIVO',
                      style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$totalPot 🍀',
                      style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMiniStat(Icons.people, '$uniqueBettors', 'Apostadores'),
                        const SizedBox(width: 24),
                        _buildMiniStat(Icons.receipt_long, '${rawBets.length}', 'Tickets'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Section Header
              Row(
                children: [
                  const Icon(Icons.person_search, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Apostadores',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_isLoadingEnriched)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: sortedBettors.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.casino_outlined, color: Colors.white24, size: 48),
                          SizedBox(height: 12),
                          Text('Aún no hay apuestas', style: TextStyle(color: Colors.white30, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                    itemCount: sortedBettors.length,
                    itemBuilder: (context, index) {
                      final bettor = sortedBettors[index];
                      return _buildBettorCard(bettor, index);
                    },
                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 16),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildBettorCard(_BettorGroup bettor, int index) {
    final hasEnrichedData = _enrichedBets.isNotEmpty;
    final initial = bettor.name.isNotEmpty ? bettor.name[0].toUpperCase() : '?';

    return Card(
      color: Colors.white.withOpacity(0.06),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: CircleAvatar(
            backgroundColor: _getBettorColor(index),
            radius: 20,
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(
            hasEnrichedData ? bettor.name : 'Apostador #${index + 1}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${bettor.bets.length} apuesta(s) · Total: ${bettor.totalBet} 🍀',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${bettor.totalBet} 🍀',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white30,
          children: [
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.flag, color: Colors.white38, size: 14),
                SizedBox(width: 6),
                Text('Apostó a:', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ...bettor.bets.map((bet) {
              final racerName = bet['racer_name'] as String? ?? 'Participante';
              final amount = (bet['amount'] as num).toInt();
              final createdAt = DateTime.tryParse(bet['created_at']?.toString() ?? '')?.toLocal();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_run, color: Colors.lightBlueAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasEnrichedData ? racerName : 'Participante',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            if (createdAt != null)
                              Text(
                                DateFormat('HH:mm:ss').format(createdAt),
                                style: const TextStyle(color: Colors.white30, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$amount 🍀',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getBettorColor(int index) {
    const colors = [
      Colors.indigo,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
      Colors.blueGrey,
      Colors.brown,
      Colors.cyan,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  Widget _buildFinalResultsView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _financialResultsFuture,
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
         }
         if (snapshot.hasError) {
            debugPrint('💰 Future Error: ${snapshot.error}');
            return Center(child: Text('Error cargando resultados: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
         }
         
         final data = snapshot.data ?? {};
         debugPrint('💰 Financial Data: $data');
         final pot = data['pot'] ?? 0;
         
         // Logic to handle different RPC return structures
         List<dynamic> podium = [];
         List<dynamic> bettors = [];

         if (data['podium'] != null) {
            podium = data['podium'] as List<dynamic>;
         } else if (data['results'] != null) {
             // Fallback for old structure
            podium = data['results'] as List<dynamic>;
         }

         if (data['bettors'] != null) {
            bettors = data['bettors'] as List<dynamic>;
         }
         
         return SingleChildScrollView(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _buildFinanceCard(
                 title: 'POTE FINAL REPARTIDO',
                 amount: '$pot 🍀',
                 icon: Icons.flag,
                 color: AppTheme.primaryPurple,
               ),
               const SizedBox(height: 20),
               
               // --- PODIUM SECTION ---
               const Text("🏆 Podio de Ganadores", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               if (podium.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 30),
                        SizedBox(height: 10),
                        Text(
                          "Los premios aún no han sido distribuidos.", 
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Usa el botón 'Distribuir Premios' en la pestaña 'Detalles' para generar la liquidación final.",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
               else
                 ...podium.map((r) {
                   final avatarId = r['avatar_id'] as String?;
                   return Card(
                   color: Colors.white10,
                   child: ListTile(
                     leading: CircleAvatar(
                       backgroundColor: r['rank'] == 1 ? Colors.amber : (r['rank'] == 2 ? Colors.grey : Colors.brown),
                       // Use text as fallback if no image logic yet, but if avatarId is present we could use it
                       // safely assuming we don't have the avatar assets logic here imported, fallback to rank
                       child: Text('${r['rank']}'),
                     ),
                     title: Text('${r['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     subtitle: Text('Posición #${r['rank']}', style: const TextStyle(color: Colors.white54)),
                     trailing: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: [
                         const Text('Premio', style: TextStyle(color: Colors.white30, fontSize: 10)),
                         Text('+${r['amount']} 🍀', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                       ],
                     ),
                   ),
                 );
                 }).toList(),
                 
               const SizedBox(height: 30),
               const Divider(color: Colors.white24),
               const SizedBox(height: 10),
               
               // --- BETTORS SECTION ---
               const Text("📊 Desglose de Apuestas", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               
               if (bettors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        "No hubieron apuestas en este evento.",
                        style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic),
                      ),
                    ),
                  )
               else
                 ...bettors.map((b) {
                    final int net = b['net'] ?? 0;
                    final bool isWinner = net > 0;
                    final int totalWon = b['total_won'] ?? 0;
                    
                    return Card(
                      color: isWinner ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                         leading: CircleAvatar(
                           backgroundColor: Colors.blueGrey,
                           child: Text((b['name'] as String).substring(0, 1).toUpperCase()),
                         ),
                         title: Text('${b['name']}', style: const TextStyle(color: Colors.white)),
                         subtitle: Text('${b['bets_count']} apuesta(s)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                  const Text('Apostado', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text('${b['total_bet']} 🍀', style: const TextStyle(color: Colors.white70)),
                               ],
                             ),
                             const SizedBox(width: 16),
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                  const Text('Ganancia', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  Text(
                                    totalWon > 0 ? '+$totalWon 🍀' : '0 🍀', 
                                    style: TextStyle(
                                      color: totalWon > 0 ? Colors.greenAccent : Colors.white30, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16
                                    )
                                  ),
                               ],
                             ),
                           ],
                         ),
                      ),
                    );
                 }).toList(),
                 
               const SizedBox(height: 50),
             ],
           ),
         );
      },
    );
  }
  
  Widget _buildFinanceCard({required String title, required String amount, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}

/// Helper class to group bets by bettor for the live view.
class _BettorGroup {
  final String userId;
  final String name;
  final String? avatarId;
  int totalBet;
  final List<Map<String, dynamic>> bets;

  _BettorGroup({
    required this.userId,
    required this.name,
    this.avatarId,
    this.totalBet = 0,
    List<Map<String, dynamic>>? bets,
  }) : bets = bets ?? [];
}
