# PortoEdu MCP Server Setup Guide

This guide will help you set up the PortoEdu MCP server to use your R functions with MCP-compatible assistants.

## Prerequisites

1. **R** (version 4.0 or higher)
2. **R packages**: Install required packages
   ```r
   install.packages("jsonlite")
   ```

## Installation

### Choose Your Server Version

Two versions are available:

1. **mcp_server_stdio.R** (Recommended) - Uses STDIO transport, works directly with MCP clients that read from standard input/output
2. **mcp_server.R** - Uses mcptools package (requires additional installation)

For most users, use **mcp_server_stdio.R** as it has fewer dependencies.

### Test the MCP Server

Test the STDIO server (recommended):

```bash
# The STDIO server reads from stdin and writes to stdout
# You can test it by piping JSON-RPC messages
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | Rscript mcp_server_stdio.R
```

Or test the mcptools server (if you have mcptools installed):

```bash
Rscript mcp_server.R
# Should start on http://127.0.0.1:3000
```

## Configuration

### Configure Your MCP Client

1. Locate your client's MCP configuration file or settings panel. The exact path varies by application—check your assistant's documentation for details.

2. Add the PortoEdu MCP server configuration. Use the STDIO variant for most desktop or CLI clients, or the HTTP variant if your client speaks MCP over HTTP.

   ```json
   {
     "mcpServers": {
       "portoedu": {
         "command": "Rscript",
         "args": ["/ABSOLUTE/PATH/TO/portoedu_back/mcp_server_stdio.R"],
         "env": {
           "PORTOEDU_DATA_DIR": "/ABSOLUTE/PATH/TO/portoedu_back/data"
         }
       }
     }
   }
   ```

   **Important**: Replace `/ABSOLUTE/PATH/TO/` with the actual full path to this directory.

3. Restart or reload your client so it picks up the new configuration.

4. The PortoEdu tools should now be listed among your MCP integrations.

### For OpenAI and Other AI Assistants

OpenAI doesn't natively support MCP yet. However, you can:

1. **Use the mcptools HTTP server** for API access:
   ```bash
   MCP_HOST=0.0.0.0 MCP_PORT=3000 Rscript mcp_server.R
   ```
   Then call the tools via HTTP JSON-RPC

2. **Create custom API endpoints** using your preferred framework (Plumber, etc.) that call the R service functions directly

3. **Wait for OpenAI MCP support** - they may add it in the future

## Available Tools

Once configured, you'll have access to these tools:

### `create_user`
Create a new user in the system.
- **Parameters**: `name` (string), `id` (string), `directory` (optional string)
- **Returns**: `{ status: "created", user: {...} }`

### `add_user_data`
Add or update custom data fields for a user.
- **Parameters**: `column_name` (string), `data` (string), `name` (string), `id` (string), `directory` (optional)
- **Returns**: `{ status: "updated", user: {...} }`

### `get_user`
Retrieve user information.
- **Parameters**: `name` (string), `id` (string), `directory` (optional)
- **Returns**: User object or `{ error: "..." }`

### `delete_user`
Remove a user from the system.
- **Parameters**: `name` (string), `id` (string), `rm_context` (optional boolean), `directory` (optional)
- **Returns**: `{ status: "deleted", name: "...", id: "...", rm_context: false }`

### `add_user_context`
Append conversation history/context for a user.
- **Parameters**: `context` (string), `user` (string), `id` (string), `directory` (optional)
- **Returns**: `{ status: "appended", file: "..." }`

### `clear_user_context`
Clear all conversation history for a user.
- **Parameters**: `name` (string), `id` (string), `directory` (optional)
- **Returns**: `{ status: "cleared", file: "..." }`

### `get_user_context`
Retrieve conversation history for a user.
- **Parameters**: `id` (string), `name` or `user` (optional string), `directory` (optional)
- **Returns**: `{ name: "...", id: "...", context: [...] }`

## Usage Examples

Once connected to your AI assistant, you can use natural language:

```
"Create a user named Alice with ID 12345"
"Add email alice@example.com to user Alice with ID 12345"
"Get all data for user Alice with ID 12345"
"Add this context to Alice's history: User asked about pricing"
"Show me Alice's conversation history"
```

## Troubleshooting

### Server won't start
- Check that R and required packages are installed
- Verify the path to `mcp_server.R` is correct
- Check that port 3000 is not already in use

### Tools don't appear in your client
- Restart your MCP client after config changes
- Check the config file path is correct
- Verify JSON syntax is valid (no trailing commas)
- Review your client's logs for configuration errors

### Permission errors
- Ensure the `data/` directory exists and is writable
- Check file permissions on the script: `chmod +x mcp_server.R`

## Environment Variables

- `PORTOEDU_DATA_DIR`: Directory for storing user data (default: `data`)
- `MCP_HOST`: Server host (default: `127.0.0.1`)
- `MCP_PORT`: Server port (default: `3000`)

## Development

To add new R functions to the MCP server:

1. Add your function to `R/service.R`
2. Register it in `mcp_server.R` using `server$add_tool()`
3. Restart the server

Example:
```r
server$add_tool(
  name = "my_new_tool",
  description = "Description of what it does",
  parameters = list(
    param1 = list(type = "string", description = "...", required = TRUE)
  ),
  handler = function(param1) {
    result <- my_r_function(param1)
    toJSON(result, auto_unbox = TRUE)
  }
)
```
