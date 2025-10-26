# PortoEdu MCP Server - Quick Reference

## 🌐 Public Access

**Your Public MCP Server URL:**
```
https://retreat-link-known-satisfactory.trycloudflare.com
```

Note: This URL will change if you restart the Cloudflare tunnel. Always check the tunnel output for the current URL.

## 🚀 Server Status

- **Status:** ✅ Running
- **Local Address:** `172.16.59.250:8080`
- **Public URL:** Via Cloudflare Tunnel
- **Protocol:** MCP JSON-RPC over HTTP

## 📋 Available Tools

1. **create_user** - Create a new user
2. **add_user_data** - Add custom fields to user
3. **get_user** - Retrieve user information
4. **delete_user** - Remove a user
5. **add_user_context** - Add conversation history
6. **clear_user_context** - Clear conversation history
7. **get_user_context** - Get conversation history

## 🔧 Server Management

### Start the MCP server
```bash
cd /home/hugorteixeira/portoedu_back
MCP_HOST=0.0.0.0 MCP_PORT=8080 Rscript mcp_http_server.R &
```

### Start Cloudflare tunnel
```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

### Check server health
```bash
curl https://retreat-link-known-satisfactory.trycloudflare.com/health
```

### Stop the server
```bash
pkill -f mcp_http_server.R
```

## 📝 Example API Calls

### List all tools
```bash
curl -X POST https://retreat-link-known-satisfactory.trycloudflare.com/ \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

### Create a user
```bash
curl -X POST https://retreat-link-known-satisfactory.trycloudflare.com/ \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc":"2.0",
    "id":2,
    "method":"tools/call",
    "params":{
      "name":"create_user",
      "arguments":{"name":"Alice","id":"123"}
    }
  }'
```

### Get user data
```bash
curl -X POST https://retreat-link-known-satisfactory.trycloudflare.com/ \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc":"2.0",
    "id":3,
    "method":"tools/call",
    "params":{
      "name":"get_user",
      "arguments":{"name":"Alice","id":"123"}
    }
  }'
```

### Add user data
```bash
curl -X POST https://retreat-link-known-satisfactory.trycloudflare.com/ \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc":"2.0",
    "id":4,
    "method":"tools/call",
    "params":{
      "name":"add_user_data",
      "arguments":{
        "name":"Alice",
        "id":"123",
        "column_name":"email",
        "data":"alice@example.com"
      }
    }
  }'
```

## 🤖 Connect AI Assistants

### For OpenAI or other HTTP-based clients
Use the public URL:
```
https://retreat-link-known-satisfactory.trycloudflare.com
```

The server implements MCP JSON-RPC protocol over HTTP.

## 📁 Files

- `mcp_http_server.R` - HTTP MCP server (currently running)
- `mcp_server.R` - mcptools-based server (alternative)
- `R/service.R` - Core R functions
- `data/` - User data storage directory

## 🔒 Security Notes

- This is a quick development tunnel (no authentication)
- Cloudflare may terminate account-less tunnels without notice
- For production, set up a named Cloudflare tunnel with authentication
- Data is stored in CSV files in the `data/` directory

## 📚 Documentation

- `SETUP.md` - Detailed setup instructions
- `README.md` - Project overview
- `SERVER_INFO.md` - This file (quick reference)

---

**Server created:** October 25, 2025
**Last updated:** Check server logs for activity
