import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The LifeCharger electric intro played while the app starts.
///
/// A gauge ring charges with the real start-up progress, the lightning bolt
/// fills bottom-up like a battery, a strike hits it at 100 %, the wordmark
/// flickers on like neon and the intro fades into the app underneath. The
/// first launch of the day plays the full sequence; later launches play a
/// short one. A tap skips it once the app is ready. A rising charge whine
/// plays under the ring and a crack with a neon buzz on the strike, mixed
/// with whatever else is playing, once the app has said its sound effects are
/// on ([LifechargerIntroController.soundEnabled]).
///
/// Assets (pubspec): `assets/lifecharger_intro/` holding the two OGGs and
/// BigShouldersDisplay-Black.ttf, declared as the `BigShouldersDisplay` family.
///
/// Usage from `main()`:
///   final intro = await LifechargerIntroController.create();
///   runApp(LifechargerIntroHost(controller: intro));
///   ... start-up work, reporting `intro.progress` ...
///   intro.soundEnabled = settings.soundEffectsEnabled; // as soon as known
///   intro.attachApp(MyApp());
class LifechargerIntroController extends ChangeNotifier {
  LifechargerIntroController._(this.full);

  static const _lastFullDayKey = 'lc_intro_last_full_day';

  /// Full sequence (first launch of the day) or the short one.
  final bool full;

  double _progress = 0;
  bool? _soundEnabled;
  Widget? _app;
  bool _finished = false;

  static Future<LifechargerIntroController> create() async {
    var full = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      full = prefs.getString(_lastFullDayKey) != today;
      if (full) await prefs.setString(_lastFullDayKey, today);
    } catch (e) {
      debugPrint('[Intro] Last intro day unavailable, playing full: $e');
    }
    return LifechargerIntroController._(full);
  }

  /// Start-up progress, 0..1. Only ever moves forward.
  double get progress => _progress;
  set progress(double value) {
    final v = value.clamp(0.0, 1.0);
    if (v <= _progress) return;
    _progress = v;
    notifyListeners();
  }

  /// Awaits [futures] together, moving [progress] from [from] to [to] as each
  /// one completes.
  Future<List<Object?>> track(
    List<Future<Object?>> futures, {
    required double from,
    required double to,
  }) {
    var done = 0;
    final n = futures.isEmpty ? 1 : futures.length;
    progress = from;
    return Future.wait(futures.map((f) => f.whenComplete(() {
          done++;
          progress = from + (to - from) * done / n;
        })));
  }

  /// The app's own sound-effects switch. Silent until it is set to true.
  bool? get soundEnabled => _soundEnabled;
  set soundEnabled(bool? value) {
    if (value == _soundEnabled) return;
    _soundEnabled = value;
    notifyListeners();
  }

  Widget? get app => _app;
  bool get finished => _finished;

  /// Hands over the real app; the intro strikes and fades into it.
  void attachApp(Widget app) {
    _app = app;
    _progress = 1;
    notifyListeners();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    notifyListeners();
  }
}

/// Root widget: the app (once attached) with the intro on top of it.
class LifechargerIntroHost extends StatefulWidget {
  const LifechargerIntroHost({super.key, required this.controller});

  final LifechargerIntroController controller;

  @override
  State<LifechargerIntroHost> createState() => _LifechargerIntroHostState();
}

class _LifechargerIntroHostState extends State<LifechargerIntroHost> {
  final _appKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final app = c.app;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (app != null)
            KeyedSubtree(key: _appKey, child: app)
          else
            const ColoredBox(color: _ink),
          if (!c.finished) _IntroOverlay(controller: c),
        ],
      ),
    );
  }
}

const _chargeSound = 'lifecharger_intro/lc_intro_charge.ogg';
const _strikeSound = 'lifecharger_intro/lc_intro_strike.ogg';

const _ink = Color(0xFF05070D);
const _inkLift = Color(0xFF0A1226);
const _volt = Color(0xFF5CE1FF);
const _core = Color(0xFFEAFBFF);
const _plasma = Color(0xFF8A6BFF);
const _muted = Color(0xFF6B7896);

// The mark in logical units, centred on the origin: a lightning bolt inside a
// charge gauge ring of radius [_ringR].
const _bolt = <Offset>[
  Offset(-6, -165),
  Offset(62, -165),
  Offset(16, -28),
  Offset(80, -28),
  Offset(-42, 165),
  Offset(-8, 14),
  Offset(-72, 14),
];
const _ringR = 205.0;
const _ticks = 48;
const _markUnits = 470.0;
const _strikeHit = Offset(28, -165);
const _startAngle = -math.pi / 2;

