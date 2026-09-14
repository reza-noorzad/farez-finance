import 'dart:convert';

import '../../shared/models/expense_item_model.dart';

class ParsedReceiptData {
  final String? storeName;
  final DateTime? date;
  final double? totalAmount;
  final List<ExpenseItemModel> items;

  const ParsedReceiptData({
    required this.storeName,
    required this.date,
    required this.totalAmount,
    required this.items,
  });

  int get reviewCount {
    return items.where((item) => item.needsReview).length;
  }
}

class ReceiptJsonParser {
  static ParsedReceiptData? parse({
    required String rawText,
    required String expenseId,
    required DateTime fallbackDate,
    required String? fallbackStoreName,
  }) {
    try {
      final cleanedText = _cleanJsonText(rawText);
      final decoded = jsonDecode(cleanedText);

      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);
      final storeName = _readString(map['storeName']) ?? fallbackStoreName;
      final date = _readDate(map['date']) ?? fallbackDate;
      final totalAmount = _readDouble(map['totalAmount']);

      final rawItems = map['items'];
      final items = <ExpenseItemModel>[];

      if (rawItems is List) {
        for (var index = 0; index < rawItems.length; index++) {
          final rawItem = rawItems[index];
          if (rawItem is! Map) continue;

          final item = Map<String, dynamic>.from(rawItem);
          final originalName = _readString(item['originalName']);
          final monthlyName = _readString(item['monthlyName']);
          final name = _readString(item['name']);
          final category = _readString(item['category']) ?? 'Sonstiges';
          final quantity = _readDouble(item['quantity']) ?? 1;
          final unit = _readString(item['unit']) ?? 'Stück';
          final totalPrice = _readDouble(item['totalPrice']) ?? 0;

          final weightGrams = _readDouble(item['weightGrams']) ??
              _readDouble(item['weightGram']) ??
              _readDouble(item['weight_g']) ??
              _weightFromQuantityAndUnit(quantity, unit);

          final volumeMl = _readDouble(item['volumeMl']) ??
              _readDouble(item['volumeML']) ??
              _readDouble(item['volume_ml']) ??
              _volumeFromQuantityAndUnit(quantity, unit);

          final countUnits = _readDouble(item['countUnits']) ??
              _readDouble(item['count']) ??
              _countFromQuantityAndUnit(quantity, unit);

          final displayName = originalName ?? monthlyName ?? name ?? 'Produkt';
          final combinedText = '$displayName $category $unit'.toLowerCase();

          final explicitImportance =
              _readBool(item['isMeasurementImportant']);
          final importanceLabel =
              _readString(item['measurementImportance'])?.toLowerCase();
          final isImportantFromJson =
              explicitImportance ?? importanceLabel == 'important';

          final isImportant =
              isImportantFromJson || _isMeasurementImportant(combinedText);

          final hasMeasurement =
              weightGrams != null || volumeMl != null || countUnits != null;

          final needsReviewFromJson = _readBool(item['needsReview']);
          final needsReview = needsReviewFromJson ??
              (isImportant && !hasMeasurement && _unitLooksLikePackage(unit));

          final reviewReason = _readString(item['reviewReason']) ??
              (needsReview
                  ? 'Menge steht nicht genau auf dem Kassenzettel.'
                  : null);

          final measurementStatus = _readString(item['measurementStatus']) ??
              (hasMeasurement
                  ? 'exact'
                  : isImportant
                      ? 'unknown'
                      : 'notImportant');

          items.add(
            ExpenseItemModel(
              id: '${expenseId}_item_$index',
              expenseId: expenseId,
              name: displayName,
              originalName: originalName,
              monthlyName: monthlyName,
              category: category,
              quantity: quantity,
              unit: unit,
              totalPrice: totalPrice,
              date: date,
              storeName: storeName,
              weightGrams: weightGrams,
              volumeMl: volumeMl,
              countUnits: countUnits,
              isMeasurementImportant: isImportant,
              needsReview: needsReview,
              reviewReason: reviewReason,
              measurementStatus: measurementStatus,
            ),
          );
        }
      }

      return ParsedReceiptData(
        storeName: storeName,
        date: date,
        totalAmount: totalAmount,
        items: items,
      );
    } catch (_) {
      return null;
    }
  }

  static String _cleanJsonText(String rawText) {
    var cleaned = rawText
        .replaceAll('\uFEFF', '')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u2060', '')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('„', '"')
        .replaceAll('‟', '"')
        .replaceAll('«', '"')
        .replaceAll('»', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('‚', "'")
        .replaceAll('‛', "'")
        .trim();

    cleaned = cleaned
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      throw const FormatException('Kein vollständiges JSON-Objekt gefunden.');
    }

    cleaned = cleaned.substring(firstBrace, lastBrace + 1).trim();

    // Häufige Modellfehler tolerant korrigieren: überflüssige Kommas
    // direkt vor } oder ]. Inhalte und Zahlen werden dabei nicht verändert.
    cleaned = cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

    return cleaned;
  }

  static bool _isMeasurementImportant(String text) {
    const keywords = [
      'fleisch','hack','huhn','hähnchen','chicken','pute','rind','schwein',
      'fisch','lachs','reis','nudel','pasta','kartoffel','tomate','gurke',
      'gemüse','obst','apfel','banane','orange','käse','joghurt','milch',
      'öl','mehl','zucker','hafer','brot','ei','eier','lebensmittel',
      'getränk','sirup','saft','wasser','tierfutter','hundefutter','katzenfutter',
    ];
    return keywords.any(text.contains);
  }

  static bool _unitLooksLikePackage(String unit) {
    final normalized = unit.toLowerCase();
    return normalized.contains('pack') ||
        normalized.contains('pkg') ||
        normalized.contains('stk') ||
        normalized.contains('stück') ||
        normalized.contains('stuck') ||
        normalized == 'x' ||
        normalized == 'ea';
  }

  static double? _weightFromQuantityAndUnit(double quantity, String unit) {
    final normalized = unit.toLowerCase().trim();
    if (normalized == 'kg' || normalized.contains('kilo')) return quantity * 1000;
    if (normalized == 'g' || normalized.contains('gramm')) return quantity;
    return null;
  }

  static double? _volumeFromQuantityAndUnit(double quantity, String unit) {
    final normalized = unit.toLowerCase().trim();
    if (normalized == 'l' || normalized == 'liter') return quantity * 1000;
    if (normalized == 'ml' || normalized == 'milliliter') return quantity;
    return null;
  }

  static double? _countFromQuantityAndUnit(double quantity, String unit) {
    final normalized = unit.toLowerCase().trim();
    if (normalized.contains('stk') ||
        normalized.contains('stück') ||
        normalized.contains('stuck')) {
      return quantity;
    }
    return null;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.').trim());
  }

  static bool? _readBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final text = value.toString().toLowerCase().trim();
    if (text == 'true' || text == 'yes' || text == '1') return true;
    if (text == 'false' || text == 'no' || text == '0') return false;
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString().trim());
  }
}
