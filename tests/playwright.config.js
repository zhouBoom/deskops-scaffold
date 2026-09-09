// @ts-check
const { defineConfig, devices } = require('@playwright/test')

module.exports = defineConfig({
  // Test directory
  testDir: './e2e/specs',

  // Timeout per test
  timeout: 60_000,

  // Timeout per assertion
  expect: {
    timeout: 10_000,
  },

  // Re-run on failure
  retries: 1,

  // Sequential execution (single DB file — avoid race conditions)
  workers: 1,

  // Reporter
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
  ],

  use: {
    // Target frontend
    baseURL: 'http://127.0.0.1:5173',

    // Fixed 1920×1080 desktop viewport
    viewport: { width: 1920, height: 1080 },

    // Headless mode
    headless: true,

    // Screenshot & traces on failure
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',

    // Action timeout
    actionTimeout: 15_000,

    // Use system-installed Chrome to avoid downloading browser binaries.
    // In Docker (Playwright base image) the chromium binary is pre-bundled
    // and PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH is set automatically.
    // On a local Mac we fall back to the Applications bundle.
    launchOptions: {
      executablePath:
        process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ||
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    },
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
})
