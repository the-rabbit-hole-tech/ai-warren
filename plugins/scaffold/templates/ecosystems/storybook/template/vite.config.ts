/// <reference types="vitest/config" />
import react from "@vitejs/plugin-react";
import path from "node:path";
import { defineConfig } from "vite";
import dts from "vite-plugin-dts";
import { libInjectCss } from "vite-plugin-lib-inject-css";

// The package ships as a React component library: Vite library mode emits an
// ESM build (dist/index.js) and a CommonJS build (dist/index.cjs),
// vite-plugin-dts emits the public .d.ts, and libInjectCss keeps each
// component's styles tree-shakeable. The stylesheet lands in
// dist/index.css, named after the entry chunk, and package.json exports it as
// "./style.css". react / react-dom are peers, so they are externalized rather
// than bundled.
//
// CommonJS, not UMD: with cssCodeSplit on (libInjectCss needs it), Vite inlines
// the CSS into a UMD bundle behind document.createElement, so require() throws
// "document is not defined" outside a browser (SSR, plain Node, tests). The cjs
// build requires ./index.css instead, which a bundler resolves.
export default defineConfig({
  build: {
    copyPublicDir: false,
    lib: {
      // Keyed "index" so the entry chunk, its stylesheet and its types keep
      // the dist/index.* names package.json exports, while the source entry
      // is packages/main.ts.
      entry: { index: path.resolve(__dirname, "packages/main.ts") },
      fileName: (format) => (format === "es" ? "index.js" : "index.cjs"),
      formats: ["es", "cjs"],
    },
    rollupOptions: {
      external: ["react", "react-dom", "react/jsx-runtime"],
    },
  },
  plugins: [
    react(),
    libInjectCss(),
    // Stories and tests live outside packages/, so only library code is
    // typed and shipped.
    dts({
      include: ["packages"],
      insertTypesEntry: true,
    }),
  ],
  test: {
    coverage: {
      include: ["packages/**"],
      provider: "v8",
      reporter: ["text", "lcov"],
    },
    environment: "jsdom",
    globals: true,
    // A new library starts with no components, so an empty test run passes.
    passWithNoTests: true,
    setupFiles: ["./.storybook/vitest.setup.ts"],
  },
});