class _Arc {
  _Arc(this.a, this.b,
      {this.life = .12, this.w = 1.2, this.rough = .35, this.branch = .25})
      : max = life;
  final Offset a, b;
  double life;
  final double max, w, rough, branch;
}

class _Spark {
  _Spark(this.pos, this.vel, this.life);
  Offset pos, vel;
  double life;
}

class _Sim extends ChangeNotifier {
  _Sim(this.controller);

  final LifechargerIntroController controller;
  final rnd = math.Random();
  final arcs = <_Arc>[];
  final sparks = <_Spark>[];

  bool reduceMotion = false;
  double t = 0, charge = 0, heat = 0, flash = 0, shake = 0, fade = 0;
  bool struck = false;
  double strikeT = 0, holdUntil = double.infinity;

  /// Top of the screen in logical units, for the strike's origin.
  double topY = -400;

  late final List<double> _segLen = [
    for (var i = 0; i < _bolt.length; i++)
      (_bolt[(i + 1) % _bolt.length] - _bolt[i]).distance,
  ];
  late final double _perimeter = _segLen.reduce((a, b) => a + b);

  double get _minCharge => controller.full ? 1.7 : 0.55;
  double get _hold => controller.full ? 1.25 : 0.5;
  static const _fadeTime = .35;

  Offset onBolt(double u) {
    var d = (u % 1) * _perimeter;
    for (var i = 0; i < _bolt.length; i++) {
      if (d <= _segLen[i]) {
        final a = _bolt[i], b = _bolt[(i + 1) % _bolt.length];
        return Offset.lerp(a, b, d / _segLen[i])!;
      }
      d -= _segLen[i];
    }
    return _bolt.first;
  }

  Offset onRing(double angle) =>
      Offset(math.cos(angle) * _ringR, math.sin(angle) * _ringR);

  void burst(Offset at, int n, double speed) {
    for (var i = 0; i < n; i++) {
      final ang = rnd.nextDouble() * math.pi * 2;
      final v = speed * (.3 + rnd.nextDouble());
      sparks.add(_Spark(at, Offset(math.cos(ang) * v, math.sin(ang) * v - 60),
          .4 + rnd.nextDouble() * .5));
    }
  }

  void strike() {
    if (struck) return;
    struck = true;
    strikeT = t;
    heat = 1;
    flash = 1;
    shake = 1;
    charge = 1;
    final top = Offset(rnd.nextDouble() * 260 - 130, topY - 30);
    arcs
      ..add(_Arc(top, _strikeHit, life: .32, w: 3.2, rough: .28, branch: .6))
      ..add(_Arc(top + const Offset(40, 0), _strikeHit,
          life: .22, w: 1.6, rough: .4, branch: .4));
    burst(_strikeHit, 60, 420);
    for (var i = 0; i < 6; i++) {
      arcs.add(_Arc(onBolt(rnd.nextDouble()),
          onRing(rnd.nextDouble() * math.pi * 2),
          life: .25, w: 1.4));
    }
    holdUntil = t + _hold;
  }

  void skip() {
    if (controller.app == null) return;
    strike();
    holdUntil = math.min(holdUntil, t + .2);
  }

