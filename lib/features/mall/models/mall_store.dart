import 'dart:convert';
import 'power_item.dart';

class MallStore {
  final String id;
  final String? eventId;
  final String name;
  final String description;
  final String imageUrl;
  final String qrCodeData;
  final List<PowerItem> products;

  MallStore({
    required this.id,
    this.eventId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.qrCodeData,
    required this.products,
  });

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'qr_code_data': qrCodeData,
      // Guardamos objeto con ID y Costo personalizado
      'products': products.map((x) => {
        'id': x.id,
        'cost': x.cost
      }).toList(), 
    };
  }

  factory MallStore.fromMap(Map<String, dynamic> map) {
    List<PowerItem> parsedProducts = [];
    if (map['products'] != null) {
      final List<dynamic> productsRaw = map['products'] is String 
          ? json.decode(map['products']) 
          : map['products'];
          
      final allItems = PowerItem.getShopItems();
      
      parsedProducts = productsRaw.map((data) {
        // Soporte Legacy: Si es solo un String (ID), usamos costo por defecto
        if (data is String) {
          return allItems.firstWhere((item) => item.id == data,
              orElse: () => PowerItem(
                    id: data,
                    name: 'Desconocido',
                    description: '',
                    type: PowerType.utility,
                    cost: 0,
                    icon: '❓',
                  ));
        } 
        // Nuevo Formato: Map con 'id' y 'cost'
        else if (data is Map) {
          final id = data['id'];
          final customCost = data['cost'];
          
          final baseItem = allItems.firstWhere((item) => item.id == id,
               orElse: () => PowerItem(
                    id: id.toString(),
                    name: 'Desconocido',
                    description: '',
                    type: PowerType.utility,
                    cost: 0,
                    icon: '❓',
                  ));
          
          // Entregamos item con costo modificado si existe
          return (customCost != null) 
              ? baseItem.copyWith(cost: customCost) 
              : baseItem;
        }
        
        return allItems.first; // Fallback extremo
      }).toList();
    }

    return MallStore(
      id: map['id'] ?? '',
      eventId: map['event_id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      qrCodeData: map['qr_code_data'] ?? '',
      products: parsedProducts,
    );
  }
}
