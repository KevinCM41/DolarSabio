# DolarSabio – Flutter App

Sistema de gestión financiera con IA, migrado desde React/TypeScript a Flutter nativo.

---

## 🏗 Arquitectura del proyecto

```
lib/
├── main.dart                    # Entry point + inicialización Firebase
├── models/
│   ├── transaction.dart         # Modelo Transaction + FinancialSummary
│   └── linked_list.dart         # Lista enlazada (estructura de datos interna)
├── services/
│   ├── firebase_service.dart    # Auth Google + CRUD Firestore
│   ├── ai_service.dart          # Chatbot IA (Groq API)
│   ├── pdf_service.dart         # Generación y exportación de reportes PDF
│   └── excel_service.dart       # Importar / exportar Excel (.xlsx)
├── screens/
│   ├── login_screen.dart        # Pantalla de inicio de sesión con Google
│   ├── home_screen.dart         # Layout principal: sidebar + topbar
│   ├── dashboard_screen.dart    # Métricas, gráfico de barras, actividad reciente
│   └── spreadsheet_screen.dart  # Hoja de cálculo editable (Journal)
├── widgets/
│   └── chat_widget.dart         # Chatbot flotante con animación
└── utils/
    ├── theme.dart               # Paleta de colores y ThemeData
    └── app_provider.dart        # Estado global (ChangeNotifier)
```

### Correspondencia con el código original (React)
| Web (React/TS)                  | Flutter                                  |
|---------------------------------|------------------------------------------|
| `src/App.tsx`                   | `home_screen.dart` + `main.dart`         |
| `src/types.ts`                  | `models/transaction.dart`                |
| `src/lib/linkedList.ts`         | `models/linked_list.dart`                |
| `src/services/firebaseService.ts` | `services/firebase_service.dart`       |
| `src/services/geminiService.ts` | `services/ai_service.dart` (Groq)        |
| `src/services/pdfService.ts`    | `services/pdf_service.dart`              |
| `src/services/excelService.ts`  | `services/excel_service.dart`            |
| Tab Dashboard                   | `screens/dashboard_screen.dart`          |
| Tab Hoja de Cálculo             | `screens/spreadsheet_screen.dart`        |
| Chat flotante                   | `widgets/chat_widget.dart`               |

---

## 🚀 Configuración paso a paso

### 1. Requisitos previos
- Flutter SDK ≥ 3.0 → [flutter.dev](https://flutter.dev/docs/get-started/install)
- Dart SDK ≥ 3.0 (incluido con Flutter)
- Una cuenta de Firebase
- Una API key de [Groq](https://console.groq.com) (gratuita)

### 2. Clonar / abrir el proyecto
```bash
cd dolarsabio_flutter
flutter pub get
```

### 3. Configurar Firebase
```bash
# Instala la CLI de Firebase y FlutterFire
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# Autentícate y configura (selecciona tu proyecto Firebase)
firebase login
flutterfire configure
```
Esto generará automáticamente `lib/firebase_options.dart`.

Luego en `lib/main.dart`, descomenta:
```dart
import 'firebase_options.dart';
// ...
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 4. Configurar la API key de Groq
La API key se pasa en tiempo de compilación para no exponerla en el código:

**Android / iOS (desarrollo):**
```bash
flutter run --dart-define=GROQ_API_KEY=tu_api_key_aqui
```

**Producción (recomendado):** Usa un backend proxy que haga las llamadas a Groq,
así la key nunca llega al cliente.

### 5. Configurar autenticación Google en Firebase
1. En Firebase Console → Authentication → Sign-in method → habilita **Google**
2. **Android:** descarga `google-services.json` → colócalo en `android/app/`
3. **iOS:** descarga `GoogleService-Info.plist` → colócalo en `ios/Runner/`
4. En Android, agrega el SHA-1 de tu keystore en Firebase Console

### 6. Reglas de Firestore
Copia estas reglas en Firebase Console → Firestore → Rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /transactions/{transactionId} {
      allow read, write: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

### 7. Ejecutar la app
```bash
# Dispositivo físico o emulador
flutter run

# Release
flutter build apk --release --dart-define=GROQ_API_KEY=...
flutter build ios --release --dart-define=GROQ_API_KEY=...
```

---

## 📦 Dependencias principales

| Paquete             | Uso                                      |
|---------------------|------------------------------------------|
| `firebase_core`     | Inicialización Firebase                  |
| `firebase_auth`     | Autenticación con Google                 |
| `cloud_firestore`   | Base de datos en tiempo real             |
| `google_sign_in`    | OAuth Google                             |
| `fl_chart`          | Gráfico de barras (Dashboard)            |
| `pdf`               | Generación de reportes PDF               |
| `printing`          | Impresión / compartir PDF                |
| `excel`             | Leer y escribir archivos .xlsx           |
| `file_picker`       | Selector de archivos del dispositivo     |
| `share_plus`        | Compartir archivos (PDF, Excel)          |
| `provider`          | Estado global                            |
| `http`              | Llamadas HTTP a la API de Groq           |
| `flutter_animate`   | Animaciones declarativas                 |
| `intl`              | Formato de fechas y monedas              |

---

## 🔧 Cambiar proveedor de IA

El proyecto usa **Groq** (llama3-8b-8192, gratuito) en lugar de Gemini,
ya que la descripción del proyecto menciona Groq. Para cambiar de proveedor
edita `lib/services/ai_service.dart`:

```dart
// Groq (actual)
static const String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
static const String _model = 'llama3-8b-8192';

// OpenAI
// static const String _groqBaseUrl = 'https://api.openai.com/v1/chat/completions';
// static const String _model = 'gpt-4o-mini';
```

El formato de la respuesta es compatible con cualquier API OpenAI-compatible.

---

## 📱 Características implementadas

- ✅ Login con Google (Firebase Auth)
- ✅ Dashboard con métricas: Balance, Créditos, Débitos
- ✅ Gráfico de barras comparativo (fl_chart)
- ✅ Actividad reciente con filtros (Todo / Créditos / Débitos)
- ✅ Hoja de cálculo editable en tiempo real (inline editing)
- ✅ Cabeceras de columna renombrables
- ✅ CRUD completo de transacciones (Firestore)
- ✅ Lista enlazada como estructura de datos interna
- ✅ Chatbot IA flotante (Groq API con contexto financiero)
- ✅ Importar desde Excel (.xlsx / .xls)
- ✅ Exportar a Excel con estilos
- ✅ Descargar plantilla Excel
- ✅ Generar y compartir reporte PDF
- ✅ Diseño oscuro fiel al original (dark theme)
- ✅ Layout responsive (móvil + tablet/desktop con sidebar)
