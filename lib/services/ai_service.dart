// lib/services/ai_service.dart
// Equivalente a src/services/geminiService.ts
// Usa la API de Groq (compatible con la descripción del proyecto)
// Reemplaza fácilmente por cualquier proveedor cambiando la URL y el model

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class AiService {
  // ─── Configuración ───────────────────────────────────────────────────────
  // Cambia estos valores en un archivo .env o en las variables de entorno
  // de tu CI/CD. Nunca expongas la API key en código fuente.
  static const String _groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _groqBaseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant'; // Modelo gratuito de Groq

  static bool get isConfigured => _groqApiKey.isNotEmpty;

  /// Envía un mensaje al chatbot con el contexto financiero del usuario.
  static Future<String> getChatbotResponse(
    String message,
    List<Transaction> transactions,
  ) async {
    final context = _buildContext(transactions);

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': context},
            {'role': 'user', 'content': message},
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        return 'Error ${response.statusCode}: No se pudo procesar tu consulta.';
      }
    } catch (e) {
      return 'Lo siento, tuve un problema al conectarme. Por favor intenta de nuevo.';
    }
  }

  static String _buildContext(List<Transaction> transactions) {
    // Enviamos los últimos 50 registros como contexto (igual que el original)
    final sample = transactions.take(50).map((t) => {
          'id': t.recordId,
          'cuenta': t.cuenta,
          'descripcion': t.descripcion,
          'fecha': t.fecha,
          'debito': t.debito,
          'credito': t.credito,
        });

    return '''
Eres DolarSabio, un asistente financiero experto.
Datos actuales del usuario (últimos 50 registros):
${jsonEncode(sample.toList())}

Responde de manera profesional y estratégica basándote en estos datos.
Usa el contexto para dar recomendaciones personalizadas sobre pérdidas, 
ganancias, flujo de caja y oportunidades financieras.
Responde siempre en español.
''';
  }

  /// Explicación del código PUC para el usuario (contabilidad colombiana).
  static Future<String> explainPucWithAi({
    required String codigo,
    required String cuentaEnLibro,
    required String catalogSummary,
  }) async {
    if (!isConfigured) {
      return 'Para usar la explicación con IA, compila con '
          '`--dart-define=GROQ_API_KEY=tu_clave` (Groq).';
    }

    const system = '''
Eres experto en contabilidad colombiana y en el Plan Único de Cuentas (PUC).
Explica de forma breve y clara (como máximo tres párrafos cortos) qué representa el código PUC que indica el usuario y cómo se usa en la práctica de una pyme.
Basa la explicación en el resumen del catálogo que recibes; no inventes códigos ni cuentas que no aparezcan ahí.
Responde en español. Puedes usar listas en Markdown si ayuda.
''';

    final userMsg = '''
Código PUC: $codigo
Cuenta elegida en el movimiento del usuario: $cuentaEnLibro

Resumen del catálogo oficial cargado en la app:
$catalogSummary
''';

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': userMsg},
          ],
          'max_tokens': 700,
          'temperature': 0.35,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
      return 'Error ${response.statusCode}: no se pudo generar la explicación.';
    } catch (e) {
      return 'No se pudo conectar con el servicio de IA. Intenta de nuevo.';
    }
  }

  /// Texto corto para notificación local (sin IA usa [heuristicFinancialReminder]).
  static Future<String> getFinancialDailyReminder(
    FinancialSummary summary,
    List<Transaction> transactions,
  ) async {
    if (!isConfigured) {
      return heuristicFinancialReminder(summary, transactions);
    }

    final now = DateTime.now();
    var monthDebit = 0.0;
    var monthCredit = 0.0;
    var monthCount = 0;
    for (final t in transactions) {
      final d = DateTime.tryParse(t.fecha);
      if (d == null) continue;
      if (d.year == now.year && d.month == now.month) {
        monthDebit += t.debito;
        monthCredit += t.credito;
        monthCount++;
      }
    }

    final fmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );

    final user = '''
Resumen global (registros cargados en la app):
- Asientos: ${summary.transactionCount}
- Total débitos: ${fmt.format(summary.totalExpenses)}
- Total créditos: ${fmt.format(summary.totalIncomes)}
- Balance (débitos − créditos): ${fmt.format(summary.balance)}

Mes calendario actual (${now.year}-${now.month.toString().padLeft(2, '0')}):
- Movimientos del mes: $monthCount
- Débitos del mes: ${fmt.format(monthDebit)}
- Créditos del mes: ${fmt.format(monthCredit)}

Escribe UN solo párrafo de como máximo 320 caracteres en español: un recordatorio sobre el mes y un consejo financiero breve para una pyme. Sin saludo, sin despedida, sin comillas, sin markdown.
''';

    const system =
        'Eres DolarSabio: asesor financiero conciso. El texto irá a una notificación móvil.';

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': system},
            {'role': 'user', 'content': user},
          ],
          'max_tokens': 220,
          'temperature': 0.45,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['choices'][0]['message']['content'] as String;
        final t = raw.trim();
        if (t.isNotEmpty) return t;
      }
    } catch (_) {}

    return heuristicFinancialReminder(summary, transactions);
  }

  /// Consejo sin red: basado en totales y movimientos del mes calendario.
  static String heuristicFinancialReminder(
    FinancialSummary summary,
    List<Transaction> transactions,
  ) {
    final now = DateTime.now();
    var monthDebit = 0.0;
    var monthCredit = 0.0;
    var monthCount = 0;
    for (final t in transactions) {
      final d = DateTime.tryParse(t.fecha);
      if (d == null) continue;
      if (d.year == now.year && d.month == now.month) {
        monthDebit += t.debito;
        monthCredit += t.credito;
        monthCount++;
      }
    }

    final fmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 0,
    );

    final tip = summary.balance > 0
        ? 'Revisa el dashboard: el saldo neto (débitos − créditos) está por encima de cero.'
        : 'Buen momento para revisar flujo de caja y reservas con tu contador.';

    return 'Este mes llevas ${fmt.format(monthDebit)} en débitos y '
        '${fmt.format(monthCredit)} en créditos ($monthCount movimientos). '
        'En total ${summary.transactionCount} asientos. $tip';
  }
}
