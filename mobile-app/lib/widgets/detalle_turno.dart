import 'package:flutter/material.dart';

import '../theme.dart';

/// Pantalla de detalle abierta al tocar una tarjeta del historial. El numero
/// de turno usa el mismo tag de Hero que la tarjeta de origen, por lo que
/// Flutter anima el "vuelo" del elemento compartido entre ambas pantallas.
class DetalleTurnoPage extends StatelessWidget {
  final Map<String, dynamic> item;
  final String heroTag;

  const DetalleTurnoPage({super.key, required this.item, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final esAlta = item['prioridad'] == 'alta';

    return Scaffold(
      appBar: AppBar(title: Text('Turno ${item['turno']}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: heroTag,
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  '${item['turno']}',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: HmtColors.textoPrincipal,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _fila('Espera', '${item['tiempoEspera']} s'),
            _fila('Ritmo cardiaco', '${item['ritmoCardiaco']} bpm'),
            _fila('SpO2', '${item['oxigenacion']}%'),
            _fila('Temperatura', '${item['temperatura']}°C'),
            if (esAlta) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: HmtColors.textoPrincipal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PRIORIDAD ALTA',
                  style: TextStyle(color: HmtColors.fondo, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            child: Text(etiqueta, style: const TextStyle(color: HmtColors.textoSecundario, fontSize: 16)),
          ),
          Text(valor, style: const TextStyle(color: HmtColors.textoPrincipal, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
