// https://docs.expo.dev/guides/using-eslint/
const { defineConfig } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');
const prettierRecommended = require('eslint-plugin-prettier/recommended');

module.exports = defineConfig([
  expoConfig,
  prettierRecommended,
  {
    rules: {
      // CLAUDE.md rule 1: strict TypeScript, no escape hatches without a reason.
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/ban-ts-comment': [
        'error',
        { 'ts-ignore': 'allow-with-description', 'ts-expect-error': 'allow-with-description' },
      ],
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      // CLAUDE.md rule 7: every user-facing string goes through t(), so raw text in JSX is an error.
      'react/jsx-no-literals': ['error', { noStrings: false, ignoreProps: true }],
      // Silent catches hide failures in irreplaceable family data.
      'no-empty': ['error', { allowEmptyCatch: false }],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },
  {
    ignores: ['dist/*', '.expo/*', 'node_modules/*', 'supabase/functions/*'],
  },
]);
