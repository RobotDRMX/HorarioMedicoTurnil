import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'theme.dart';

/// Curva de easing propia (cubic-bezier), en vez de usar solo las de Flutter,
/// para que todas las transiciones de la app compartan la misma "firma" de
/// movimiento: arranque rapido y llegada suave.
const Curve hmtEase = Cubic(0.22, 1, 0.36, 1);
const Duration hmtDuration = Duration(milliseconds: 420);

/// Envuelve [child] y le da un "pop" con fisica de resorte (no con una curva
/// interpolada) cada vez que [triggerKey] cambia de valor. Se usa para que la
/// tarjeta de turno reaccione con un rebote natural cuando llega un dato
/// nuevo del servidor.
class SpringPop extends StatefulWidget {
  final Widget child;
  final Object? triggerKey;

  const SpringPop({super.key, required this.child, required this.triggerKey});

  @override
  State<SpringPop> createState() => _SpringPopState();
}

class _SpringPopState extends State<SpringPop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _resorte = SpringDescription(mass: 1, stiffness: 260, damping: 14);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, upperBound: 2);
  }

  @override
  void didUpdateWidget(covariant SpringPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.triggerKey != widget.triggerKey) {
      _controller.animateWith(SpringSimulation(_resorte, 0, 1, 6));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final escala = 1.0 + (_controller.value * 0.05);
        return Transform.scale(scale: escala, child: child);
      },
      child: widget.child,
    );
  }
}

/// Bloque de "esqueleto" con efecto shimmer (barrido de brillo), usado como
/// placeholder mientras no ha llegado el primer estado del servidor.
class HmtShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const HmtShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<HmtShimmer> createState() => _HmtShimmerState();
}

class _HmtShimmerState extends State<HmtShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.6 + t * 3.2, 0),
            end: Alignment(-0.6 + t * 3.2, 0),
            colors: const [HmtColors.tarjeta, Colors.white70, HmtColors.tarjeta],
          ).createShader(bounds),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(color: HmtColors.tarjeta, borderRadius: widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Anima la entrada de un elemento de lista con un retraso proporcional a su
/// [index] (staggered animation): cada tarjeta del historial aparece un poco
/// despues que la anterior, en vez de todas a la vez.
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;

  const StaggeredEntrance({super.key, required this.child, required this.index});

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: hmtDuration);
    _fade = CurvedAnimation(parent: _controller, curve: hmtEase);
    _slide = Tween(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: hmtEase));

    final retraso = Duration(milliseconds: 45 * widget.index.clamp(0, 10));
    Future.delayed(retraso, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Microinteraccion tactil: reduce ligeramente la escala del contenido
/// mientras se mantiene presionado, y vuelve a su tamano con la curva propia.
class BounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BounceTap({super.key, required this.child, this.onTap});

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap> {
  double _escala = 1.0;

  void _set(double valor) => setState(() => _escala = valor);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(0.94),
      onTapUp: (_) => _set(1.0),
      onTapCancel: () => _set(1.0),
      child: AnimatedScale(
        scale: _escala,
        duration: const Duration(milliseconds: 120),
        curve: hmtEase,
        child: widget.child,
      ),
    );
  }
}
