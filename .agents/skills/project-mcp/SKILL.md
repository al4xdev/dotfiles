---
name: project-mcp
description: Activate and connect project-local MCP servers in DSH workspaces via .agents/mcp.json. Use whenever connecting to, discovering, or using MCP tools in a project.
---

# Project-Local MCP Activation

DSH includes the native `alex-project-mcp` plugin, which automatically injects MCP servers into agent sessions based on `<git-root>/.agents/mcp.json`.

## How to Activate

Declare the server in `.agents/mcp.json` at the root of the project:

```json
{
  "mcpServers": {
    "<serverName>": {
      "command": "<executable>",
      "args": ["<args>"],
      "cwd": "."
    }
  }
}
```

Any new agent, resumed session, or subagent created in the project will automatically have all server tools exposed natively as `mcp__<serverName>__<toolName>`.
