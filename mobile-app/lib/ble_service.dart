import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UUIDs del servicio/caracteristica GATT expuestos por HorarioMedicoTurnil Wear.
/// Deben coincidir exactamente con los definidos en el wearable (Kotlin).
class HmtBleUuids {
  static final Guid serviceUuid = Guid('12345678-1234-1234-1234-123456789abc');
  static final Guid characteristicUuid = Guid('87654321-4321-4321-4321-cba987654321');
}

/// Datos de telemetria emitidos por el wearable via NOTIFY.
class TurnoData {
  final int turno;
  final int tiempoEsperaSegundos;
  final int ritmoCardiacoBpm;
  final int oxigenacionPorcentaje;
  final double temperaturaCorporal;

  const TurnoData({
    required this.turno,
    required this.tiempoEsperaSegundos,
    required this.ritmoCardiacoBpm,
    required this.oxigenacionPorcentaje,
    required this.temperaturaCorporal,
  });

  @override
  String toString() =>
      'TurnoData(turno: $turno, tiempoEspera: $tiempoEsperaSegundos s, ritmoCardiaco: $ritmoCardiacoBpm bpm, '
      'oxigenacion: $oxigenacionPorcentaje%, temperatura: $temperaturaCorporal C)';
}

enum EstadoConexionBle { desconectado, escaneando, conectando, conectado }

/// Servicio encargado de escanear, conectar y suscribirse al wearable
/// HorarioMedicoTurnil via Bluetooth Low Energy.
class BleService {
  final _estadoController = StreamController<EstadoConexionBle>.broadcast();
  final _turnoController = StreamController<TurnoData>.broadcast();

  Stream<EstadoConexionBle> get estadoStream => _estadoController.stream;
  Stream<TurnoData> get turnoStream => _turnoController.stream;

  BluetoothDevice? _dispositivoConectado;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  EstadoConexionBle _estadoActual = EstadoConexionBle.desconectado;
  EstadoConexionBle get estadoActual => _estadoActual;

  void _setEstado(EstadoConexionBle estado) {
    _estadoActual = estado;
    _estadoController.add(estado);
  }

  static const Duration _timeoutEscaneo = Duration(seconds: 15);

  /// Escanea dispositivos filtrando por el UUID de servicio del wearable
  /// y se conecta automaticamente al primero que encuentre. Si no se
  /// encuentra nada antes del timeout, el estado vuelve a "desconectado"
  /// en lugar de quedarse en "escaneando" indefinidamente.
  ///
  /// Nota: `FlutterBluePlus.startScan()` NO espera a que el escaneo termine
  /// (su `timeout` solo agenda un `stopScan()` interno y el metodo retorna
  /// casi de inmediato), asi que el reinicio de estado se controla aqui con
  /// un temporizador propio en vez de confiar en el `await` de `startScan`.
  Future<void> escanearYConectar() async {
    _setEstado(EstadoConexionBle.escaneando);

    bool yaConectando = false;

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      if (results.isEmpty || yaConectando) return;

      yaConectando = true;
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();

      await conectar(results.first.device);
    });

    await FlutterBluePlus.startScan(
      withServices: [HmtBleUuids.serviceUuid],
      timeout: _timeoutEscaneo,
    );

    Future.delayed(_timeoutEscaneo, () {
      if (!yaConectando && _estadoActual == EstadoConexionBle.escaneando) {
        _scanSubscription?.cancel();
        _setEstado(EstadoConexionBle.desconectado);
      }
    });
  }

  Future<void> conectar(BluetoothDevice dispositivo) async {
    _setEstado(EstadoConexionBle.conectando);

    try {
      await dispositivo.connect(timeout: const Duration(seconds: 10));
      _dispositivoConectado = dispositivo;

      final servicios = await dispositivo.discoverServices();
      final servicio = servicios.firstWhere(
        (s) => s.uuid == HmtBleUuids.serviceUuid,
        orElse: () => throw Exception('Servicio HorarioMedicoTurnil no encontrado'),
      );

      final caracteristica = servicio.characteristics.firstWhere(
        (c) => c.uuid == HmtBleUuids.characteristicUuid,
        orElse: () => throw Exception('Caracteristica NOTIFY no encontrada'),
      );

      await caracteristica.setNotifyValue(true);

      _notifySubscription = caracteristica.lastValueStream.listen((bytes) {
        final data = _decodificarPayload(bytes);
        if (data != null) {
          _turnoController.add(data);
        }
      });

      _setEstado(EstadoConexionBle.conectado);
    } catch (e) {
      _setEstado(EstadoConexionBle.desconectado);
      rethrow;
    }
  }

  /// Decodifica el payload recibido por NOTIFY.
  /// Formato esperado: cadena UTF-8
  /// "turno,tiempoEsperaSegundos,ritmoCardiaco,oxigenacion,temperatura"
  /// (ej. "42,780,88,97,36.7"). Acepta tambien los formatos antiguos de 2,
  /// 3 y 4 campos por compatibilidad, usando valores normales por defecto.
  TurnoData? _decodificarPayload(List<int> bytes) {
    try {
      final texto = utf8.decode(Uint8List.fromList(bytes));
      final partes = texto.split(',');
      if (partes.length < 2) return null;

      final turno = int.parse(partes[0].trim());
      final tiempo = int.parse(partes[1].trim());
      final ritmoCardiaco = partes.length >= 3 ? int.parse(partes[2].trim()) : 75;
      final oxigenacion = partes.length >= 4 ? int.parse(partes[3].trim()) : 97;
      final temperatura = partes.length >= 5 ? double.parse(partes[4].trim()) : 36.5;

      return TurnoData(
        turno: turno,
        tiempoEsperaSegundos: tiempo,
        ritmoCardiacoBpm: ritmoCardiaco,
        oxigenacionPorcentaje: oxigenacion,
        temperaturaCorporal: temperatura,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> desconectar() async {
    await _notifySubscription?.cancel();
    await _dispositivoConectado?.disconnect();
    _dispositivoConectado = null;
    _setEstado(EstadoConexionBle.desconectado);
  }

  void dispose() {
    _notifySubscription?.cancel();
    _scanSubscription?.cancel();
    _estadoController.close();
    _turnoController.close();
  }
}
