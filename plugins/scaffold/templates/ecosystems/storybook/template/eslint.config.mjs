// Flat config: the TypeScript and Storybook rule sets. ESLint is the formatter here (there is
// no Prettier).
import js from "@eslint/js";
import storybook from "eslint-plugin-storybook";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist/", "storybook-static/", "coverage/"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...storybook.configs["flat/recommended"],
);
