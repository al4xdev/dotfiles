---
name: playwright
description: Browser automation, E2E testing, UI inspection, and page navigation powered by Playwright and Microsoft Playwright MCP.
---

# Playwright Skill

This skill provides browser automation capabilities powered by **Microsoft Playwright** and `@playwright/mcp`.

## Features & Capabilities
1. **Automated Web Browser Testing**:
   - Run end-to-end tests for web applications (React, Vite, Next.js, Vue, HTML/JS).
   - Verify UI layouts, button clicks, form inputs, dynamic state changes, and modal popups.
2. **Visual Inspection & Screenshots**:
   - Capture full page screenshots or specific element snapshots for verification.
3. **Form & Interactive Automation**:
   - Fill text fields, trigger click events, scroll, press keyboard shortcuts, and navigate between URLs.
4. **Performance & Console Monitoring**:
   - Monitor browser console errors, failed network requests, and page load performance.

---

## MCP Server Integration

Playwright is configured as an MCP server:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
```

---

## Command Line & E2E Testing Workflows

### 1. Running Playwright Tests directly in Node/Vite Projects
```bash
npx playwright test
```

### 2. Launching Playwright MCP interactively
```bash
npx -y @playwright/mcp@latest --headless
```

### 3. Key Playwright MCP Tools Available
- `playwright_navigate`: Navigate to a specified URL.
- `playwright_click`: Click elements using CSS selectors or text.
- `playwright_fill`: Fill input fields.
- `playwright_screenshot`: Take a screenshot of the active page.
- `playwright_evaluate`: Run custom JavaScript in the browser context.

---

## Best Practices
- Run web servers locally (e.g. `npm run dev` at `http://localhost:5173`) before running Playwright tests or navigation.
- For headless execution on Linux/Wayland, ensure `--headless` mode is enabled.
- Save test artifacts (screenshots, traces) in the conversation artifact directory or `/tmp/playwright-reports/`.
