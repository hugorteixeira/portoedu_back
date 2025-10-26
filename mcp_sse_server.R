#!/usr/bin/env Rscript
# PortoEdu MCP Server with SSE support for clients that expect Server-Sent Events.

library(httpuv)
library(jsonlite)

# Source the service functions
source("R/service.R")

# Tool definitions
TOOLS <- list(
  list(
    name = "create_user",
    description = "Create a new user with name and ID in the PortoEdu system",
    inputSchema = list(
      type = "object",
      properties = list(
        name = list(type = "string", description = "User's name"),
        id = list(type = "string", description = "User's unique ID"),
        directory = list(type = "string", description = "Optional data directory path")
      ),
      required = c("name", "id")
    )
  ),
  list(
    name = "add_user_data",
    description = "Add or update a custom data field for a user",
    inputSchema = list(
      type = "object",
      properties = list(
        column_name = list(type = "string", description = "Name of the data field/column to add"),
        data = list(type = "string", description = "The data value to store"),
        name = list(type = "string", description = "User's name"),
        id = list(type = "string", description = "User's ID"),
        directory = list(type = "string", description = "Optional data directory path")
      ),
      required = c("column_name", "data", "name", "id")
    )
  ),
  list(
    name = "get_user",
    description = "Retrieve user data by name and ID",
    inputSchema = list(
      type = "object",
      properties = list(
        name = list(type = "string", description = "User's name"),
        id = list(type = "string", description = "User's ID"),
        directory = list(type = "string", description = "Optional data directory path")
      ),
      required = c("name", "id")
    )
  ),
  list(
    name = "delete_user",
    description = "Delete a user from the system",
    inputSchema = list(
      type = "object",
      properties = list(
        name = list(type = "string", description = "User's name"),
        id = list(type = "string", description = "User's ID"),
        rm_context = list(type = "boolean", description = "Whether to also delete the user's context file"),
        directory = list(type = "string", description = "Optional data directory path")
      ),
      required = c("name", "id")
    )
  ),
  list(
    name = "add_user_context",
    description = "Append context/conversation history for a user",
    inputSchema = list(
      type = "object",
      properties = list(
        context = list(type = "string", description = "Context text to append"),
        user = list(type = "string", description = "User's name"),
        id = list(type = "string", description = "User's ID"),
        directory = list(type = "string", description = "Optional data directory path")
      ),
      required = c("context", "user", "id")
    )
  ),
  list(
    name = "clear_user_context",
    description = "Clear all context/conversation history for a user",
    inputSchema = list(
      type = "object",
      properties = list(
        name = list(type = "string", description = "User's name"),
        id = list(type = "string", description = "User's ID"),
        directory = list(type = "string", description = "Optional data directory path")
      ),
      required = c("name", "id")
    )
  ),
  list(
    name = "get_user_context",
    description = "Retrieve all context/conversation history for a user",
    inputSchema = list(
      type = "object",
      properties = list(
        name = list(type = "string", description = "User's name"),
        user = list(type = "string", description = "Alternative parameter for user's name"),
        id = list(type = "string", description = "User's ID"),
        directory = list(type = "string", description = "Optional data directory path")
      ),
      required = c("id")
    )
  )
)

# Handle tool calls - with proper NULL handling
handle_tool_call <- function(tool_name, arguments) {
  result <- tryCatch({
    # Helper to safely get argument or NULL
    get_arg <- function(name) {
      if (is.null(arguments[[name]])) NULL else arguments[[name]]
    }

    switch(tool_name,
      "create_user" = svc_create_user(
        name = arguments$name,
        id = arguments$id,
        directory = get_arg("directory")
      ),
      "add_user_data" = svc_add_user_data(
        column_name = arguments$column_name,
        data = arguments$data,
        name = arguments$name,
        id = arguments$id,
        directory = get_arg("directory")
      ),
      "get_user" = svc_get_user(
        name = arguments$name,
        id = arguments$id,
        directory = get_arg("directory")
      ),
      "delete_user" = svc_delete_user(
        name = arguments$name,
        id = arguments$id,
        rm_context = get_arg("rm_context"),
        directory = get_arg("directory")
      ),
      "add_user_context" = svc_add_user_context(
        context = arguments$context,
        user = arguments$user,
        id = arguments$id,
        directory = get_arg("directory")
      ),
      "clear_user_context" = svc_clear_user_context(
        name = arguments$name,
        id = arguments$id,
        directory = get_arg("directory")
      ),
      "get_user_context" = svc_get_user_context(
        name = get_arg("name"),
        user = get_arg("user"),
        id = arguments$id,
        directory = get_arg("directory")
      ),
      list(error = paste("Unknown tool:", tool_name))
    )
  }, error = function(e) {
    list(error = paste("Error executing tool:", e$message))
  })
  result
}

# Create SSE response
sse_message <- function(data, event = "message", id = NULL) {
  msg <- ""
  if (!is.null(id)) msg <- paste0(msg, "id: ", id, "\n")
  if (!is.null(event)) msg <- paste0(msg, "event: ", event, "\n")
  msg <- paste0(msg, "data: ", data, "\n\n")
  msg
}

