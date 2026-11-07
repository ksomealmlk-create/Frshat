import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const WhiteEpicApp());
}

String fmt(double v) {
  if (v < 1000) {
    return v == v.floorToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }
  const s = ['K', 'M', 'B', 'T', 'Qa', 'Qi'];
  var i = -1;
  var x = v;
  while (x >= 1000 && i < s.length - 1) {
    x /= 1000;
    i++;
  }
  return '${x.toStringAsFixed(2)}${s[i]}';
}

class Machine {
  final String name, note;
  final double cost, out;
  const Machine(this.name, this.cost, this.out, this.note);
}

const machines = [
  Machine('ماء صابوني', 50, 1, 'رخيصة وبداية كل لاعب'),
  Machine('ابن عمتك', 500, 10, 'يشتغل بالإجبار'),
  Machine('فرشاة Sonic', 3000, 50, 'تضاعف نقرتك ×2 وهي شغالة'),
  Machine('Roomba Pro', 20000, 300, 'يدور بالمنطقة'),
  Machine('مدفع الرغوة', 150000, 2000, 'ينظف مساحة كبيرة'),
  Machine('درون الليزر', 1000000, 15000, 'يستهدف البقع العنيدة'),
  Machine('روبوت التيتانيوم الكوني', 10000000, 100000, 'للكوكب والكون'),
];

class BrushUp {
  final String name;
  final double cost, bonus;
  const BrushUp(this.name, this.cost, this.bonus);
}

const boostNames = ['كوب الماء الساخن', 'معجون النعناع'];
const boostNotes = ['×2 للإنتاج والنقر لمدة 30 ثانية', '×5 للأرباح لمدة 30 ثانية'];
const boostMults = [2.0, 5.0];
const boostCool = [120, 300];

const brushes = [
  BrushUp('فرشاة بلاستيكية', 15, 1),
  BrushUp('فرشاة بشعيرات صلبة', 100, 5),
  BrushUp('فرشاة الليزر الضوئي', 12000, 50),
  BrushUp('فرشاة التيتانيوم الكونية', 130000, 500),
];

class Area {
  final String name, letter;
  final double dirt;
  const Area(this.name, this.dirt, this.letter);
}

// أرقام الوسخ مبدئية وتنضبط بعد التجربة
const areas = [
  Area('غرفة المستودع', 20000, 'هذه فرشاتي، والبصمة بصمتي. لا تخف من البقعة الأولى.'),
  Area('القصر', 1000000, 'البقع تتغذى على الإهمال، وكل مكان تتركه يتسخ من جديد.'),
  Area('المدينة', 100000000, 'الناس لا يرون البقع، وأنت وحدك ترى.'),
  Area('الكوكب', 10000000000, 'الفوضى لها مصدر واحد، وهو أكبر من أي بقعة.'),
  Area('الكون', 1000000000000, 'ستفهم كل شيء عندما تنظف آخر ذرة.'),
];

class Game extends ChangeNotifier {
  double money = 0;
  int areaIdx = 0;
  double progress = 0;
  bool finished = false;
  List<int> counts = List.filled(machines.length, 0);
  List<int> levels = List.filled(machines.length, 1);
  List<bool> brushOwned = List.filled(brushes.length, false);
  DateTime lastSeen = DateTime.now();
  String? pendingLetter;
  bool pendingEnd = false;
  List<bool> managers = List.filled(machines.length, false);
  int drops = 0, prestiges = 0, taps = 0;
  double cycleEarned = 0;
  bool vibrate = true;
  List<int> boostEnd = [0, 0], cool = [0, 0];

  double get boostMult {
    final n = DateTime.now().millisecondsSinceEpoch;
    var m = 1.0;
    for (var i = 0; i < 2; i++) {
      if (boostEnd[i] > n) m *= boostMults[i];
    }
    return m;
  }

