import 'package:flutter/material.dart';

import '../../../data/models/filter_state.dart';
import '../../../data/models/scoring_template.dart';

/// 筛选底部面板
class FilterBottomSheet extends StatefulWidget {
  final FilterState initialFilter;
  final ScoringTemplate? selectedTemplate;
  final int maxEvalCount;
  final ValueChanged<FilterState> onChanged;

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.selectedTemplate,
    required this.maxEvalCount,
    required this.onChanged,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  // ---- 分数 ----
  late RangeValues _scoreRange;
  final _scoreMinCtrl = TextEditingController();
  final _scoreMaxCtrl = TextEditingController();

  // ---- 评价次数 ----
  late RangeValues _evalCountRange;
  final _evalCountMinCtrl = TextEditingController();
  final _evalCountMaxCtrl = TextEditingController();

  // ---- 日期 ----
  DateTime? _startDate;
  DateTime? _endDate;

  // ---- 维度 ----
  /// key = 维度名
  late Map<String, RangeValues> _dimensionRanges;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilter;

    _scoreRange = RangeValues(
      f.minScore ?? 0.0,
      f.maxScore ?? 10.0,
    );
    _scoreMinCtrl.text = (f.minScore ?? 0.0).toStringAsFixed(0);
    _scoreMaxCtrl.text = (f.maxScore ?? 10.0).toStringAsFixed(0);

    final maxEval = widget.maxEvalCount > 0 ? widget.maxEvalCount : 1;
    _evalCountRange = RangeValues(
      (f.minEvalCount ?? 0).toDouble(),
      (f.maxEvalCount ?? maxEval).toDouble(),
    );
    _evalCountMinCtrl.text = (f.minEvalCount ?? 0).toString();
    _evalCountMaxCtrl.text = (f.maxEvalCount ?? maxEval).toString();

    _startDate = f.startDate;
    _endDate = f.endDate;

