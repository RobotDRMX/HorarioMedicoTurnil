import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'ble_service.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets/detalle_turno.dart';

const int umbralAlertaSegundos = 900;
const String servidorUrlPorDefecto = 'http://10.13.30.108:3000';
const String tokenServidor = 'secure123';
const String historialKey = 'hmt_historial_turnos';
const String servidorUrlKey = 'hmt_servidor_url';

void main() {
  runApp(const HorarioMedicoTurnilApp());
}

class HorarioMedicoTurnilApp extends StatelessWidget {
  const HorarioMedicoTurnilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HorarioMedicoTurnil',
      debugShowCheckedModeBanner: false,
      theme: buildHorarioMedicoTurnilTheme(),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

/// Color propio para el boton de detener/reanudar la simulacion, fuera de la
/// paleta oficial a proposito: se pidio que resaltara como una accion critica.
const Color _colorBotonDetener = Color(0xFFFA6146);

class _PantallaPrincipalState extends State<PantallaPrincipal> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final BleService _bleService = BleService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _servidorController =
      TextEditingController(text: servidorUrlPorDefecto);
  final ScrollController _scrollController = ScrollController();
  socket_io.Socket? _socket;

  EstadoConexionBle _estado = EstadoConexionBle.desconectado;
  List<String> _historial = [];
  bool _socketConectado = false;
  double _scrollOffset = 0;

  // Estado compartido retransmitido por el SERVIDOR (fuente de verdad unica
  // con la que tambien se sincronizan la TV y el wearable). La tarjeta
  // principal se pinta a partir de este mapa, no del ultimo turno generado
  // localmente, para que los tres dispositivos muestren siempre lo mismo.
  Map<String, dynamic>? _estadoServidor;

  // Simulacion del wearable: se usa unicamente cuando no hay hardware BLE
  // fisico (reloj/ESP32) disponible para emitir la caracteristica NOTIFY real.
  // Reutiliza exactamente el mismo pipeline (_onTurnoRecibido) que usaria un
  // dato real recibido por BLE, por lo que Socket.IO -> Servidor -> TV siguen
  // funcionando de extremo a extremo con datos reales viajando por la red.
  Timer? _simulacionTimer;
  int _turnoSimulado = 0;
  bool get _simulando => _simulacionTimer != null;

