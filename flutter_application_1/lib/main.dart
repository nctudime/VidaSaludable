import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      title: 'Vida Saludable',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lime),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
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
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PresentationScreen()),
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
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
              'assets/Gemini_Generated_Image_x2zl3xx2zl3xx2zl.png',
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
        Text(
          'Vida saludable',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
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
        title: Row(
          children: [
            const SizedBox(width: 8),
            const Text(
              'VIDA',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _seed,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'PLUS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
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
                      'assets/Gemini_Generated_Image_x2zl3xx2zl3xx2zl.png',
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
  const SettingsScreen({
    super.key,
    required this.brightness,
    required this.seed,
    required this.fontFamily,
    required this.followLocation,
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Brightness _brightness;
  late Color _seed;
  String? _fontFamily;
  late bool _followLocation;

  final _palette = <MapEntry<String, Color>>[
    const MapEntry('Amarillo', Color(0xFFFFEB3B)),
    const MapEntry('Lima', Color(0xFFCDDC39)),
    const MapEntry('Verde', Color(0xFF4CAF50)),
    const MapEntry('Azul', Color(0xFF2196F3)),
    const MapEntry('Rojo', Color(0xFFF44336)),
    const MapEntry('Morado', Color(0xFF9C27B0)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tema', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButton<Brightness>(
            value: _brightness,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: Brightness.light, child: Text('Claro')),
              DropdownMenuItem(value: Brightness.dark, child: Text('Oscuro')),
            ],
            onChanged: (b) =>
                setState(() => _brightness = b ?? Brightness.light),
          ),
          const SizedBox(height: 16),
          const Text(
            'Paleta de colores',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _palette.map((e) {
              final selected = _seed == e.value;
              return ChoiceChip(
                label: Text(e.key),
                selected: selected,
                onSelected: (_) => setState(() => _seed = e.value),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Fuente', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButton<String?>(
            value: _fontFamily,
            isExpanded: true,
            hint: const Text('Sistema (por defecto)'),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('Sistema')),
              DropdownMenuItem<String?>(value: 'serif', child: Text('Serif')),
              DropdownMenuItem<String?>(
                value: 'monospace',
                child: Text('Monospace'),
              ),
            ],
            onChanged: (v) => setState(() => _fontFamily = v),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Seguir ubicación'),
            value: _followLocation,
            onChanged: (v) => setState(() => _followLocation = v),
            subtitle: const Text('Permitir que la app use tu ubicación'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
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
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
