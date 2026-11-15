import type { Preview } from "@storybook/react-vite";

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    a11y: {
      // 'todo' surfaces violations in the test UI without failing the build;
      // switch to 'error' once the catalog is clean to gate on accessibility.
      test: "todo",
    },
  },
};

export default preview;