  @override
  void initState() {
    super.initState();
    _cargarServidorGuardado();
    _cargarHistorial();

    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });

    _bleService.estadoStream.listen((estado) {
      setState(() => _estado = estado);
    });

    _bleService.turnoStream.listen(_onTurnoRecibido);
  }

  Future<void> _cargarServidorGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(servidorUrlKey);
    if (guardado != null && guardado.isNotEmpty) {
      _servidorController.text = guardado;
    }
    _inicializarSocket(_servidorController.text);
  }

  Future<void> _reconectarServidor() async {
    final url = _servidorController.text.trim();
    if (url.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(servidorUrlKey, url);

    _socket?.dispose();
    _inicializarSocket(url);
  }

  void _inicializarSocket(String url) {
    _socket = socket_io.io(
      url,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'token': tokenServidor, 'role': 'mobile'})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      setState(() => _socketConectado = true);
      // Sincroniza a la TV con el estado actual del toggle de simulacion,
      // por si se reconecta el socket mientras la simulacion ya esta activa.
      _reportarEstadoSimulacion(_simulando);
    });
    _socket!.onDisconnect((_) => setState(() => _socketConectado = false));
    _socket!.onConnectError((err) => setState(() => _socketConectado = false));

    // El servidor es la fuente de verdad del estado compartido (misma cola
    // que ve la TV y, si esta conectado por WiFi, el wearable). Guardamos
    // el mapa completo para que la tarjeta principal muestre exactamente
    // el mismo turno/ritmo/prioridad que esas dos pantallas.
    _socket!.on('update', (data) {
      if (data is Map) {
        final estado = Map<String, dynamic>.from(data);
        setState(() => _estadoServidor = estado);
        _registrarEnHistorialSiCambio(estado);
      }
    });

    _socket!.connect();
  }

  /// Activa/desactiva la simulacion del wearable (usada solo cuando no hay
  /// dispositivo BLE fisico disponible). Genera un turno cada 3 segundos con
  /// el mismo formato/rango que el servicio GATT real (300-1500s de espera
  /// y 40-160 bpm de ritmo cardiaco, con picos ocasionales fuera de rango
  /// normal para poder observar el efecto de prioridad en la cola).
  void _alternarSimulacionWearable(bool activar) {
    if (!activar) {
      _simulacionTimer?.cancel();
      setState(() => _simulacionTimer = null);
      _reportarEstadoSimulacion(false);
      return;
    }

    final random = Random();
    _simulacionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _turnoSimulado += 1;
      final tiempo = 300 + random.nextInt(1500 - 300 + 1);
      final ritmoCardiaco = _generarRitmoCardiacoSimulado(random);
      final oxigenacion = _generarOxigenacionSimulada(random);
      final temperatura = _generarTemperaturaSimulada(random);
      _onTurnoRecibido(TurnoData(
        turno: _turnoSimulado,
        tiempoEsperaSegundos: tiempo,
        ritmoCardiacoBpm: ritmoCardiaco,
        oxigenacionPorcentaje: oxigenacion,
        temperaturaCorporal: temperatura,
      ));
    });
    setState(() {});
    _reportarEstadoSimulacion(true);
  }

  /// Informa al servidor si la simulacion de este dispositivo esta activa o
  /// detenida, para que la TV (y los demas clientes) puedan mostrarlo.
  void _reportarEstadoSimulacion(bool activa) {
    _socket?.emit('simEstado', {'rol': 'mobile', 'activa': activa});
  }

  /// Genera un ritmo cardiaco simulado: normalmente entre 60-100 bpm, con
  /// ~20% de probabilidad de un pico fuera de rango (40-159 bpm) para
  /// disparar prioridad alta en la cola.
  int _generarRitmoCardiacoSimulado(Random random) {
    final esPico = random.nextInt(100) < 20;
    if (esPico) {
      final bajo = random.nextBool();
      return bajo ? 40 + random.nextInt(10) : 121 + random.nextInt(39);
    }
    return 60 + random.nextInt(41);
  }

  /// Genera una saturacion de oxigeno simulada: normalmente 95-100%, con
  /// ~15% de probabilidad de un pico bajo (80-91%, hipoxemia) para disparar
  /// prioridad alta en la cola.
  int _generarOxigenacionSimulada(Random random) {
    final esPico = random.nextInt(100) < 15;
    if (esPico) {
      return 80 + random.nextInt(12);
    }
    return 95 + random.nextInt(6);
  }

  /// Genera una temperatura corporal simulada: normalmente 36.1-37.2 C, con
  /// ~15% de probabilidad de un pico (hipotermia 34.0-35.0 C o fiebre
  /// 38.0-39.5 C) para disparar prioridad alta en la cola.
  double _generarTemperaturaSimulada(Random random) {
    final esPico = random.nextInt(100) < 15;
    if (esPico) {
      final baja = random.nextBool();
      final valor = baja ? 34.0 + random.nextDouble() : 38.0 + random.nextDouble() * 1.5;
      return double.parse(valor.toStringAsFixed(1));
    }
    final valor = 36.1 + random.nextDouble() * 1.1;
    return double.parse(valor.toStringAsFixed(1));
  }

  Future<void> _cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historial = prefs.getStringList(historialKey) ?? [];
    });
  }

  /// Registra en el historial local (persistido, ultimas 10 entradas) el
  /// estado compartido que retransmite el servidor, evitando duplicar la
  /// misma entrada si el turno no cambio desde la ultima vez. Se alimenta
  /// del broadcast 'update' (no del dato generado localmente) para que el
  /// historial refleje SIEMPRE la cola real, sin importar si el turno vino
  /// del wearable, del BLE o de la simulacion de este mismo telefono.
  Future<void> _registrarEnHistorialSiCambio(Map<String, dynamic> estado) async {
    final turno = estado['turno'];
    if (turno == null) return;

    if (_historial.isNotEmpty) {
      final ultimo = jsonDecode(_historial.first) as Map<String, dynamic>;
      if (ultimo['turno'] == turno) return;
    }

    final prefs = await SharedPreferences.getInstance();
    final entrada = jsonEncode({
      'turno': estado['turno'],
      'tiempoEspera': estado['tiempoEspera'],
      'ritmoCardiaco': estado['ritmoCardiaco'],
      'oxigenacion': estado['oxigenacion'],
      'temperatura': estado['temperatura'],
      'prioridad': estado['prioridad'],
      'timestamp': DateTime.now().toIso8601String(),
    });

    _historial.insert(0, entrada);
    if (_historial.length > 10) {
      _historial = _historial.sublist(0, 10);
    }

    await prefs.setStringList(historialKey, _historial);
    setState(() {});
  }

  void _onTurnoRecibido(TurnoData data) {
    _enviarTelemetriaAlServidor(data);

    if (data.tiempoEsperaSegundos >= umbralAlertaSegundos) {
      _mostrarAlertaUmbral(data);
    }
  }

  void _enviarTelemetriaAlServidor(TurnoData data) {
    _socket?.emit('telemetry', {
      'turno': data.turno,
      'tiempoEspera': data.tiempoEsperaSegundos,
      'ritmoCardiaco': data.ritmoCardiacoBpm,
      'oxigenacion': data.oxigenacionPorcentaje,
      'temperatura': data.temperaturaCorporal,
    });
  }

  Future<void> _mostrarAlertaUmbral(TurnoData data) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alert.wav'));
    } catch (_) {
      // Si el sonido no esta disponible, la alerta visual sigue mostrandose.
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        content: Text(
          'ALERTA: Turno ${data.turno} supera el tiempo de espera '
          '(${data.tiempoEsperaSegundos}s >= $umbralAlertaSegundos s)',
          style: const TextStyle(
            color: HmtColors.textoPrincipal,
            fontWeight: FontWeight.bold,
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HmtColors.fondo,
        title: const Text(
          'Tiempo de espera excedido',
          style: TextStyle(color: HmtColors.textoPrincipal, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'El turno ${data.turno} lleva ${data.tiempoEsperaSegundos} segundos de espera, '
          'superando el umbral configurado.',
          style: const TextStyle(color: HmtColors.textoPrincipal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(color: HmtColors.acento)),
          ),
        ],
      ),
    );
  }

  String _textoEstado() {
    switch (_estado) {
      case EstadoConexionBle.desconectado:
        return 'Desconectado';
      case EstadoConexionBle.escaneando:
        return 'Escaneando...';
      case EstadoConexionBle.conectando:
        return 'Conectando...';
      case EstadoConexionBle.conectado:
        return 'Conectado';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _simulacionTimer?.cancel();
    _servidorController.dispose();
    _scrollController.dispose();
    _bleService.dispose();
    _socket?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HorarioMedicoTurnil'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: HmtColors.fondo,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Principal'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_vistaPrincipal(), _vistaHistorial()],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _alternarSimulacionWearable(!_simulando),
        backgroundColor: _colorBotonDetener,
        foregroundColor: Colors.white,
        icon: _simulando
            ? SizedBox(width: 22, height: 22, child: Lottie.asset('assets/lottie/pulso.json'))
            : const Icon(Icons.play_arrow),
        label: Text(_simulando ? 'Detener datos' : 'Simular wearable'),
      ),
    );
  }

  Widget _vistaPrincipal() {
    // El FAB flota en una posicion fija cerca del borde inferior de la
    // pantalla, sin importar cuanto contenido tenga la lista. Reservamos esa
    // franja con un SizedBox FUERA del ListView (no como padding al final,
    // que solo cuenta si el contenido ya desborda el viewport) para que
    // nunca quede tapada la ultima tarjeta.
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SeccionConexion(
                controller: _servidorController,
                onConectar: _reconectarServidor,
                socketConectado: _socketConectado,
                estadoBle: _textoEstado(),
              ),
              const SizedBox(height: 16),
              _TarjetaTurno(estadoServidor: _estadoServidor),
              const SizedBox(height: 16),
              _SeccionControles(
                bleConectado: _estado == EstadoConexionBle.conectado,
                onBleTap: _estado == EstadoConexionBle.conectado
                    ? _bleService.desconectar
                    : _bleService.escanearYConectar,
              ),
            ],
          ),
        ),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget _vistaHistorial() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned(
                top: 20 - _scrollOffset * 0.35,
                right: -50,
                child: const IgnorePointer(
                  child: Opacity(
                    opacity: 0.10,
                    child: Icon(Icons.monitor_heart, size: 260, color: HmtColors.textoPrincipal),
                  ),
                ),
              ),
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Historial (ultimos 10 turnos)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList.builder(
                      itemCount: _historial.length,
                      itemBuilder: (context, index) {
                        final item = jsonDecode(_historial[index]) as Map<String, dynamic>;
                        final heroTag = 'turno-hero-${item['turno']}-${item['timestamp']}';
                        return StaggeredEntrance(
                          key: ValueKey(heroTag),
                          index: index,
                          child: _TarjetaHistorial(item: item, heroTag: heroTag),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 88),
      ],
    );
  }
}