  void step(double dt) {
    t += dt;
    final ready = controller.app != null;

    if (reduceMotion) {
      // One still frame of the finished mark, gone shortly after the app is in.
      if (!struck) {
        struck = true;
        charge = 1;
        heat = .4;
        strikeT = -10;
      }
      if (ready && holdUntil == double.infinity) holdUntil = t + .5;
      if (t >= holdUntil) controller._finish();
      notifyListeners();
      return;
    }

    if (!struck) {
      final byTime = (t / _minCharge).clamp(0.0, 1.0);
      final target = math.min(controller.progress, byTime);
      charge += (target - charge) * math.min(1.0, dt * 7);
      if (ready && t >= _minCharge && charge > .985) strike();

      // Ring head: sparks and small jumps onto the bolt while charging.
      final head = onRing(_startAngle + charge * math.pi * 2);
      if (charge > .01) {
        if (rnd.nextDouble() < .5) burst(head, 1, 120);
        if (rnd.nextDouble() < .25) {
          arcs.add(_Arc(head, onBolt(rnd.nextDouble()),
              life: .07, w: .9, rough: .5));
        }
        // Arcs skating along the fill line inside the bolt.
        if (rnd.nextDouble() < .3) {
          final y = 165 - charge * 330;
          final x = -60 + rnd.nextDouble() * 140;
          arcs.add(_Arc(Offset(x - 30, y), Offset(x + 30, y),
              life: .05, w: .8, rough: .5, branch: 0));
        }
      }
    } else if (t >= holdUntil) {
      fade += dt / _fadeTime;
      if (fade >= 1) controller._finish();
    }

    heat = math.max(0, heat - dt * 1.4);
    flash = math.max(0, flash - dt * 3.2);
    shake = math.max(0, shake - dt * 4);

    // Ambient crackle along the bolt, more of it once charged.
    if (charge > .05 &&
        rnd.nextDouble() < (struck ? .16 : .1 * charge)) {
      final u = rnd.nextDouble();
      arcs.add(_Arc(onBolt(u), onBolt(u + .04 + rnd.nextDouble() * .12),
          life: .08, w: .8, rough: .6, branch: .15));
    }
    if (struck && rnd.nextDouble() < .045) {
      arcs.add(_Arc(onBolt(rnd.nextDouble()),
          onRing(rnd.nextDouble() * math.pi * 2),
          life: .1, w: 1));
    }

    for (var i = arcs.length - 1; i >= 0; i--) {
      arcs[i].life -= dt;
      if (arcs[i].life <= 0) arcs.removeAt(i);
    }
    for (var i = sparks.length - 1; i >= 0; i--) {
      final p = sparks[i];
      p.life -= dt;
      if (p.life <= 0) {
        sparks.removeAt(i);
        continue;
      }
      p.vel = Offset(p.vel.dx * .985, p.vel.dy + 520 * dt);
      p.pos += p.vel * dt;
    }
    notifyListeners();
  }

  /// Neon flicker of letter [i] of the wordmark, 0..1.
  double letterOpacity(int i) {
    if (!struck) return .07;
    final dur = controller.full ? .9 : .45;
    final stagger = controller.full ? .055 : .02;
    final p = (t - strikeT - i * stagger) / dur;
    if (p < 0) return .07;
    if (p < .10) return 1;
    if (p < .18) return .15;
    if (p < .30) return .9;
    if (p < .36) return .25;
    return 1;
  }
}

class _IntroOverlay extends StatefulWidget {
  const _IntroOverlay({required this.controller});

  final LifechargerIntroController controller;

