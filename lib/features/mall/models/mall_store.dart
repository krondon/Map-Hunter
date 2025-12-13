import 'power_item.dart';

class MallStore {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String qrCodeData;
  final List<PowerItem> products;

  MallStore({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.qrCodeData,
    required this.products,
  });

  // Datos simulados del Centro Comercial Millenium
  static List<MallStore> getMilleniumStores() {
    return [
      MallStore(
        id: 'mcdonals',
        name: "McDonald's",
        description: "Recarga energías con la mejor comida rápida.",
        imageUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/McDonald%27s_Golden_Arches.svg/1200px-McDonald%27s_Golden_Arches.svg.png",
        qrCodeData: "store:mcdonals",
        products: [
          PowerItem(
            id: 'extra_life',
            name: 'Vida Extra',
            description: 'Recupera una vida perdida para seguir en el juego.',
            icon: '❤️',
            cost: 50,
            type: PowerType.buff,
          ),
          PowerItem(
            id: 'energy_drink',
            name: 'Energía',
            description: 'Aumenta tu velocidad de movimiento por 5 minutos.',
            icon: '⚡',
            cost: 30,
            type: PowerType.buff,
          ),
        ],
      ),
      MallStore(
        id: 'el_dorado',
        name: "Cinex (El Dorado)",
        description: "Entretenimiento y sabotajes de película.",
        imageUrl: "https://pbs.twimg.com/profile_images/1359879781682335746/Nq1aQd_z_400x400.jpg", 
        qrCodeData: "store:cinex",
        products: [
          PowerItem(
            id: 'black_screen',
            name: 'Pantalla Negra',
            description: 'Deja la pantalla de un rival en negro por 1 minuto.',
            icon: '🎬',
            cost: 80,
            type: PowerType.debuff,
          ),
          PowerItem(
            id: 'slow_motion',
            name: 'Cámara Lenta',
            description: 'Reduce la velocidad de los rivales a la mitad.',
            icon: '🐢',
            cost: 60,
            type: PowerType.debuff,
          ),
        ],
      ),
       MallStore(
        id: 'farmatodo',
        name: "Farmatodo",
        description: "Cura y protección para tus aventuras.",
        imageUrl: "https://pbs.twimg.com/profile_images/1118182255763005440/1VjXyQj-_400x400.png",
        qrCodeData: "store:farmatodo",
        products: [
          PowerItem(
            id: 'shield_pro',
            name: 'Escudo Pro',
            description: 'Protección contra cualquier sabotaje por 10 min.',
            icon: '🛡️',
            cost: 100,
            type: PowerType.buff,
          ),
          PowerItem(
            id: 'cure_all',
            name: 'Cura Total',
            description: 'Elimina cualquier efecto negativo activo.',
            icon: '💊',
            cost: 40,
            type: PowerType.buff,
          ),
        ],
      ),
    ];
  }
}
