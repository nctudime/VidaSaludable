import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
// Reemplazado activity_recognition_flutter por geolocator + sensors_plus (AGP 8+)
import 'package:google_generative_ai/google_generative_ai.dart';
// pubspec.yaml (agregar dependencias)
// hive: ^2.2.3
// hive_flutter: ^1.1.0
import 'package:hive_flutter/hive_flutter.dart';
// Corregido lint: unnecessary import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('users');
  await Hive.openBox('user_settings');
  await Hive.openBox('daily_exercise');
  await Hive.openBox('hydration_logs');
  await Hive.openBox('daily_hydration_summary');
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

int colorToArgb(Color c) =>
    ((c.a * 255).round() << 24) |
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lime),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class User {
  final String nombre;
  final String apellido;
  final String genero;
  final int edad;
  final double altura; // cm
  final double peso; // kg
  final String correo;
  final String contrasena; // simple local
  final String? brightness; // 'light' | 'dark'
  final int? seedColor; // ARGB int
  final String? fontFamily; // null | 'serif' u otras
  final bool? followLocation;
  const User({
    required this.nombre,
    required this.apellido,
    required this.genero,
    required this.edad,
    required this.altura,
    required this.peso,
    required this.correo,
    required this.contrasena,
    this.brightness,
    this.seedColor,
    this.fontFamily,
    this.followLocation,
  });
  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'apellido': apellido,
    'genero': genero,
    'edad': edad,
    'altura': altura,
    'peso': peso,
    'correo': correo,
    'contrasena': contrasena,
    'brightness': brightness,
    'seedColor': seedColor,
    'fontFamily': fontFamily,
    'followLocation': followLocation,
  };
  factory User.fromMap(Map map) {
    return User(
      nombre: '${map['nombre'] ?? ''}',
      apellido: '${map['apellido'] ?? ''}',
      genero: '${map['genero'] ?? ''}',
      edad: (map['edad'] is int)
          ? map['edad']
          : int.tryParse('${map['edad'] ?? 0}') ?? 0,
      altura: (map['altura'] is double)
          ? map['altura']
          : double.tryParse('${map['altura'] ?? 0}') ?? 0.0,
      peso: (map['peso'] is double)
          ? map['peso']
          : double.tryParse('${map['peso'] ?? 0}') ?? 0.0,
      correo: '${map['correo'] ?? ''}',
      contrasena: '${map['contrasena'] ?? ''}',
      brightness: map['brightness'] == null ? null : '${map['brightness']}',
      seedColor: (map['seedColor'] is int)
          ? map['seedColor']
          : int.tryParse('${map['seedColor'] ?? ''}'),
      fontFamily: map['fontFamily'] == null ? null : '${map['fontFamily']}',
      followLocation: map['followLocation'] == null
          ? null
          : (map['followLocation'] is bool
                ? map['followLocation']
                : '${map['followLocation']}' == 'true'),
    );
  }
}

Box get _usersBox => Hive.box('users');
Box get _userSettingsBox => Hive.box('user_settings');
Box get _dailyExerciseBox => Hive.box('daily_exercise');
Box get _hydrationLogsBox => Hive.box('hydration_logs');
Box get _hydrationSummaryBox => Hive.box('daily_hydration_summary');
String? getCurrentUserEmail() {
  final v = _usersBox.get('currentUserEmail');
  if (v is String && v.isNotEmpty) return v;
  return null;
}

User? getUserByEmail(String correo) {
  final raw = _usersBox.get('user:$correo');
  if (raw is Map) return User.fromMap(raw);
  return null;
}

User? getCurrentUser() {
  final email = getCurrentUserEmail();
  if (email == null) return null;
  return getUserByEmail(email);
}

Future<void> saveCurrentUser(User u) async {
  await _usersBox.put('user:${u.correo}', u.toMap());
  await _usersBox.put('currentUserEmail', u.correo);
}

bool verifyLogin(String correo, String contrasena) {
  final u = getUserByEmail(correo.trim().toLowerCase());
  if (u == null) return false;
  return u.contrasena == contrasena;
}

class UserSettings {
  final String userId;
  final String? brightness;
  final int? seedColor;
  final String? fontFamily;
  final bool? followLocation;
  final double? metaHydratationMl;
  const UserSettings({
    required this.userId,
    this.brightness,
    this.seedColor,
    this.fontFamily,
    this.followLocation,
    this.metaHydratationMl,
  });
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'brightness': brightness,
    'seedColor': seedColor,
    'fontFamily': fontFamily,
    'followLocation': followLocation,
    'metaHydratationMl': metaHydratationMl,
  };
  factory UserSettings.fromMap(Map map) => UserSettings(
    userId: '${map['userId'] ?? ''}',
    brightness: map['brightness'] == null ? null : '${map['brightness']}',
    seedColor: (map['seedColor'] is int)
        ? map['seedColor']
        : int.tryParse('${map['seedColor'] ?? ''}'),
    fontFamily: map['fontFamily'] == null ? null : '${map['fontFamily']}',
    followLocation: map['followLocation'] == null
        ? null
        : (map['followLocation'] is bool
              ? map['followLocation']
              : '${map['followLocation']}' == 'true'),
    metaHydratationMl: (map['metaHydratationMl'] is double)
        ? map['metaHydratationMl']
        : double.tryParse('${map['metaHydratationMl'] ?? ''}'),
  );
}

double computeDailyHydrationGoalMl(User u) {
  final base = (u.peso > 0 ? u.peso : 70.0) * 35.0;
  double adj = base;
  if (u.edad > 0 && u.edad < 14) adj = base * 0.9;
  if (u.edad >= 65) adj = base * 0.95;
  if (u.genero.toLowerCase() == 'masculino') adj += 200;
  return adj.clamp(1200.0, 4500.0);
}

UserSettings? getSettingsForUser(String userId) {
  final raw = _userSettingsBox.get('settings:$userId');
  if (raw is Map) return UserSettings.fromMap(raw);
  return null;
}

