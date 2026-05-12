// lib/services/ai_service.dart
// Equivalente a src/services/geminiService.ts
// Usa la API de Groq (compatible con la descripción del proyecto)
// Reemplaza fácilmente por cualquier proveedor cambiando la URL y el model

import 'dart:convert';
import 'package:http/http.dart' as http;
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

  /// Envía un mensaje al chatbot con el contexto financiero del usuario.
  static Future<String> getChatbotResponse(
    String message,
    List<Transaction> transactions,
  ) async {
    final context = _buildContext(transactions);

    print('GROQ_API_KEY: $_groqApiKey');

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
}
