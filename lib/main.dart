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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
// Reemplazado activity_recognition_flutter por geolocator + sensors_plus (AGP 8+)
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

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
  String? _plato;
  int? _kcal;
  double? _prot;
  double? _carb;
  double? _fat;

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
    const apiKey = 'AIzaSyD8IL51lskViMD7NxcHYGnNvOChFMJfSVg';

    // Inicializa el modelo de Gemini
    _geminiModel = GenerativeModel(
      model: 'gemini-1.5-flash', // v1
      apiKey: apiKey,
    );

    // Verificación inicial de conectividad con Gemini (ping)
    Future.microtask(() async {
      try {
        final ct = await _geminiModel.countTokens([Content.text('test')]);
        debugPrint('Gemini ping OK: ${ct.totalTokens} tokens');
      } on GenerativeAIException catch (e, st) {
        debugPrint('Gemini ping failed: ${e.message}');
        debugPrint('Stack trace: $st');
        // Fallback para errores de modelo/versión (v1beta o modelo no encontrado)
        final msg = e.message.toLowerCase(); // Quitado '??' innecesario
        final looksLikeV1Beta =
            msg.contains('v1beta') ||
            msg.contains('not found') ||
            msg.contains('not supported') ||
            msg.contains('model');
        if (looksLikeV1Beta) {
          try {
            // Intento 1: usar alias latest de flash
            _geminiModel = GenerativeModel(
              model: 'gemini-1.5-flash-latest',
              apiKey: apiKey,
            );
            final ct2 = await _geminiModel.countTokens([Content.text('test')]);
            debugPrint(
              'Fallback gemini-1.5-flash-latest OK: ${ct2.totalTokens} tokens',
            );
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'API antigua detectada: usando gemini-1.5-flash-latest',
                    ),
                  ),
                );
              });
            }
          } on Exception catch (e2, st2) {
            debugPrint('Fallback flash-latest falló: $e2');
            debugPrint('Stack trace: $st2');
            try {
              // Intento 2: gemini-pro (texto)
              _geminiModel = GenerativeModel(
                model: 'gemini-pro',
                apiKey: apiKey,
              );
              final ct3 = await _geminiModel.countTokens([
                Content.text('test'),
              ]);
              debugPrint('Fallback gemini-pro OK: ${ct3.totalTokens} tokens');
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'API antigua detectada: usando gemini-pro como fallback',
                      ),
                    ),
                  );
                });
              }
            } on Exception catch (e3, st3) {
              debugPrint('Fallback gemini-pro falló: $e3');
              debugPrint('Stack trace: $st3');
              if (mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'API versión antigua detectada – actualiza paquete o clave',
                      ),
                    ),
                  );
                });
              }
            }
          }
        }
      } on SocketException catch (e, st) {
        debugPrint('Sin internet (ping): $e');
        debugPrint('Stack trace: $st');
      } catch (e, st) {
        debugPrint('Ping error: $e');
        debugPrint('Stack trace: $st');
      }
    });
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (xfile == null) return;
    setState(() => _saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/comida_$ts.jpg';
      final file = File(path);
      await file.writeAsBytes(await xfile.readAsBytes());
      setState(() => _photo = file);
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
      const prompt = '''
Analiza esta comida en la foto.
Identifica el plato principal aproximado.
Estima valores nutricionales aproximados.
Responde SOLO en este formato exacto, sin texto adicional:
Plato: [nombre aproximado]
Calorías: [número] kcal
Proteínas: [número] g
Carbohidratos: [número] g
Grasas: [número] g
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
        _showSnack(
          'Error de IA: $msg',
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
                            : (_analyzing
                                  ? 'Analizando...'
                                  : 'Analizar con IA'),
                      ),
                    ),
                  ),
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
                  Text('Tips útiles', style: heading.copyWith(fontSize: 20)),
                  const SizedBox(height: 6),
                  _tipTile(
                    isDark,
                    widget.seedColor,
                    body,
                    sub,
                    Icons.water_drop,
                    'Bebe agua después de comer',
                  ),
                  _tipTile(
                    isDark,
                    widget.seedColor,
                    body,
                    sub,
                    Icons.balance,
                    'Equilibra tu plato',
                  ),
                  _tipTile(
                    isDark,
                    widget.seedColor,
                    body,
                    sub,
                    Icons.local_florist,
                    'Prefiere alimentos frescos',
                  ),
                  _tipTile(
                    isDark,
                    widget.seedColor,
                    body,
                    sub,
                    Icons.timer,
                    'Come sin prisa y mastica bien',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipTile(
    bool isDark,
    Color seed,
    TextStyle body,
    TextStyle sub,
    IconData icon,
    String text,
  ) {
    return ListTile(
      leading: Icon(icon, color: seed),
      title: Text(text, style: body),
      trailing: const Icon(Icons.chevron_right),
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
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
  bool _cardioExpanded = false;
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
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final savedDate = prefs.getString('last_date') ?? todayStr;
    if (savedDate != todayStr) {
      await prefs.setInt('daily_steps', 0);
      await prefs.setString('last_date', todayStr);
      setState(() {
        _dailySteps = 0;
        _lastDate = todayStr;
      });
    } else {
      setState(() {
        _dailySteps = prefs.getInt('daily_steps') ?? 0;
        _lastDate = savedDate;
      });
    }
  }

  Future<void> _persistSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_steps', _dailySteps);
    if (_lastDate.isNotEmpty) {
      await prefs.setString('last_date', _lastDate);
    }
  }

  Future<void> _appendLog(String type, int delta) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('activity_logs') ?? <String>[];
    final entry = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'steps_delta': delta,
    });
    raw.add(entry);
    await prefs.setStringList('activity_logs', raw);
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
    } else if (_speedKmh < 1.0) {
      inferred = ActivityKind.stationary;
    } else if (_speedKmh < 6.0 && mag > 1.2) {
      inferred = ActivityKind.walking;
    } else if (_speedKmh < 12.0 && mag > 1.6) {
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
    final threshold = _currentKind == ActivityKind.running ? 1.6 : 1.2;
    final now = DateTime.now();
    if (mag > threshold && now.difference(_lastStepTs).inMilliseconds > 350) {
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
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: progress == 0 ? null : progress,
                          strokeWidth: 12,
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
                              fontSize: 16,
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
                    style: heading.copyWith(fontSize: 20),
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
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: MediaQuery.of(context).size.width > 700
                      ? 4
                      : 2,
                  childAspectRatio: 1.2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _routineTile(
                      widget.seedColor,
                      isDark,
                      body,
                      Icons.directions_run,
                      'Cardio',
                      onTap: _toggleCardio,
                    ),
                    _routineTile(
                      widget.seedColor,
                      isDark,
                      body,
                      Icons.fitness_center,
                      'Fuerza',
                    ),
                    _routineTile(
                      widget.seedColor,
                      isDark,
                      body,
                      Icons.self_improvement,
                      'Yoga',
                    ),
                    _routineTile(
                      widget.seedColor,
                      isDark,
                      body,
                      Icons.accessibility_new,
                      'Estiramientos',
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _cardioExpandedSection(isDark, heading, body),
                  crossFadeState: _cardioExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
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
                  height: 220,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _weeklyBarChart(widget.seedColor, isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCardio() {
    setState(() => _cardioExpanded = !_cardioExpanded);
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
                      getTitlesWidget: (v, m) {
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
    final values = [500.0, 420.0, 650.0, 720.0, 390.0, 810.0, 560.0];
    for (var i = 0; i < 7; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
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
          horizontalInterval: 200,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
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
                if (v % 400 != 0) return const SizedBox.shrink();
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
        maxY: 1000,
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
  double _liters = 1.8;
  final double _goal = 3.0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _liters = prefs.getDouble('hydration_liters') ?? 1.8;
    });
  }

  Future<void> _save(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hydration_liters', v);
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
                  child: _hydrationLineChart(widget.seedColor, isDark),
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
                  title: Text('Meta diaria: 2.5–3 L', style: body),
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

  Widget _hydrationLineChart(Color seed, bool isDark) {
    final spots = <FlSpot>[
      const FlSpot(0, 1.8),
      const FlSpot(1, 2.2),
      const FlSpot(2, 1.5),
      const FlSpot(3, 2.8),
      const FlSpot(4, 2.0),
      const FlSpot(5, 3.0),
      const FlSpot(6, 2.5),
    ];
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
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
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
        maxY: 3.5,
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

class _SleepScreenState extends State<SleepScreen> {
  final double _hours = 7.5;
  int _rating = 4;
  final List<Map<String, String>> _log = [
    {
      'fecha': 'Hoy',
      'dormir': '23:30',
      'despertar': '07:00',
      'calidad': 'Buena',
    },
    {
      'fecha': 'Ayer',
      'dormir': '00:10',
      'despertar': '07:30',
      'calidad': 'Buena',
    },
    {
      'fecha': 'Domingo',
      'dormir': '23:50',
      'despertar': '07:10',
      'calidad': 'Media',
    },
  ];
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
              String fmt(TimeOfDay t) =>
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              final dormirTxt = fmt(dormir);
              final despertarTxt = fmt(despertar);
              setState(() {
                _log.add({
                  'fecha': 'Nuevo',
                  'dormir': dormirTxt,
                  'despertar': despertarTxt,
                  'calidad': 'Buena',
                });
              });
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
                        'Anoche: ${_hours.toStringAsFixed(1)} h',
                        style: heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (i) {
                          return IconButton(
                            padding: EdgeInsets.zero,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            onPressed: () => setState(() => _rating = i + 1),
                            icon: Icon(
                              i < _rating ? Icons.star : Icons.star_border,
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
                  child: _sleepBarChart(widget.seedColor, isDark),
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          Container(
            decoration: cardDeco(),
            padding: const EdgeInsets.all(8),
            child: Column(
              children: _log
                  .map(
                    (e) => ListTile(
                      leading: Icon(Icons.nights_stay, color: widget.seedColor),
                      title: Text(
                        '${e['fecha']}: ${e['dormir']} – ${e['despertar']}',
                        style: body,
                      ),
                      subtitle: Text('Calidad: ${e['calidad']}', style: sub),
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

  Widget _sleepBarChart(Color seed, bool isDark) {
    final bars = <BarChartGroupData>[];
    final values = [7.5, 6.0, 8.0, 7.0, 7.8, 8.2, 7.0];
    for (var i = 0; i < 7; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
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
        maxY: 9,
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VidaPlusApp()),
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
          key: ValueKey('${_brightness}_${_seed.toARGB32()}'),
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
                        Tooltip(
                          message: 'Usa la app sin conexión',
                          child: SwitchListTile(
                            title: Text(
                              'Modo offline',
                              style: TextStyle(color: bodyColor),
                            ),
                            subtitle: Text(
                              'Usar datos locales cuando no haya conexión',
                              style: TextStyle(fontSize: 14, color: subColor),
                            ),
                            value: false,
                            onChanged: (_) {},
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.volume_up,
                            color: isDark ? _seed.withAlpha(230) : _seed,
                          ),
                          title: Text(
                            'Volumen de notificaciones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: headingColor,
                            ),
                          ),
                          subtitle: Tooltip(
                            message: 'Ajusta el volumen de avisos',
                            child: Slider(
                              value: 0.5,
                              onChanged: (_) {},
                              min: 0,
                              max: 1,
                              divisions: 5,
                              label: '50%',
                            ),
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
                Icon(Icons.person, color: sectionHeaderColor),
                const SizedBox(width: 8),
                Text('Cuenta', style: sectionTitleStyle),
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
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: saturateColor(
                            _seed,
                            0.1,
                          ).withAlpha(isDark ? 200 : 220),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          'Nombre: Javier',
                          style: TextStyle(color: bodyColor),
                        ),
                        subtitle: Text(
                          'Editar perfil',
                          style: TextStyle(fontSize: 14, color: subColor),
                        ),
                        trailing: const Icon(Icons.edit, size: 22),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.email_outlined,
                          color: isDark ? subColor : _seed,
                          size: 26,
                        ),
                        title: Text(
                          'Correo: ejemplo@vidasaludable.com',
                          style: TextStyle(color: bodyColor),
                        ),
                        trailing: const Icon(Icons.email, size: 22),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.lock_outline,
                          color: isDark ? subColor : _seed,
                          size: 26,
                        ),
                        title: Text(
                          'Cambiar contraseña',
                          style: TextStyle(color: subColor),
                        ),
                        trailing: const Icon(Icons.lock, size: 22),
                        onTap: () {},
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
                        onTap: () {},
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
