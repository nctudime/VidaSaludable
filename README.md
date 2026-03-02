# Vitu

Aplicación Flutter para bienestar integral que ayuda a llevar un estilo de vida saludable con cuatro pilares: alimentación (análisis de comida con IA), ejercicio (pasos y actividad), hidratación (registro por día) y sueño (detección automática). Toda la app está contenida en un único archivo de código fuente: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart).

> Nota: Vitu funciona 100% local con Hive (NoSQL) para almacenamiento y usa Google Generative AI (Gemini) para análisis de imágenes y sugerencias de recetas. No se modifica ningún archivo de código en esta documentación.

## Tabla de contenido
- Descripción general
- Características
- Tecnologías
- Instalación y ejecución
- Estructura del proyecto
- Detalle por secciones (flujo y funciones)
- Base de datos (Hive)
- Integración con Gemini
- Agregar nuevas funcionalidades
- Capturas de pantalla
- Seguridad y buenas prácticas
- Roadmap

## Descripción general
- Objetivo: Dar al usuario una experiencia unificada para registrar y analizar hábitos saludables (comida, actividad, agua y sueño), con ajustes de apariencia y datos personales.
- Arquitectura: Single-file app en Flutter (main.dart) con UI Material 3, persistencia local en Hive, y módulos de sensores/ubicación para actividad.
- Plataformas: Android, iOS, Windows, Linux y macOS (según tooling de Flutter).

## Características
- Splash y flujo inicial con animaciones fluidas.
- Autenticación local (login/registro) con persistencia en Hive.
- Home: 
  - Análisis de comida con Google Generative AI (Gemini).
  - Selector cámara/galería para subir fotos de alimentos.
  - Placeholder vacío cuando no hay resultados.
  - PieChart nutricional dinámico.
  - Recetas recomendadas por IA.
- Exercise: conteo de pasos, evita recuento al ir en vehículo, integración con geolocator + sensors_plus.
- Hydration: registro de consumo (botones +100/+250/+500 ml), meta diaria dinámica y gráfico semanal desde Hive (0% al inicio del día).
- Sleep: detección automática de sueño por pantalla apagada entre 19:00–07:00, margen de 10 min, guardado en Hive, gráfico semanal y calidad editable.
- Settings: tema (claro/oscuro), color semilla, familia tipográfica, datos personales, cambiar contraseña, cerrar sesión; todo guardado en Hive.

## Tecnologías
- Flutter SDK (Dart ^3.10.8).
- Paquetes:
  - hive, hive_flutter (almacenamiento local).
  - google_generative_ai (Gemini para análisis y recetas).
  - sensors_plus, geolocator (actividad y movimiento).
  - fl_chart (gráficos).
  - image_picker, path_provider (multimedia y paths).
  - shared_preferences (compatibilidad/estado simple).
  - screen_state (opcional; el código actual usa ciclo de vida de app para “pantalla apagada”).

## Instalación y ejecución
1. Clona el repositorio:
   ```bash
   git clone https://github.com/<tu-usuario>/VidaSaludable.git
   cd VidaSaludable
   ```
2. Instala dependencias:
   ```bash
   flutter pub get
   ```
3. Configura la clave de Gemini:
   - Crea una clave en Google AI Studio.
   - Cárgala de forma segura (no la incluyas en el repositorio). Ejemplos:
     - Variables de entorno.
     - Archivo local ignorado por Git.
4. Ejecuta la app:
   ```bash
   flutter run
   ```

## Estructura del proyecto
- `lib/main.dart`: todo el código de la app (UI, lógica, persistencia).
- `pubspec.yaml`: versiones de SDK, dependencias y assets.
- `assets/`: recursos estáticos (imágenes).
- Plataformas: `android/`, `ios/`, `windows/`, `linux/`, `macos/`.

## Detalle por secciones

### SplashScreen y flujo inicial
- Qué hace: muestra un logotipo con animaciones (escala y fade) y redirige al flujo de acceso.
- Principales funciones:
  - `initState`: configura `AnimationController`.
  - Redirección: después de la animación, revisa si hay usuario logueado en Hive y navega a la app o al login.
- Persistencia: consulta la box de usuarios para saber si hay sesión actual.
- Referencia: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart)

### Login / Registro con Hive
- Qué hace: permite iniciar sesión o crear una cuenta local.
- Principales funciones:
  - Validaciones de formulario (correo/contraseña).
  - `verifyLogin`: verifica credenciales y actualiza el “currentUserEmail” en Hive.
  - Registro: crea un usuario y guarda datos personales en la box `users`.
- Persistencia: 
  - Box `users` para información del usuario.
  - Puntero de sesión `currentUserEmail`.
- Referencia: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart)

### HomeScreen
- Qué hace: analiza fotos de comida con Gemini, muestra resultados nutricionales y recetas sugeridas.
- Principales funciones:
  - Selector de imagen (cámara/galería) con `image_picker`.
  - Llamadas a Gemini para análisis y recomendaciones.
  - Render de `PieChart` con `fl_chart`.
  - Placeholder vacío si no hay resultados.
- Persistencia: resultados se gestionan en memoria; los ajustes de UI vienen de Hive.
- Referencia: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart)

### ExerciseScreen
- Qué hace: detecta pasos y actividad (caminar/correr), evita conteo en vehículo (>15 km/h).
- Principales funciones:
  - `sensors_plus` para acelerómetro y `geolocator` para velocidad/ubicación.
  - Buffer de pasos y persistencia periódica.
  - Cálculo de umbrales según tipo de actividad.
