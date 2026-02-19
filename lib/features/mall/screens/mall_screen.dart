import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mall_store.dart';
import '../../../core/theme/app_theme.dart';
import 'store_detail_screen.dart';
import '../providers/store_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/screens/qr_scanner_screen.dart'; // Import Scanner
import '../../../core/providers/app_mode_provider.dart'; // IMPORT AGREGADO

class MallScreen extends StatefulWidget {
  const MallScreen({super.key});

  @override
  State<MallScreen> createState() => _MallScreenState();
}

class _MallScreenState extends State<MallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      
      // 1. Refresh basic profile (coins, lives)
      await playerProvider.refreshProfile();

      // 2. Fetch specific event inventory (power counts for shop validation)
      // This populates the _eventInventories map used by getPowerCount
      if (gameProvider.currentEventId != null && playerProvider.currentPlayer != null) {
        storeProvider.fetchStores(gameProvider.currentEventId!);
        playerProvider.fetchInventory(
          playerProvider.currentPlayer!.userId, 
          gameProvider.currentEventId!
        );
      }
    });
  }

  void _onStoreTap(BuildContext context, MallStore store) async {
    final isOnline = Provider.of<AppModeProvider>(context, listen: false).isOnlineMode;
    
    // BYPASS ONLINE: Entrar directo sin escanear QR
    if (isOnline) {
       Navigator.push(
         context, 
         MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store))
       );
       return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Entrar a ${store.name}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Para entrar debes escanear el código QR ubicado en la tienda física.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.qr_code_scanner, size: 60, color: AppTheme.accentGold),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white60)),
          ),
          // Botón Escaneo Real
          TextButton.icon(
             icon: const Icon(Icons.qr_code, color: AppTheme.accentGold),
             label: const Text("ESCANEAR QR", style: TextStyle(color: AppTheme.accentGold)),
             onPressed: () async {
                 // Close dialog temporarily? No, push scanner on top.
                 final scannedCode = await Navigator.push<String>(
                   context, 
                   MaterialPageRoute(builder: (_) => const QRScannerScreen())
                 );
                 
                 if (scannedCode != null) {
                     if (scannedCode == store.qrCodeData) {
                         // Éxito: Cerrar diálogo con TRUE
                         if (context.mounted) Navigator.pop(context, true);
                     } else {
                         // Fallo - Mostrar Alerta en vez de SnackBar (que puede quedar tapado)
                         if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppTheme.cardBg,
                                title: const Text("❌ Código Incorrecto", style: TextStyle(color: AppTheme.dangerRed)),
                                content: const Text("El código QR escaneado no pertenece a esta tienda. Intenta de nuevo.", style: TextStyle(color: Colors.white)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context), 
                                    child: const Text("OK")
                                  )
                                ],
                              )
                            );
                         }
                     }
                 }
             },
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("SIMULAR ESCANEO"),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
       Navigator.push(
         context, 
         MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store))
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final stores = storeProvider.stores;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: Stack(
          children: [
            Column(
              children: [
                AppBar(
                  title: Text(
                    Provider.of<AppModeProvider>(context).isOnlineMode ? "Tienda Online" : "Tiendas Aliadas",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false, // Hide default back button
                  centerTitle: true,
                ),
                // Header
                Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: AppTheme.cardBg,
                 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                 boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)
                 ]
               ),
               child: Row(
                 children: [
                   const Icon(Icons.storefront, size: 40, color: AppTheme.accentGold),
                   const SizedBox(width: 15),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: const [
                          Text(
                            "Directorio de Tiendas",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          Text(
                            "Busca sabotajes y vidas en las tiendas aliadas.",
                            style: TextStyle(color: Colors.white70, fontSize: 12)
                          ),
                       ],
                     ),
                   )
                 ],
               ),
             ),

             Expanded(
               child: storeProvider.isLoading 
                 ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                 : stores.isEmpty
                   ? _buildEmptyState()
                   : ListView.builder(
                     padding: const EdgeInsets.all(16),
                     itemCount: stores.length,
                     itemBuilder: (context, index) {
                       final store = stores[index];
                       return Card(
                         color: AppTheme.cardBg,
                         margin: const EdgeInsets.only(bottom: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         child: InkWell(
                           onTap: () => _onStoreTap(context, store),
                           borderRadius: BorderRadius.circular(16),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               // Imagen de Tienda (Cover)
                               ClipRRect(
                                 borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                 child: store.imageUrl.isNotEmpty 
                                   ? Image.network(
                                       store.imageUrl,
                                       height: 120,
                                       width: double.infinity,
                                       fit: BoxFit.cover,
                                       errorBuilder: (_,__,___) => _buildImagePlaceholder(),
                                     )
                                   : _buildImagePlaceholder(),
                               ),
                               
                               Padding(
                                 padding: const EdgeInsets.all(16),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             store.name,
                                             style: const TextStyle(
                                               color: Colors.white, 
                                               fontSize: 18, 
                                               fontWeight: FontWeight.bold
                                             )
                                           ),
                                           const SizedBox(height: 5),
                                           Text(
                                             store.description,
                                              style: const TextStyle(color: Colors.white60, fontSize: 12)
                                           ),
                                         ],
                                       ),
                                     ),
                                     if (!Provider.of<AppModeProvider>(context).isOnlineMode)
                                        const Icon(Icons.qr_code_scanner, color: AppTheme.secondaryPink),
                                   ],
                                 ),
                               )
                             ],
                           ),
                         ),
                       );
                     },
                   ),
             )
          ],
        ),
            // Cyberpunk Back Button (Matching Inventory & Store Detail)
            Positioned(
              top: MediaQuery.of(context).padding.top + 5,
              left: 15,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentGold.withOpacity(0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0D0D0F),
                      border: Border.all(
                        color: AppTheme.accentGold,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGold.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 120, 
      color: Colors.grey[800],
      child: const Center(child: Icon(Icons.store, size: 50, color: Colors.white24))
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            "No hay tiendas disponibles para este evento",
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