Future<void> saveSettings(UserSettings s) async {
  await _userSettingsBox.put('settings:${s.userId}', s.toMap());
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> addHydrationMl(String userId, double ml) async {
  final today = _dateKey(DateTime.now());
  final logKey = '${userId}_$today';
  final list = (_hydrationLogsBox.get(logKey) as List?)?.cast<Map>() ?? <Map>[];
  list.add({'ts': DateTime.now().millisecondsSinceEpoch, 'ml': ml});
  await _hydrationLogsBox.put(logKey, list);
  final u = getUserByEmail(userId);
  final settings =
      getSettingsForUser(userId) ??
      UserSettings(
        userId: userId,
        metaHydratationMl: computeDailyHydrationGoalMl(
          u ??
              User(
                nombre: '',
                apellido: '',
                genero: '',
                edad: 0,
                altura: 0,
                peso: 70,
                correo: userId,
                contrasena: '',
              ),
        ),
      );
  final summaryKey = '${userId}_$today';
  final raw = _hydrationSummaryBox.get(summaryKey);
  double total = 0.0;
  if (raw is Map) {
    total = (raw['total_ml'] is double)
        ? raw['total_ml']
        : double.tryParse('${raw['total_ml'] ?? 0}') ?? 0.0;
  }
  total += ml;
  final meta = settings.metaHydratationMl ?? computeDailyHydrationGoalMl(u!);
  final pct = ((total / meta) * 100).clamp(0, 100);
  await _hydrationSummaryBox.put(summaryKey, {
    'userId': userId,
    'date': today,
    'total_ml': total,
    'meta_ml': meta,
    'percentage': pct,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  });
}

String buildUserPromptPersonalization() {
  final u = getCurrentUser();
  if (u == null) return '';
  final g = u.genero.isEmpty ? 'No especificado' : u.genero;
  final edad = u.edad > 0 ? u.edad : 0;
  final altura = u.altura > 0 ? u.altura : 0;
  final peso = u.peso > 0 ? u.peso : 0;
  return '\nDatos del usuario: edad $edad años, peso ${peso.toStringAsFixed(peso % 1 == 0 ? 0 : 1)} kg, altura ${altura.toStringAsFixed(altura % 1 == 0 ? 0 : 1)} cm, género $g. Personaliza las recomendaciones considerando estas características.\n';
}

class _Receta {
  final String nombre;
  final String tiempo;
  final String dificultad;
  final String? imagenUrl;
  final String? imagenDesc;
  final String? porque;
  final List<_Ingrediente> ingredientes;
  final _Nutricion? nutricion;
  _Receta({
    required this.nombre,
    required this.tiempo,
    required this.dificultad,
    this.porque,
    required this.ingredientes,
    this.nutricion,
  }) : imagenUrl = null,
       imagenDesc = null;
}

class _Ingrediente {
  final String nombre;
  final String tienda;
  _Ingrediente(this.nombre, this.tienda);
}

class _Nutricion {
  final int kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasas;
  _Nutricion({
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
  });
}

class VidaPlusApp extends StatefulWidget {
  const VidaPlusApp({super.key});
  @override
  State<VidaPlusApp> createState() => _VidaPlusAppState();
}

class _VidaPlusAppState extends State<VidaPlusApp> {
  int _index = 0;
  Brightness _brightness = Brightness.light;
  Color _seedColor = const Color(0xFF80CBC4);
  String? _fontFamily;
  bool _followLocation = false;
  @override
  void initState() {
    super.initState();
    final u = getCurrentUser();
    if (u != null) {
      final s = getSettingsForUser(u.correo);
      if ('${s?.brightness}' == 'dark') {
        _brightness = Brightness.dark;
      } else if ('${s?.brightness}' == 'light') {
        _brightness = Brightness.light;
      }
      if (s?.seedColor is int) {
        _seedColor = Color(s!.seedColor!);
      }
      _fontFamily = s?.fontFamily;
      _followLocation = s?.followLocation ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : (Colors.grey[50] ?? Colors.white);
    final items = const [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center),
        label: 'Ejercicio',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.water_drop),
        label: 'Hidratación',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.bedtime), label: 'Sueño'),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
    ];
    final pages = [
      HomeScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      ExerciseScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      HydrationScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      SleepScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      SettingsScreen(
        brightness: _brightness,
        seed: _seedColor,
        fontFamily: _fontFamily,
        followLocation: _followLocation,
        asTab: true,
        onChanged: (data) {
          setState(() {
            _brightness = data.brightness;
            _seedColor = data.seed;
            _fontFamily = data.fontFamily;
            _followLocation = data.followLocation;
          });
        },
      ),
    ];
    return Scaffold(
      backgroundColor: background,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: _seedColor,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: items,
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const PressableScale({super.key, required this.child, required this.onTap});
  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const HomeScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _photo;
  bool _saving = false;
  // Gemini es autónomo: solo necesita internet, no BD ni servidor propio
  late GenerativeModel _geminiModel; // ¡Cambia la API key en initState!
  bool _analyzing = false;
  final List<File> _savedPhotos = [];
  String? _plato;
  int? _kcal;
  double? _prot;
  double? _carb;
  double? _fat;
  List<_Receta> _recetasRecomendadas = [];
  bool _cargandoRecetas = false;

  bool get _hasNutrients =>
      _prot != null &&
      _carb != null &&
      _fat != null &&
      (_prot! + _carb! + _fat!) > 0;

  @override
  void initState() {
    super.initState();

    // Clave API real – NUNCA la subas a GitHub. Usa .env o constante segura en producción.
    // Genera nueva en https://aistudio.google.com/app/apikey si esta falla.
    const apiKey = 'AIzaSyCEwgwToG9cfPvf2wzNHGOhSeXCLafD1ms';

    // Inicializa el modelo de Gemini
    _geminiModel = GenerativeModel(
      model: 'gemini-2.5-flash', // v1
      apiKey: apiKey,
    );

    // Verificación inicial de conectividad con Gemini (ping)
    Future.microtask(() async {
      try {
        debugPrint("Intentando ping con modelo: gemini-pro-vision");
        final ct = await _geminiModel.countTokens([Content.text('test')]);
        debugPrint("Respuesta ping: ${ct.totalTokens} tokens");
        debugPrint('Gemini ping OK: ${ct.totalTokens} tokens');
      } on GenerativeAIException catch (e, st) {
        debugPrint('Gemini ping failed: ${e.message}');
        debugPrint('Stack trace: $st');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Error de conexión con Gemini. Revisa internet o genera nueva clave en `https://aistudio.google.com/app/apikey`',
                ),
              ),
            );
          });
        }
      } on SocketException catch (e, st) {
        debugPrint('Sin internet (ping): $e');
        debugPrint('Stack trace: $st');
      } catch (e, st) {
        debugPrint('Ping error: $e');
        debugPrint('Stack trace: $st');
      }
    });
    Future.microtask(_cargarRecetasRecomendadas);
  }

  Future<void> _takePhoto() async {
    // Conservado por compatibilidad; abre selector de fuente
    await _selectImageSource();
  }

  Future<void> _pickFromSource(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (xfile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó imagen')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/vitu_food_$ts.jpg';
      final file = File(path);
      await file.writeAsBytes(await xfile.readAsBytes());
      setState(() {
        _photo = file;
        _savedPhotos.insert(0, file);
      });
      setState(() => _analyzing = true);
      await _analizarConGemini(file);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _analyzing = false;
        });
      }
    }
  }

  Future<void> _selectImageSource() async {
    if (_saving || _analyzing) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: (widget.brightness == Brightness.dark)
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: widget.seedColor),
                  title: const Text('Cámara'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickFromSource(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: widget.seedColor),
                  title: const Text('Galería'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickFromSource(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg, {bool error = false, VoidCallback? onRetry}) {
    final snack = SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
      action: onRetry != null
          ? SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  Future<void> _analizarConGemini(File foto) async {
    try {
      final length = await foto.length();
      debugPrint('Foto path: ${foto.path}');
      // Quitadas llaves innecesarias en la interpolación
      debugPrint('Foto size: $length bytes');
      debugPrint('Enviando foto: ${foto.path}, tamaño: $length bytes');
      if (length == 0) {
        _showSnack(
          'Imagen vacía o no legible',
          error: true,
          onRetry: () {
            if (_photo != null) _analizarConGemini(_photo!);
          },
        );
        return;
      }
      final prompt =
          '''
Analiza esta comida en la foto.
Identifica el plato principal aproximado.
Estima valores nutricionales aproximados.
Responde SOLO en este formato exacto, sin texto adicional:
Plato: [nombre aproximado]
Calorías: [número] kcal
Proteínas: [número] g
Carbohidratos: [número] g
Grasas: [número] g
${buildUserPromptPersonalization()}
''';
      final bytes = await foto.readAsBytes();
      final lower = foto.path.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final content = Content.multi([TextPart(prompt), DataPart(mime, bytes)]);
      // Nota: Si >2MB, considera comprimir con paquete "image" (opcional)
      final resp = await _geminiModel
          .generateContent([content])
          .timeout(const Duration(seconds: 20));
      final text = resp.text ?? '';
      debugPrint('Gemini raw response:\n$text');
      if (text.isEmpty) {
        if (mounted) {
          _showSnack(
            'Gemini no devolvió respuesta',
            error: true,
            onRetry: () {
              if (_photo != null) _analizarConGemini(_photo!);
            },
          );
        }
        return;
      }
      final platoRx = RegExp(
        r'^Plato:\s*(.+)$',
        multiLine: true,
        caseSensitive: false,
      );
      final kcalRx = RegExp(
        r'^Calor[ií]as:\s*(\d+)\s*kcal',
        multiLine: true,
        caseSensitive: false,
      );
      final protRx = RegExp(
        r'^Prote[ií]nas:\s*([\d\.]+)\s*g',
        multiLine: true,
        caseSensitive: false,
      );
      final carbRx = RegExp(
        r'^Carbohidratos:\s*([\d\.]+)\s*g',
        multiLine: true,
        caseSensitive: false,
      );
      final fatRx = RegExp(
        r'^Grasas:\s*([\d\.]+)\s*g',
        multiLine: true,
        caseSensitive: false,
      );

      final p = platoRx.firstMatch(text)?.group(1)?.trim();
      final kcal = int.tryParse(kcalRx.firstMatch(text)?.group(1) ?? '');
      final pr = double.tryParse(protRx.firstMatch(text)?.group(1) ?? '');
      final cb = double.tryParse(carbRx.firstMatch(text)?.group(1) ?? '');
      final gr = double.tryParse(fatRx.firstMatch(text)?.group(1) ?? '');

      if (p == null || kcal == null || pr == null || cb == null || gr == null) {
        if (mounted) {
          _showSnack(
            'No se pudo estimar nutrientes',
            error: true,
            onRetry: () {
              if (_photo != null) _analizarConGemini(_photo!);
            },
          );
        }
      }
      if (mounted) {
        setState(() {
          _plato = p ?? 'No se pudo detectar';
          _kcal = kcal ?? 0;
          _prot = pr ?? 0;
          _carb = cb ?? 0;
          _fat = gr ?? 0;
        });
      }
    } on GenerativeAIException catch (e) {
      if (mounted) {
        final msg = e.message;
        debugPrint('GenerativeAIException: $msg');
        final lm = msg.toLowerCase();
        final modelIssue =
            lm.contains('v1beta') ||
            lm.contains('not found') ||
            lm.contains('not supported') ||
            lm.contains('model');
        final text = modelIssue
            ? 'Modelo no disponible en esta versión – prueba actualizar paquete o usar gemini-pro-vision'
            : 'Error de IA: $msg';
        _showSnack(
          text,
          error: true,
          onRetry: () {
            if (_photo != null) _analizarConGemini(_photo!);
          },
        );
      }
    } on SocketException catch (e) {
      debugPrint('SocketException: $e');
      if (mounted) {
        _showSnack(
          'No hay internet',
          error: true,
          onRetry: () {
            if (_photo != null) _analizarConGemini(_photo!);
          },
        );
      }
    } on TimeoutException {
      debugPrint('TimeoutException durante generateContent');
      if (mounted) {
        _showSnack(
          'Tiempo de espera agotado',
          error: true,
          onRetry: () {
            if (_photo != null) _analizarConGemini(_photo!);
          },
        );
      }
    } catch (e, st) {
      debugPrint('Error inesperado: $e');
      debugPrint('$st');
      if (mounted) {
        _showSnack(
          'Error inesperado: $e',
          error: true,
          onRetry: () {
            if (_photo != null) _analizarConGemini(_photo!);
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : (Colors.grey[50] ?? Colors.white);
    final heading = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: isDark ? const Color(0xFFEDEDED) : const Color(0xFF111111),
      fontFamily: widget.fontFamily,
    );
    final body = TextStyle(
      fontSize: 16,
      color: isDark ? const Color(0xFFD0D0D0) : const Color(0xFF1F1F1F),
      fontFamily: widget.fontFamily,
    );
    final sub = TextStyle(
      fontSize: 14,
      color: isDark ? const Color(0xFFA0B0C0) : const Color(0xFF616161),
      fontFamily: widget.fontFamily,
    );
    final vspace = MediaQuery.of(context).size.height / 50;
    final appBarColor = isDark
        ? widget.seedColor.withAlpha(80)
        : widget.seedColor.withAlpha(120);
    BoxDecoration cardDeco() => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.seedColor.withAlpha(isDark ? 28 : 36),
          widget.seedColor.withAlpha(isDark ? 18 : 26),
          Colors.transparent,
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? const Color(0xFF424242) : const Color(0x11000000),
      ),
    );
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 2,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Nutrición'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: ListView(
          key: ValueKey(
            '${widget.brightness}_${widget.seedColor.toARGB32()}_${_photo?.path ?? ''}',
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              decoration: cardDeco(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analiza tu Comida Hoy', style: heading),
                  const SizedBox(height: 6),
                  Text('Toma una foto para registrar nutrientes', style: sub),
                  SizedBox(height: vspace),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            child: _photo != null
                                ? Image.file(_photo!, fit: BoxFit.cover)
                                : Center(
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 80,
                                      color: widget.seedColor,
                                    ),
                                  ),
                          ),
                        ),
                        if (_analyzing)
                          AnimatedOpacity(
                            opacity: _analyzing ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 3,
                                  sigmaY: 3,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.40),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: widget.seedColor,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Analizando imagen con IA...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            fontFamily: widget.fontFamily,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: vspace),
                  PressableScale(
                    onTap: (_saving || _analyzing) ? () {} : _takePhoto,
                    child: ElevatedButton.icon(
                      onPressed: (_saving || _analyzing) ? null : _takePhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.seedColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        _saving
                            ? 'Guardando...'
                            : (_analyzing ? 'Analizando...' : 'Tomar Foto'),
                      ),
                    ),
                  ),
                  if (_savedPhotos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Fotos guardadas',
                      style: body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _savedPhotos.length > 8
                          ? 8
                          : _savedPhotos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                      itemBuilder: (context, index) {
                        final f = _savedPhotos[index];
                        return GestureDetector(
                          onTap: () async {
                            if (_saving || _analyzing) return;
                            setState(() {
                              _photo = f;
                              _analyzing = true;
                            });
                            try {
                              await _analizarConGemini(f);
                            } finally {
                              if (mounted) {
                                setState(() => _analyzing = false);
                              }
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(f, fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: vspace),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _hasNutrients
                  ? Container(
                      key: const ValueKey('resumen'),
                      decoration: cardDeco(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_plato != null && _plato!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Plato detectado: ${_plato!}',
                                style: heading.copyWith(fontSize: 20),
                              ),
                            ),
                          Text('Resumen de Nutrientes', style: heading),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _nutriChip(
                                'Calorías',
                                _kcal != null ? '$_kcal kcal' : '0 kcal',
                                Icons.local_fire_department,
                                widget.seedColor,
                                body.copyWith(fontSize: 18),
                                sub,
                              ),
                              _nutriChip(
                                'Proteínas',
                                '${_prot?.toStringAsFixed(0) ?? '0'} g',
                                Icons.eco, // hoja verde
                                Colors.green,
                                body.copyWith(fontSize: 18),
                                sub,
                              ),
                              _nutriChip(
                                'Carbs',
                                '${_carb?.toStringAsFixed(0) ?? '0'} g',
                                Icons
                                    .dataset, // icono estilo pan/trigo alternativo
                                Colors.amber.shade700,
                                body.copyWith(fontSize: 18),
                                sub,
                              ),
                              _nutriChip(
                                'Grasas',
                                '${_fat?.toStringAsFixed(0) ?? '0'} g',
                                Icons.opacity,
                                Colors.redAccent,
                                body.copyWith(fontSize: 18),
                                sub,
                              ),
                            ],
                          ),
                          SizedBox(height: vspace),
                          SizedBox(
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 36,
                                    sections: _macroSections(widget.seedColor),
                                  ),
                                  swapAnimationDuration: const Duration(
                                    milliseconds: 800,
                                  ),
                                  swapAnimationCurve: Curves.easeOutCubic,
                                ),
                                Text(
                                  'Nutrientes',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFE0E0E0)
                                        : const Color(0xFF303030),
                                    fontWeight: FontWeight.w700,
                                    fontFamily: widget.fontFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      key: const ValueKey('placeholder'),
                      decoration: cardDeco(),
                      padding: const EdgeInsets.all(28),
                      child: SizedBox(
                        height: 220,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fastfood_rounded,
                                size: 52,
                                color:
                                    (isDark
                                            ? Colors.white70
                                            : Colors.grey.shade600)
                                        .withValues(alpha: 0.9),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Toma una foto para analizar nutrientes',
                                textAlign: TextAlign.center,
                                style: sub.copyWith(
                                  fontSize: 16,
                                  color: isDark
                                      ? const Color(0xFFB0B0B0)
                                      : const Color(0xFF6D6D6D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            SizedBox(height: vspace),
            Container(
              decoration: cardDeco(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recetas recomendadas',
                    style: heading.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 10),
                  if (_cargandoRecetas)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: widget.seedColor,
                          ),
                        ),
                      ),
                    )
                  else if (_recetasRecomendadas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No se pudieron generar recetas. Intenta de nuevo.',
                        style: sub,
                      ),
                    )
                  else
                    ..._recetasRecomendadas.map((r) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          color: (widget.brightness == Brightness.dark)
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 68,
                                        height: 68,
                                        child: r.imagenUrl != null
                                            ? Image.network(
                                                r.imagenUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) => Icon(
                                                  Icons.restaurant_rounded,
                                                  color: widget.seedColor,
                                                  size: 32,
                                                ),
                                              )
                                            : Center(
                                                child: Icon(
                                                  Icons.restaurant_rounded,
                                                  color: widget.seedColor,
                                                  size: 32,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.nombre,
                                            style: body.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.timer_outlined,
                                                color: widget.seedColor,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(r.tiempo, style: sub),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.stars_rounded,
                                                color: widget.seedColor,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(r.dificultad, style: sub),
                                            ],
                                          ),
                                          if (r.porque != null) ...[
                                            const SizedBox(height: 6),
                                            Text(r.porque!, style: sub),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _mostrarIngredientes(r),
                                        child: const Text('Ingredientes'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _mostrarPasos(r),
                                        child: const Text('Pasos'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: () => _mostrarNutricion(r),
                                        child: const Text(
                                          'Estimado Nutricional',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cargarRecetasRecomendadas() async {
    if (!mounted) return;
    setState(() => _cargandoRecetas = true);
    try {
      final u = getCurrentUser();
      final genero = u?.genero ?? 'no especificado';
      final edad = u?.edad ?? 0;
      final altura = u?.altura ?? 0.0;
      final peso = u?.peso ?? 0.0;
      final prompt =
          'Sugiere 3 recetas saludables y variadas para hoy en El Salvador, basadas en una dieta balanceada para un usuario de género '
          '$genero, $edad años, $altura cm y $peso kg. Para cada receta incluye: nombre, tiempo aproximado, dificultad, breve porqué es saludable, '
          'lista de ingredientes (solo nombres y cantidades, sin tiendas), y estimado nutricional aproximado (kcal, proteínas, carbohidratos, grasas). '
          'Responde SOLO en formato JSON array con claves: nombre, tiempo, dificultad, razonSaludable, ingredientes (array de strings), '
          'nutricional (objeto con kcal, proteinas, carbohidratos, grasas).';
      final res = await _geminiModel.generateContent([Content.text(prompt)]);
      final text = res.text?.trim() ?? '';
      final list = _parseRecetas(text);
      setState(() => _recetasRecomendadas = list);
    } catch (_) {
      setState(() => _recetasRecomendadas = []);
    } finally {
      if (mounted) setState(() => _cargandoRecetas = false);
    }
  }

  List<_Receta> _parseRecetas(String text) {
    final out = <_Receta>[];
    try {
      // Primero intenta decodificar JSON completo
      dynamic data;
      try {
        data = json.decode(text);
      } catch (_) {
        // Si no es JSON puro, intenta extraer el array JSON
        final start = text.indexOf('[');
        final end = text.lastIndexOf(']');
        if (start != -1 && end != -1 && end > start) {
          final jsonStr = text.substring(start, end + 1);
          data = json.decode(jsonStr);
        }
      }
      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final nombre = '${item['nombre'] ?? item['name'] ?? ''}'.trim();
            final tiempo = '${item['tiempo'] ?? item['time'] ?? ''}'.trim();
            final dif = '${item['dificultad'] ?? item['difficulty'] ?? ''}'
                .trim();
            final porque =
                '${item['razonSaludable'] ?? item['porque'] ?? item['salud'] ?? item['why'] ?? ''}'
                    .trim();
            if (nombre.isEmpty) continue;
            final ingredientesRaw = item['ingredientes'] ?? item['ingredients'];
            final ingredientes = <_Ingrediente>[];
            if (ingredientesRaw is List) {
              for (final it in ingredientesRaw) {
                var n = '$it'.trim();
                if (n.isEmpty) continue;
                n = n
                    .replaceAll(RegExp(r'^\{?\s*item\s*:\s*'), '')
                    .replaceAll(RegExp(r'^\{?\s*nombre\s*:\s*'), '')
                    .replaceAll(RegExp(r'^\{?\s*cantidad\s*:\s*'), '')
                    .replaceAll(RegExp(r'^\{'), '')
                    .replaceAll(RegExp(r'\}$'), '')
                    .replaceAll('"', '')
                    .trim();
                ingredientes.add(_Ingrediente(n, ''));
              }
            }
            _Nutricion? nutr;
            final nutRaw =
                item['nutricional'] ?? item['nutricion'] ?? item['nutrition'];
            if (nutRaw is Map) {
              nutr = _Nutricion(
                kcal: int.tryParse('${nutRaw['kcal'] ?? 0}') ?? 0,
                proteinas:
                    double.tryParse(
                      '${nutRaw['proteinas'] ?? nutRaw['protein'] ?? 0}',
                    ) ??
                    0.0,
                carbohidratos:
                    double.tryParse(
                      '${nutRaw['carbohidratos'] ?? nutRaw['carbs'] ?? 0}',
                    ) ??
                    0.0,
                grasas:
                    double.tryParse(
                      '${nutRaw['grasas'] ?? nutRaw['fat'] ?? 0}',
                    ) ??
                    0.0,
              );
            }
            out.add(
              _Receta(
                nombre: nombre,
                tiempo: tiempo.isEmpty ? '30 min' : tiempo,
                dificultad: dif.isEmpty ? 'Fácil' : dif,
                porque: porque.isEmpty ? null : porque,
                ingredientes: ingredientes,
                nutricion: nutr,
              ),
            );
          }
        }
      }
    } catch (_) {}
    return out;
  }

  // mock de recetas eliminado: se usa solo resultados reales o mensaje vacío

  // _sugerirTienda eliminado por no uso

  Future<void> _mostrarIngredientes(_Receta r) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ingredientes'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: r.ingredientes.isNotEmpty
                  ? r.ingredientes
                        .map(
                          (e) => ListTile(
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: widget.seedColor,
                            ),
                            title: Text(e.nombre),
                          ),
                        )
                        .toList()
                  : [
                      ListTile(
                        leading: Icon(
                          Icons.info_outline,
                          color: widget.seedColor,
                        ),
                        title: const Text('Sin ingredientes'),
                      ),
                    ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarPasos(_Receta r) async {
    final u = getCurrentUser();
    final genero = u?.genero ?? 'no especificado';
    final edad = u?.edad ?? 0;
    final prompt =
        "Genera los pasos detallados de la receta '${r.nombre}' para $genero, $edad años. Incluye 5-8 pasos claros y fáciles.";
    String contenido = '';
    bool loading = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.microtask(() async {
          try {
            final res = await _geminiModel.generateContent([
              Content.text(prompt),
            ]);
            final text = res.text?.trim() ?? '';
            final lines = text
                .split('\n')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList();
            contenido = lines.join('\n');
          } catch (_) {
            contenido = 'No se pudieron generar los pasos. Intenta de nuevo.';
          } finally {
            loading = false;
            // ignore: use_build_context_synchronously
            (context as Element).markNeedsBuild();
          }
        });
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('Pasos de la receta'),
              content: SizedBox(
                width: double.maxFinite,
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: widget.seedColor,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: contenido
                            .split('\n')
                            .map(
                              (l) => ListTile(
                                leading: Icon(
                                  Icons.checklist_rtl,
                                  color: widget.seedColor,
                                ),
                                title: Text(l),
                              ),
                            )
                            .toList(),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarNutricion(_Receta r) async {
    final n =
        r.nutricion ??
        _Nutricion(kcal: 400, proteinas: 25, carbohidratos: 40, grasas: 12);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Estimado nutricional'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.local_fire_department,
                  color: widget.seedColor,
                ),
                title: const Text('Calorías'),
                trailing: Text('${n.kcal} kcal'),
              ),
              ListTile(
                leading: Icon(Icons.bolt, color: Colors.green),
                title: const Text('Proteínas'),
                trailing: Text('${n.proteinas} g'),
              ),
              ListTile(
                leading: Icon(Icons.grain, color: Colors.blue),
                title: const Text('Carbohidratos'),
                trailing: Text('${n.carbohidratos} g'),
              ),
              ListTile(
                leading: Icon(Icons.water_drop, color: Colors.orange),
                title: const Text('Grasas'),
                trailing: Text('${n.grasas} g'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _nutriChip(
    String title,
    String value,
    IconData icon,
    Color color,
    TextStyle body,
    TextStyle sub,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(title, style: sub),
        Text(value, style: body.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  List<PieChartSectionData> _macroSections(Color seed) {
    // Usa resultados de IA; esta función solo se llama cuando hay datos
    final proteins = _prot ?? 0.0;
    final carbs = _carb ?? 0.0;
    final fats = _fat ?? 0.0;
    final total = proteins + carbs + fats;
    final safeTotal = total == 0 ? 1.0 : total;
    return [
      PieChartSectionData(
        value: proteins / safeTotal * 100,
        color: Colors.green,
        title: 'Proteínas',
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      PieChartSectionData(
        value: carbs / safeTotal * 100,
        color: Colors.amber.shade700,
        title: 'Carbs',
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      PieChartSectionData(
        value: fats / safeTotal * 100,
        color: Colors.redAccent,
        title: 'Grasas',
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }
}

// Reemplazado activity_recognition_flutter por geolocator + sensors_plus (AGP 8+)
enum ActivityKind { stationary, walking, running, vehicle, unknown }

class ExerciseScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const ExerciseScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });
  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with TickerProviderStateMixin {
  // Reemplazado: ya no usamos activity_recognition_flutter
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _posSub;
  Timer? _chartTimer;
  ActivityKind _currentKind = ActivityKind.unknown;
  bool _paused = false;
  int _dailySteps = 0;
  double _speedKmh = 0;
  String _lastDate = '';
  int _stepBuffer = 0;
  DateTime _lastStepTs = DateTime.now().subtract(const Duration(seconds: 2));
  final List<FlSpot> _cardioSpots = [];
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    _loadPersisted();
    _ensurePermissionAndStart();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _posSub?.cancel();
    _chartTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPersisted() async {
    final u = getCurrentUser();
    if (u == null) return;
    final todayStr = _dateKey(DateTime.now());
    final key = '${u.correo}_$todayStr';
    final raw = _dailyExerciseBox.get(key);
    if (raw is Map) {
      setState(() {
        _dailySteps = (raw['steps'] is int)
            ? raw['steps']
            : int.tryParse('${raw['steps'] ?? 0}') ?? 0;
        _lastDate = todayStr;
      });
    } else {
      await _dailyExerciseBox.put(key, {
        'userId': u.correo,
        'date': todayStr,
        'steps': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() {
        _dailySteps = 0;
        _lastDate = todayStr;
      });
    }
  }

  Future<void> _persistSteps() async {
    final u = getCurrentUser();
    if (u == null || _lastDate.isEmpty) return;
    final key = '${u.correo}_$_lastDate';
    await _dailyExerciseBox.put(key, {
      'userId': u.correo,
      'date': _lastDate,
      'steps': _dailySteps,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _appendLog(String type, int delta) async {
    final u = getCurrentUser();
    if (u == null) return;
    final list =
        (_dailyExerciseBox.get('exercise_logs:${u.correo}') as List?)
            ?.cast<Map>() ??
        <Map>[];
    list.add({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'type': type,
      'steps_delta': delta,
    });
    await _dailyExerciseBox.put('exercise_logs:${u.correo}', list);
  }

  Future<void> _ensurePermissionAndStart() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa el servicio de ubicación')),
      );
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permiso de ubicación'),
          content: const Text(
            'Habilita la ubicación en ajustes para registrar tu actividad.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
    _startStreams();
  }

  void _startStreams() {
    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((pos) {
          setState(() {
            _speedKmh = ((pos.speed.isNaN ? 0.0 : pos.speed.toDouble()) * 3.6);
            if (_speedKmh > 15.0) {
              _currentKind = ActivityKind.vehicle;
            } else if (_speedKmh < 1.0) {
              // Solo marcamos estacionario si no estamos sumando pasos activos
              if (_currentKind != ActivityKind.walking &&
                  _currentKind != ActivityKind.running) {
                _currentKind = ActivityKind.stationary;
              }
            }
          });
        });
    _accelSub = userAccelerometerEventStream().listen(_onAccel);
    _chartTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final t = _cardioSpots.isEmpty ? 0.0 : (_cardioSpots.last.x + 1.0);
      final y = _stepBuffer.toDouble();
      setState(() {
        _cardioSpots.add(FlSpot(t, y));
        if (_cardioSpots.length > 60) {
          _cardioSpots.removeAt(0);
        }
        _stepBuffer = 0;
      });
    });
  }

  void _onAccel(UserAccelerometerEvent e) {
    if (_paused) return;
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

    ActivityKind inferred = _currentKind;
    if (_speedKmh > 15.0) {
      inferred = ActivityKind.vehicle;
    } else if (_speedKmh < 0.5) {
      inferred = ActivityKind.stationary;
    } else if (_speedKmh < 6.0 && mag > 0.9) {
      inferred = ActivityKind.walking;
    } else if (_speedKmh < 12.0 && mag > 1.4) {
      inferred = ActivityKind.running;
    }

    if (inferred != _currentKind) {
      setState(() => _currentKind = inferred);
      _appendLog('activity:$inferred', 0);
    }

    if (_speedKmh >= 15.0) return; // no contamos en vehículo
    if (_currentKind != ActivityKind.walking &&
        _currentKind != ActivityKind.running) {
      return;
    }
    final threshold = _currentKind == ActivityKind.running ? 1.4 : 0.9;
    final now = DateTime.now();
    final debounceMs = _speedKmh < 2.0 ? 450 : 320;
    if (mag > threshold &&
        now.difference(_lastStepTs).inMilliseconds > debounceMs) {
      _lastStepTs = now;
      final next = _dailySteps + 1;
      final deltaBucket = _stepBuffer + 1;
      setState(() {
        _dailySteps = next;
        _stepBuffer = deltaBucket;
      });
      if (_dailySteps % 10 == 0) {
        _persistSteps();
        _appendLog('steps', 10);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : (Colors.grey[50] ?? Colors.white);
    final heading = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: isDark ? const Color(0xFFEDEDED) : const Color(0xFF111111),
      fontFamily: widget.fontFamily,
    );
    final body = TextStyle(
      fontSize: 16,
      color: isDark ? const Color(0xFFD0D0D0) : const Color(0xFF1F1F1F),
      fontFamily: widget.fontFamily,
    );
    final appBarColor = isDark
        ? widget.seedColor.withAlpha(80)
        : widget.seedColor.withAlpha(120);
    final vspace = MediaQuery.of(context).size.height / 50;
    BoxDecoration cardDeco() => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.seedColor.withAlpha(isDark ? 40 : 60),
          widget.seedColor.withAlpha(isDark ? 24 : 36),
          Colors.transparent,
        ],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: isDark ? const Color(0xFF424242) : const Color(0x11000000),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x55000000) : const Color(0x22000000),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
    );
    final goal = 10000;
    final progress = math.min(1.0, _dailySteps / goal.toDouble());
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 2,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Ejercicio'),
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: progress == 0 ? null : progress,
                          strokeWidth: 14,
                          color: widget.seedColor,
                          backgroundColor: isDark
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}% completado',
                            style: body.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    'Pasos hoy: $_dailySteps',
                    key: ValueKey(_dailySteps),
                    style: heading.copyWith(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _fadeCtrl,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _activityIcon(_currentKind),
                        color: _currentKind == ActivityKind.vehicle
                            ? Colors.grey
                            : widget.seedColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _activityLabel(_currentKind),
                          style: body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_speedKmh.toStringAsFixed(1)} km/h',
                        style: body.copyWith(
                          color: isDark
                              ? const Color(0xFFA0B0C0)
                              : const Color(0xFF616161),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _cardioExpandedSection(isDark, heading, body),
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actividad semanal',
                  style: heading.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 240,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _weeklyBarChart(widget.seedColor, isDark),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 1,
              childAspectRatio: 2.3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _routineTile(
                  widget.seedColor,
                  isDark,
                  body,
                  Icons.fitness_center,
                  'Fuerza',
                  onTap: () => _openRoutine('Fuerza'),
                ),
                _routineTile(
                  widget.seedColor,
                  isDark,
                  body,
                  Icons.self_improvement,
                  'Yoga',
                  onTap: () => _openRoutine('Yoga'),
                ),
                _routineTile(
                  widget.seedColor,
                  isDark,
                  body,
                  Icons.accessibility_new,
                  'Estiramientos',
                  onTap: () => _openRoutine('Estiramientos'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRoutine(String kind) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RoutineSuggestionScreen(
          kind: kind,
          brightness: widget.brightness,
          seedColor: widget.seedColor,
          fontFamily: widget.fontFamily,
        ),
      ),
    );
  }

  Widget _routineTile(
    Color seed,
    bool isDark,
    TextStyle body,
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: seed, size: 34),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: seed,
                  side: BorderSide(color: seed.withAlpha(180)),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 14),
                ),
                child: const FittedBox(child: Text('Empezar')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardioExpandedSection(
    bool isDark,
    TextStyle heading,
    TextStyle body,
  ) {
    final color = _currentKind == ActivityKind.vehicle
        ? Colors.grey
        : widget.seedColor;
    final pct = math.min(1.0, _dailySteps / 10000.0);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0x11000000),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 10,
                      color: color,
                      backgroundColor: isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFE0E0E0),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${(_dailySteps / 100).toStringAsFixed(0)}%',
                          style: heading.copyWith(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        '$_dailySteps pasos',
                        key: ValueKey(_dailySteps),
                        style: heading.copyWith(fontSize: 24),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(_activityIcon(_currentKind), color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _activityLabel(_currentKind),
                            style: body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_speedKmh.toStringAsFixed(1)} km/h • ${(_dailySteps * 0.04).toStringAsFixed(0)} kcal',
                      style: body.copyWith(
                        color: isDark
                            ? const Color(0xFFA0B0C0)
                            : const Color(0xFF616161),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PressableScale(
                onTap: () => setState(() => _paused = !_paused),
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _paused = !_paused),
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                  label: Text(_paused ? 'Reanudar' : 'Pausar'),
                  style: FilledButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    backgroundColor: color.withAlpha(40),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      getTitlesWidget: (v, _) {
                        return Transform.rotate(
                          angle: -0.6,
                          child: Text(
                            '${v.toInt() * 10}s',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? const Color(0xFFD0D0D0)
                                  : const Color(0xFF616161),
                            ),
                          ),
                        );
                      },
                      reservedSize: 26,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFFA0B0C0)
                              : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _cardioSpots.isEmpty
                        ? [const FlSpot(0, 0)]
                        : _cardioSpots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withAlpha(36),
                    ),
                  ),
                ],
                minY: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(ActivityKind k) {
    switch (k) {
      case ActivityKind.running:
        return Icons.directions_run;
      case ActivityKind.walking:
        return Icons.directions_walk;
      case ActivityKind.vehicle:
        return Icons.directions_car;
      case ActivityKind.stationary:
        return Icons.self_improvement;
      default:
        return Icons.sports_martial_arts;
    }
  }

  String _activityLabel(ActivityKind k) {
    switch (k) {
      case ActivityKind.running:
        return 'Corriendo';
      case ActivityKind.walking:
        return 'Caminando';
      case ActivityKind.vehicle:
        return 'En vehículo (no contando)';
      case ActivityKind.stationary:
        return 'Parado';
      default:
        return 'Actividad desconocida';
    }
  }

  Widget _weeklyBarChart(Color seed, bool isDark) {
    final bars = <BarChartGroupData>[];
    final u = getCurrentUser();
    final now = DateTime.now();
    final maxY = 12000.0;
    for (var i = 0; i < 7; i++) {
      double steps = 0.0;
      if (u != null) {
        final d = now.subtract(Duration(days: 6 - i));
        final key = '${u.correo}_${_dateKey(d)}';
        final raw = _dailyExerciseBox.get(key);
        if (raw is Map) {
          steps = (raw['steps'] is int)
              ? (raw['steps'] as int).toDouble()
              : double.tryParse('${raw['steps'] ?? 0}') ?? 0.0;
        }
      }
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: steps.clamp(0.0, maxY),
              color: seed,
              width: 16,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2000,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    days[v.toInt() % 7],
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFD0D0D0)
                          : const Color(0xFF616161),
                    ),
                  ),
                );
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                if (v % 4000 != 0) return const SizedBox.shrink();
                return Text(
                  '${v.toInt()}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFFA0B0C0)
                        : const Color(0xFF9E9E9E),
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: bars,
        minY: 0,
        maxY: maxY,
      ),
    );
  }
}

