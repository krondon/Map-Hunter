import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../models/mall_store.dart';
import '../../../core/theme/app_theme.dart';
import 'store_detail_screen.dart';
import '../../game/providers/game_provider.dart';
import '../providers/store_provider.dart';
import '../../game/screens/qr_scanner_screen.dart';

class MallScreen extends StatefulWidget {
  const MallScreen({super.key});

  @override
  State<MallScreen> createState() => _MallScreenState();
}

class _MallScreenState extends State<MallScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.currentEventId != null) {
        Provider.of<StoreProvider>(context, listen: false).fetchStores(gameProvider.currentEventId!);
      }
    });
  }

  void _onStoreTap(BuildContext context, MallStore store) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text("Entrar a ${store.name}", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Para entrar debes escanear el código QR ubicado en la tienda física.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.white),
            const SizedBox(height: 20),
             // Debug info (optional, helps user verify generated codes)
             // Text("Data esperada: ${store.qrCodeData}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context, false),
             child: const Text("Cancelar", style: TextStyle(color: Colors.white60))
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
               ElevatedButton.icon(
                onPressed: () async {
                   final scannedCode = await Navigator.push<String>(
                     context, 
                     MaterialPageRoute(builder: (_) => const QRScannerScreen())
                   );
                   
                   if (scannedCode != null && context.mounted) {
                      if (scannedCode == store.qrCodeData) {
                         Navigator.pop(context, true); // Éxito
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(
                             content: Text('❌ Código QR incorrecto. Intenta nuevamente.'), 
                             backgroundColor: Colors.red
                           )
                         );
                      }
                   }
                }, 
                icon: const Icon(Icons.camera_alt),
                label: const Text("Escanear con Cámara"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold, 
                  foregroundColor: Colors.black
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true), 
                child: const Text("Simular (Pruebas)"),
              ),
            ],
          )
        ],
      )
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Centro Comercial"),
        backgroundColor: AppTheme.darkBg,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: Column(
          children: [
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
               child: Consumer<StoreProvider>(
                 builder: (context, provider, child) {
                   if (provider.isLoading) {
                     return const Center(child: CircularProgressIndicator());
                   }
                   
                   final stores = provider.stores;
                   
                   if (stores.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.store_mall_directory, size: 80, color: Colors.white24),
                            SizedBox(height: 16),
                            Text("No hay tiendas disponibles en este evento", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      );
                   }

                   return ListView.builder(
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
                                 child: (store.imageUrl.isNotEmpty && store.imageUrl.startsWith('http'))
                                   ? Image.network(
                                       store.imageUrl,
                                       height: 120,
                                       width: double.infinity,
                                       fit: BoxFit.cover,
                                       errorBuilder: (_,__,___) => Container(
                                         height: 120, 
                                         color: Colors.grey[800],
                                         child: const Center(child: Icon(Icons.store, size: 50, color: Colors.white24))
                                       ),
                                     )
                                   : Container(
                                       height: 120,
                                       color: Colors.grey[800],
                                       child: const Center(child: Icon(Icons.store, size: 50, color: Colors.white24)),
                                     ),
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
                                     const Icon(Icons.qr_code_scanner, color: AppTheme.secondaryPink),
                                   ],
                                 ),
                               )
                             ],
                           ),
                         ),
                       );
                     },
                   );
                 },
               ),
             )
          ],
        ),
      ),
    );
  }
}
