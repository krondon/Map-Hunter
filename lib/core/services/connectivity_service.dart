import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado de conectividad del dispositivo
enum ConnectivityStatus {
  /// Conexión estable y funcional
  online,
  /// Conexión inestable o lenta
  lowSignal,
  /// Sin conexión a internet
  offline,
}

/// Servicio singleton para monitorear la conectividad a internet
/// mediante ping activo a Supabase.
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  Timer? _pingTimer;
  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  
  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  int _failedPings = 0;
  
  /// Stream de cambios en el estado de conectividad
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;
  
  /// Estado actual de conectividad
  ConnectivityStatus get currentStatus => _currentStatus;
  
  /// Tiempo de gracia antes de considerar desconexión (10 segundos)
  static const Duration gracePeriod = Duration(seconds: 10);
  
  /// Intervalo entre pings (5 segundos)
  static const Duration pingInterval = Duration(seconds: 5);
  
  /// Número de pings fallidos para considerar señal baja
  static const int lowSignalThreshold = 1;
  
  /// Número de pings fallidos para considerar desconexión total
  /// Con 5s de intervalo y 10s de gracia = 2 pings fallidos
  static const int offlineThreshold = 2;

  /// Inicia el monitoreo de conectividad
  void startMonitoring() {
    if (_pingTimer != null) return; // Ya está corriendo
    
    // SKIP on Web: Chrome tiene problemas de CORS con pings y causa falsos positivos
    if (kIsWeb) {
      debugPrint('ConnectivityService: Saltando monitoreo en Web (desarrollo)');
      _currentStatus = ConnectivityStatus.online; // Asumir online
      return;
    }
    
    debugPrint('ConnectivityService: Iniciando monitoreo de conexión');
    _failedPings = 0;
    _currentStatus = ConnectivityStatus.online;
    
    // Ping inicial inmediato
    _checkConnection();
    
    // Ping periódico cada 5 segundos
    _pingTimer = Timer.periodic(pingInterval, (_) => _checkConnection());
  }

  /// Detiene el monitoreo de conectividad
  void stopMonitoring() {
    debugPrint('ConnectivityService: Deteniendo monitoreo de conexión');
    _pingTimer?.cancel();
    _pingTimer = null;
    _failedPings = 0;
    _currentStatus = ConnectivityStatus.online;
  }

  /// Realiza un ping a Supabase para verificar conectividad
  Future<void> _checkConnection() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      
      // Ping al health endpoint de Supabase REST
      final response = await http.get(
        Uri.parse(supabaseUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode >= 200 && response.statusCode < 500) {
        // Conexión exitosa - resetear contador
        _failedPings = 0;
        _updateStatus(ConnectivityStatus.online);
      } else {
        // Respuesta anómala - contar como fallo
        _handlePingFailure();
      }
    } catch (e) {
      // Timeout o error de red - contar como fallo
      _handlePingFailure();
    }
  }

  void _handlePingFailure() {
    _failedPings++;
    // debugPrint('ConnectivityService: Ping fallido #$_failedPings');
    
    if (_failedPings >= offlineThreshold) {
      _updateStatus(ConnectivityStatus.offline);
    } else if (_failedPings >= lowSignalThreshold) {
      _updateStatus(ConnectivityStatus.lowSignal);
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      debugPrint('ConnectivityService: Estado cambiado de $_currentStatus a $newStatus');
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Libera recursos del servicio
  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}
