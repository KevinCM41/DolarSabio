// lib/models/puc_entry.dart
// Entrada del Plan Único de Cuentas (PUC) para dropdowns y guía.

class PucEntry {
  final String claseTitulo;
  final String codigo;
  final String cuenta;

  const PucEntry({
    required this.claseTitulo,
    required this.codigo,
    required this.cuenta,
  });
}

class PucSection {
  final String titulo;
  final List<PucEntry> entries;

  PucSection({required this.titulo}) : entries = <PucEntry>[];
}
