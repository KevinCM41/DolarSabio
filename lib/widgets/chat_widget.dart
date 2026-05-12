// lib/widgets/chat_widget.dart
// Equivalente al chat flotante del App.tsx

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../utils/app_provider.dart';
import '../utils/theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser})
      : timestamp = DateTime.now();
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({super.key});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  final List<ChatMessage> _history = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = false;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  Future<void> _send() async {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty || _loading) return;

    _ctrl.clear();
    setState(() {
      _history.add(ChatMessage(text: msg, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    final transactions =
        context.read<AppProvider>().transactions;
    final response =
        await AiService.getChatbotResponse(msg, transactions);

    setState(() {
      _history.add(ChatMessage(text: response, isUser: false));
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // ── Ventana del chat ─────────────────────────────────────────
        if (_open)
          ScaleTransition(
            scale: _scaleAnim,
            alignment: Alignment.bottomRight,
            child: Container(
              width: 340,
              height: 480,
              margin: const EdgeInsets.only(bottom: 72, right: 0),
              decoration: BoxDecoration(
                color: AppTheme.darkBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.darkBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      color: AppTheme.darkCard,
                      border: Border(
                          bottom: BorderSide(color: AppTheme.darkBorder)),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPrimary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentPrimary.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'DolarSabio AI Assistant',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        const Spacer(),
                        const Text('vía GROQ',
                            style: TextStyle(
                                color: AppTheme.darkMuted, fontSize: 9)),
                      ],
                    ),
                  ),

                  // Mensajes
                  Expanded(
                    child: _history.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    color: AppTheme.accentPrimary, size: 32),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Text(
                                    'Haz preguntas sobre tus tendencias,\nmárgenes o recomendaciones financieras.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          AppTheme.darkMuted.withValues(alpha: 0.7),
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(12),
                            itemCount: _history.length + (_loading ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _history.length) {
                                return _TypingIndicator();
                              }
                              return _ChatBubble(message: _history[i]);
                            },
                          ),
                  ),

                  // Input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppTheme.darkCard,
                      border: Border(
                          top: BorderSide(color: AppTheme.darkBorder)),
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Pregunta sobre tus finanzas...',
                              hintStyle: const TextStyle(
                                  color: AppTheme.darkMuted, fontSize: 12),
                              filled: true,
                              fillColor: AppTheme.darkBg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                    color: AppTheme.darkBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                    color: AppTheme.darkBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(
                                    color: AppTheme.accentPrimary),
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _send,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: _loading
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.darkBg),
                                  )
                                : const Icon(Icons.send_rounded,
                                    color: AppTheme.darkBg, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── FAB ───────────────────────────────────────────────────────
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _open ? Icons.close : Icons.chat_bubble_rounded,
                key: ValueKey(_open),
                color: AppTheme.darkBg,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFF059669)
                  : AppTheme.darkCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 2),
                bottomRight: Radius.circular(isUser ? 2 : 14),
              ),
              border: isUser
                  ? null
                  : Border.all(color: AppTheme.darkBorder),
            ),
            child: Text(
              message.text,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '${isUser ? 'Tú' : 'Asistente'} • ${_fmt(message.timestamp)}',
              style: const TextStyle(
                  color: AppTheme.darkMuted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accentPrimary,
          ),
        ),
      ),
    );
  }
}
