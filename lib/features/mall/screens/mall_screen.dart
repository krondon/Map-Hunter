import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../models/mall_store.dart';
import '../../../core/theme/app_theme.dart';
import 'store_detail_screen.dart';

class MallScreen extends StatelessWidget {
  const MallScreen({super.key});

  void _onStoreTap(BuildContext context, MallStore store) async {
    // Simular escaneo de QR para entrar a la tienda
    // En producción redirigiría a QRScannerScreen
    // y validaría que el QR coincida con store.qrCodeData
    
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
          ],
        ),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context, false),
             child: const Text("Cancelar")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // Simula escaneo exitoso
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: const Text("Escanear (Simulado)"),
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
    final stores = MallStore.getMilleniumStores();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Centro Comercial Millenium"),
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
               child: ListView.builder(
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
               ),
             )
          ],
        ),
      ),
    );
  }
}
