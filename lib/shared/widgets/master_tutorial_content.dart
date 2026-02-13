import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'cyber_tutorial_overlay.dart';

class MasterTutorialContent {
  static List<TutorialStep> getStepsForSection(String section, BuildContext context) {
    switch (section) {
      case 'HOME':
        return [
          TutorialStep(
            title: "¡BIENVENIDO AGENTE!",
            description: "Estás dentro del Protocolo Asthoria. Tu objetivo: recolectar los Tréboles Dorados antes que tus rivales.",
            icon: Icons.security,
            visual: _buildWelcomeVisual(),
          ),
          TutorialStep(
            title: "ESTA ES TU BASE",
            description: "Aquí verás tu progreso, vidas y el acceso a todas las secciones del sistema: Pistas, Inventario y Ranking.",
            icon: Icons.home,
            visual: _buildHomeVisual(),
          ),
        ];
      case 'CLUES':
        return [
          TutorialStep(
            title: "RUIDO EN EL MAPA",
            description: "Cada punto el mapa es una pista. Algunas son online (hackeo directo) y otras físicas (debes buscar el QR real).",
            icon: Icons.map,
            visual: _buildMapVisual(),
          ),
          TutorialStep(
            title: "LA CARRERA",
            description: "Observa la pista superior: muestra en tiempo real tu posición respecto a los demás jugadores. ¡No te dejes alcanzar!",
            icon: Icons.speed,
            visual: _buildRaceVisual(),
          ),
        ];
      case 'INVENTORY':
        return [
          TutorialStep(
            title: "MERCADO DE PODERES",
            description: "Usa tus monedas para comprar ventajas tácticas. Los Escudos bloquean ataques y los Sabotajes frenan a otros.",
            icon: Icons.shopping_cart,
            visual: _buildShopVisual(),
          ),
          TutorialStep(
            title: "TU ARSENAL",
            description: "Desde aquí puedes activar tus poderes. Toca un ítem para usarlo en el momento justo del juego.",
            icon: Icons.inventory_2,
            visual: _buildArsenalVisual(),
          ),
        ];
      case 'PUZZLE':
        return [
          TutorialStep(
            title: "SISTEMA DE HACKEO",
            description: "Cada pista es un minijuego diferente. Resuélvelo rápido para obtener el Trébol Dorado de esta zona.",
            icon: Icons.videogame_asset,
            visual: _buildMinigameVisual(),
          ),
          TutorialStep(
            title: "ZONA DE PELIGRO",
            description: "Si fallas o el tiempo se acaba, perderás una vida. Al llegar a 0 vidas, quedarás fuera de la pista temporalmente.",
            icon: Icons.warning_amber_rounded,
            visual: _buildWarningVisual(),
          ),
        ];
      case 'RANKING':
        return [
          TutorialStep(
            title: "TABLA DE LÍDERES",
            description: "Aquí verás quién domina la ciudad. El XP acumulado determina tu nivel y prestigio como Agente.",
            icon: Icons.leaderboard,
            visual: _buildRankingVisual(),
          ),
        ];
      case 'SCENARIOS':
        return [
          TutorialStep(
            title: "PANTALLA DE ESCENARIOS",
            description: "Aquí aparecen todos los eventos disponibles. Selecciona uno para entrar a la carrera.",
            icon: Icons.event,
            visual: _buildScenariosVisual(),
          ),
          TutorialStep(
            title: "ESTADO DEL EVENTO",
            description: "Los eventos pueden estar ACTIVOS (puedes jugar ya), PENDIENTES (aún no comienzan) o COMPLETADOS (ya finalizaron).",
            icon: Icons.calendar_today,
            visual: _buildEventStatusVisual(),
          ),
          TutorialStep(
            title: "GEOLOCALIZACIÓN",
            description: "Algunos eventos requieren que estés cerca del lugar físico para poder entrar. Si aparece 'Fuera de Rango', acércate al punto de inicio.",
            icon: Icons.location_on,
            visual: _buildGeoLocationVisual(),
          ),
          TutorialStep(
            title: "CONGELADO/DESCONGELADO",
            description: "Si un evento aparece congelado (con icono de candado), significa que aún no cumples los requisitos para entrar (puede ser por distancia, cupo lleno, o que aún no inicia).",
            icon: Icons.ac_unit,
            visual: _buildFrozenVisual(),
          ),
        ];
      case 'MODE_SELECTOR':
        return [
          TutorialStep(
            title: "SELECCIÓN DE MODO",
            description: "MapHunter tiene dos modos de juego: PRESENCIAL (debes estar en el lugar físico) y ONLINE (juega desde cualquier parte).",
            icon: Icons.grid_view,
            visual: _buildModeSelectorVisual(),
          ),
          TutorialStep(
            title: "MODO PRESENCIAL",
            description: "Este modo requiere que estés físicamente en los lugares de las pistas. Usa tu GPS para navegar y encontrar los códigos QR reales.",
            icon: Icons.near_me,
            visual: _buildPresentialModeVisual(),
          ),
          TutorialStep(
            title: "MODO ONLINE",
            description: "Juega desde tu casa. Todos los minijuegos son digitales y no requieren moverte. Perfecto para practicar o competir a distancia.",
            icon: Icons.wifi,
            visual: _buildOnlineModeVisual(),
          ),
        ];
      case 'CODE_FINDER':
        return [
          TutorialStep(
            title: "SISTEMA FRÍO/CALIENTE",
            description: "En modo presencial, tu pantalla te dirá qué tan cerca estás del código QR. Sigue las indicaciones de temperatura para encontrarlo.",
            icon: Icons.thermostat,
            visual: _buildHotColdVisual(),
          ),
          TutorialStep(
            title: "NAVEGANDO AL OBJETIVO",
            description: "CONGELADO significa muy lejos (500m+), FRÍO (200m+), TIBIO (50m+), CALIENTE (10m+). Cuando veas '¡AQUÍ ESTÁ!' significa que llegaste.",
            icon: Icons.navigation,
            visual: _buildNavigationVisual(),
          ),
          TutorialStep(
            title: "EN LA ZONA",
            description: "Cuando estés a menos de 20 metros, aparecerá el botón 'ESCANEAR AHORA'. Busca el código QR físico y escanéalo para desbloquear el evento.",
            icon: Icons.qr_code_scanner,
            visual: _buildInZoneVisual(),
          ),
        ];
      case 'CLUE_SCANNER':
        return [
          TutorialStep(
            title: "ESCANEANDO PISTAS",
            description: "Ya estás en el juego. Cada punto del mapa es una pista que debes completar. Navega hacia ella usando el sistema frío/caliente.",
            icon: Icons.map,
            visual: _buildClueMapVisual(),
          ),
          TutorialStep(
            title: "LLEGASTE A LA ZONA",
            description: "Cuando estés cerca (menos de 35m), aparecerá el botón 'ESCANEAR CÓDIGO'. Busca el QR físico y escanéalo para desbloquear el minijuego.",
            icon: Icons.qr_code_2,
            visual: _buildScanButtonVisual(),
          ),
          TutorialStep(
            title: "COMPLETA EL DESAFÍO",
            description: "Después de escanear, resolverás un minijuego. Si lo completas, ganas el Trébol Dorado de esa pista. ¡Cuidado con tus vidas!",
            icon: Icons.videogame_asset,
            visual: _buildChallengeVisual(),
          ),
        ];
      default:
        return [];
    }
  }