class _RoutineSuggestionScreen extends StatefulWidget {
  final String kind;
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const _RoutineSuggestionScreen({
    required this.kind,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });
  @override
  State<_RoutineSuggestionScreen> createState() =>
      _RoutineSuggestionScreenState();
}

class _RoutineSuggestionScreenState extends State<_RoutineSuggestionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, String>> _suggestions = [];
  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    // Usa misma clave y modelo que recetas
    const apiKey = 'AIzaSyCEwgwToG9cfPvf2wzNHGOhSeXCLafD1ms';
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    final u = getCurrentUser();
    final genero = u?.genero ?? 'no especificado';
    final edad = u?.edad ?? 0;
    final altura = u?.altura ?? 0.0;
    final peso = u?.peso ?? 0.0;
    final prompt =
        'Sugiere 4 sesiones de entrenamiento completas de ${widget.kind} personalizadas para un usuario de género $genero, $edad años, $altura cm y $peso kg. '
        'Para cada sesión incluye: nombre, duración aproximada, breve descripción, y lista de 3-5 ejercicios con nombre, series/reps/duración y pequeña descripción. '
        'Responde SOLO en formato JSON array.';
    try {
      debugPrint('Iniciando sugerencias para ${widget.kind}');
      debugPrint('Prompt enviado: $prompt');
      final res = await _model.generateContent([Content.text(prompt)]);
      debugPrint('Respuesta Gemini cruda: ${res.text ?? 'null'}');
      final text = res.text?.trim() ?? '';
      final parsed = _parseRoutineList(text);
      debugPrint('Parseado: ${parsed.length} ejercicios');
      setState(() {
        _suggestions = parsed;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('ERROR GEMINI DETALLADO: $e');
      debugPrint('Stack: $stack');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}\nRevisa consola.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, String>> _parseRoutineList(String text) {
    // Limpia posibles fences de markdown ```json ... ```
    String clean = text.trim();
    clean = clean.replaceAll('```json', '').replaceAll('```', '').trim();
    debugPrint('Texto limpio para parseo: $clean');
    // Intenta JSON primero (sobre texto limpio) con extracción de array si es necesario
    try {
      dynamic data;
      try {
        data = json.decode(clean);
      } catch (e) {
        debugPrint('Parseo JSON falló, texto crudo: $text');
        final start = clean.indexOf('[');
        final end = clean.lastIndexOf(']');
        if (start != -1 && end != -1 && end > start) {
          final jsonStr = clean.substring(start, end + 1);
          data = json.decode(jsonStr);
        }
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) {
              final nombre = '${item['nombre'] ?? item['name'] ?? ''}'.trim();
              if (nombre.isEmpty) return <String, String>{};
              final duracion = '${item['duracion'] ?? item['duration'] ?? ''}'
                  .trim();
              final desc = '${item['descripcion'] ?? item['description'] ?? ''}'
                  .trim();
              final ejerciciosRaw = item['ejercicios'] ?? item['exercises'];
              String ejercicios = '';
              String ejerciciosJson = '';
              if (ejerciciosRaw is List) {
                if (ejerciciosRaw.isNotEmpty && ejerciciosRaw.first is Map) {
                  final norm = <Map<String, String>>[];
                  for (final e in ejerciciosRaw) {
                    final m = Map<String, dynamic>.from(e as Map);
                    final enombre = '${m['nombre'] ?? m['name'] ?? ''}'.trim();
                    final edet =
                        '${m['seriesRepsDuracion'] ?? m['reps'] ?? m['series'] ?? m['detalle'] ?? ''}'
                            .trim();
                    final tiempo = '${m['duracion'] ?? m['duration'] ?? ''}'
                        .trim();
                    final edesc =
                        '${m['descripcion'] ?? m['description'] ?? ''}'.trim();
                    final out = <String, String>{};
                    if (enombre.isNotEmpty) out['nombre'] = enombre;
                    if (edet.isNotEmpty) out['detalle'] = edet;
                    if (tiempo.isNotEmpty) out['tiempo'] = tiempo;
                    if (edesc.isNotEmpty) out['descripcion'] = edesc;
                    if (out.isNotEmpty) norm.add(out);
                  }
                  ejerciciosJson = json.encode(norm);
                } else {
                  final lines = <String>[];
                  for (final e in ejerciciosRaw) {
                    final s = '$e'.trim();
                    if (s.isEmpty) continue;
                    lines.add(s);
                  }
                  ejercicios = lines.join('\n');
                }
              } else if (ejerciciosRaw is String) {
                ejercicios = ejerciciosRaw.trim();
              }
              return {
                'nombre': nombre,
                if (duracion.isNotEmpty) 'duracion': duracion,
                if (desc.isNotEmpty) 'descripcion': desc,
                if (ejercicios.isNotEmpty) 'ejercicios': ejercicios,
                if (ejerciciosJson.isNotEmpty) 'ejerciciosJson': ejerciciosJson,
              };
            })
            .where((m) => m.isNotEmpty)
            .cast<Map<String, String>>()
            .toList();
      }
    } catch (_) {
      // continúa con parseo manual
    }
    // Parseo manual básico
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final out = <Map<String, String>>[];
    Map<String, String> current = {};
    for (final l in lines) {
      final lower = l.toLowerCase();
      if (RegExp(r'^\d+[\)\.]').hasMatch(l) || lower.startsWith('- ')) {
        if (current.isNotEmpty) out.add(current);
        current = {};
        current['nombre'] = l
            .replaceFirst(RegExp(r'^\d+[\)\.\s-]*'), '')
            .trim();
      } else if (lower.startsWith('duracion') || lower.startsWith('duración')) {
        current['duracion'] = l
            .replaceFirst(
              RegExp(r'duraci[oó]n[:\s]*', caseSensitive: false),
              '',
            )
            .trim();
      } else if (lower.contains('descrip')) {
        current['descripcion'] = l;
      } else if (lower.startsWith('*') || lower.startsWith('-')) {
        final line = l.replaceFirst(RegExp(r'^[\*\-]\s*'), '').trim();
        final prev = current['ejercicios'] ?? '';
        current['ejercicios'] = prev.isEmpty ? line : '$prev\n$line';
      }
    }
    if (current.isNotEmpty) out.add(current);
    return out.where((m) => m.containsKey('nombre')).toList();
  }

  // Fallback eliminado: resultados 100% automáticos desde Gemini

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final body = TextStyle(
      fontSize: 16,
      color: isDark ? const Color(0xFFD0D0D0) : const Color(0xFF1F1F1F),
      fontFamily: widget.fontFamily,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Sugerencias: ${widget.kind}'),
        backgroundColor: isDark
            ? widget.seedColor.withAlpha(80)
            : widget.seedColor.withAlpha(120),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (isDark ? const Color(0xFF121212) : const Color(0xFFF7F7F7)),
              widget.seedColor.withAlpha(isDark ? 40 : 30),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text('Generando sugerencias...', style: body),
                  ],
                ),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!, style: body),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          _fetchSuggestions();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.seedColor.withAlpha(40),
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _suggestions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No se encontraron sugerencias. Intenta de nuevo.',
                        style: body,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          _fetchSuggestions();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.seedColor.withAlpha(40),
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, i) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final it = _suggestions[i];
                  final emoji = widget.kind.toLowerCase().contains('yoga')
                      ? '🧘'
                      : widget.kind.toLowerCase().contains('estira')
                      ? '🏋️'
                      : '💪';
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SessionDetailScreen(
                            session: it,
                            seedColor: widget.seedColor,
                            brightness: widget.brightness,
                            fontFamily: widget.fontFamily,
                          ),
                        ),
                      );
                    },
                    child: Material(
                      elevation: 2,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                              widget.seedColor.withAlpha(isDark ? 26 : 20),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it['nombre'] ?? 'Sesión',
                                        style:
                                            Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  color: isDark
                                                      ? const Color(0xFFD0D0D0)
                                                      : const Color(0xFF1F1F1F),
                                                  fontFamily: widget.fontFamily,
                                                ) ??
                                            body.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 20,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        it['duracion'] ?? '45 min',
                                        style: body.copyWith(
                                          color: isDark
                                              ? const Color(0xFFA0B0C0)
                                              : const Color(0xFF616161),
                                        ),
                                      ),
                                      if ((it['descripcion'] ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            it['descripcion']!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: body,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  final Map<String, String> session;
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const SessionDetailScreen({
    super.key,
    required this.session,
    required this.seedColor,
    required this.brightness,
    this.fontFamily,
  });
  List<Map<String, String>> _buildExercises() {
    final jsonStr = session['ejerciciosJson'] ?? '';
    if (jsonStr.isNotEmpty) {
      try {
        final data = json.decode(jsonStr);
        if (data is List) {
          return data.whereType<Map>().map((e) {
            final m = Map<String, dynamic>.from(e);
            final n = '${m['nombre'] ?? ''}'.trim();
            final d = '${m['detalle'] ?? ''}'.trim();
            final t = '${m['tiempo'] ?? ''}'.trim();
            final desc = '${m['descripcion'] ?? ''}'.trim();
            return {
              'nombre': n,
              'detalle': d,
              'tiempo': t,
              'descripcion': desc,
            };
          }).toList();
        }
      } catch (_) {}
    }
    final lines = (session['ejercicios'] ?? '')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return lines.map((l) {
      String name = l;
      String det = '';
      String t = '';
      String desc = '';
      if (l.contains(':')) {
        final idx = l.indexOf(':');
        name = l.substring(0, idx).trim();
        det = l.substring(idx + 1).trim();
      } else if (l.contains('-')) {
        final idx = l.indexOf('-');
        name = l.substring(0, idx).trim();
        det = l.substring(idx + 1).trim();
      }
      final p = RegExp(r'\(([^)]+)\)').firstMatch(l);
      if (p != null) desc = (p.group(1) ?? '').trim();
      if (det.isEmpty) {
        final r1 = RegExp(
          r'(\d+)\s*x\s*(\d+(?:-\d+)?)',
          caseSensitive: false,
        ).firstMatch(l);
        final r2 = RegExp(
          r'(\d+)\s*series?\s*(de)?\s*(\d+(?:-\d+)?)\s*reps?',
          caseSensitive: false,
        ).firstMatch(l);
        if (r1 != null) {
          det = '${r1.group(1)} series de ${r1.group(2)} reps';
        } else if (r2 != null) {
          det = '${r2.group(1)} series de ${r2.group(3)} reps';
        }
      }
      final m = RegExp(r'(\d+)\s*min', caseSensitive: false).firstMatch(l);
      if (m != null) t = '${m.group(1)} min';
      return {'nombre': name, 'detalle': det, 'tiempo': t, 'descripcion': desc};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final body = TextStyle(
      fontSize: 16,
      color: isDark ? const Color(0xFFD0D0D0) : const Color(0xFF1F1F1F),
      fontFamily: fontFamily,
    );
    final items = _buildExercises();
    return Scaffold(
      appBar: AppBar(
        title: Text(session['nombre'] ?? 'Sesión'),
        backgroundColor: isDark
            ? seedColor.withAlpha(80)
            : seedColor.withAlpha(120),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (isDark ? const Color(0xFF121212) : const Color(0xFFF7F7F7)),
              seedColor.withAlpha(isDark ? 40 : 30),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['nombre'] ?? 'Sesión',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: isDark
                              ? const Color(0xFFD0D0D0)
                              : const Color(0xFF1F1F1F),
                          fontFamily: fontFamily,
                        ) ??
                        body.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session['duracion'] ?? '45 min',
                    style: body.copyWith(
                      color: isDark
                          ? const Color(0xFFA0B0C0)
                          : const Color(0xFF616161),
                    ),
                  ),
                  if ((session['descripcion'] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        session['descripcion']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: body,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No se pudo cargar la sesión. Intenta de nuevo.',
                              style: body,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                              style: FilledButton.styleFrom(
                                backgroundColor: seedColor.withAlpha(40),
                                foregroundColor: isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (_, i) {
                        final ex = items[i];
                        return Material(
                          elevation: 2,
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  (isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white),
                                  seedColor.withAlpha(isDark ? 26 : 20),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex['nombre'] ?? 'Ejercicio',
                                  style: body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if ((ex['descripcion'] ?? '').isNotEmpty)
                                  Text(
                                    ex['descripcion']!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: body.copyWith(
                                      color: isDark
                                          ? const Color(0xFFA0B0C0)
                                          : const Color(0xFF616161),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                if ((ex['detalle'] ?? '').isNotEmpty)
                                  Text(
                                    'Series/Reps: ${ex['detalle']}',
                                    style: body,
                                  ),
                                if ((ex['tiempo'] ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Tiempo estimado: ${ex['tiempo']}',
                                      style: body.copyWith(
                                        color: isDark
                                            ? const Color(0xFFA0B0C0)
                                            : const Color(0xFF616161),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemCount: items.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class HydrationScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const HydrationScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });
  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  double _liters = 0.0;
  double _goal = 3.0;
  List<double> _weeklyPercent = List.filled(7, 0.0);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = getCurrentUser();
    if (u == null) return;
    final s = getSettingsForUser(u.correo);
    if (s?.metaHydratationMl != null) {
      _goal = (s!.metaHydratationMl! / 1000.0).clamp(1.0, 5.0);
    } else {
      _goal = computeDailyHydrationGoalMl(u) / 1000.0;
    }
    final today = _dateKey(DateTime.now());
    final summaryKey = '${u.correo}_$today';
    final raw = _hydrationSummaryBox.get(summaryKey);
    double total = 0.0;
    if (raw is Map) {
      total = (raw['total_ml'] is double)
          ? raw['total_ml']
          : double.tryParse('${raw['total_ml'] ?? 0}') ?? 0.0;
    }
    final weekly = <double>[];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${u.correo}_${_dateKey(d)}';
      final r = _hydrationSummaryBox.get(key);
      double t = 0.0;
      if (r is Map) {
        t = (r['total_ml'] is double)
            ? r['total_ml']
            : double.tryParse('${r['total_ml'] ?? 0}') ?? 0.0;
      }
      final p = ((t / (_goal * 1000.0)) * 100.0).clamp(0.0, 100.0);
      weekly.add(p);
    }
    setState(() {
      _liters = (total / 1000.0).clamp(0.0, 10.0);
      _weeklyPercent = weekly;
    });
  }

  Future<void> _save(double v) async {
    final u = getCurrentUser();
    if (u == null) return;
    final deltaMl = (v - _liters) * 1000.0;
    if (deltaMl > 0) {
      await addHydrationMl(u.correo, deltaMl);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : (Colors.grey[50] ?? Colors.white);
    final heading = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: isDark ? const Color(0xFFEDEDED) : const Color(0xFF111111),
      fontFamily: widget.fontFamily,
    );
    final body = TextStyle(
      fontSize: 16,
      color: isDark ? const Color(0xFFD0D0D0) : const Color(0xFF1F1F1F),
      fontFamily: widget.fontFamily,
    );
    final sub = TextStyle(
      fontSize: 14,
      color: isDark ? const Color(0xFFA0B0C0) : const Color(0xFF616161),
      fontFamily: widget.fontFamily,
    );
    final appBarColor = isDark
        ? widget.seedColor.withAlpha(80)
        : widget.seedColor.withAlpha(120);
    final vspace = MediaQuery.of(context).size.height / 50;
    BoxDecoration cardDeco() => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.seedColor.withAlpha(isDark ? 28 : 36),
          widget.seedColor.withAlpha(isDark ? 18 : 26),
          Colors.transparent,
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? const Color(0xFF424242) : const Color(0x11000000),
      ),
    );
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 2,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Hidratación'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _liters / _goal),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12,
                              color: widget.seedColor,
                              backgroundColor: isDark
                                  ? const Color(0xFF2C2C2C)
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${_liters.toStringAsFixed(1)} L',
                                style: heading.copyWith(fontSize: 24),
                              ),
                              Text(
                                'de ${_goal.toStringAsFixed(1)} L',
                                style: sub,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(height: vspace),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _addButton(0.1),
                    _addButton(0.25),
                    _addButton(0.5),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consumo semanal', style: heading.copyWith(fontSize: 20)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: _hydrationLineChartDynamic(widget.seedColor, isDark),
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.flag, color: widget.seedColor),
                  title: Text(
                    'Meta diaria: ${_goal.toStringAsFixed(1)} L',
                    style: body,
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.alarm, color: widget.seedColor),
                  title: Text('Recordatorio cada 2 h', style: body),
                  trailing: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Configurar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton(double amount) {
    return PressableScale(
      onTap: () async {
        final v = (_liters + amount).clamp(0.0, 10.0);
        setState(() => _liters = v);
        await _save(v);
      },
      child: ElevatedButton.icon(
        onPressed: () async {
          final v = (_liters + amount).clamp(0.0, 10.0);
          setState(() => _liters = v);
          await _save(v);
        },
        icon: const Icon(Icons.water_drop),
        label: Text('+${(amount * 1000).toInt()} ml'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _hydrationLineChartDynamic(Color seed, bool isDark) {
    final spots = <FlSpot>[];
    for (var i = 0; i < 7; i++) {
      spots.add(FlSpot(i.toDouble(), _weeklyPercent[i]));
    }
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    days[v.toInt() % 7],
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFD0D0D0)
                          : const Color(0xFF616161),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                if (v % 25 != 0) return const SizedBox.shrink();
                return Text(
                  '${v.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFFA0B0C0)
                        : const Color(0xFF9E9E9E),
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: seed,
            barWidth: 4,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: seed.withAlpha(40)),
          ),
        ],
        minY: 0,
        maxY: 100,
      ),
    );
  }
}

class SleepScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const SleepScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });
  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _screenEvents;
  DateTime? _screenOffStart;
  bool _monitoring = false;
  Map<String, dynamic>? _lastNight;
  List<Map<String, dynamic>> _recent = [];
  Timer? _cutoffTimer;
  Box get _sleepBox => Hive.box('daily_sleep');
  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : (Colors.grey[50] ?? Colors.white);
    final heading = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: isDark ? const Color(0xFFEDEDED) : const Color(0xFF111111),
      fontFamily: widget.fontFamily,
    );
    final body = TextStyle(
      fontSize: 16,
      color: isDark ? const Color(0xFFD0D0D0) : const Color(0xFF1F1F1F),
      fontFamily: widget.fontFamily,
    );
    final appBarColor = isDark
        ? widget.seedColor.withAlpha(80)
        : widget.seedColor.withAlpha(120);
    final vspace = MediaQuery.of(context).size.height / 50;
    BoxDecoration cardDeco() => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.seedColor.withAlpha(isDark ? 28 : 36),
          widget.seedColor.withAlpha(isDark ? 18 : 26),
          Colors.transparent,
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? const Color(0xFF424242) : const Color(0x11000000),
      ),
    );
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 2,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Sueño'),
        actions: [
          IconButton(
            onPressed: () async {
              final dormir = await showTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 23, minute: 0),
              );
              if (!context.mounted) return;
              if (dormir == null) return;
              final despertar = await showTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 7, minute: 0),
              );
              if (!context.mounted) return;
              if (despertar == null) return;
              final u = getCurrentUser();
              if (u == null) return;
              final date = _resolveSleepDateForNow();
              final start = _timeOfDayToDate(date, dormir);
              final end = _timeOfDayToDate(
                date.add(const Duration(days: 1)),
                despertar,
              );
              final durH = end.difference(start).inMinutes / 60.0;
              await _saveSleep(
                userId: u.correo,
                date: _fmtDate(date),
                start: start,
                end: end,
                durationH: durH,
                quality: _initialQualityForHours(durH),
              );
              await _reload();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: widget.seedColor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anoche: ${(_lastNight?['duration_h'] ?? 0.0).toStringAsFixed(1)} h',
                        style: heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (i) {
                          final q = (_lastNight?['quality'] ?? 0) as int;
                          return IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            onPressed: () async {
                              final u = getCurrentUser();
                              if (u == null || _lastNight == null) return;
                              await _updateQuality(
                                u.correo,
                                _lastNight!['date'] as String,
                                i + 1,
                              );
                              await _reload();
                            },
                            icon: Icon(
                              i < q ? Icons.star : Icons.star_border,
                              color: Colors.amber.shade600,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Horas por día', style: heading.copyWith(fontSize: 20)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: _sleepBarChartDynamic(widget.seedColor, isDark),
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: _recent
                  .map(
                    (e) => ListTile(
                      leading: Icon(Icons.nights_stay, color: widget.seedColor),
                      title: Text(
                        '${e['date']}: ${(e['duration_h'] as double).toStringAsFixed(1)} h',
                        style: body,
                      ),
                      subtitle: Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < (e['quality'] ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber.shade600,
                            size: 18,
                          );
                        }),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.mobile_off, color: widget.seedColor),
                  title: Text('Evita pantallas 1 h antes', style: body),
                ),
                ListTile(
                  leading: Icon(
                    Icons.self_improvement,
                    color: widget.seedColor,
                  ),
                  title: Text('Rutina relajante', style: body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initSleep();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _screenEvents?.cancel();
    _cutoffTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSleep() async {
    if (!Hive.isBoxOpen('daily_sleep')) {
      await Hive.openBox('daily_sleep');
    }
    await _reload();
    _startMonitoring();
    _scheduleCutoff();
  }

  Future<void> _reload() async {
    final u = getCurrentUser();
    if (u == null) return;
    final today = DateTime.now();
    final List<Map<String, dynamic>> list = [];
    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key = '${u.correo}_${_fmtDate(d)}';
      final raw = _sleepBox.get(key);
      if (raw is Map) {
        list.add(raw.cast<String, dynamic>());
      } else {
        list.add({
          'userId': u.correo,
          'date': _fmtDate(d),
          'duration_h': 0.0,
          'quality': 0,
        });
      }
    }
    _recent = list;
    _lastNight = list.isNotEmpty ? list.last : null;
    if (mounted) setState(() {});
  }

  void _startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void _scheduleCutoff() {
    _cutoffTimer?.cancel();
    final now = DateTime.now();
    final nextCutoff = _nextCutoff(now);
    final ms = nextCutoff.difference(now).inMilliseconds;
    _cutoffTimer = Timer(Duration(milliseconds: ms), () async {
      final start = _screenOffStart;
      _screenOffStart = null;
      if (start != null) {
        await _accumulateSleep(start, nextCutoff);
      }
      await _ensureTodayEntry();
      await _reload();
      _scheduleCutoff();
    });
  }

  Future<void> _ensureTodayEntry() async {
    final u = getCurrentUser();
    if (u == null) return;
    final date = _fmtDate(DateTime.now());
    final key = '${u.correo}_$date';
    if (_sleepBox.get(key) == null) {
      await _sleepBox.put(key, {
        'userId': u.correo,
        'date': date,
        'duration_h': 0.0,
        'quality': 0,
      });
    }
  }

  Future<void> _accumulateSleep(DateTime start, DateTime end) async {
    DateTime s = start;
    DateTime e = end;
    if (!_inWindow(s)) s = _clipToWindowStart(s);
    if (!_inWindow(e)) e = _clipToWindowEnd(e);
    final minutes = e.difference(s).inMinutes;
    if (minutes < 10) return;
    final u = getCurrentUser();
    if (u == null) return;
    final date = _fmtDate(_resolveSleepDateForNow(from: s));
    final key = '${u.correo}_$date';
    final raw = _sleepBox.get(key);
    double prev = 0.0;
    DateTime? firstStart;
    DateTime? lastEnd;
    int quality = 0;
    if (raw is Map) {
      prev = (raw['duration_h'] is double)
          ? raw['duration_h']
          : double.tryParse('${raw['duration_h'] ?? 0}') ?? 0.0;
      final ss = raw['hora_inicio'];
      final se = raw['hora_fin'];
      if (ss is String) firstStart = DateTime.tryParse(ss);
      if (se is String) lastEnd = DateTime.tryParse(se);
      quality = (raw['quality'] is int)
          ? raw['quality']
          : int.tryParse('${raw['quality'] ?? 0}') ?? 0;
    }
    final durH = prev + (minutes / 60.0);
    firstStart ??= s;
    lastEnd = e;
    await _sleepBox.put(key, {
      'userId': u.correo,
      'date': date,
      'hora_inicio': firstStart.toIso8601String(),
      'hora_fin': lastEnd.toIso8601String(),
      'duration_h': durH,
      'quality': quality == 0 ? _initialQualityForHours(durH) : quality,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _saveSleep({
    required String userId,
    required String date,
    required DateTime start,
    required DateTime end,
    required double durationH,
    required int quality,
  }) async {
    final key = '${userId}_$date';
    await _sleepBox.put(key, {
      'userId': userId,
      'date': date,
      'hora_inicio': start.toIso8601String(),
      'hora_fin': end.toIso8601String(),
      'duration_h': durationH,
      'quality': quality,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _updateQuality(String userId, String date, int q) async {
    final key = '${userId}_$date';
    final raw = _sleepBox.get(key);
    if (raw is Map) {
      raw['quality'] = q;
      await _sleepBox.put(key, raw);
    }
  }

  bool _inWindow(DateTime d) {
    final h = d.hour;
    return (h >= 19 && h <= 23) || (h >= 0 && h < 7);
  }

  DateTime _nextCutoff(DateTime now) {
    final tomorrow7 = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1)).add(const Duration(hours: 7));
    if (now.hour < 7) {
      return DateTime(now.year, now.month, now.day, 7);
    }
    return tomorrow7;
  }

  DateTime _clipToWindowStart(DateTime d) {
    if (d.hour < 7) {
      return DateTime(d.year, d.month, d.day, 0, 0);
    }
    return DateTime(d.year, d.month, d.day, 19, 0);
  }

  DateTime _clipToWindowEnd(DateTime d) {
    if (d.hour < 7) {
      return DateTime(d.year, d.month, d.day, 7, 0);
    }
    return DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  DateTime _resolveSleepDateForNow({DateTime? from}) {
    final now = from ?? DateTime.now();
    if (now.hour < 7) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final now = DateTime.now();
      if (_inWindow(now)) {
        _screenOffStart = now;
      }
    } else if (state == AppLifecycleState.resumed) {
      final start = _screenOffStart;
      _screenOffStart = null;
      final now = DateTime.now();
      if (start != null) {
        _accumulateSleep(start, now);
      }
    }
  }

  DateTime _timeOfDayToDate(DateTime date, TimeOfDay t) =>
      DateTime(date.year, date.month, date.day, t.hour, t.minute);

  int _initialQualityForHours(double h) {
    if (h < 6.0) return 2;
    if (h <= 8.0) return 4;
    return 5;
  }

  Widget _sleepBarChartDynamic(Color seed, bool isDark) {
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < 7; i++) {
      final v = i < _recent.length
          ? (_recent[i]['duration_h'] as double? ?? 0.0)
          : 0.0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              color: seed,
              width: 18,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                return Text(
                  days[v.toInt() % 7],
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFD0D0D0)
                        : const Color(0xFF616161),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: bars,
        maxY: 12,
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.8, end: 1.0));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        final hasUser = getCurrentUser() != null;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                hasUser ? const VidaPlusApp() : const LoginRegisterScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    Color lighten(Color c, double amount) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
          .toColor();
    }

    Color darken(Color c, double amount) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
          .toColor();
    }

    final seed = const Color(0xFFE53935);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 1.0],
                colors: isDark
                    ? [const Color(0xFF0F0F10), const Color(0xFF1B1B1D)]
                    : [lighten(seed, 0.22), darken(seed, 0.06)],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: const _LogoVidaSaludable(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});
  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF121212)
        : (Colors.grey[50] ?? Colors.white);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Acceso'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Iniciar sesión'),
            Tab(text: 'Registrarse'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_LoginForm(), _RegisterForm()],
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Correo inválido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      final ok = verifyLogin(
                        _emailCtrl.text.trim(),
                        _passCtrl.text,
                      );
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Correo o contraseña inválidos'),
                          ),
                        );
                        return;
                      }
                      if (!mounted) return;
                      final nav = Navigator.of(context);
                      await _usersBox.put(
                        'currentUserEmail',
                        _emailCtrl.text.trim(),
                      );
                      if (!mounted) return;
                      nav.pushReplacement(
                        MaterialPageRoute(builder: (_) => const VidaPlusApp()),
                      );
                    },
                    child: const Text('Iniciar Sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();
  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  String? _genero;
  final _edadCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController(); // cm
  final _pesoCtrl = TextEditingController(); // kg
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _edadCtrl.dispose();
    _alturaCtrl.dispose();
    _pesoCtrl.dispose();
    _correoCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa tu nombre'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Apellido',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa tu apellido'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _genero, // Corregido lint: deprecated value
                        decoration: const InputDecoration(
                          labelText: 'Género',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Masculino',
                            child: Text('Masculino'),
                          ),
                          DropdownMenuItem(
                            value: 'Femenino',
                            child: Text('Femenino'),
                          ),
                          DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                        ],
                        onChanged: (v) => setState(() => _genero = v),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Selecciona tu género'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _edadCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Edad',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            // Corregido lint: curly braces
                            return 'Ingresa tu edad';
                          }
                          final n = int.tryParse(v);
                          if (n == null || n <= 0) return 'Edad inválida';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _alturaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Altura (cm)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            // Corregido lint: curly braces
                            return 'Ingresa tu altura';
                          }
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Altura inválida';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pesoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Peso (kg)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            // Corregido lint: curly braces
                            return 'Ingresa tu peso';
                          }
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Peso inválido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _correoCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Correo inválido'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure1,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure1
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure1 = !_obscure1),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _pass2Ctrl,
                        obscureText: _obscure2,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure2
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure2 = !_obscure2),
                          ),
                        ),
                        validator: (v) => (v == null || v != _passCtrl.text)
                            ? 'No coinciden'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      final u = User(
                        nombre: _nombreCtrl.text.trim(),
                        apellido: _apellidoCtrl.text.trim(),
                        genero: _genero ?? '',
                        edad: int.tryParse(_edadCtrl.text.trim()) ?? 0,
                        altura: double.tryParse(_alturaCtrl.text.trim()) ?? 0.0,
                        peso: double.tryParse(_pesoCtrl.text.trim()) ?? 0.0,
                        correo: _correoCtrl.text.trim(),
                        contrasena: _passCtrl.text,
                      );
                      final nav = Navigator.of(
                        context,
                      ); // Corregido lint: use_build_method
                      await saveCurrentUser(u);
                      await saveSettings(
                        UserSettings(
                          userId: u.correo,
                          brightness: null,
                          seedColor: colorToArgb(const Color(0xFF80CBC4)),
                          fontFamily: null,
                          followLocation: false,
                          metaHydratationMl: computeDailyHydrationGoalMl(u),
                        ),
                      );
                      if (!mounted) return;
                      nav.pushReplacement(
                        MaterialPageRoute(builder: (_) => const VidaPlusApp()),
                      );
                    },
                    child: const Text('Registrarse'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PresentationScreen extends StatelessWidget {
  const PresentationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFCCFF90),
                  Color(0xFFAEEA00),
                  Color(0xFF7CB342),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF004D40).withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00332A,
                          ).withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(6, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LogoVidaSaludable(),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF004D40),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const HomeTabs(initialIndex: 0),
                                ),
                              );
                            },
                            child: const Text('Iniciar sesión'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const HomeTabs(initialIndex: 1),
                                ),
                              );
                            },
                            child: const Text('Registrarse gratis'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoVidaSaludable extends StatelessWidget {
  const _LogoVidaSaludable();
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                base.primary.withValues(alpha: 0.2),
                base.secondary.withValues(alpha: 0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/WhatsApp Image 2026-02-16 at 12.16.07 PM.jpeg',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.spa,
                  size: 64,
                  color: Color(0xFF689F38),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vitu',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }
}

class HomeTabs extends StatefulWidget {
  final int initialIndex;
  const HomeTabs({super.key, this.initialIndex = 0});
  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  late int index;
  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00C853),
                  Color(0xFF69F0AE),
                  Color(0xFFE8F5E9),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00C853).withValues(alpha: 0.18),
                    const Color(0xFF00C853).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -30,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF69F0AE).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 140,
            right: -50,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 160,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF00C853).withValues(alpha: 0.20),
                      const Color(0xFFE8F5E9).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF004D40).withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00332A,
                          ).withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(6, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: index == 0
                              ? Column(
                                  key: const ValueKey('login-with-logo'),
                                  children: [
                                    const _LogoVidaSaludable(),
                                    const SizedBox(height: 16),
                                    LoginTab(
                                      onGoRegister: () =>
                                          setState(() => index = 1),
                                    ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey('register-with-logo'),
                                  children: [
                                    const _LogoVidaSaludable(),
                                    const SizedBox(height: 16),
                                    RegisterTab(
                                      onGoLogin: () =>
                                          setState(() => index = 0),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginTab extends StatefulWidget {
  final VoidCallback onGoRegister;
  const LoginTab({super.key, required this.onGoRegister});
  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa un usuario'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Ingresa una contraseña'
                      : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const MagazineHomeScreen(),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Completa los campos')),
                        );
                      }
                    },
                    child: const Text('Iniciar Sesión'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: widget.onGoRegister,
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterTab extends StatefulWidget {
  final VoidCallback onGoLogin;
  const RegisterTab({super.key, required this.onGoLogin});
  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _firstLastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String? _gender;
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passRepeatCtrl = TextEditingController();
  int _step = 0;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _firstLastNameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passRepeatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Registro',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: base.primary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_step == 0) ...[
                  TextFormField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstLastNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu apellido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Edad',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa tu edad';
                            }
                            final n = int.tryParse(v);
                            if (n == null || n <= 0) {
                              return 'Edad inválida';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'Género',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Masculino',
                              child: Text('Masculino'),
                            ),
                            DropdownMenuItem(
                              value: 'Femenino',
                              child: Text('Femenino'),
                            ),
                            DropdownMenuItem(
                              value: 'Otro',
                              child: Text('Otro'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _gender = v),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Selecciona tu género'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Peso (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v);
                            if (n == null || n <= 0) return 'Peso inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Altura (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v);
                            if (n == null || n <= 0) return 'Altura inválida';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF004D40),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          setState(() => _step = 1);
                        }
                      },
                      child: const Text('Siguiente'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: widget.onGoLogin,
                    child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa un usuario'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Correo inválido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passRepeatCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Repetir contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v != _passCtrl.text)
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _step = 0),
                          child: const Text('Atrás'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF004D40),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const MagazineHomeScreen(),
                                ),
                              );
                            }
                          },
                          child: const Text('Registrarse'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MagazineHomeScreen extends StatefulWidget {
  const MagazineHomeScreen({super.key});
  @override
  State<MagazineHomeScreen> createState() => _MagazineHomeScreenState();
}

class _MagazineHomeScreenState extends State<MagazineHomeScreen>
    with SingleTickerProviderStateMixin {
  static const Color _yellow = Color(0xFFFFEB3B);
  static const Color _black = Color(0xFF111111);
  static const Color _white = Colors.white;
  late final TabController _tabs;
  int _bottomIndex = 0;
  final PageController _heroController = PageController();
  Color _seed = _yellow;
  Brightness _brightness = Brightness.light;
  String? _fontFamily;
  bool _followLocation = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                color: _yellow,
                child: Row(
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const HomeTabs(initialIndex: 0),
                              ),
                              (route) => false,
                            );
                          },
                          style: TextButton.styleFrom(foregroundColor: _black),
                          child: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: const [
                    ListTile(title: Text('QWERTY')),
                    ListTile(title: Text('ASDFG')),
                    ListTile(title: Text('ZXCVB')),
                    ListTile(title: Text('PLMKO')),
                    ListTile(title: Text('NJIUH')),
                    ListTile(title: Text('YTRSA')),
                    ListTile(title: Text('GHJKL')),
                    ListTile(title: Text('CVBNM')),
                    ListTile(title: Text('POIUY')),
                    ListTile(title: Text('LKJHG')),
                    ListTile(title: Text('MNBVC')),
                    Divider(),
                    ListTile(title: Text('TREWQ')),
                    ListTile(title: Text('DFGHJ')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _black,
        elevation: 0,
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Vitu',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        actions: const [SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: _black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _black,
              tabs: const [
                Tab(text: 'HOME'),
                Tab(text: 'CULTURE'),
                Tab(text: 'SCIENCE'),
                Tab(text: 'SOCIETY'),
                Tab(text: 'ECONOMY'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: List.generate(
          5,
          (i) => _HomeContent(controller: _heroController),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        onTap: (i) async {
          if (i == 4) {
            final result = await Navigator.of(context).push<SettingsData>(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  brightness: _brightness,
                  seed: _seed,
                  fontFamily: _fontFamily,
                  followLocation: _followLocation,
                ),
              ),
            );
            if (result != null) {
              setState(() {
                _brightness = result.brightness;
                _seed = result.seed;
                _fontFamily = result.fontFamily;
                _followLocation = result.followLocation;
              });
            }
          } else {
            setState(() => _bottomIndex = i);
          }
        },
        selectedItemColor: _seed,
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final PageController controller;
  const _HomeContent({required this.controller});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: controller,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: AssetImage(
                      'assets/WhatsApp Image 2026-02-16 at 12.16.07 PM.jpeg',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SOCIETY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Glued to your phone? Generation Z\'s smartphone addiction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class SettingsData {
  final Brightness brightness;
  final Color seed;
  final String? fontFamily;
  final bool followLocation;
  const SettingsData({
    required this.brightness,
    required this.seed,
    required this.fontFamily,
    required this.followLocation,
  });
}

class SettingsScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seed;
  final String? fontFamily;
  final bool followLocation;
  final void Function(SettingsData data)? onChanged;
  final bool asTab;
  const SettingsScreen({
    super.key,
    required this.brightness,
    required this.seed,
    required this.fontFamily,
    required this.followLocation,
    this.onChanged,
    this.asTab = false,
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Brightness _brightness;
  late Color _seed;
  String? _fontFamily;
  late bool _followLocation;
  final _alturaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  void _emit() {
    final cb = widget.onChanged;
    if (cb != null) {
      cb(
        SettingsData(
          brightness: _brightness,
          seed: _seed,
          fontFamily: _fontFamily,
          followLocation: _followLocation,
        ),
      );
    }
  }

  final _palette = <MapEntry<String, Color>>[
    const MapEntry('Amarillo', Color(0xFFFFECB3)),
    const MapEntry('Lima', Color(0xFFC5E1A5)),
    const MapEntry('Verde', Color(0xFFA5D6A7)),
    const MapEntry('Azul', Color(0xFF90CAF9)),
    const MapEntry('Rojo', Color(0xFFEF9A9A)),
    const MapEntry('Morado', Color(0xFFCE93D8)),
  ];

  @override
  void initState() {
    super.initState();
    _brightness = widget.brightness;
    _seed = widget.seed;
    _fontFamily = widget.fontFamily;
    _followLocation = widget.followLocation;
    final u = getCurrentUser();
    _alturaCtrl.text = u?.altura.toString() ?? '';
    _pesoCtrl.text = u?.peso.toString() ?? '';
  }

  @override
  void dispose() {
    _alturaCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final vspace = size.height / 50;
    final isDark = _brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121212)
        : (Colors.grey[50] ?? Colors.white);
    final bodyColor = isDark
        ? const Color(0xFFD0D0D0)
        : const Color(0xFF1F1F1F);
    final headingColor = isDark
        ? const Color(0xFFF0F0F0)
        : const Color(0xFF111111);
    final subColor = isDark ? const Color(0xFFA0B0C0) : const Color(0xFF616161);
    final sectionHeaderColor = isDark ? _seed.withAlpha(230) : _seed;
    final sectionTitleStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: sectionHeaderColor,
    );
    // Helpers de color (ajustes sutiles)
    Color lightenColor(Color c, double amount) {
      final h = HSLColor.fromColor(c);
      return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
    }

    Color darkenColor(Color c, double amount) {
      final h = HSLColor.fromColor(c);
      return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).toColor();
    }

    Color saturateColor(Color c, double amount) {
      final h = HSLColor.fromColor(c);
      return h
          .withSaturation((h.saturation + amount).clamp(0.0, 1.0))
          .toColor();
    }

    // Estilo de SegmentedButton sin MaterialStateProperty (APIs modernas)
    ButtonStyle segmentedStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        final selected = states.contains(WidgetState.selected);
        if (isDark) {
          return selected
              ? saturateColor(_seed, 0.1).withAlpha(200)
              : const Color(0xFF2C2C2C);
        }
        return selected
            ? saturateColor(_seed, 0.1).withAlpha(220)
            : (Colors.grey[100] ?? Colors.white);
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        final selected = states.contains(WidgetState.selected);
        return selected ? Colors.white : bodyColor;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide?>(
        (_) => BorderSide(
          color: isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
        ),
      ),
      shape: const WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );

    // Card con gradient sutil a 3 paradas
    BoxDecoration gradientCardDecoration() => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.55, 1.0],
        colors: [
          lightenColor(_seed, 0.12).withAlpha(isDark ? 22 : 28),
          saturateColor(_seed, 0.08).withAlpha(isDark ? 18 : 24),
          darkenColor(_seed, 0.08).withAlpha(isDark ? 14 : 20),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? const Color(0xFF424242) : const Color(0x11000000),
      ),
    );
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: isDark ? _seed.withAlpha(90) : _seed.withAlpha(180),
        elevation: 2,
        foregroundColor: Colors.white,
        title: const Text('Ajustes'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: ListView(
          key: ValueKey('${_brightness}_${colorToArgb(_seed)}'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('General', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: SwitchTheme(
                    data: SwitchThemeData(
                      thumbColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        final selected = states.contains(WidgetState.selected);
                        if (selected) {
                          return saturateColor(
                            _seed,
                            0.1,
                          ).withAlpha(isDark ? 220 : 230);
                        }
                        return isDark ? const Color(0xFF757575) : Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith<Color?>(
                        (_) =>
                            isDark ? const Color(0xFF333333) : Colors.black12,
                      ),
                      trackOutlineColor:
                          WidgetStateProperty.resolveWith<Color?>(
                            (_) => isDark
                                ? const Color(0xFF424242)
                                : const Color(0xFFE0E0E0),
                          ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.language,
                            color: isDark ? _seed.withAlpha(230) : _seed,
                          ),
                          title: Text(
                            'Idioma',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: headingColor,
                            ),
                          ),
                          subtitle: Text(
                            'Selecciona tu idioma preferido',
                            style: TextStyle(fontSize: 14, color: subColor),
                          ),
                          trailing: DropdownButton<String>(
                            value: 'Español',
                            items: const [
                              DropdownMenuItem(
                                value: 'Español',
                                child: Text('Español'),
                              ),
                              DropdownMenuItem(
                                value: 'English',
                                child: Text('English'),
                              ),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            Row(
              children: [
                Icon(Icons.palette, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Apariencia', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo tema',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<Brightness>(
                        segments: const [
                          ButtonSegment(
                            value: Brightness.light,
                            label: Text('Claro'),
                            icon: Icon(Icons.wb_sunny_rounded),
                          ),
                          ButtonSegment(
                            value: Brightness.dark,
                            label: Text('Oscuro'),
                            icon: Icon(Icons.nightlight_round),
                          ),
                        ],
                        selected: {_brightness},
                        onSelectionChanged: (s) {
                          setState(() => _brightness = s.first);
                          final u = getCurrentUser();
                          if (u != null) {
                            final prev = getSettingsForUser(u.correo);
                            final sdata = UserSettings(
                              userId: u.correo,
                              brightness: _brightness == Brightness.dark
                                  ? 'dark'
                                  : 'light',
                              seedColor: prev?.seedColor ?? colorToArgb(_seed),
                              fontFamily: prev?.fontFamily,
                              followLocation:
                                  prev?.followLocation ?? _followLocation,
                              metaHydratationMl:
                                  prev?.metaHydratationMl ??
                                  computeDailyHydrationGoalMl(u),
                            );
                            saveSettings(sdata);
                          }
                          _emit();
                        },
                        style: segmentedStyle,
                      ),
                      SizedBox(height: vspace),
                      Text(
                        'Paleta de colores',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          width: size.width > 600 ? 120 : 100,
                          height: size.width > 600 ? 120 : 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              stops: const [0.0, 0.6, 1.0],
                              colors: [
                                lightenColor(_seed, 0.12),
                                _seed,
                                darkenColor(_seed, 0.08),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: saturateColor(
                                  _seed,
                                  0.1,
                                ).withAlpha(isDark ? 120 : 100),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cross = constraints.maxWidth > 600 ? 4 : 3;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  childAspectRatio: 1,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                ),
                            itemCount: _palette.length,
                            itemBuilder: (context, index) {
                              final e = _palette[index];
                              final selected = _seed == e.value;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        setState(() => _seed = e.value);
                                        final u = getCurrentUser();
                                        if (u != null) {
                                          final prev = getSettingsForUser(
                                            u.correo,
                                          );
                                          final sdata = UserSettings(
                                            userId: u.correo,
                                            brightness: prev?.brightness,
                                            seedColor: colorToArgb(_seed),
                                            fontFamily:
                                                prev?.fontFamily ?? _fontFamily,
                                            followLocation:
                                                prev?.followLocation ??
                                                _followLocation,
                                            metaHydratationMl:
                                                prev?.metaHydratationMl ??
                                                computeDailyHydrationGoalMl(u),
                                          );
                                          saveSettings(sdata);
                                        }
                                        _emit();
                                      },
                                      child: AnimatedScale(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        scale: selected ? 1.08 : 1.0,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 280,
                                          ),
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: e.value,
                                            boxShadow: selected
                                                ? [
                                                    BoxShadow(
                                                      color: saturateColor(
                                                        _seed,
                                                        0.1,
                                                      ).withAlpha(120),
                                                      blurRadius: 14,
                                                      spreadRadius: 1,
                                                    ),
                                                  ]
                                                : [],
                                            border: Border.all(
                                              color: selected
                                                  ? saturateColor(
                                                      _seed,
                                                      0.1,
                                                    ).withAlpha(220)
                                                  : Colors.transparent,
                                              width: selected ? 2 : 0,
                                            ),
                                          ),
                                          child: selected
                                              ? Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 26,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black54,
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: bodyColor,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            Row(
              children: [
                Icon(Icons.badge, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Datos personales', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _alturaCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Altura (cm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _pesoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Peso (kg)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _seed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final a = double.tryParse(_alturaCtrl.text.trim());
                            final p = double.tryParse(_pesoCtrl.text.trim());
                            if (a == null || a <= 0 || p == null || p <= 0) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Valores inválidos'),
                                ),
                              );
                              return;
                            }
                            final u = getCurrentUser();
                            if (u != null) {
                              final updated = User(
                                nombre: u.nombre,
                                apellido: u.apellido,
                                genero: u.genero,
                                edad: u.edad,
                                altura: a,
                                peso: p,
                                correo: u.correo,
                                contrasena: u.contrasena,
                              );
                              await saveCurrentUser(updated);
                              final prev = getSettingsForUser(u.correo);
                              final goal = computeDailyHydrationGoalMl(updated);
                              await saveSettings(
                                UserSettings(
                                  userId: u.correo,
                                  brightness: prev?.brightness,
                                  seedColor:
                                      prev?.seedColor ?? colorToArgb(_seed),
                                  fontFamily: prev?.fontFamily ?? _fontFamily,
                                  followLocation:
                                      prev?.followLocation ?? _followLocation,
                                  metaHydratationMl: goal,
                                ),
                              );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Datos actualizados'),
                                ),
                              );
                            }
                          },
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            Row(
              children: [
                Icon(Icons.security, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Seguridad', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.lock_outline,
                          color: isDark ? subColor : _seed,
                          size: 26,
                        ),
                        title: Text(
                          'Cambiar contraseña',
                          style: TextStyle(color: bodyColor),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final currentCtrl = TextEditingController();
                          final newCtrl = TextEditingController();
                          final confirmCtrl = TextEditingController();
                          final res = await showDialog<bool>(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                backgroundColor: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : null,
                                title: const Text('Cambiar contraseña'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: currentCtrl,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Ingresa contraseña actual',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: newCtrl,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Nueva contraseña',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: confirmCtrl,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Confirmar',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Guardar'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (res == true) {
                            final u = getCurrentUser();
                            if (u == null) return;
                            if (currentCtrl.text != u.contrasena) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Contraseña actual incorrecta'),
                                ),
                              );
                              return;
                            }
                            if (newCtrl.text.isEmpty ||
                                newCtrl.text.length < 6 ||
                                newCtrl.text != confirmCtrl.text) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Nueva/confirmación inválida'),
                                ),
                              );
                              return;
                            }
                            final updated = User(
                              nombre: u.nombre,
                              apellido: u.apellido,
                              genero: u.genero,
                              edad: u.edad,
                              altura: u.altura,
                              peso: u.peso,
                              correo: u.correo,
                              contrasena: newCtrl.text,
                            );
                            await saveCurrentUser(updated);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Contraseña actualizada'),
                              ),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 26,
                        ),
                        title: const Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        onTap: () async {
                          final nav = Navigator.of(context);
                          await _usersBox.delete('currentUserEmail');
                          if (!mounted) return;
                          nav.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginRegisterScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            Row(
              children: [
                Icon(Icons.security, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Privacidad y seguridad', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: SwitchTheme(
                    data: SwitchThemeData(
                      thumbColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        final selected = states.contains(WidgetState.selected);
                        if (selected) {
                          return saturateColor(
                            _seed,
                            0.1,
                          ).withAlpha(isDark ? 220 : 230);
                        }
                        return isDark ? const Color(0xFF757575) : Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith<Color?>(
                        (_) =>
                            isDark ? const Color(0xFF333333) : Colors.black12,
                      ),
                      trackOutlineColor:
                          WidgetStateProperty.resolveWith<Color?>(
                            (_) => isDark
                                ? const Color(0xFF424242)
                                : const Color(0xFFE0E0E0),
                          ),
                    ),
                    child: Column(
                      children: [
                        Tooltip(
                          message: 'Activa geolocalización',
                          child: SwitchListTile(
                            title: Text(
                              'Seguir ubicación',
                              style: TextStyle(color: bodyColor),
                            ),
                            subtitle: Text(
                              'Permite acceso a GPS para funciones locales',
                              style: TextStyle(fontSize: 14, color: subColor),
                            ),
                            value: _followLocation,
                            onChanged: (v) {
                              setState(() => _followLocation = v);
                              final u = getCurrentUser();
                              if (u != null) {
                                final prev = getSettingsForUser(u.correo);
                                saveSettings(
                                  UserSettings(
                                    userId: u.correo,
                                    brightness: prev?.brightness,
                                    seedColor:
                                        prev?.seedColor ?? colorToArgb(_seed),
                                    fontFamily: prev?.fontFamily ?? _fontFamily,
                                    followLocation: v,
                                    metaHydratationMl:
                                        prev?.metaHydratationMl ??
                                        computeDailyHydrationGoalMl(u),
                                  ),
                                );
                              }
                              _emit();
                            },
                          ),
                        ),
                        Tooltip(
                          message: 'Ayúdanos a mejorar con datos anónimos',
                          child: SwitchListTile(
                            title: Text(
                              'Compartir datos anónimos',
                              style: TextStyle(color: bodyColor),
                            ),
                            value: false,
                            onChanged: (_) {},
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.shield_moon_outlined,
                            color: isDark ? subColor : _seed,
                            size: 26,
                          ),
                          title: Text(
                            'Gestionar permisos',
                            style: TextStyle(color: bodyColor),
                          ),
                          subtitle: Text(
                            'Cámara, micrófono, etc.',
                            style: TextStyle(fontSize: 14, color: subColor),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            Row(
              children: [
                Icon(Icons.notifications, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Notificaciones', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: SwitchTheme(
                    data: SwitchThemeData(
                      thumbColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        final selected = states.contains(WidgetState.selected);
                        if (selected) {
                          return saturateColor(
                            _seed,
                            0.1,
                          ).withAlpha(isDark ? 220 : 230);
                        }
                        return isDark ? const Color(0xFF757575) : Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith<Color?>(
                        (_) =>
                            isDark ? const Color(0xFF333333) : Colors.black12,
                      ),
                      trackOutlineColor:
                          WidgetStateProperty.resolveWith<Color?>(
                            (_) => isDark
                                ? const Color(0xFF424242)
                                : const Color(0xFFE0E0E0),
                          ),
                    ),
                    child: Column(
                      children: [
                        Tooltip(
                          message: 'Permite notificaciones push',
                          child: SwitchListTile(
                            title: Text(
                              'Activar push',
                              style: TextStyle(color: bodyColor),
                            ),
                            value: true,
                            onChanged: (_) {},
                          ),
                        ),
                        Tooltip(
                          message: 'Recibe avisos diarios',
                          child: SwitchListTile(
                            title: Text(
                              'Recordatorios diarios',
                              style: TextStyle(color: bodyColor),
                            ),
                            value: false,
                            onChanged: (_) {},
                          ),
                        ),
                        Tooltip(
                          message: 'Alertas basadas en tu ubicación',
                          child: SwitchListTile(
                            title: Text(
                              'Alertas de salud',
                              style: TextStyle(color: bodyColor),
                            ),
                            subtitle: Text(
                              'Personalizadas por ubicación',
                              style: TextStyle(fontSize: 14, color: subColor),
                            ),
                            value: true,
                            onChanged: (_) {},
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.schedule,
                            color: isDark ? subColor : _seed,
                          ),
                          title: Text(
                            'Frecuencia de notificaciones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: headingColor,
                            ),
                          ),
                          subtitle: Slider(
                            value: 50,
                            min: 0,
                            max: 100,
                            divisions: 5,
                            label: '50',
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            Row(
              children: [
                Icon(Icons.text_fields, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Tipografía y accesibilidad', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fuente',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'system',
                            label: Text('Sistema'),
                            icon: Icon(Icons.phone_android),
                          ),
                          ButtonSegment(
                            value: 'custom',
                            label: Text('Personalizada'),
                            icon: Icon(Icons.text_fields),
                          ),
                        ],
                        selected: {_fontFamily == null ? 'system' : 'custom'},
                        onSelectionChanged: (s) {
                          final choice = s.first;
                          setState(
                            () => _fontFamily = choice == 'system'
                                ? null
                                : 'serif',
                          );
                          final u = getCurrentUser();
                          if (u != null) {
                            final prev = getSettingsForUser(u.correo);
                            saveSettings(
                              UserSettings(
                                userId: u.correo,
                                brightness: prev?.brightness,
                                seedColor:
                                    prev?.seedColor ?? colorToArgb(_seed),
                                fontFamily: _fontFamily,
                                followLocation:
                                    prev?.followLocation ?? _followLocation,
                                metaHydratationMl:
                                    prev?.metaHydratationMl ??
                                    computeDailyHydrationGoalMl(u),
                              ),
                            );
                          }
                          _emit();
                        },
                        style: segmentedStyle,
                      ),
                      SizedBox(height: vspace),
                      Text(
                        'Tamaño de texto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: 'Ajusta el tamaño del texto',
                        child: Slider(
                          value: 1.0,
                          min: 0.8,
                          max: 1.5,
                          divisions: 5,
                          label: '1.0x',
                          onChanged: (_) {},
                        ),
                      ),
                      SwitchTheme(
                        data: SwitchThemeData(
                          thumbColor: WidgetStateProperty.resolveWith<Color?>((
                            states,
                          ) {
                            final selected = states.contains(
                              WidgetState.selected,
                            );
                            if (selected) {
                              return saturateColor(
                                _seed,
                                0.1,
                              ).withAlpha(isDark ? 220 : 230);
                            }
                            return isDark
                                ? const Color(0xFF757575)
                                : Colors.white;
                          }),
                          trackColor: WidgetStateProperty.resolveWith<Color?>(
                            (_) => isDark
                                ? const Color(0xFF333333)
                                : Colors.black12,
                          ),
                          trackOutlineColor:
                              WidgetStateProperty.resolveWith<Color?>(
                                (_) => isDark
                                    ? const Color(0xFF424242)
                                    : const Color(0xFFE0E0E0),
                              ),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Modo alto contraste',
                            style: TextStyle(color: bodyColor),
                          ),
                          value: isDark,
                          onChanged: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            Row(
              children: [
                Icon(Icons.info_outline, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Acerca de', style: sectionTitleStyle),
              ],
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: gradientCardDecoration(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.info,
                          color: isDark ? subColor : _seed,
                          size: 26,
                        ),
                        title: Text(
                          'Versión: 1.2.0',
                          style: TextStyle(color: bodyColor),
                        ),
                        subtitle: Text(
                          'Última actualización: 2024',
                          style: TextStyle(fontSize: 14, color: subColor),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.privacy_tip_outlined,
                          color: isDark ? subColor : _seed,
                          size: 26,
                        ),
                        title: Text(
                          'Política de privacidad',
                          style: TextStyle(color: bodyColor),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.article_outlined,
                          color: isDark ? subColor : _seed,
                          size: 26,
                        ),
                        title: Text(
                          'Términos de uso',
                          style: TextStyle(color: bodyColor),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.mail_outline,
                          color: isDark ? subColor : _seed,
                          size: 26,
                        ),
                        title: Text(
                          'Contacto: support@vidasaludable.com',
                          style: TextStyle(color: bodyColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: vspace),
            widget.asTab
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? bodyColor : subColor,
                            side: BorderSide(
                              color: isDark
                                  ? _seed.withAlpha(120)
                                  : _seed.withAlpha(160),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.close),
                              SizedBox(width: 8),
                              Text('Cancelar'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _seed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(
                              SettingsData(
                                brightness: _brightness,
                                seed: _seed,
                                fontFamily: _fontFamily,
                                followLocation: _followLocation,
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check),
                              SizedBox(width: 8),
                              Text('Guardar'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