# HTTP request handler
app <- list(
  call = function(req) {
    path <- req$PATH_INFO
    method <- req$REQUEST_METHOD

    # Log all incoming requests
    cat(sprintf("[%s] %s %s\n", Sys.time(), method, path))
    if (!is.null(req$HTTP_USER_AGENT)) {
      cat(sprintf("  User-Agent: %s\n", req$HTTP_USER_AGENT))
    }

    # CORS headers
    headers <- list(
      "Access-Control-Allow-Origin" = "*",
      "Access-Control-Allow-Methods" = "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers" = "Content-Type, Accept"
    )

    # Handle OPTIONS for CORS
    if (method == "OPTIONS") {
      return(list(
        status = 200L,
        headers = headers,
        body = ""
      ))
    }

    # Health check
    if (path == "/health" && method == "GET") {
      headers$"Content-Type" <- "application/json"
      return(list(
        status = 200L,
        headers = headers,
        body = toJSON(list(status = "ok", server = "portoedu-mcp"), auto_unbox = TRUE)
      ))
    }

    # SSE endpoint
    if (method == "GET" && (path == "/sse" || path == "/" || path == "/events")) {
      headers$"Content-Type" <- "text/event-stream"
      headers$"Cache-Control" <- "no-cache"
      headers$"Connection" <- "keep-alive"

      # Send initial connection message
      body <- sse_message(toJSON(list(
        type = "connection",
        status = "connected",
        server = "portoedu-mcp"
      ), auto_unbox = TRUE), event = "open")

      return(list(
        status = 200L,
        headers = headers,
        body = body
      ))
    }

    # JSON-RPC POST endpoint
    if (method == "POST" && (path == "/" || path == "/rpc")) {
      body_raw <- req$rook.input$read()
      body_str <- rawToChar(body_raw)

      cat(sprintf("  Body: %s\n", substr(body_str, 1, 200)))

      request <- tryCatch(
        fromJSON(body_str, simplifyVector = FALSE),
        error = function(e) {
          cat(sprintf("  JSON Parse Error: %s\n", e$message))
          return(list(
            jsonrpc = "2.0",
            id = NULL,
            error = list(code = -32700, message = "Parse error")
          ))
        }
      )

      rpc_method <- request$method
      params <- request$params
      req_id <- request$id

      response <- NULL

      # Respect the protocol version provided by the client (defaulting to the latest known version).
      if (rpc_method == "initialize") {
        protocol_version <- "2024-11-05"
        if (!is.null(params$protocolVersion)) {
          protocol_version <- params$protocolVersion
        }

        response <- list(
          jsonrpc = "2.0",
          id = req_id,
          result = list(
            protocolVersion = protocol_version,
            capabilities = list(
              tools = list(
                listChanged = FALSE
              )
            ),
            serverInfo = list(
              name = "portoedu-server",
              version = "1.0.0"
            )
          )
        )
        cat(sprintf("  Initialized with protocol version: %s\n", protocol_version))
      } else if (rpc_method == "tools/list") {
        response <- list(
          jsonrpc = "2.0",
          id = req_id,
          result = list(tools = TOOLS)
        )
      } else if (rpc_method == "tools/call") {
        tool_name <- params$name
        arguments <- params$arguments
        result <- handle_tool_call(tool_name, arguments)

        response <- list(
          jsonrpc = "2.0",
          id = req_id,
          result = list(
            content = list(
              list(
                type = "text",
                text = toJSON(result, auto_unbox = TRUE, pretty = TRUE)
              )
            )
          )
        )
      } else if (rpc_method == "ping") {
        response <- list(
          jsonrpc = "2.0",
          id = req_id,
          result = list()
        )
      } else {
        response <- list(
          jsonrpc = "2.0",
          id = req_id,
          error = list(
            code = -32601,
            message = paste("Method not found:", rpc_method)
          )
        )
      }

      headers$"Content-Type" <- "application/json"
      return(list(
        status = 200L,
        headers = headers,
        body = toJSON(response, auto_unbox = TRUE)
      ))
    }

    # Handle OAuth discovery endpoints (not supported, but return proper errors)
    if (grepl("/.well-known/", path, fixed = TRUE)) {
      headers$"Content-Type" <- "application/json"
      return(list(
        status = 404L,
        headers = headers,
        body = toJSON(list(error = "OAuth not supported"), auto_unbox = TRUE)
      ))
    }

    # Handle registration endpoint
    if (path == "/register") {
      headers$"Content-Type" <- "application/json"
      return(list(
        status = 501L,
        headers = headers,
        body = toJSON(list(error = "Registration not required - server is public"), auto_unbox = TRUE)
      ))
    }

    # 404 for everything else
    return(list(
      status = 404L,
      headers = list("Content-Type" = "text/plain"),
      body = "Not Found"
    ))
  }
)

# Get configuration
host <- Sys.getenv("MCP_HOST", unset = "0.0.0.0")
port <- as.integer(Sys.getenv("MCP_PORT", unset = "8002"))

cat("\n=================================================\n")
cat("PortoEdu MCP SSE Server\n")
cat("=================================================\n")
cat(sprintf("Server starting on %s:%d\n", host, port))
cat("\nAvailable MCP tools:\n")
cat("  - create_user\n")
cat("  - add_user_data\n")
cat("  - get_user\n")
cat("  - delete_user\n")
cat("  - add_user_context\n")
cat("  - clear_user_context\n")
cat("  - get_user_context\n")
cat("\nEndpoints:\n")
cat(sprintf("  JSON-RPC: http://%s:%d/ (POST)\n", host, port))
cat(sprintf("  SSE Stream: http://%s:%d/sse (GET)\n", host, port))
cat(sprintf("  Health: http://%s:%d/health (GET)\n", host, port))
cat("\nPress Ctrl+C to stop the server\n")
cat("=================================================\n\n")

# Start server
runServer(host, port, app)