  void useBoost(int i) {
    final n = DateTime.now().millisecondsSinceEpoch;
    if (cool[i] > n) return;
    boostEnd[i] = n + 30000;
    cool[i] = n + 30000 + boostCool[i] * 1000;
    notifyListeners();
  }

  int get dropGain => 1 + sqrt(cycleEarned / 1e12).floor();

  void prestige() {
    final d = drops + dropGain, p = prestiges + 1, t = taps;
    reset();
    drops = d;
    prestiges = p;
    taps = t;
    notifyListeners();
  }

  double managerCost(int i) => machines[i].cost * 100;

  void buyManager(int i) {
    final c = managerCost(i);
    if (managers[i] || money < c) return;
    money -= c;
    managers[i] = true;
    notifyListeners();
  }

  List<(String, String, bool)> get achievements => [
        ('أول فلس', 'أول نقرة', taps >= 1),
        ('فرك محترف', '1,000 نقرة', taps >= 1000),
        ('رجل الأعمال', 'شراء أول آلة', counts.any((c) => c > 0)),
        ('جيش النظافة', '100 وحدة من آلة واحدة', counts.any((c) => c >= 100)),
        ('الحارس الجديد', 'أول تسليم للفرشاة', prestiges >= 1),
      ];

  void refresh() => notifyListeners();

  void reset() {
    drops = 0;
    prestiges = 0;
    taps = 0;
    cycleEarned = 0;
    managers = List.filled(machines.length, false);
    boostEnd = [0, 0];
    cool = [0, 0];
    money = 0;
    areaIdx = 0;
    progress = 0;
    finished = false;
    counts = List.filled(machines.length, 0);
    levels = List.filled(machines.length, 1);
    brushOwned = List.filled(brushes.length, false);
    lastSeen = DateTime.now();
    notifyListeners();
  }

  double get areaMult => pow(2, areaIdx).toDouble();
  double machineCost(int i) => machines[i].cost * pow(1.15, counts[i]);
  double levelCost(int i) => machines[i].cost * 10 * pow(1.3, levels[i] - 1);

  double unitOut(int i) {
    final l = levels[i];
    var m = 1 + 0.1 * (l - 1);
    if (l >= 10) m *= 2;
    if (l >= 25) m *= 2;
    if (l >= 50) m *= 2;
    return machines[i].out * m;
  }

  double get perSec => baseSec * boostMult;

  double get baseSec {
    var s = 0.0;
    for (var i = 0; i < machines.length; i++) {
      s += counts[i] * unitOut(i);
    }
    return s * areaMult * (1 + drops);
  }

  double get clickPower {
    var p = 1.0;
    for (var i = 0; i < brushes.length; i++) {
      if (brushOwned[i]) p += brushes[i].bonus;
    }
    if (counts[2] > 0) p *= 2;
    return p * areaMult * (1 + drops) * boostMult;
  }

  double get frac =>
      finished ? 1.0 : (progress / areas[areaIdx].dirt).clamp(0.0, 1.0).toDouble();

  void earn(double x) {
    if (x <= 0) return;
    money += x;
    cycleEarned += x;
    if (finished) return;
    progress += x;
    while (!finished && progress >= areas[areaIdx].dirt) {
      progress -= areas[areaIdx].dirt;
      pendingLetter = areas[areaIdx].letter;
      if (areaIdx < areas.length - 1) {
        areaIdx++;
      } else {
        finished = true;
        pendingEnd = true;
        progress = 0;
      }
    }
  }

  void tap() {
    taps++;
    earn(clickPower);
    notifyListeners();
  }

  void tick(double dt) {
    earn(perSec * dt);
    for (var i = 0; i < machines.length; i++) {
      if (!managers[i]) continue;
      if (money >= machineCost(i)) {
        money -= machineCost(i);
        counts[i]++;
      } else if (counts[i] > 0 && levels[i] < 100 && money >= levelCost(i)) {
        money -= levelCost(i);
        levels[i]++;
      }
    }
    notifyListeners();
  }

