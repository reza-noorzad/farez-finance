import 'dart:math' as math;

import 'package:flutter/material.dart';

class FinanceBarDatum {
  final String label;
  final double value;

  const FinanceBarDatum({
    required this.label,
    required this.value,
  });
}

class FinanceBarChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<FinanceBarDatum> data;
  final String valuePrefix;
  final String valueSuffix;

  const FinanceBarChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.data,
    this.valuePrefix = '',
    this.valueSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final visibleData = data.where((item) => item.value.abs() > 0.001).toList();
    visibleData.sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: visibleData.isEmpty
            ? _EmptyChart(title: title, subtitle: subtitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChartHeader(title: title, subtitle: subtitle),
                  const SizedBox(height: 16),
                  _HorizontalBarList(
                    data: visibleData.take(8).toList(),
                    valuePrefix: valuePrefix,
                    valueSuffix: valueSuffix,
                  ),
                ],
              ),
      ),
    );
  }
}

class FinanceProgressSplitCard extends StatelessWidget {
  final String title;
  final double firstValue;
  final double secondValue;
  final String firstLabel;
  final String secondLabel;
  final String Function(double value) formatter;

  const FinanceProgressSplitCard({
    super.key,
    required this.title,
    required this.firstValue,
    required this.secondValue,
    required this.firstLabel,
    required this.secondLabel,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final total = firstValue.abs() + secondValue.abs();
    final firstShare = total <= 0 ? 0.0 : (firstValue.abs() / total).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 18,
                child: Stack(
                  children: [
                    Container(color: colorScheme.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: firstShare,
                      child: Container(color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LegendValue(
                    label: firstLabel,
                    value: formatter(firstValue),
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LegendValue(
                    label: secondLabel,
                    value: formatter(secondValue),
                    color: colorScheme.surfaceContainerHighest,
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

class FinanceLineDatum {
  final String label;
  final double value;

  const FinanceLineDatum({
    required this.label,
    required this.value,
  });
}

class FinanceLineChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<FinanceLineDatum> data;
  final String valuePrefix;
  final String valueSuffix;

  const FinanceLineChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.data,
    this.valuePrefix = '',
    this.valueSuffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final visibleData = data.where((item) => item.value.abs() > 0.001).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: visibleData.length < 2
            ? _EmptyChart(title: title, subtitle: subtitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChartHeader(title: title, subtitle: subtitle),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 190,
                    child: CustomPaint(
                      painter: _FinanceLineChartPainter(
                        data: visibleData,
                        color: Theme.of(context).colorScheme.primary,
                        gridColor: Theme.of(context).colorScheme.outlineVariant,
                        textColor: Theme.of(context).colorScheme.onSurface,
                        valuePrefix: valuePrefix,
                        valueSuffix: valueSuffix,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _ChartHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _EmptyChart({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
          ),
          child: const Text('Noch keine Daten für dieses Diagramm.'),
        ),
      ],
    );
  }
}

class _HorizontalBarList extends StatelessWidget {
  final List<FinanceBarDatum> data;
  final String valuePrefix;
  final String valueSuffix;

  const _HorizontalBarList({
    required this.data,
    required this.valuePrefix,
    required this.valueSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.map((item) => item.value.abs()).fold<double>(0, math.max);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: data.map((item) {
        final share = maxValue <= 0 ? 0.0 : (item.value.abs() / maxValue).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$valuePrefix${item.value.toStringAsFixed(0)}$valueSuffix',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(height: 12, color: colorScheme.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: share,
                      child: Container(height: 12, color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LegendValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LegendValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinanceLineChartPainter extends CustomPainter {
  final List<FinanceLineDatum> data;
  final Color color;
  final Color gridColor;
  final Color textColor;
  final String valuePrefix;
  final String valueSuffix;

  _FinanceLineChartPainter({
    required this.data,
    required this.color,
    required this.gridColor,
    required this.textColor,
    required this.valuePrefix,
    required this.valueSuffix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final values = data.map((item) => item.value).toList();
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);

    if ((maxValue - minValue).abs() < 0.001) {
      maxValue += 1;
      minValue -= 1;
    }

    const left = 8.0;
    const right = 8.0;
    const top = 18.0;
    const bottom = 34.0;

    final width = size.width - left - right;
    final height = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.8)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = top + height * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    Offset pointFor(int index) {
      final x = left + width * index / (data.length - 1);
      final normalized = (data[index].value - minValue) / (maxValue - minValue);
      final y = top + height - normalized * height;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointFor(0).dx, pointFor(0).dy);
    for (var i = 1; i < data.length; i++) {
      final previous = pointFor(i - 1);
      final current = pointFor(i);
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(controlX, previous.dy, controlX, current.dy, current.dx, current.dy);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (var i = 0; i < data.length; i++) {
      final point = pointFor(i);
      canvas.drawCircle(point, 4, dotPaint);
    }

    _drawText(canvas, data.first.label, Offset(left, size.height - 14), textColor, 10, alignLeft: true);
    _drawText(canvas, data.last.label, Offset(size.width - right, size.height - 14), textColor, 10, alignLeft: false);
    _drawText(
      canvas,
      '$valuePrefix${data.last.value.toStringAsFixed(0)}$valueSuffix',
      Offset(size.width - right, pointFor(data.length - 1).dy - 12),
      textColor,
      10,
      alignLeft: false,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    required bool alignLeft,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 90);

    textPainter.paint(
      canvas,
      Offset(
        alignLeft ? offset.dx : offset.dx - textPainter.width,
        offset.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _FinanceLineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