    _dimensionRanges = Map.from(f.dimensionRanges);
  }

  @override
  void dispose() {
    _scoreMinCtrl.dispose();
    _scoreMaxCtrl.dispose();
    _evalCountMinCtrl.dispose();
    _evalCountMaxCtrl.dispose();
    super.dispose();
  }

  // ---- 构建当前 FilterState ----
  FilterState _buildFilter() {
    final sMin = _scoreRange.start == 0.0 ? null : _scoreRange.start;
    final sMax = _scoreRange.start == 0.0 && _scoreRange.end == 10.0
        ? null
        : _scoreRange.end;
    final evalMax = widget.maxEvalCount > 0 ? widget.maxEvalCount : 1;
    final eMin = _evalCountRange.start == 0 ? null
        : _evalCountRange.start.toInt();
    final eMax = _evalCountRange.start == 0 &&
            _evalCountRange.end == evalMax.toDouble()
        ? null
        : _evalCountRange.end.toInt();

    return FilterState(
      minScore: sMin,
      maxScore: sMax,
      minEvalCount: eMin,
      maxEvalCount: eMax,
      startDate: _startDate,
      endDate: _endDate,
      dimensionRanges: Map.from(_dimensionRanges),
    );
  }

  void _apply() {
    widget.onChanged(_buildFilter());
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _scoreRange = const RangeValues(0.0, 10.0);
      _scoreMinCtrl.text = '0';
      _scoreMaxCtrl.text = '10';
      final maxEval = widget.maxEvalCount > 0 ? widget.maxEvalCount : 1;
      _evalCountRange = RangeValues(0, maxEval.toDouble());
      _evalCountMinCtrl.text = '0';
      _evalCountMaxCtrl.text = maxEval.toString();
      _startDate = null;
      _endDate = null;
      _dimensionRanges.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _buildFilter().isActive;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- 标题栏 ----
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text('筛选条件',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: isActive ? _reset : null,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重置'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ---- 分数范围 ----
              _buildSectionHeader('分数范围', Icons.score),
              _buildSliderSection(
                range: _scoreRange,
                min: 0.0,
                max: 10.0,
                divisions: 20,
                minCtrl: _scoreMinCtrl,
                maxCtrl: _scoreMaxCtrl,
                formatValue: (v) => v.toStringAsFixed(0),
                onChanged: (v) {
                  setState(() {
                    _scoreRange = v;
                    _scoreMinCtrl.text = v.start.toStringAsFixed(0);
                    _scoreMaxCtrl.text = v.end.toStringAsFixed(0);
                  });
                },
                onMinEdited: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    setState(() {
                      _scoreRange = RangeValues(
                          val.clamp(0.0, _scoreRange.end), _scoreRange.end);
                    });
                  }
                },
                onMaxEdited: (v) {
                  final val = double.tryParse(v);
                  if (val != null) {
                    setState(() {
                      _scoreRange = RangeValues(
                          _scoreRange.start, val.clamp(_scoreRange.start, 10.0));
                    });
                  }
                },
              ),

              // ---- 评价次数 ----
              _buildSectionHeader('评价次数', Icons.repeat),
              _buildSliderSection(
                range: _evalCountRange,
                min: 0,
                max: (widget.maxEvalCount > 0 ? widget.maxEvalCount : 1)
                    .toDouble(),
                divisions: widget.maxEvalCount > 0 ? widget.maxEvalCount : 1,
                minCtrl: _evalCountMinCtrl,
                maxCtrl: _evalCountMaxCtrl,
                formatValue: (v) => v.toInt().toString(),
                onChanged: (v) {
                  setState(() {
                    _evalCountRange = v;
                    _evalCountMinCtrl.text = v.start.toInt().toString();
                    _evalCountMaxCtrl.text = v.end.toInt().toString();
                  });
                },
                onMinEdited: (v) {
                  final val = int.tryParse(v);
                  if (val != null) {
                    setState(() {
                      _evalCountRange = RangeValues(
                        val.clamp(0, _evalCountRange.end.toInt()).toDouble(),
                        _evalCountRange.end,
                      );
                    });
                  }
                },
                onMaxEdited: (v) {
                  final val = int.tryParse(v);
                  if (val != null) {
                    final max = widget.maxEvalCount > 0
                        ? widget.maxEvalCount
                        : 1;
                    setState(() {
                      _evalCountRange = RangeValues(
                        _evalCountRange.start,
                        val
                            .clamp(_evalCountRange.start.toInt(), max)
                            .toDouble(),
                      );
                    });
                  }
                },
              ),

              // ---- 首次添加时间 ----
              _buildSectionHeader('首次添加时间', Icons.calendar_today),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: '起始日期',
                        date: _startDate,
                        onPicked: (d) => setState(() => _startDate = d),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~'),
                    ),
                    Expanded(
                      child: _DateButton(
                        label: '截止日期',
                        date: _endDate,
                        onPicked: (d) => setState(() => _endDate = d),
                      ),
                    ),
                  ],
                ),
              ),
              if (_startDate != null || _endDate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 4),
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('清除日期', style: TextStyle(fontSize: 13)),
                  ),
                ),

              // ---- 维度评分（仅选中分类时） ----
              if (widget.selectedTemplate != null) ...[
                const SizedBox(height: 4),
                _buildSectionHeader('${widget.selectedTemplate!.name} 维度评分',
                    Icons.insights),
                ...widget.selectedTemplate!.dimensions.map((dim) {
                  final current = _dimensionRanges[dim] ??
                      const RangeValues(0.0, 10.0);
                  final dminCtrl = TextEditingController(
                      text: current.start.toStringAsFixed(0));
                  final dmaxCtrl = TextEditingController(
                      text: current.end.toStringAsFixed(0));

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dim,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: TextField(
                                controller: dminCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: false),
                                decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 8)),
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                                onChanged: (v) {
                                  final val = double.tryParse(v);
                                  if (val != null) {
                                    setState(() {
                                      final newEnd = _dimensionRanges[dim]
                                              ?.end ??
                                          10.0;
                                      _dimensionRanges[dim] = RangeValues(
                                          val.clamp(0.0, newEnd), newEnd);
                                    });
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  rangeThumbShape:
                                      const RoundRangeSliderThumbShape(
                                          enabledThumbRadius: 8),
                                ),
                                child: RangeSlider(
                                  values:
                                      _dimensionRanges[dim] ??
                                          const RangeValues(0.0, 10.0),
                                  min: 0.0,
                                  max: 10.0,
                                  divisions: 20,
                                  labels: RangeLabels(
                                    (_dimensionRanges[dim]?.start ?? 0)
                                        .toStringAsFixed(0),
                                    (_dimensionRanges[dim]?.end ?? 10)
                                        .toStringAsFixed(0),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      _dimensionRanges[dim] = v;
                                      dminCtrl.text =
                                          v.start.toStringAsFixed(0);
                                      dmaxCtrl.text =
                                          v.end.toStringAsFixed(0);
                                    });
                                  },
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: TextField(
                                controller: dmaxCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: false),
                                decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 8)),
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                                onChanged: (v) {
                                  final val = double.tryParse(v);
                                  if (val != null) {
                                    setState(() {
                                      final newStart = _dimensionRanges[dim]
                                              ?.start ??
                                          0.0;
                                      _dimensionRanges[dim] = RangeValues(
                                          newStart,
                                          val.clamp(newStart, 10.0));
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 8),

              // ---- 应用按钮 ----
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _apply,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('应用筛选'),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 通用区块标题 ----
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---- 通用双滑块区块 ----
  Widget _buildSliderSection({
    required RangeValues range,
    required double min,
    required double max,
    required int divisions,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    required String Function(double) formatValue,
    required ValueChanged<RangeValues> onChanged,
    required ValueChanged<String> onMinEdited,
    required ValueChanged<String> onMaxEdited,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: TextField(
                  controller: minCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: false),
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8)),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                  onChanged: onMinEdited,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 8),
                  ),
                  child: RangeSlider(
                    values: range,
                    min: min,
                    max: max,
                    divisions: divisions,
                    labels: RangeLabels(
                      formatValue(range.start),
                      formatValue(range.end),
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: TextField(
                  controller: maxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: false),
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8)),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                  onChanged: onMaxEdited,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 日期选择按钮
class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPicked;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2099),
          helpText: label,
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month,
                size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                date != null
                    ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
                    : label,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      date != null ? colorScheme.onSurface : colorScheme.outline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