  void buyMachine(int i) {
    final c = machineCost(i);
    if (money < c) return;
    money -= c;
    counts[i]++;
    notifyListeners();
  }

  void upLevel(int i) {
    if (counts[i] == 0 || levels[i] >= 100) return;
    final c = levelCost(i);
    if (money < c) return;
    money -= c;
    levels[i]++;
    notifyListeners();
  }

  void buyBrush(int i) {
    if (brushOwned[i] || money < brushes[i].cost) return;
    money -= brushes[i].cost;
    brushOwned[i] = true;
    notifyListeners();
  }

  Future<void> save() async {
    lastSeen = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'save',
      jsonEncode({
        'money': money,
        'area': areaIdx,
        'progress': progress,
        'finished': finished,
        'counts': counts,
        'levels': levels,
        'brush': brushOwned,
        'seen': lastSeen.millisecondsSinceEpoch,
        'mgr': managers,
        'drops': drops,
        'pres': prestiges,
        'taps': taps,
        'cycle': cycleEarned,
        'vib': vibrate,
      }),
    );
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('save');
    if (s == null) return;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      money = (m['money'] as num).toDouble();
      areaIdx = m['area'] as int;
      progress = (m['progress'] as num).toDouble();
      finished = m['finished'] as bool;
      counts = List<int>.from(m['counts']);
      levels = List<int>.from(m['levels']);
      brushOwned = List<bool>.from(m['brush']);
      lastSeen = DateTime.fromMillisecondsSinceEpoch(m['seen'] as int);
      if (m['mgr'] != null) managers = List<bool>.from(m['mgr']);
      drops = (m['drops'] as int?) ?? 0;
      prestiges = (m['pres'] as int?) ?? 0;
      taps = (m['taps'] as int?) ?? 0;
      cycleEarned = (m['cycle'] as num?)?.toDouble() ?? 0;
      vibrate = (m['vib'] as bool?) ?? true;
    } catch (_) {}
  }

  // أرباح الغياب: لحد 8 ساعات وبنسبة 50%
  double offlineGain() {
    final secs = min(DateTime.now().difference(lastSeen).inSeconds, 8 * 3600);
    lastSeen = DateTime.now();
    if (secs < 60) return 0;
    final g = baseSec * secs * 0.5;
    earn(g);
    return g;
  }
}

class WhiteEpicApp extends StatelessWidget {
  const WhiteEpicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'الملحمة البيضاء',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        builder: (c, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final game = Game();
  Timer? timer;
  DateTime last = DateTime.now();
  int saveTick = 0;
  final List<_Pop> pops = [];
  int popId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await game.load();
    final g = game.offlineGain();
    last = DateTime.now();
    game.refresh();
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
    if (g > 0 && mounted) _msg('أثناء غيابك', 'جمعت آلاتك ${fmt(g)} فلس');
  }

  void _onTick() {
    final now = DateTime.now();
    final dt = min(now.difference(last).inMilliseconds, 1000) / 1000.0;
    last = now;
    game.tick(dt);
    if (++saveTick % 50 == 0) game.save();
    final l = game.pendingLetter;
    if (l != null && mounted) {
      game.pendingLetter = null;
      final end = game.pendingEnd;
      game.pendingEnd = false;
      _msg('رسالة من الجد', l).then((_) {
        if (end && mounted) {
          _msg('النهاية', 'صار الكون أبيض ناصع. وفجأة نزلت قطرة قهوة وحدة على نقطة البداية. رفعت راسك وشفت كوب جدك يراقبك من الأول. قالك: «التنظيف ما ينتهي أبداً. هسّه إنت الحارس.» اضغط تسليم الفرشاة لتبدأ دورة أقوى.');
        }
      });
    }
  }