class _SeccionConexion extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onConectar;
  final bool socketConectado;
  final String estadoBle;

  const _SeccionConexion({
    required this.controller,
    required this.onConectar,
    required this.socketConectado,
    required this.estadoBle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Conexion', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: HmtColors.textoPrincipal),
                    decoration: const InputDecoration(
                      labelText: 'Servidor (http://IP-de-tu-PC:3000)',
                      labelStyle: TextStyle(color: HmtColors.textoSecundario),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BounceTap(
                  onTap: onConectar,
                  child: ElevatedButton(
                    onPressed: onConectar,
                    child: const Text('Conectar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PuntoEstado(activo: socketConectado),
                const SizedBox(width: 6),
                Text(
                  'Servidor: ${socketConectado ? "Conectado" : "Desconectado"}  |  BLE: $estadoBle',
                  style: const TextStyle(
                    color: HmtColors.textoSecundario,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto de estado con microinteraccion: pulsa suavemente mientras esta
/// activo, en vez de ser un icono estatico.
class _PuntoEstado extends StatefulWidget {
  final bool activo;
  const _PuntoEstado({required this.activo});

  @override
  State<_PuntoEstado> createState() => _PuntoEstadoState();
}

class _PuntoEstadoState extends State<_PuntoEstado> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activo) {
      return const Icon(Icons.circle, size: 10, color: Colors.grey);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: 0.6 + _controller.value * 0.4,
          child: const Icon(Icons.circle, size: 10, color: HmtColors.acento),
        );
      },
    );
  }
}

class _SeccionControles extends StatelessWidget {
  final bool bleConectado;
  final VoidCallback onBleTap;

  const _SeccionControles({
    required this.bleConectado,
    required this.onBleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Controles', style: Theme.of(context).textTheme.titleMedium),
            ),
            BounceTap(
              onTap: onBleTap,
              child: ListTile(
                leading: Icon(
                  bleConectado ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                  color: HmtColors.textoPrincipal,
                ),
                title: Text(bleConectado ? 'Desconectar BLE' : 'Escanear y Conectar (BLE real)'),
                onTap: onBleTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaTurno extends StatelessWidget {
  // Estado compartido tal cual lo retransmite el servidor (evento 'update'):
  // el mismo mapa que consumen la TV y el wearable, para que las tres
  // pantallas muestren siempre el mismo turno/ritmo/prioridad/proximos.
  final Map<String, dynamic>? estadoServidor;

  const _TarjetaTurno({required this.estadoServidor});

  @override
  Widget build(BuildContext context) {
    final estado = estadoServidor;

    if (estado == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: _EsqueletoTarjetaTurno(),
        ),
      );
    }

    final prioridad = estado['prioridad'] as String?;
    final esPrioridadAlta = prioridad == 'alta';
    final proximos = (estado['proximos'] as List?) ?? const [];

    return SpringPop(
      triggerKey: estado['turno'],
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _campoMorph('Turno', '${estado['turno'] ?? '--'}', 40),
                  _campoMorph('Espera (s)', '${estado['tiempoEspera'] ?? '--'}', 40),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _campoMorph('Ritmo (bpm)', '${estado['ritmoCardiaco'] ?? '--'}', 32),
                  _campoMorph('SpO2 (%)', '${estado['oxigenacion'] ?? '--'}', 32),
                  _campoMorph('Temp (°C)', '${estado['temperatura'] ?? '--'}', 32),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: hmtDuration,
                curve: hmtEase,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: esPrioridadAlta ? HmtColors.textoPrincipal : HmtColors.acento,
                  borderRadius: BorderRadius.circular(esPrioridadAlta ? 8 : 20),
                ),
                child: Text(
                  esPrioridadAlta ? 'PRIORIDAD ALTA (segun servidor)' : 'Prioridad normal',
                  style: const TextStyle(color: HmtColors.fondo, fontWeight: FontWeight.bold),
                ),
              ),
              if (proximos.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Proximos turnos',
                    style: TextStyle(color: HmtColors.textoPrincipal, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 6),
                ...proximos.map((p) {
                  final mapa = p as Map;
                  final esAlta = mapa['prioridad'] == 'alta';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Turno ${mapa['turno']}', style: const TextStyle(color: HmtColors.textoSecundario)),
                        if (esAlta)
                          const Text('ALTA', style: TextStyle(color: HmtColors.textoPrincipal, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoMorph(String etiqueta, String valor, double tamano) {
    return Column(
      children: [
        Text(etiqueta, style: const TextStyle(color: HmtColors.textoSecundario, fontSize: 16)),
        AnimatedSwitcher(
          duration: hmtDuration,
          switchInCurve: hmtEase,
          switchOutCurve: hmtEase,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            valor,
            key: ValueKey('$etiqueta-$valor'),
            style: TextStyle(
              color: HmtColors.textoPrincipal,
              fontSize: tamano,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _EsqueletoTarjetaTurno extends StatelessWidget {
  const _EsqueletoTarjetaTurno();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            HmtShimmer(width: 70, height: 44),
            HmtShimmer(width: 70, height: 44),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            HmtShimmer(width: 50, height: 34),
            HmtShimmer(width: 50, height: 34),
            HmtShimmer(width: 50, height: 34),
          ],
        ),
        const SizedBox(height: 16),
        const HmtShimmer(width: 180, height: 24, borderRadius: BorderRadius.all(Radius.circular(20))),
      ],
    );
  }
}

class _TarjetaHistorial extends StatelessWidget {
  final Map<String, dynamic> item;
  final String heroTag;

  const _TarjetaHistorial({required this.item, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final esAlta = item['prioridad'] == 'alta';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BounceTap(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: hmtDuration,
              pageBuilder: (_, __, ___) => DetalleTurnoPage(item: item, heroTag: heroTag),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: CurvedAnimation(parent: animation, curve: hmtEase), child: child),
            ),
          );
        },
        child: Card(
          child: ListTile(
            title: Hero(
              tag: heroTag,
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  'Turno ${item['turno']}',
                  style: const TextStyle(color: HmtColors.textoPrincipal, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            subtitle: Text(
              'Espera: ${item['tiempoEspera']}s | Ritmo: ${item['ritmoCardiaco']} bpm | '
              'SpO2: ${item['oxigenacion']}% | Temp: ${item['temperatura']}°C',
              style: const TextStyle(color: HmtColors.textoSecundario),
            ),
            trailing: esAlta
                ? const Text(
                    'ALTA',
                    style: TextStyle(color: HmtColors.textoPrincipal, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