  // Visual builders unchanged or adjusted to focus on gameplay
  static Widget _buildWelcomeVisual() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, AppTheme.primaryPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, color: AppTheme.accentGold, size: 80),
          Positioned(
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("ANALIZANDO SISTEMA...", style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildHomeVisual() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMiniTab(Icons.map, "PISTAS", true),
          _buildMiniTab(Icons.inventory_2, "ITEMS", false),
          _buildMiniTab(Icons.leaderboard, "RANK", false),
        ],
      ),
    );
  }

  static Widget _buildMiniTab(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? AppTheme.accentGold : Colors.white24, size: 30),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: active ? AppTheme.accentGold : Colors.white24, fontSize: 8)),
        if (active) Container(margin: const EdgeInsets.only(top: 4), width: 20, height: 2, color: AppTheme.accentGold),
      ],
    );
  }

  static Widget _buildMapVisual() {
    return Container(
      color: const Color(0xFF020617),
      child: Stack(
        children: [
          CustomPaint(painter: GridPainter(), size: Size.infinite),
          const Positioned(top: 40, left: 60, child: Icon(Icons.location_on, color: Colors.redAccent, size: 24)),
          const Positioned(bottom: 60, right: 80, child: Icon(Icons.location_on, color: AppTheme.accentGold, size: 30)),
          const Center(child: Icon(Icons.navigation, color: Colors.blueAccent, size: 20)),
        ],
      ),
    );
  }

  static Widget _buildRaceVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.cardBg,
      child: Column(
        children: [
          const Text("POSICIÓN EN CARRERA", style: TextStyle(color: Colors.white30, fontSize: 10)),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.blueAccent),
              Expanded(child: Container(height: 2, color: Colors.white10)),
              const Icon(Icons.person, color: AppTheme.accentGold),
              Expanded(child: Container(height: 2, color: Colors.white10)),
              const Icon(Icons.flag, color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildShopVisual() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1A1A1D),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TIENDA", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
              const Icon(Icons.monetization_on, color: AppTheme.accentGold, size: 14),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniItem(Icons.shield, "500"),
              _buildMiniItem(Icons.bolt, "300"),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildArsenalVisual() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryPurple, width: 2),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.5), blurRadius: 10)],
        ),
        child: const Icon(Icons.shield, color: Colors.blueAccent, size: 40),
      ),
    );
  }

  static Widget _buildMinigameVisual() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) => Container(
            width: 30, height: 40, margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.accentGold), borderRadius: BorderRadius.circular(5)),
            child: const Center(child: Text("?", style: TextStyle(color: Colors.white))),
          )),
        ),
      ),
    );
  }

  static Widget _buildWarningVisual() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, color: AppTheme.dangerRed, size: 60),
          SizedBox(height: 10),
          Text("1 VIDA RESTANTE", style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  static Widget _buildRankingVisual() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Text("#${i+1}", style: const TextStyle(color: AppTheme.accentGold)),
              const SizedBox(width: 15),
              Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(5))),
              const Spacer(),
              Container(width: 30, height: 10, decoration: BoxDecoration(color: AppTheme.secondaryPink.withOpacity(0.3), borderRadius: BorderRadius.circular(5))),
            ],
          ),
        )),
      ),
    );
  }

  // New visual builders for SCENARIOS
  static Widget _buildScenariosVisual() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0A0E27),
      child: Column(
        children: [
          _buildMiniEventCard("Carrera Asthoria", "ACTIVO", Colors.green),
          const SizedBox(height: 8),
          _buildMiniEventCard("Noche de Hackeo", "PENDIENTE", Colors.orange),
        ],
      ),
    );
  }

  static Widget _buildMiniEventCard(String title, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryPurple, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.event, color: AppTheme.accentGold, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 10))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor, width: 1),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  static Widget _buildEventStatusVisual() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatusBadge("ACTIVO", Colors.green),
          _buildStatusBadge("PENDIENTE", Colors.orange),
          _buildStatusBadge("COMPLETADO", Colors.grey),
        ],
      ),
    );
  }

  static Widget _buildStatusBadge(String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(Icons.circle, color: color, size: 12),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: color, fontSize: 8)),
      ],
    );
  }

  static Widget _buildGeoLocationVisual() {
    return Container(
      color: const Color(0xFF020617),
      child: Stack(
        children: [
          CustomPaint(painter: GridPainter(), size: Size.infinite),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.my_location, color: Colors.blueAccent, size: 40),
                SizedBox(height: 20),
                Icon(Icons.location_on, color: AppTheme.accentGold, size: 30),
                SizedBox(height: 5),
                Text("500m", style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFrozenVisual() {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.event, color: Colors.white24, size: 50),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, color: Colors.blueAccent, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  // New visual builders for MODE_SELECTOR
  static Widget _buildModeSelectorVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1A1A1D),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeCard(Icons.near_me, "PRESENCIAL"),
          _buildModeCard(Icons.wifi, "ONLINE"),
        ],
      ),
    );
  }

  static Widget _buildModeCard(IconData icon, String label) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryPurple, AppTheme.secondaryPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 8)),
        ],
      ),
    );
  }

  static Widget _buildPresentialModeVisual() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_searching, color: AppTheme.accentGold, size: 50),
            SizedBox(height: 10),
            Icon(Icons.qr_code_scanner, color: Colors.white70, size: 40),
          ],
        ),
      ),
    );
  }

  static Widget _buildOnlineModeVisual() {
    return Container(
      color: const Color(0xFF0A0E27),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.computer, color: AppTheme.secondaryPink, size: 50),
            SizedBox(height: 10),
            Icon(Icons.videogame_asset, color: Colors.white70, size: 40),
          ],
        ),
      ),
    );
  }

  // Visual builders for CODE_FINDER
  static Widget _buildHotColdVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF0A0E27),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.thermostat, color: Colors.orange, size: 60),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange, width: 2),
            ),
            child: const Text(
              "TIBIO",
              style: TextStyle(
                color: Colors.orange,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "150m del objetivo",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Widget _buildNavigationVisual() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDistanceBadge("CONGELADO", Colors.cyanAccent, "500m+"),
          _buildDistanceBadge("FRÍO", Colors.blue, "200m+"),
          _buildDistanceBadge("TIBIO", Colors.orange, "50m+"),
          _buildDistanceBadge("CALIENTE", Colors.red, "10m+"),
          _buildDistanceBadge("¡AQUÍ ESTÁ!", AppTheme.successGreen, "0m"),
        ],
      ),
    );
  }

  static Widget _buildDistanceBadge(String label, Color color, String distance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          Text(
            distance,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static Widget _buildInZoneVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF020617),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.accentGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGold.withOpacity(0.3),
                blurRadius: 15,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "¡ESTÁS EN LA ZONA!",
                style: TextStyle(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 15),
              const Icon(Icons.qr_code_2, color: AppTheme.accentGold, size: 50),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "ESCANEAR AHORA",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Visual builders for CLUE_SCANNER
  static Widget _buildClueMapVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF020617),
      child: Stack(
        children: [
          CustomPaint(painter: GridPainter(), size: Size.infinite),
          Positioned(
            top: 30,
            left: 40,
            child: _buildMapPin(Colors.green, "COMPLETADA"),
          ),
          Positioned(
            bottom: 50,
            right: 60,
            child: _buildMapPin(AppTheme.accentGold, "ACTUAL"),
          ),
          const Center(
            child: Icon(Icons.my_location, color: Colors.blueAccent, size: 30),
          ),
        ],
      ),
    );
  }

  static Widget _buildMapPin(Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 6, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  static Widget _buildScanButtonVisual() {
    return Container(
      padding: const EdgeInsets.all(30),
      color: const Color(0xFF1A1A1D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "¡ESTÁS EN LA ZONA!",
              style: TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentGold,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.4),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code, color: Colors.black, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "ESCANEAR CÓDIGO",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildChallengeVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videogame_asset, color: AppTheme.secondaryPink, size: 60),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accentGold, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "MINIJUEGO",
                  style: TextStyle(
                    color: AppTheme.accentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, color: Colors.red, size: 16),
                    SizedBox(width: 5),
                    Icon(Icons.favorite, color: Colors.red, size: 16),
                    SizedBox(width: 5),
                    Icon(Icons.favorite_border, color: Colors.white24, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMiniItem(IconData icon, String price) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 5),
        Text("$price CR", style: const TextStyle(color: AppTheme.accentGold, fontSize: 8)),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 20) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint); }
    for (double i = 0; i < size.height; i += 20) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
