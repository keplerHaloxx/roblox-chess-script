import tsParser from '@typescript-eslint/parser';
import tseslint from '@typescript-eslint/eslint-plugin';
import svelte from 'eslint-plugin-svelte';
import svelteParser from 'svelte-eslint-parser';

export default [
  // Global ignores
  {
    ignores: [
      'build/**',
      '.svelte-kit/**',
      'src-tauri/gen/**',
      'src-tauri/target/**',
      'node_modules/**',
    ],
  },

  // Base JS/TS linting (non-Svelte)
  {
    files: ['**/*.{js,ts}'],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {
      ...tseslint.configs.recommended.rules,
    },
  },

  // Svelte linting (+ TS in <script lang="ts">)
  {
    files: ['**/*.svelte'],
    languageOptions: {
      parser: svelteParser,
      parserOptions: {
        parser: tsParser,
        ecmaVersion: 'latest',
        sourceType: 'module',
        extraFileExtensions: ['.svelte'],
      },
    },
  },
  ...svelte.configs['flat/recommended'],

  // Prettier compatibility (don’t fight formatting)
  {
    rules: {
      'svelte/indent': 'off',
    },
  },
];
