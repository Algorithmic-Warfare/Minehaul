/** @type { import('@storybook/html-vite').StorybookConfig } */
const config = {
  framework: "@storybook/html-vite",
  stories: ["../stories/**/*.mdx", "../stories/**/*.stories.js"],
  addons: ["@storybook/addon-docs", "@storybook/addon-a11y"],
  core: { disableTelemetry: true },
};

export default config;
