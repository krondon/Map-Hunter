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
        imageUrl:
            "https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/McDonald%27s_Golden_Arches.svg/1200px-McDonald%27s_Golden_Arches.svg.png",
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
        ],
      ),
      MallStore(
        id: 'el_dorado',
        name: "Cinex (El Dorado)",
        description: "Entretenimiento y sabotajes de película.",
        imageUrl:
            "https://pbs.twimg.com/profile_images/1359879781682335746/Nq1aQd_z_400x400.jpg",
        qrCodeData: "store:cinex",
        products: [
          PowerItem(
            id: 'black_screen',
            name: 'Pantalla Negra',
            description: 'Ciega al rival por 5s',
            icon: '🎬',
            cost: 100,
            type: PowerType.blind,
          ),
          // PowerItem(
          //   id: 'blur_screen',
          //   name: 'Pantalla Borrosa',
          //   description:
          //       'Aplica un efecto borroso sobre la pantalla del objetivo.',
          //   icon: '🌫️',
          //   cost: 110,
          //   type: PowerType.debuff,
          // ),
          PowerItem(
            id: 'freeze',
            name: 'Congelar',
            description: 'Congela al rival por 120s',
            type: PowerType.freeze,
            cost: 50,
            icon: '❄️',
          ),
          PowerItem(
            id: 'life_steal',
            name: 'Robo de Vida',
            description: 'Roba una vida a un rival',
            type: PowerType.lifeSteal,
            cost: 130,
            icon: '🧛',
          ),
        ],
      ),
      MallStore(
        id: 'farmatodo',
        name: "Farmatodo",
        description: "Cura y protección para tus aventuras.",
        imageUrl:
            "https://pbs.twimg.com/profile_images/1118182255763005440/1VjXyQj-_400x400.png",
        qrCodeData: "store:farmatodo",
        products: [
          // PowerItem(
          //   id: 'shield',
          //   name: 'Escudo',
          //   description: 'Bloquea sabotajes por 300s',
          //   type: PowerType.shield,
          //   cost: 150,
          //   icon: '🛡️',
          // ),
          const PowerItem(
            id: 'return',
            name: 'Devolución',
            description: 'Devuelve el ataque al origen',
            type: PowerType.buff, // CAMBIADO: De utility a buff
            cost: 90,
            icon: '↩️',
          ),
          PowerItem(
            id: 'invisibility',
            name: 'Invisibilidad',
            description: 'Te vuelve invisible por 45s',
            type: PowerType.stealth,
            cost: 100,
            icon: '👻',
          ),
        ],
      ),
    ];
  }
}