  void _confirmReset() => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('بدء من جديد؟'),
          content: const Text('راح تنمسح كل تقدماتك.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                game.reset();
                game.save();
                Navigator.pop(c);
              },
              child: const Text('نعم'),
            ),
          ],
        ),
      );

  Future<void> _msg(String t, String b) {
    return showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t),
        content: Text(b),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('تمام')),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) game.save();
    if (s == AppLifecycleState.resumed) {
      final g = game.offlineGain();
      last = DateTime.now();
      if (g > 0 && mounted) _msg('أثناء غيابك', 'جمعت آلاتك ${fmt(g)} فلس');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    game.save();
    super.dispose();
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          SizedBox(
            height: 32,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'بدء من جديد',
                onPressed: _confirmReset,
                icon: const Icon(Icons.restart_alt),
              ),
            ),
          ),
          Text('${fmt(game.money)} فلس',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text('${fmt(game.perSec)} / ثانية  •  ${fmt(game.clickPower)} / نقرة${game.drops > 0 ? '  •  💧${game.drops}' : ''}'),
          const SizedBox(height: 8),
          Text(game.finished
              ? 'نظّفت الكون كله!'
              : '${areas[game.areaIdx].name}: ${(game.frac * 100).toStringAsFixed(1)}%'),
          LinearProgressIndicator(value: game.frac, minHeight: 8),
          if (game.finished)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton(
                onPressed: game.prestige,
                child: Text('تسليم الفرشاة (+${game.dropGain} قطرة)'),
              ),
            ),
        ]),
      );

  Widget _machineCard(int i) {
    final m = machines[i];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m.name}  ×${game.counts[i]}  (مستوى ${game.levels[i]})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${m.note} • ${fmt(game.unitOut(i))}/ث للوحدة',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
          Column(children: [
            FilledButton(
              onPressed: game.money >= game.machineCost(i) ? () => game.buyMachine(i) : null,
              child: Text('شراء ${fmt(game.machineCost(i))}'),
            ),
            OutlinedButton(
              onPressed: game.counts[i] > 0 && game.money >= game.levelCost(i)
                  ? () => game.upLevel(i)
                  : null,
              child: Text('تطوير ${fmt(game.levelCost(i))}'),
            ),
            game.managers[i]
                ? const Icon(Icons.smart_toy, color: Colors.teal)
                : TextButton(
                    onPressed: game.money >= game.managerCost(i) ? () => game.buyManager(i) : null,
                    child: Text('مدير ${fmt(game.managerCost(i))}'),
                  ),
          ]),
        ]),
      ),
    );
  }

  Widget _brushCard(int i) {
    final b = brushes[i];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(b.name),
        subtitle: Text('+${fmt(b.bonus)} لكل نقرة'),
        trailing: game.brushOwned[i]
            ? const Icon(Icons.check_circle, color: Colors.green)
            : FilledButton(
                onPressed: game.money >= b.cost ? () => game.buyBrush(i) : null,
                child: Text(fmt(b.cost)),
              ),
      ),
    );
  }

  Widget _letters() {
    final n = (game.finished || game.prestiges > 0) ? areas.length : game.areaIdx;
    if (n == 0) {
      return const Center(child: Text('نظّف أول منطقة لتصلك رسالة من الجد'));
    }
    return ListView.builder(
      itemCount: n,
      itemBuilder: (c, i) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.mail_outline),
          title: Text(areas[i].name),
          subtitle: Text(areas[i].letter),
        ),
      ),
    );
  }

  Widget _boosts() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ListView.builder(
      itemCount: boostNames.length,
      itemBuilder: (c, i) {
        final active = game.boostEnd[i] > now;
        final cd = game.cool[i] > now;
        final left = ((active ? game.boostEnd[i] : game.cool[i]) - now) ~/ 1000;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(boostNames[i]),
            subtitle: Text(boostNotes[i]),
            trailing: FilledButton(
              onPressed: active || cd ? null : () => game.useBoost(i),
              child: Text(active ? 'شغّال $leftث' : cd ? 'انتظار $leftث' : 'تفعيل'),
            ),
          ),
        );
      },
    );
  }

  Widget _achievements() => ListView(
        children: [
          for (final a in game.achievements)
            ListTile(
              leading: Icon(a.$3 ? Icons.emoji_events : Icons.lock_outline,
                  color: a.$3 ? Colors.amber : Colors.grey),
              title: Text(a.$1),
              subtitle: Text(a.$2),
            ),
        ],
      );

  Widget _settings() => ListView(children: [
        SwitchListTile(
          title: const Text('الاهتزاز عند النقر'),
          value: game.vibrate,
          onChanged: (v) {
            game.vibrate = v;
            game.refresh();
          },
        ),
        ListTile(
          title: const Text('قطرات الأكسجين النقي'),
          trailing: Text('${game.drops}'),
        ),
      ]);

  Widget _shop() => DefaultTabController(
        length: 6,
        child: Column(children: [
          const TabBar(isScrollable: true, tabs: [Tab(text: 'الآلات'), Tab(text: 'الفرشاة'), Tab(text: 'رسائل الجد'), Tab(text: 'المعززات'), Tab(text: 'الإنجازات'), Tab(text: 'الإعدادات')]),
          Expanded(
            child: TabBarView(children: [
              ListView.builder(
                  itemCount: machines.length, itemBuilder: (c, i) => _machineCard(i)),
              ListView.builder(
                  itemCount: brushes.length, itemBuilder: (c, i) => _brushCard(i)),
              _letters(),
              _boosts(),
              _achievements(),
              _settings(),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (c, _) => Column(children: [
            _header(),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  if (game.vibrate) HapticFeedback.selectionClick();
                  final p = _Pop(popId++, d.localPosition, '+${fmt(game.clickPower)}');
                  pops.add(p);
                  if (pops.length > 12) pops.removeAt(0);
                  Future.delayed(const Duration(milliseconds: 800), () => pops.remove(p));
                  game.tap();
                },
                child: Stack(children: [
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: FloorPainter(game.frac, game.areaIdx),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  for (final p in pops)
                    Positioned(
                      left: p.pos.dx - 20,
                      top: p.pos.dy - 30,
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(p.id),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          builder: (c, t, _) => Opacity(
                            opacity: 1 - t,
                            child: Transform.translate(
                              offset: Offset(0, -60 * t),
                              child: Text(p.text,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00796B))),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            SizedBox(height: 300, child: _shop()),
          ]),
        ),
      ),
    );
  }
}

// الأرضية من الأعلى (Top-Down): البقع تختفي كلما زادت النظافة
class FloorPainter extends CustomPainter {
  final double frac;
  final int area;
  FloorPainter(this.frac, this.area);

  static const floors = [
    Color(0xFFF5F5F0),
    Color(0xFFFFF3E0),
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFEDE7F6),
  ];

  static final List<List<double>> stains = (() {
    final r = Random(7);
    return List.generate(
        40, (_) => [r.nextDouble(), r.nextDouble(), 10 + r.nextDouble() * 22]);
  })();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = floors[area % floors.length]);
    final line = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final n = ((1 - frac) * stains.length).ceil();
    final dirt = Paint()..color = const Color(0xCC5D4037);
    for (var i = 0; i < n; i++) {
      final s = stains[i];
      canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), s[2], dirt);
    }
    // لمعة الأماكن اللي تنظفت
    final glow = Paint()..color = const Color(0x66FFD54F);
    final star = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 2;
    for (var i = n; i < stains.length; i++) {
      final c = Offset(stains[i][0] * size.width, stains[i][1] * size.height);
      canvas.drawCircle(c, 6, glow);
      canvas.drawLine(c.translate(-8, 0), c.translate(8, 0), star);
      canvas.drawLine(c.translate(0, -8), c.translate(0, 8), star);
    }
  }

  @override
  bool shouldRepaint(FloorPainter o) => o.frac != frac || o.area != area;
}

class _Pop {
  final int id;
  final Offset pos;
  final String text;
  _Pop(this.id, this.pos, this.text);
}
