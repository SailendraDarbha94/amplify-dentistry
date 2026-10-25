import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_mobile/core/whatsapp_cloud.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owner form for the clinic's Meta credentials. Saving calls
/// `set_whatsapp_config`; the access token travels only inside that call
/// (the server stores it in Vault) and the field is cleared on success.
/// Nothing from this form is written to the local database or settings.
class WhatsAppConfigForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const WhatsAppConfigForm({super.key});

  @override
  ConsumerState<WhatsAppConfigForm> createState() => _WhatsAppConfigFormState();
}

class _WhatsAppConfigFormState extends ConsumerState<WhatsAppConfigForm> {
  static const Logger _log = Logger('whatsapp-form');

  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _phoneNumberId = TextEditingController();
  final TextEditingController _wabaId = TextEditingController();
  final TextEditingController _displayPhone = TextEditingController();
  final TextEditingController _accessToken = TextEditingController();
  final TextEditingController _verifyToken = TextEditingController();
  bool _busy = false;
  bool _showToken = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _phoneNumberId.dispose();
    _wabaId.dispose();
    _displayPhone.dispose();
    _accessToken.dispose();
    _verifyToken.dispose();
    super.dispose();
  }

  void _prefill(WhatsAppStatus? status) {
    if (_prefilled || status == null || !status.configured) return;
    _prefilled = true;
    _phoneNumberId.text = status.phoneNumberId ?? '';
    _wabaId.text = status.wabaId ?? '';
    _displayPhone.text = status.displayPhone ?? '';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final service = ref.read(whatsappCloudServiceProvider);
    final clinicId = ref.read(currentClinicIdProvider);
    if (service == null || clinicId == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.saveConfig(
        clinicId: clinicId,
        phoneNumberId: _phoneNumberId.text,
        wabaId: _wabaId.text,
        displayPhone: _displayPhone.text,
        accessToken: _accessToken.text,
        verifyToken: _verifyToken.text,
      );
      // The token lives in Vault now; drop it from memory and the field.
      _accessToken.clear();
      ref.invalidate(whatsappStatusProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saved. The token is stored in Supabase Vault.'),
        ),
      );
    } on Object catch (e) {
      _log.warning('save failed: ${e.runtimeType}');
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefill(ref.watch(whatsappStatusProvider).value);
    return SectionCard(
      title: 'Meta Cloud API credentials',
      subtitle: 'From the Meta app dashboard (WhatsApp > API setup)',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('whatsapp-phone-number-id'),
              controller: _phoneNumberId,
              decoration: const InputDecoration(
                labelText: 'Phone number id',
                helperText: 'The 15-digit id, not the phone number',
              ),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  WhatsAppConfigValidators.digits(v, 'Phone number id'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('whatsapp-waba-id'),
              controller: _wabaId,
              decoration: const InputDecoration(labelText: 'WABA id'),
              keyboardType: TextInputType.number,
              validator: (v) => WhatsAppConfigValidators.digits(v, 'WABA id'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('whatsapp-display-phone'),
              controller: _displayPhone,
              decoration: const InputDecoration(
                labelText: 'Display phone',
                helperText: 'The number patients see',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('whatsapp-access-token'),
              controller: _accessToken,
              decoration: InputDecoration(
                labelText: 'Permanent access token',
                helperText: 'Sent to the server once; never kept on this phone',
                suffixIcon: IconButton(
                  tooltip: _showToken ? 'Hide' : 'Show',
                  onPressed: () => setState(() => _showToken = !_showToken),
                  icon: Icon(
                    _showToken ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: !_showToken,
              autocorrect: false,
              enableSuggestions: false,
              validator: WhatsAppConfigValidators.accessToken,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('whatsapp-verify-token'),
              controller: _verifyToken,
              decoration: const InputDecoration(
                labelText: 'Webhook verify token',
                helperText: 'Any string, 8 to 128 characters',
              ),
              autocorrect: false,
              validator: WhatsAppConfigValidators.verifyToken,
            ),
            const SizedBox(height: AppSpacing.lg),
            BigActionButton(
              key: const ValueKey('whatsapp-save'),
              label: 'Save to server',
              icon: Icons.cloud_upload_outlined,
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
