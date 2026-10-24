import 'package:ampdent_core/ampdent_core.dart';

import 'message_template.dart';

// Post-operative notices. The instructions themselves sit behind the
// authenticated {link}; the body names only the procedure.

/// Codes of the post-operative instruction templates (generic + variants).
const List<String> postOpTemplateCodes = [
  'POST_OP_INSTRUCTIONS',
  'POST_OP_EXTRACTION',
  'POST_OP_RCT',
  'POST_OP_SCALING',
  'POST_OP_IMPLANT',
  'POST_OP_WHITENING',
];

const List<String> _postOpVariables = [
  'patient_name',
  'clinic_name',
  'link',
  'clinic_phone',
];

/// Post-operative instruction templates: one generic plus five procedure
/// variants whose only clinical word is the procedure name.
const List<MessageTemplate> postOpTemplates = [
  MessageTemplate(
    code: 'POST_OP_INSTRUCTIONS',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, thank you for visiting {clinic_name} today. Your '
        'after-care instructions for {procedure_name} are here: {link}. If '
        'anything worries you, call {clinic_phone}.',
    variables: [
      'patient_name',
      'clinic_name',
      'procedure_name',
      'link',
      'clinic_phone',
    ],
    description: 'Generic after-care notice; the procedure name is a variable.',
  ),
  MessageTemplate(
    code: 'POST_OP_EXTRACTION',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, thank you for visiting {clinic_name} today. Your '
        'after-care instructions for your tooth extraction are here: {link}. '
        'If anything worries you, call {clinic_phone}.',
    variables: _postOpVariables,
    description: 'After-care notice following an extraction.',
  ),
  MessageTemplate(
    code: 'POST_OP_RCT',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, thank you for visiting {clinic_name} today. Your '
        'after-care instructions for your root canal treatment are here: '
        '{link}. If anything worries you, call {clinic_phone}.',
    variables: _postOpVariables,
    description: 'After-care notice following a root canal sitting.',
  ),
  MessageTemplate(
    code: 'POST_OP_SCALING',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, thank you for visiting {clinic_name} today. Your '
        'after-care instructions for your scaling and polishing are here: '
        '{link}. If anything worries you, call {clinic_phone}.',
    variables: _postOpVariables,
    description: 'After-care notice following scaling.',
  ),
  MessageTemplate(
    code: 'POST_OP_IMPLANT',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, thank you for visiting {clinic_name} today. Your '
        'after-care instructions for your implant placement are here: {link}. '
        'If anything worries you, call {clinic_phone}.',
    variables: _postOpVariables,
    description: 'After-care notice following implant surgery.',
  ),
  MessageTemplate(
    code: 'POST_OP_WHITENING',
    channel: MessageChannel.whatsapp,
    category: MessageCategory.utility,
    body:
        'Hi {patient_name}, thank you for visiting {clinic_name} today. Your '
        'after-care instructions for your teeth whitening are here: {link}. '
        'If anything worries you, call {clinic_phone}.',
    variables: _postOpVariables,
    description: 'After-care notice following in-office whitening.',
  ),
];
