import 'dart:async';

import 'package:flutter/material.dart';

import '../strings/app_strings.dart';

/// Search input with a clear button and a debounced [onChanged]. Clearing
/// fires `onChanged('')` immediately so lists reset without waiting.
class SearchField extends StatefulWidget {
  /// Creates a search field.
  const SearchField({
    super.key,
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.hintText,
    this.debounce = const Duration(milliseconds: 300),
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
  });

  /// Debounced text change callback.
  final ValueChanged<String>? onChanged;

  /// Fired on keyboard submit (not debounced).
  final ValueChanged<String>? onSubmitted;

  /// Optional external controller.
  final TextEditingController? controller;

  /// Placeholder; defaults to [AppStrings.searchHint].
  final String? hintText;

  /// Delay between the last keystroke and [onChanged].
  final Duration debounce;

  /// Focus on first build.
  final bool autofocus;

  /// Keyboard type (use `TextInputType.phone` for phone-only search).
  final TextInputType keyboardType;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _ownController;
  Timer? _timer;

  TextEditingController get _controller => widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownController = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onTextChanged);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      } else {
        _ownController ??= TextEditingController();
      }
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onTextChanged);
    _ownController?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Rebuild so the clear button appears/disappears.
    setState(() {});
  }

  void _handleChanged(String value) {
    _timer?.cancel();
    final callback = widget.onChanged;
    if (callback == null) return;
    if (widget.debounce == Duration.zero) {
      callback(value);
      return;
    }
    _timer = Timer(widget.debounce, () => callback(value));
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final hasText = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.search,
      onChanged: _handleChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText ?? strings.searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: hasText
            ? IconButton(
                tooltip: strings.clear,
                icon: const Icon(Icons.close),
                onPressed: _clear,
              )
            : null,
      ),
    );
  }
}
