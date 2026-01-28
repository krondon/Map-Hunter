import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../mall/models/mall_store.dart';

class EventFactoryService {
  
  static String generatePin({bool isOnline = false}) {
     final random = Random();
     if (isOnline) {
       // Online Mode: Alphanumeric
       const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
       return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
     } else {
       // Presencial Mode: Numeric
       return (100000 + random.nextInt(900000)).toString();
     }
  }

  static MallStore createDefaultOnlineStore(String eventId) {
     return MallStore(
       id: const Uuid().v4(),
       eventId: eventId,
       name: 'Tienda Online Oficial',
       description: 'Tienda oficial para este evento online.',
       imageUrl: '', 
       qrCodeData: 'ONLINE_STORE_$eventId',
       products: [], 
     );
  }

  static void sanitizeCluesForOnline(List<Map<String, dynamic>> clues) {
     for (var clue in clues) {
        if (clue['description'] == null || clue['description'].toString().trim().isEmpty) {
            clue['description'] = "Pista Online";
        }
        if (clue['hint'] == null || clue['hint'].toString().trim().isEmpty) {
            clue['hint'] = "Pista Online";
        }
        if (clue['latitude'] == null) clue['latitude'] = 0.0;
        if (clue['longitude'] == null) clue['longitude'] = 0.0;
     }
  }
}
