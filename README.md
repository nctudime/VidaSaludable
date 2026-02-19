# Vida Saludable

Aplicación Flutter de demostración con pantallas de bienvenida, inicio de sesión, registro y una vista principal tipo revista con pestañas, navegación inferior y ajustes de tema. Pensada para explicar a alguien sin experiencia cómo está hecha y cómo usarla.

## Resumen
- Nombre: Vida Saludable
- Propósito: Mostrar un flujo completo básico de una app (splash → presentación → login/registro → contenido principal → ajustes).
- Estado: Demo local sin backend; los formularios validan datos pero no guardan información.
- Código principal: [main.dart](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart)

## Tecnologías
- Lenguaje: Dart (SDK especificado en `pubspec.yaml`: `^3.10.8`)
- Framework: Flutter (Material Design 3)
- Plugins: 
  - `flutter_lints` para buenas prácticas
  - `flutter_launcher_icons` para generar íconos de la app
- Recursos: una imagen en `assets/` usada como logo y en el carrusel

## Características Clave
- Pantalla de splash con animaciones de escala y desvanecimiento
- Pantalla de presentación con acceso a “Iniciar sesión” y “Registrarse gratis”
- Inicio de sesión con validaciones de usuario/contraseña y alternar visibilidad de contraseña
- Registro en dos pasos con validaciones (nombre, apellido, edad, género, correo, contraseñas, peso/altura opcional)
- Pantalla principal tipo revista con:
  - AppBar con branding “VIDA PLUS”
  - TabBar con 5 secciones (HOME, CULTURE, SCIENCE, SOCIETY, ECONOMY)
  - Carrusel de portada (PageView) con imagen de assets y overlay
  - Drawer con opción “Cerrar sesión”
  - BottomNavigationBar con 5 ítems (Home, Saved, Alerts, Chat, Settings)
- Ajustes de tema: brillo (claro/oscuro), paleta semilla, familia tipográfica y switch “Seguir ubicación”

## Cómo Está Hecha (flujo y componentes)
- Arranque de la app: [MyApp](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L10-L25) define `MaterialApp`, tema Material 3 y `home` como `SplashScreen`. Se activa modo UI inmersivo con `SystemChrome`.
- Splash: [SplashScreen](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L27-L96) usa `AnimationController` con transiciones hacia `PresentationScreen`.
- Presentación: [PresentationScreen](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L98-L198) muestra logo y dos botones que navegan a `HomeTabs` con índice inicial (0 login, 1 registro).
- Contenedor login/registro: [HomeTabs](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L258-L413) alterna entre `LoginTab` y `RegisterTab` con `AnimatedSwitcher`.
- Login: [LoginTab](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L415-L513) valida campos y navega a la pantalla principal (`MagazineHomeScreen`).
- Registro: [RegisterTab](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L515-L792) flujo en dos pasos; al completar, navega a `MagazineHomeScreen`.
- Pantalla principal: [MagazineHomeScreen](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L794-L1003) gestiona `TabController`, `Drawer` y `BottomNavigationBar`. El contenido por pestaña se renderiza con [_HomeContent](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L1006-L1077).
- Ajustes: [SettingsScreen](file:///c:/Users/javie/Documents/GitHub/VidaSaludable/flutter_application_1/lib/main.dart#L1092-L1224) retorna un `SettingsData` que actualiza brillo, color semilla, fuente y ubicación en la pantalla principal.

## Estructura de Proyecto (simplificada)
- `lib/main.dart`: toda la lógica de vistas, navegación y estado local de la demo
- `assets/`: imagen usada como logo y portada del carrusel
- `pubspec.yaml`: dependencias, assets y config de `flutter_launcher_icons`
- Plataformas soportadas en el repo: `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`

## Requisitos Previos
- Tener Flutter instalado y en PATH (canal estable)
- Android SDK/iOS tooling opcional según plataforma destino

## Cómo Ejecutar
1. Instalar dependencias:
   ```bash
   flutter pub get
   ```
2. Ejecutar en dispositivo/emulador:
   ```bash
   flutter run
   ```
3. Ejecutar pruebas:
   ```bash
   flutter test
   ```

## Ícono de la App
- Configuración en `pubspec.yaml` bajo `flutter_launcher_icons`
- Comando típico para generar íconos (requiere assets configurados):
  ```bash
  dart run flutter_launcher_icons
  ```

## Notas Importantes
- No hay almacenamiento ni backend: todo es navegación y validaciones locales
- Los datos ingresados en login/registro no se guardan ni se envían
- El carrusel usa la imagen de `assets/` y un overlay con gradiente
- El cambio de tema/brillo/fuente se mantiene mientras la pantalla está abierta

## Próximos Pasos (sugerencias)
- Integrar backend para autenticación y perfil
- Persistir ajustes y preferencias del usuario
- Cargar contenido real en pestañas (API/BD)
- Añadir tests específicos para cada formulario y flujo de navegación
