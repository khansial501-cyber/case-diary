import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/providers.dart';
import 'widgets.dart';

/// Mic button that appends dictated text (English or Urdu) to a controller.
class VoiceButton extends ConsumerStatefulWidget {
  final TextEditingController controller;
  const VoiceButton({super.key, required this.controller});
  @override
  ConsumerState<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<VoiceButton> {
  final SpeechToText _stt = SpeechToText();
  bool _on = false;

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final l = ref.read(l10nProvider);
    if (_on) {
      await _stt.stop();
      if (mounted) setState(() => _on = false);
      return;
    }
    final ok = await _stt.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _on = false);
      },
      onError: (_) {
        if (mounted) setState(() => _on = false);
      },
    );
    if (!ok) {
      if (mounted) snack(context, l('voiceUnavailable'));
      return;
    }
    final base = widget.controller.text.trim();
    setState(() => _on = true);
    await _stt.listen(
      localeId: l.isUr ? 'ur_PK' : 'en_US',
      listenOptions: SpeechListenOptions(partialResults: true),
      onResult: (r) {
        final t = r.recognizedWords;
        widget.controller.text = base.isEmpty ? t : '$base $t';
        widget.controller.selection = TextSelection.collapsed(offset: widget.controller.text.length);
      },
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(_on ? Icons.mic : Icons.mic_none, color: _on ? Colors.red : null),
        onPressed: _toggle,
      );
}
