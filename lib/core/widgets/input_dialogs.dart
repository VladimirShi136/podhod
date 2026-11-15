import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Спрашивает целое число. Возвращает null, если пользователь отменил.
Future<int?> askNumber(
  BuildContext context, {
  required String title,
  required int initial,
  String? suffix,
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(
      title: title,
      initial: '$initial',
      number: true,
      suffix: suffix,
    ),
  );
  return text == null ? null : int.tryParse(text.trim());
}

/// Спрашивает текст. Возвращает null, если пользователь отменил.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _InputDialog(
      title: title,
      initial: initial,
      number: false,
      hint: hint,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.initial,
    required this.number,
    this.suffix,
    this.hint,
  });

  final String title;
  final String initial;
  final bool number;
  final String? suffix;
  final String? hint;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.paper,
      title: Text(widget.title, style: AppText.hand(28)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: AppText.body(20),
        keyboardType:
            widget.number ? TextInputType.number : TextInputType.multiline,
        inputFormatters:
            widget.number ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLines: widget.number ? 1 : 4,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: widget.hint,
          suffixText: widget.suffix,
        ),
        onSubmitted: widget.number ? (_) => _submit() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Отмена', style: AppText.body(18)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Готово', style: AppText.body(18)),
        ),
      ],
    );
  }
}
