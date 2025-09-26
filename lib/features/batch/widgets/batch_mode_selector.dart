import 'package:flutter/material.dart';
import '../../../core/models/batch_analysis.dart';
import '../../../core/models/quality_report.dart';

class BatchModeSelector extends StatelessWidget {
  final BatchMode selectedMode;
  final ValueChanged<BatchMode> onModeChanged;
  final String globalPartSerial;
  final ValueChanged<String> onGlobalPartSerialChanged;
  final PartType? globalPartType;
  final ValueChanged<PartType?> onGlobalPartTypeChanged;

  const BatchModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.globalPartSerial,
    required this.onGlobalPartSerialChanged,
    required this.globalPartType,
    required this.onGlobalPartTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.batch_prediction, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('Batch Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Mode selector
            Column(
              children: [
                RadioListTile<BatchMode>(
                  title: const Text('Více dílů'),
                  subtitle: const Text('Každý pár má jiný typ dílu a sériové číslo'),
                  value: BatchMode.multipleParts,
                  groupValue: selectedMode,
                  onChanged: (value) => onModeChanged(value!),
                ),
                RadioListTile<BatchMode>(
                  title: const Text('Stejný díl'),
                  subtitle: const Text('Všechny páry jsou ze stejného dílu'),
                  value: BatchMode.samePart,
                  groupValue: selectedMode,
                  onChanged: (value) => onModeChanged(value!),
                ),
              ],
            ),

            // Global settings for same part mode
            if (selectedMode == BatchMode.samePart) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Global part type selector
              DropdownButtonFormField<PartType>(
                decoration: const InputDecoration(
                  labelText: 'Typ dílu (pro všechny páry)',
                  border: OutlineInputBorder(),
                ),
                value: globalPartType,
                items: PartType.values.map((type) =>
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  )
                ).toList(),
                onChanged: onGlobalPartTypeChanged,
              ),

              const SizedBox(height: 16),

              // Global part serial field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Sériové číslo dílu (pro všechny páry)',
                  border: OutlineInputBorder(),
                  hintText: 'Např. ABC-12345',
                ),
                onChanged: onGlobalPartSerialChanged,
                initialValue: globalPartSerial,
              ),

              const SizedBox(height: 8),
              Text(
                'V tomto režimu se sériové číslo a typ dílu použije pro všechny foto páry.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension PartTypeExtension on PartType {
  String get displayName {
    switch (this) {
      case PartType.vylisky:
        return 'Výlisky';
      case PartType.obrabene:
        return 'Obráběné díly';
    }
  }
}