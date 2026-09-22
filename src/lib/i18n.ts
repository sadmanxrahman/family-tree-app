import en from './en.json';

/**
 * Minimal translation layer. There is only English today, but routing every string
 * through t() now means adding a language later is a data change, not a rewrite.
 */

type Messages = typeof en;

// Builds the union of every dotted path to a string, e.g. "tabs.tree" | "feed.placeholderTitle".
// This makes a typo in a key a compile error instead of a blank label on someone's phone.
type LeafKeys<T, Prefix extends string = ''> = {
  [K in keyof T & string]: T[K] extends string ? `${Prefix}${K}` : LeafKeys<T[K], `${Prefix}${K}.`>;
}[keyof T & string];

export type TranslationKey = LeafKeys<Messages>;

export type TranslationParams = Record<string, string | number>;

const messages: Messages = en;

function lookup(key: string): string | undefined {
  let node: unknown = messages;
  for (const part of key.split('.')) {
    if (typeof node !== 'object' || node === null) return undefined;
    node = (node as Record<string, unknown>)[part];
  }
  return typeof node === 'string' ? node : undefined;
}

/**
 * Translate a key, filling `{{name}}` placeholders from params.
 * @example t('feed.addedBy', { name: 'Nana' })
 */
export function t(key: TranslationKey, params?: TranslationParams): string {
  const template = lookup(key);
  if (template === undefined) {
    // The type system should prevent this; if it happens, show the key rather than nothing.
    console.warn(`[i18n] Missing translation for "${key}"`);
    return key;
  }
  if (!params) return template;
  return template.replace(/\{\{(\w+)\}\}/g, (match, name: string) =>
    name in params ? String(params[name]) : match,
  );
}
