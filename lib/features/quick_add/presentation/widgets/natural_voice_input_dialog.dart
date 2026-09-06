import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/natural_input_parser.dart';

class NaturalVoiceInputDialog extends StatefulWidget {
  final Function(ParsedTransactionInput parsed) onParsed;

  const NaturalVoiceInputDialog({super.key, required this.onParsed});

  @override
  State<NaturalVoiceInputDialog> createState() => _NaturalVoiceInputDialogState();
}

class _NaturalVoiceInputDialogState extends State<NaturalVoiceInputDialog> {
  final TextEditingController _controller = TextEditingController();
  ParsedTransactionInput? _preview;

  void _onTextChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() => _preview = null);
    } else {
      setState(() {
        _preview = NaturalInputParser.parse(text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Smart Quick Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type or speak naturally (e.g., "250 lunch", "₹450 grocery at Walmart", "Uber 35")',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. 200 for Starbucks coffee',
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _onTextChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onTextChanged,
              onSubmitted: (_) {
                if (_preview != null && _preview!.amountCents != null) {
                  widget.onParsed(_preview!);
                  Navigator.pop(context);
                }
              },
            ),
            if (_preview != null && _preview!.amountCents != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detected Info:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount:', style: TextStyle(fontSize: 13)),
                        Text(
                          CurrencyFormatter.formatCents(_preview!.amountCents!),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Note:', style: TextStyle(fontSize: 13)),
                        Text(
                          _preview!.note,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (_preview!.suggestedCategoryName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Category:', style: TextStyle(fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _preview!.suggestedCategoryName!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryLight),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _preview != null && _preview!.amountCents != null
              ? () {
                  widget.onParsed(_preview!);
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
