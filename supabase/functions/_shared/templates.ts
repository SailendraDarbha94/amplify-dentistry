// templates.ts
// Loader for _shared/templates.json, the template export written by package:ampdent_messaging.
// Contract (one entry per template code + language):
//   { code, metaName, language, category: UTILITY | AUTHENTICATION | MARKETING,
//     bodyParams: [variable names in body order], buttons: [{ type, text }], body }
// metaName is the lower_snake_case of code and is the name the template is submitted under in Meta.

import exported from './templates.json' with { type: 'json' };

export type TemplateCategory = 'UTILITY' | 'AUTHENTICATION' | 'MARKETING';

export interface TemplateButton {
  type: 'QUICK_REPLY' | 'URL' | 'PHONE_NUMBER';
  text: string;
  url?: string;
  phoneNumber?: string;
}

export interface ExportedTemplate {
  code: string;
  metaName: string;
  language: string;
  category: TemplateCategory;
  bodyParams: string[];
  buttons: TemplateButton[];
  body: string;
}

export interface TemplateExport {
  generatedAt: string;
  templates: ExportedTemplate[];
}

const data = exported as unknown as TemplateExport;

/** Every exported template, as written by the messaging package. */
export function allTemplates(): ExportedTemplate[] {
  return data.templates;
}

/** ISO timestamp of the export. */
export function exportedAt(): string {
  return data.generatedAt;
}

/**
 * Template for `code` in `language`, falling back to English when the requested language was not
 * exported. Returns undefined when the code is unknown.
 */
export function findTemplate(code: string, language = 'en'): ExportedTemplate | undefined {
  const exact = data.templates.find((t) => t.code === code && t.language === language);
  if (exact) return exact;
  return data.templates.find((t) => t.code === code && t.language === 'en');
}

/** Meta template name for an app template code (`APPT_REMINDER_24H` -> `appt_reminder_24h`). */
export function metaNameFor(code: string): string {
  return code.toLowerCase();
}

/**
 * Body text in Meta's submission form: `{patient_name}` becomes `{{1}}`, numbered by position in
 * bodyParams. This is the exact text to paste into Business Manager when submitting for approval.
 */
export function metaBody(t: ExportedTemplate): string {
  return t.body.replace(/\{([a-z0-9_]+)\}/g, (match, name: string) => {
    const index = t.bodyParams.indexOf(name);
    return index === -1 ? match : `{{${index + 1}}}`;
  });
}

/** Problems that would make Meta reject the export or the sender mis-map variables. */
export function validateTemplate(t: ExportedTemplate): string[] {
  const problems: string[] = [];
  if (t.metaName !== metaNameFor(t.code)) {
    problems.push(`${t.code}: metaName must be ${metaNameFor(t.code)}`);
  }
  if (!/^[a-z0-9_]{1,512}$/.test(t.metaName)) {
    problems.push(`${t.code}: metaName has invalid characters`);
  }
  const seen: string[] = [];
  for (const m of t.body.matchAll(/\{([a-z0-9_]+)\}/g)) {
    if (!seen.includes(m[1])) seen.push(m[1]);
  }
  if (seen.join(',') !== t.bodyParams.join(',')) {
    problems.push(
      `${t.code}: bodyParams [${t.bodyParams}] do not match body placeholders [${seen}]`,
    );
  }
  if (!['UTILITY', 'AUTHENTICATION', 'MARKETING'].includes(t.category)) {
    problems.push(`${t.code}: category ${t.category} is not a Meta category`);
  }
  if (/\n|\t|\s{5,}/.test(t.body)) {
    problems.push(`${t.code}: body contains newlines, tabs or long runs of spaces`);
  }
  if (/AI detects/i.test(t.body)) problems.push(`${t.code}: body must never say "AI detects"`);
  return problems;
}
