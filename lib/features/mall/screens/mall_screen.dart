import 'dart:ui';
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

    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.accentGold.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.15),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF151517),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.accentGold, width: 2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with glow
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.accentGold.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppTheme.accentGold,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        'Entrar a Tienda',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Accent line
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accentGold.withOpacity(0.3),
                              AppTheme.accentGold,
                              AppTheme.accentGold.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Store name
                      Text(
                        store.name,
                        style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      const Text(
                        'Para entrar debes escanear el código QR ubicado en la tienda física.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Scan button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.dGoldMain, Color(0xFFE5A700)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.dGoldMain.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                            label: const Text('ESCANEAR QR',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 1)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              // Cerrar modal antes de abrir scanner
                              Navigator.pop(dialogContext);
                              
                              final scannedCode = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                              );
                              if (scannedCode != null && context.mounted) {
                                if (scannedCode == store.qrCodeData || scannedCode == "DEV_SKIP_CODE") {
                                  // Código correcto - navegar a tienda
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store)),
                                  );
                                } else {
                                  // Código incorrecto - mostrar error con diseño cyberpunk
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.dangerRed.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: AppTheme.dangerRed.withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1A1A1D),
                                            borderRadius: BorderRadius.circular(21),
                                            border: Border.all(
                                              color: AppTheme.dangerRed.withOpacity(0.7),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppTheme.dangerRed, width: 2.5),
                                                ),
                                                child: const Icon(
                                                  Icons.qr_code_scanner,
                                                  color: AppTheme.dangerRed,
                                                  size: 36,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              const Text(
                                                'CÓDIGO INCORRECTO',
                                                style: TextStyle(
                                                  color: AppTheme.dangerRed,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w900,
                                                  fontFamily: 'Orbitron',
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'El código QR escaneado no pertenece a esta tienda. Intenta de nuevo.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppTheme.dangerRed,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'ENTENDIDO',
                                                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Simulate button (dev)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.accentGold.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('SIMULAR ESCANEO', style: TextStyle(fontSize: 13, letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Cancel
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.white70.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo gradiente base
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
            ),
          ),
          // Imagen de fondo
          Positioned.fill(
            child: Opacity(
              opacity: 0.8,
              child: Image.asset(
                isDarkMode ? 'assets/images/hero.png' : 'assets/images/loginclaro.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Capa oscura sutil
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.05),
            ),
          ),
          // Contenido
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
                // Header - Glassmorphism (posición original)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0F).withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3), width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
                        ],
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
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Busca sabotajes y vidas en las tiendas aliadas.",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

             Expanded(
               child: storeProvider.isLoading 
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppTheme.accentGold),
                          const SizedBox(height: 16),
                          Text(
                            'Cargando...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: AppTheme.accentGold.withOpacity(0.5), blurRadius: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                 : stores.isEmpty
                   ? _buildEmptyState()
                   : ListView.builder(
                     padding: const EdgeInsets.all(16),
                     itemCount: stores.length,
                     itemBuilder: (context, index) {
                       final store = stores[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () => _onStoreTap(context, store),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.accentGold.withOpacity(0.6), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentGold.withOpacity(0.05),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppTheme.accentGold.withOpacity(0.2), width: 1.0),
                                      color: AppTheme.accentGold.withOpacity(0.02),
                                    ),
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
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppTheme.accentGold.withOpacity(0.1),
                                                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.2), width: 1),
                                                ),
                                                child: Icon(
                                                  !Provider.of<AppModeProvider>(context).isOnlineMode
                                                    ? Icons.qr_code_scanner
                                                    : Icons.storefront,
                                                  color: AppTheme.accentGold,
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      store.name,
                                                      style: TextStyle(
                                                        color: AppTheme.accentGold,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                        shadows: [
                                                          Shadow(color: AppTheme.accentGold.withOpacity(0.4), blurRadius: 6),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      store.description,
                                                      style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(Icons.arrow_forward_ios, color: AppTheme.accentGold.withOpacity(0.5), size: 14),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                     },
                   ),
             )
          ],
        ),
            // Back Button (mismo estilo que avatar_selection_screen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 5,
              left: 15,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
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
                      color: Colors.black.withOpacity(0.4),
                      border: Border.all(
                        color: AppTheme.accentGold.withOpacity(0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGold.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
          Icon(Icons.store_outlined, size: 80, color: AppTheme.accentGold.withOpacity(0.4)),
          const SizedBox(height: 20),
          const Text(
            "No hay tiendas disponibles",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Aún no se han registrado tiendas para este evento",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