  @override
  State<_IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<_IntroOverlay>
    with SingleTickerProviderStateMixin {
  late final _Sim _sim = _Sim(widget.controller);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  AudioPlayer? _chargePlayer, _strikePlayer;
  bool _chargeStarted = false, _strikeHandled = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, .05);
      _last = elapsed;
      _sim.step(dt);
      _syncSound();
    })
      ..start();
    // After the intro's first frame, so no audio platform call runs before
    // the window has been drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSounds());
  }

  Future<void> _loadSounds() async {
    final charge = AudioPlayer(playerId: 'lc_intro_charge');
    final strike = AudioPlayer(playerId: 'lc_intro_strike');
    try {
      // Mixed with other audio: the intro never pauses the player's music.
      final ctx =
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build();
      await Future.wait([
        charge.setAudioContext(ctx),
        strike.setAudioContext(ctx),
      ]);
      await Future.wait([
        charge.setSource(AssetSource(_chargeSound)),
        strike.setSource(AssetSource(_strikeSound)),
      ]);
    } catch (e) {
      debugPrint('[Intro] Intro sounds could not be loaded: $e');
      await charge.dispose();
      await strike.dispose();
      return;
    }
    if (!mounted) {
      await charge.dispose();
      await strike.dispose();
      return;
    }
    _chargePlayer = charge;
    _strikePlayer = strike;
  }

  void _syncSound() {
    if (widget.controller.soundEnabled != true || _sim.reduceMotion) return;
    final charge = _chargePlayer, strike = _strikePlayer;
    if (charge == null || strike == null) return;
    if (!_chargeStarted && !_sim.struck) {
      _chargeStarted = true;
      charge.resume();
    }
    if (!_strikeHandled && _sim.struck) {
      _strikeHandled = true;
      if (_chargeStarted) charge.stop();
      // A crack that would land well after the flash is left out.
      if (_sim.t - _sim.strikeT < .25) strike.resume();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sim.reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _chargePlayer?.dispose();
    // The strike's neon tail outlives the fade; let it finish, then release.
    final strike = _strikePlayer;
    if (strike != null) {
      Future.delayed(const Duration(seconds: 2), strike.dispose);
    }
    _sim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _sim.skip,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final markSize = math.min(w * .8, h * .46);
        final scale = markSize / _markUnits;
        final center = Offset(w / 2, h * .43);
        _sim.topY = -center.dy / scale;
        final fontSize = markSize * .2;
        return AnimatedBuilder(
          animation: _sim,
          builder: (context, _) => Opacity(
            opacity: (1 - _sim.fade).clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -.2),
                      radius: 1.1,
                      colors: [_inkLift, _ink],
                      stops: [0, .6],
                    ),
                  ),
                ),
                CustomPaint(painter: _MarkPainter(_sim, center, scale)),
                Positioned(
                  left: 16,
                  right: 16,
                  top: center.dy + markSize * .5 + fontSize * .15,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _Wordmark(sim: _sim, fontSize: fontSize),
                  ),
                ),
                if (_sim.flash > 0)
                  ColoredBox(color: _volt.withAlpha((_sim.flash * 70).round())),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.sim, required this.fontSize});

  final _Sim sim;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const word = 'LIFECHARGER';
    return Semantics(
      label: 'LifeCharger',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < word.length; i++)
              _letter(word[i], sim.letterOpacity(i), i >= 4),
          ],
        ),
      ),
    );
  }

  Widget _letter(String ch, double o, bool charger) {
    final lit = o > .5;
    final base = charger ? _volt : _core;
    return Text(
      ch,
      style: TextStyle(
        fontFamily: 'BigShouldersDisplay',
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        height: 1,
        letterSpacing: fontSize * .02,
        color: lit ? base.withAlpha((o * 255).round()) : _muted.withAlpha((o * 255).round() + 20),
        shadows: lit
            ? [
                Shadow(color: _volt.withAlpha(charger ? 230 : 90), blurRadius: fontSize * .14),
                if (charger) Shadow(color: _volt.withAlpha(120), blurRadius: fontSize * .4),
              ]
            : null,
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.sim, this.center, this.scale);

  final _Sim sim;
  final Offset center;
  final double scale;

  static final Path _boltPath = Path()
    ..addPolygon(_bolt, true);

  final _paint = Paint()..isAntiAlias = true;

  List<Offset> _zap(Offset a, Offset b, double rough) {
    final out = <Offset>[a];
    void rec(Offset p, Offset q, double disp) {
      if (disp < 3) {
        out.add(q);
        return;
      }
      final m = Offset(
        (p.dx + q.dx) / 2 + (sim.rnd.nextDouble() - .5) * disp,
        (p.dy + q.dy) / 2 + (sim.rnd.nextDouble() - .5) * disp,
      );
      rec(p, m, disp / 2);
      rec(m, q, disp / 2);
    }

    rec(a, b, (b - a).distance * rough);
    return out;
  }

  void _strokeZap(Canvas canvas, List<Offset> pts, double w, double alpha) {
    final path = Path()..addPolygon(pts, false);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..blendMode = BlendMode.plus
      ..maskFilter = null;
    _paint
      ..color = _plasma.withAlpha((.18 * alpha * 255).round())
      ..strokeWidth = w * 9;
    canvas.drawPath(path, _paint);
    _paint
      ..color = _volt.withAlpha((.45 * alpha * 255).round())
      ..strokeWidth = w * 3.2;
    canvas.drawPath(path, _paint);
    _paint
      ..color = _core.withAlpha((alpha * 255).round())
      ..strokeWidth = w;
    canvas.drawPath(path, _paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = sim.rnd;
    final t = sim.t;
    final shakeOffset = Offset(
        (r.nextDouble() - .5) * 10 * sim.shake,
        (r.nextDouble() - .5) * 10 * sim.shake);
    canvas.save();
    canvas.translate(center.dx + shakeOffset.dx, center.dy + shakeOffset.dy);
    canvas.scale(scale);

    final breath = sim.struck ? .5 + .5 * math.sin(t * 2.2) : 0.0;
    final ringRect = Rect.fromCircle(center: Offset.zero, radius: _ringR);

    // Gauge ring
    _paint
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.srcOver
      ..maskFilter = null
      ..strokeCap = StrokeCap.butt
      ..color = _volt.withAlpha(20)
      ..strokeWidth = 10;
    canvas.drawCircle(Offset.zero, _ringR, _paint);

    final sweep = sim.charge * math.pi * 2;
    _paint.blendMode = BlendMode.plus;
    if (sweep > .001) {
      _paint
        ..color = _volt.withAlpha(((.25 + .15 * breath) * 255).round())
        ..strokeWidth = 14;
      canvas.drawArc(ringRect, _startAngle, sweep, false, _paint);
      _paint
        ..color = _core.withAlpha(230)
        ..strokeWidth = 2.2;
      canvas.drawArc(ringRect, _startAngle, sweep, false, _paint);
      if (!sim.struck) {
        _paint.style = PaintingStyle.fill;
        _paint.color = _core;
        canvas.drawCircle(sim.onRing(_startAngle + sweep), 6, _paint);
        _paint.style = PaintingStyle.stroke;
      }
    }
    for (var i = 0; i < _ticks; i++) {
      final a = _startAngle + i / _ticks * math.pi * 2;
      final major = i % 4 == 0;
      final lit = i / _ticks < sim.charge;
      final r1 = _ringR + 16, r2 = _ringR + (major ? 30 : 23);
      _paint
        ..blendMode = lit ? BlendMode.plus : BlendMode.srcOver
        ..color = lit
            ? _volt.withAlpha(((.55 + (major ? .35 * breath : 0)) * 255).round())
            : _muted.withAlpha(64)
        ..strokeWidth = major ? 3 : 1.6;
      canvas.drawLine(Offset(math.cos(a) * r1, math.sin(a) * r1),
          Offset(math.cos(a) * r2, math.sin(a) * r2), _paint);
    }
    if (sim.struck) {
      // Current pulse running round the ring.
      final pa = _startAngle + (t * 1.6) % (math.pi * 2);
      _paint
        ..blendMode = BlendMode.plus
        ..color = _core.withAlpha(180)
        ..strokeWidth = 5;
      canvas.drawArc(ringRect, pa - .35, .35, false, _paint);
    }

    // Bolt body: battery-style fill from the bottom.
    canvas.save();
    canvas.clipPath(_boltPath);
    final level = 165 - sim.charge * 330;
    _paint
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xD98A6BFF), Color(0xE65CE1FF)],
      ).createShader(const Rect.fromLTRB(-100, -165, 100, 165));
    canvas.drawRect(Rect.fromLTRB(-100, level, 100, 175), _paint);
    _paint.shader = null;
    if (sim.struck) {
      _paint
        ..blendMode = BlendMode.plus
        ..color = _core.withAlpha(
            (math.min(.9, sim.heat * .9 + .12 + .1 * breath) * 255).round());
      canvas.drawRect(const Rect.fromLTRB(-100, -175, 100, 175), _paint);
    } else if (sim.charge > 0) {
      _paint
        ..blendMode = BlendMode.plus
        ..color = _core;
      canvas.drawRect(Rect.fromLTRB(-100, level - 1.5, 100, level + 1.5), _paint);
    }
    canvas.restore();

    // Bolt outline with glow.
    _paint
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.plus
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = 6
      ..color = _volt.withAlpha(((.5 + .4 * sim.heat) * 255).round())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 18 * sim.heat + 4 * breath);
    canvas.drawPath(_boltPath, _paint);
    _paint
      ..maskFilter = null
      ..strokeWidth = 3
      ..color = sim.struck ? _core : _volt.withAlpha(140);
    canvas.drawPath(_boltPath, _paint);

    // Arcs, re-jagged every frame.
    for (final a in sim.arcs) {
      final alpha = (a.life / a.max) * (.6 + r.nextDouble() * .4);
      final pts = _zap(a.a, a.b, a.rough);
      _strokeZap(canvas, pts, a.w, alpha);
      if (r.nextDouble() < a.branch && pts.length > 4) {
        final p = pts[(r.nextDouble() * pts.length * .8).floor()];
        final d = a.b - a.a;
        final len = d.distance * (.15 + r.nextDouble() * .25);
        final ang = d.direction + (r.nextDouble() - .5) * 1.6;
        _strokeZap(
            canvas,
            _zap(p, p + Offset(math.cos(ang) * len, math.sin(ang) * len), .5),
            a.w * .55,
            alpha * .8);
      }
    }

    // Sparks
    _paint
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    for (final p in sim.sparks) {
      _paint.color = _core.withAlpha((math.min(1.0, p.life * 2) * 255).round());
      canvas.drawLine(p.pos - p.vel * .02, p.pos, _paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => true;
}
