import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../game/models/event.dart';
import '../../mall/models/mall_store.dart';
import '../../mall/models/power_item.dart'; // NEW
import '../../../core/enums/entry_types.dart';

/// Pure Dart domain service for event business rules.
/// 
/// This service encapsulates:
/// - PIN generation logic (alphanumeric for online, numeric for on-site)
/// - Default online store creation
/// - Clue sanitization for online mode
/// - Event configuration with mode-specific defaults
/// - Entry type and currency handling for wallet integration
class EventDomainService {
  
  /// Generates a PIN based on the event mode.
  /// 
  /// - Online Mode: 6 alphanumeric characters (excluding ambiguous chars like 0, O, 1, I)
  /// - On-Site Mode: 6 numeric digits
  static String generatePin({bool isOnline = false}) {
     final random = Random();
     if (isOnline) {
       // Online Mode: Alphanumeric (excluding ambiguous characters)
       const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
       return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
     } else {
       // Presencial Mode: Numeric
       return (100000 + random.nextInt(900000)).toString();
     }
  }

  /// Creates a default MallStore for online events.
  /// 
  /// Online events automatically get a pre-configured store with
  /// standard name and description. Now supports custom prices.
  static MallStore createDefaultOnlineStore(String eventId, {Map<String, int>? customPrices}) {
     // 1. Get Base Items
     final defaultItems = PowerItem.getShopItems();
     
     // 2. Apply Custom Prices
     List<PowerItem> products = defaultItems.map((item) {
        if (customPrices != null && customPrices.containsKey(item.id)) {
           return item.copyWith(cost: customPrices[item.id]);
        }
        return item;
     }).toList();

     return MallStore(
       id: const Uuid().v4(),
       eventId: eventId,
       name: 'Tienda Online Oficial',
       description: 'Tienda oficial para este evento online. ¡Adquiere poderes aquí!',
       imageUrl: '', 
       qrCodeData: 'ONLINE_STORE_$eventId',
       products: products, 
     );
  }

  /// Sanitizes clue data for online mode.
  /// 
  /// Ensures all required fields have valid defaults:
  /// - description: "Pista Online" if empty
  /// - hint: "Pista Online" if empty
  /// - latitude/longitude: 0.0 if null
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

  /// Calculates the pot for a paid event.
  /// 
  /// [entryFee] The entry fee per participant.
  /// [participantCount] The number of participants.
  /// [houseCut] Percentage the platform takes (0.0 to 1.0).
  static double calculatePot({
    required double entryFee,
    required int participantCount,
    double houseCut = 0.1,
  }) {
    final totalCollected = entryFee * participantCount;
    return totalCollected * (1 - houseCut);
  }

  /// Validates entry fee amount.
  /// 
  /// Returns an error message if invalid, null if valid.
  static String? validateEntryFee(int? amount, EntryType entryType) {
    if (entryType == EntryType.free) return null;
    
    if (amount == null || amount <= 0) {
      return 'Los eventos de pago requieren una cuota mayor a 0 🍀';
    }
    
    if (amount > 1000) {
      return 'La cuota máxima es 1000 🍀';
    }
    
    return null;
  }

  /// Creates a fully configured GameEvent with mode-specific defaults.
  /// 
  /// Handles the following mode-specific logic:
  /// - Online: locationName='Online', lat/long=0.0, auto-generates PIN
  /// - On-Site: Uses provided location and PIN
  /// - Paid: Requires entry fee and currency type
  static GameEvent createConfiguredEvent({
    required String id,
    required String title,
    required String description,
    required String? locationName,
    required double? latitude,
    required double? longitude,
    required DateTime date,
    required String clue,
    required int maxParticipants,
    required String pin,
    required String eventType,
    required String imageFileName,
    // --- NEW: Wallet Support ---
    EntryType entryType = EntryType.free,
    int? entryFee, // Changed to int to match GameEvent
    CurrencyType currency = CurrencyType.treboles,
  }) {
    final isOnline = eventType == 'online';
    final finalPin = isOnline ? generatePin(isOnline: true) : pin;
    
    // Validate entry fee if paid
    if (entryType == EntryType.paid) {
      final error = validateEntryFee(entryFee, entryType);
      if (error != null) {
        throw ArgumentError(error);
      }
    }
    
    return GameEvent(
      id: id,
      title: title,
      description: description,
      locationName: isOnline ? 'Online' : (locationName ?? 'Unknown'),
      latitude: isOnline ? 0.0 : latitude!,
      longitude: isOnline ? 0.0 : longitude!,
      date: date,
      createdByAdminId: 'admin_1',
      imageUrl: imageFileName,
      clue: clue,
      maxParticipants: maxParticipants,
      pin: finalPin,
      type: eventType,
      entryFee: entryFee ?? 0,
    );
  }

  /// Creates event configuration with entry type metadata.
  /// 
  /// Returns a map that can be merged with event data for storage.
  static Map<String, dynamic> createEventEntryConfig({
    required EntryType entryType,
    double? entryFee,
    CurrencyType currency = CurrencyType.treboles,
  }) {
    return {
      'entry_type': entryType.name,
      if (entryType == EntryType.paid) ...{
        'entry_fee': entryFee,
        'currency': currency.name,
      },
    };
  }
}

