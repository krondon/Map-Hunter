/// Entry and currency type enums for event configuration.
/// 
/// Supports the Wallet system by defining how events can be joined
/// and what currency is used for transactions.
library;

/// Type of entry required to join an event.
enum EntryType {
  /// No payment required - anyone can join.
  free,
  
  /// Payment in Tréboles required to participate.
  paid,
  
  /// Entry by invitation only.
  invitation;

  /// Display name for UI purposes.
  String get displayName {
    switch (this) {
      case EntryType.free:
        return 'Gratis';
      case EntryType.paid:
        return 'De Pago';
      case EntryType.invitation:
        return 'Por Invitación';
    }
  }

  /// Icon representation.
  String get icon {
    switch (this) {
      case EntryType.free:
        return '🆓';
      case EntryType.paid:
        return '🍀';
      case EntryType.invitation:
        return '✉️';
    }
  }
}

/// Currency types supported by the wallet system.
enum CurrencyType {
  /// In-game currency (Tréboles/Clovers).
  treboles,
  
  /// Real money (for future payment gateway integration).
  realMoney;

  /// Display symbol for the currency.
  String get symbol {
    switch (this) {
      case CurrencyType.treboles:
        return '🍀';
      case CurrencyType.realMoney:
        return '\$';
    }
  }

  /// Full display name.
  String get displayName {
    switch (this) {
      case CurrencyType.treboles:
        return 'Tréboles';
      case CurrencyType.realMoney:
        return 'USD';
    }
  }
}
