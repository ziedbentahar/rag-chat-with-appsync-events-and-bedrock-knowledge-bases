import eslint from "@eslint/js";
import eslintConfigPrettier from "eslint-config-prettier";
import tseslint from "typescript-eslint";

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  eslintConfigPrettier,
  {
    languageOptions: {
      parserOptions: {},
    },
  },
  {
    files: ["*.js", "*.mjs"],
    ...tseslint.configs.disableTypeChecked,
  },
  {
    ignores: ["dist/", "node_modules/"],
  }
);