- Persistencia:
  - Box `daily_exercise` con clave `${userId}_${YYYY-MM-DD}` para conteos diarios.
  - Box `hydration_logs` para eventos relacionados si aplica.
- Referencia: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart)

### HydrationScreen
- Qué hace: registra consumo de agua y muestra progreso circular y gráfico semanal real desde Hive.
- Principales funciones:
  - Botones +100/+250/+500 ml que actualizan la box `hydration_logs` y el resumen `daily_hydration_summary`.
  - Meta diaria dinámica: desde ajustes (`user_settings.metaHydratationMl`) o calculada por peso (≈35 ml/kg).
  - Gráfico semanal de porcentaje: `(total_ml_consumido / meta_ml) * 100`.
- Persistencia:
  - Box `daily_hydration_summary` para totales por día (`${userId}_${YYYY-MM-DD}`).
  - Box `hydration_logs` para entradas detalladas.
- Referencia: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart)

### SleepScreen
- Qué hace: detecta sueño cuando la pantalla está apagada dentro de 19:00–07:00 con margen de 10 minutos, guarda segmentos y los consolida.
- Principales funciones:
  - Observador de ciclo de vida: `WidgetsBindingObserver` para `paused/resumed`.
  - Lógica de ventana horaria y recorte (clip) para sumar solo el tiempo válido.
  - Calidad inicial automática según horas dormidas (<6h=2★, 6–8h=4★, >8h=5★); editable por el usuario.
  - Gráfico semanal y lista de noches dinámicos desde Hive.
- Persistencia:
  - Box `daily_sleep` con clave `${userId}_${YYYY-MM-DD}` y campos: `hora_inicio`, `hora_fin`, `duration_h`, `quality`.
- Referencia: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart)

### SettingsScreen
- Qué hace: permite configurar tema, color semilla, familia tipográfica, datos personales, cambiar contraseña y cerrar sesión.
- Principales funciones:
  - Carga/guarda en Hive las preferencias de UI y meta de hidratación.
  - Aplica cambios de tema y tipografía a toda la app.
- Persistencia:
  - Box `user_settings` asociada a cada usuario (`userId`).
- Referencia: [main.dart](file:///C:/Users/javie/OneDrive/Documentos/GitHub/VidaSaludable/lib/main.dart)

## Base de datos Hive
- Boxes usadas:
  - `users`: datos del perfil (nombre, correo, contraseña, etc.).
  - `user_settings`: preferencias de UI y metas (brightness, seedColor, fontFamily, followLocation, metaHydratationMl).
  - `daily_exercise`: pasos/actividad diarios.
  - `hydration_logs`: entradas de consumo de agua (eventos).
  - `daily_hydration_summary`: totales de hidratación por día (ml).
  - `daily_sleep`: registros de sueño diarios.
- Claves y relaciones:
  - Clave compuesta: `${userId}_${YYYY-MM-DD}` para entidades diarias.
  - `userId` actúa como llave foránea en todas las boxes (une cada registro al usuario).
- Esquema y acceso:
  - Lectura y escritura directa mediante `Hive.box('<nombre>')`.
  - No hay migraciones complejas; los mapas almacenan valores simples (int/double/string/bool).

## Integración con Gemini (Google Generative AI)
- Uso: análisis de imágenes de comida y recomendaciones de recetas/nutrición.
- Flujo:
  - El usuario captura o selecciona una imagen.
  - Se envía a Gemini y se parsea la respuesta (nutrientes/recetas).
  - Se muestra en el Home con `PieChart` y tarjetas de recetas.
- Clave API:
  - Debe configurarse de forma segura (variables de entorno o archivos excluidos de Git).
  - Nunca subas la clave API al repositorio.

## Agregar nuevas funcionalidades
- Nuevas pantallas:
  - Sigue el patrón de `StatefulWidget` y mantén la persistencia en Hive con claves `${userId}_${YYYY-MM-DD}` para datos diarios.
- Nuevas boxes/entidades:
  - Define una box nueva y guarda mapas con tipos primitivos.
  - Usa `userId` como relación y preferentemente claves compuestas por fecha.
- IA adicional:
  - Agrega prompts y parseo en el Home sin romper la estructura actual.

## Capturas de pantalla
- Coloca tus imágenes en `images/` y referencia aquí:
  - ![Home](images/home.png)
  - ![Ejercicio](images/exercise.png)
  - ![Hidratación](images/hydration.png)
  - ![Sueño](images/sleep.png)
  - ![Ajustes](images/settings.png)

## Seguridad y buenas prácticas
- Claves y secretos:
  - Usa variables de entorno o archivos locales ignorados por Git.
  - No subas claves a GitHub.
- Contraseñas:
  - Almacena hashes, no texto plano (si añades backend/seguridad).
- Permisos:
  - Ubicación y sensores requieren permisos en Android/iOS (decláralos según las guías de cada plugin).
- Privacidad:
  - No compartas datos personales sin consentimiento.

## Roadmap
- Mejoras de sueño:
  - Integrar `screen_state` (si corresponde) o un plugin dedicado para estados de pantalla en segundo plano.
- Hidratación:
  - Recordatorios push y metas adaptativas (clima/actividad).
- Ejercicio:
  - Métricas adicionales (distancia/calorías) y sincronización con Health/Google Fit.
- IA:
  - Explicaciones nutricionales más detalladas y planes personalizados.
- Infraestructura:
  - Tests unitarios y de integración.
  - Sincronización en la nube y respaldo de datos.

---

© 2026 Vitu. Este proyecto está diseñado como guía y base para una app de bienestar. Ajusta y amplía según tus necesidades.
