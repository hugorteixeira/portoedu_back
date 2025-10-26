#!/usr/bin/env Rscript
# PortoEdu MCP HTTP Server
# Provides JSON-RPC MCP endpoints over HTTP

library(plumber)
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

# Handle tool calls by dispatching to service functions and wrapping errors.
handle_tool_call <- function(tool_name, arguments) {
  result <- tryCatch({
    switch(tool_name,
      "create_user" = {
        svc_create_user(
          name = arguments$name,
          id = arguments$id,
          directory = arguments$directory
        )
      },
      "add_user_data" = {
        svc_add_user_data(
          column_name = arguments$column_name,
          data = arguments$data,
          name = arguments$name,
          id = arguments$id,
          directory = arguments$directory
        )
      },
      "get_user" = {
        svc_get_user(
          name = arguments$name,
          id = arguments$id,
          directory = arguments$directory
        )
      },
      "delete_user" = {
        svc_delete_user(
          name = arguments$name,
          id = arguments$id,
          rm_context = arguments$rm_context,
          directory = arguments$directory
        )
      },
      "add_user_context" = {
        svc_add_user_context(
          context = arguments$context,
          user = arguments$user,
          id = arguments$id,
          directory = arguments$directory
        )
      },
      "clear_user_context" = {
        svc_clear_user_context(
          name = arguments$name,
          id = arguments$id,
          directory = arguments$directory
        )
      },
      "get_user_context" = {
        svc_get_user_context(
          name = arguments$name,
          user = arguments$user,
          id = arguments$id,
          directory = arguments$directory
        )
      },
      list(error = paste("Unknown tool:", tool_name))
    )
  }, error = function(e) {
    list(error = paste("Error executing tool:", e$message))
  })

  result
}

#* @apiTitle PortoEdu MCP Server
#* @apiDescription MCP JSON-RPC server for PortoEdu user management

#* Handle MCP JSON-RPC requests
#* @post /
#* @serializer unboxedJSON
function(req) {
  body <- req$postBody

  request <- tryCatch(
    fromJSON(body, simplifyVector = FALSE),
    error = function(e) {
      return(list(
        jsonrpc = "2.0",
        id = NULL,
        error = list(code = -32700, message = "Parse error")
      ))
    }
  )

  method <- request$method
  params <- request$params
  req_id <- request$id

  if (method == "initialize") {
    return(list(
      jsonrpc = "2.0",
      id = req_id,
      result = list(
        protocolVersion = "2024-11-05",
        capabilities = list(tools = list()),
        serverInfo = list(
          name = "portoedu-server",
          version = "1.0.0"
        )
      )
    ))
  } else if (method == "tools/list") {
    return(list(
      jsonrpc = "2.0",
      id = req_id,
      result = list(tools = TOOLS)
    ))
  } else if (method == "tools/call") {
    tool_name <- params$name
    arguments <- params$arguments

    result <- handle_tool_call(tool_name, arguments)

    return(list(
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
    ))
  } else if (method == "ping") {
    return(list(
      jsonrpc = "2.0",
      id = req_id,
      result = list()
    ))
  } else {
    return(list(
      jsonrpc = "2.0",
      id = req_id,
      error = list(
        code = -32601,
        message = paste("Method not found:", method)
      )
    ))
  }
}

#* Health check endpoint
#* @get /health
function() {
  list(status = "ok", server = "portoedu-mcp")
}

# Get configuration from environment
host <- Sys.getenv("MCP_HOST", unset = "0.0.0.0")
port <- as.integer(Sys.getenv("MCP_PORT", unset = "8002"))

cat("\n=================================================\n")
cat("PortoEdu MCP HTTP Server\n")
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
cat(sprintf("  MCP JSON-RPC: http://%s:%d/\n", host, port))
cat(sprintf("  Health check: http://%s:%d/health\n", host, port))
cat("\nPress Ctrl+C to stop the server\n")
cat("=================================================\n\n")

# Create and run the plumber API
pr() |>
  pr_get("/health", function() {
    list(status = "ok", server = "portoedu-mcp")
  }) |>
  pr_post("/", function(req) {
    body <- req$postBody

    request <- tryCatch(
      fromJSON(body, simplifyVector = FALSE),
      error = function(e) {
        return(list(
          jsonrpc = "2.0",
          id = NULL,
          error = list(code = -32700, message = "Parse error")
        ))
      }
    )

    method <- request$method
    params <- request$params
    req_id <- request$id

    if (method == "initialize") {
      return(list(
        jsonrpc = "2.0",
        id = req_id,
        result = list(
          protocolVersion = "2024-11-05",
          capabilities = list(tools = list()),
          serverInfo = list(
            name = "portoedu-server",
            version = "1.0.0"
          )
        )
      ))
    } else if (method == "tools/list") {
      return(list(
        jsonrpc = "2.0",
        id = req_id,
        result = list(tools = TOOLS)
      ))
    } else if (method == "tools/call") {
      tool_name <- params$name
      arguments <- params$arguments

      result <- handle_tool_call(tool_name, arguments)

      return(list(
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
      ))
    } else if (method == "ping") {
      return(list(
        jsonrpc = "2.0",
        id = req_id,
        result = list()
      ))
    } else {
      return(list(
        jsonrpc = "2.0",
        id = req_id,
        error = list(
          code = -32601,
          message = paste("Method not found:", method)
        )
      ))
    }
  }) |>
  pr_run(host = host, port = port)
