#!/usr/bin/env Rscript
# PortoEdu MCP Server using mcptools
# Exposes R service functions as MCP tools

library(mcptools)
library(jsonlite)

# Source the service functions
source("R/service.R")

# Initialize MCP server
# mcptools handles HTTP transport and JSON-RPC semantics for us; we only need to register handlers.
server <- mcp_server("portoedu-server")

# Register tool: create_user
server$add_tool(
  name = "create_user",
  description = "Create a new user with name and ID in the PortoEdu system",
  parameters = list(
    name = list(
      type = "string",
      description = "User's name",
      required = TRUE
    ),
    id = list(
      type = "string",
      description = "User's unique ID",
      required = TRUE
    ),
    directory = list(
      type = "string",
      description = "Optional data directory path (defaults to PORTOEDU_DATA_DIR env var or 'data')",
      required = FALSE
    )
  ),
  handler = function(name, id, directory = NULL) {
    result <- svc_create_user(name = name, id = id, directory = directory)
    toJSON(result, auto_unbox = TRUE)
  }
)

# Register tool: add_user_data
server$add_tool(
  name = "add_user_data",
  description = "Add or update a custom data field for a user",
  parameters = list(
    column_name = list(
      type = "string",
      description = "Name of the data field/column to add",
      required = TRUE
    ),
    data = list(
      type = "string",
      description = "The data value to store",
      required = TRUE
    ),
    name = list(
      type = "string",
      description = "User's name",
      required = TRUE
    ),
    id = list(
      type = "string",
      description = "User's ID",
      required = TRUE
    ),
    directory = list(
      type = "string",
      description = "Optional data directory path",
      required = FALSE
    )
  ),
  handler = function(column_name, data, name, id, directory = NULL) {
    result <- svc_add_user_data(
      column_name = column_name,
      data = data,
      name = name,
      id = id,
      directory = directory
    )
    toJSON(result, auto_unbox = TRUE)
  }
)

# Register tool: get_user
server$add_tool(
  name = "get_user",
  description = "Retrieve user data by name and ID",
  parameters = list(
    name = list(
      type = "string",
      description = "User's name",
      required = TRUE
    ),
    id = list(
      type = "string",
      description = "User's ID",
      required = TRUE
    ),
    directory = list(
      type = "string",
      description = "Optional data directory path",
      required = FALSE
    )
  ),
  handler = function(name, id, directory = NULL) {
    result <- svc_get_user(name = name, id = id, directory = directory)
    toJSON(result, auto_unbox = TRUE)
  }
)

# Register tool: delete_user
server$add_tool(
  name = "delete_user",
  description = "Delete a user from the system",
  parameters = list(
    name = list(
      type = "string",
      description = "User's name",
      required = TRUE
    ),
    id = list(
      type = "string",
      description = "User's ID",
      required = TRUE
    ),
    rm_context = list(
      type = "boolean",
      description = "Whether to also delete the user's context file",
      required = FALSE
    ),
    directory = list(
      type = "string",
      description = "Optional data directory path",
      required = FALSE
    )
  ),
  handler = function(name, id, rm_context = FALSE, directory = NULL) {
    result <- svc_delete_user(
      name = name,
      id = id,
      rm_context = rm_context,
      directory = directory
    )
    toJSON(result, auto_unbox = TRUE)
  }
)

# Register tool: add_user_context
server$add_tool(
  name = "add_user_context",
  description = "Append context/conversation history for a user",
  parameters = list(
    context = list(
      type = "string",
      description = "Context text to append",
      required = TRUE
    ),
    user = list(
      type = "string",
      description = "User's name",
      required = TRUE
    ),
    id = list(
      type = "string",
      description = "User's ID",
      required = TRUE
    ),
    directory = list(
      type = "string",
      description = "Optional data directory path",
      required = FALSE
    )
  ),
  handler = function(context, user, id, directory = NULL) {
    result <- svc_add_user_context(
      context = context,
      user = user,
      id = id,
      directory = directory
    )
    toJSON(result, auto_unbox = TRUE)
  }
)

# Register tool: clear_user_context
server$add_tool(
  name = "clear_user_context",
  description = "Clear all context/conversation history for a user",
  parameters = list(
    name = list(
      type = "string",
      description = "User's name",
      required = TRUE
    ),
    id = list(
      type = "string",
      description = "User's ID",
      required = TRUE
    ),
    directory = list(
      type = "string",
      description = "Optional data directory path",
      required = FALSE
    )
  ),
  handler = function(name, id, directory = NULL) {
    result <- svc_clear_user_context(name = name, id = id, directory = directory)
    toJSON(result, auto_unbox = TRUE)
  }
)

# Register tool: get_user_context
server$add_tool(
  name = "get_user_context",
  description = "Retrieve all context/conversation history for a user",
  parameters = list(
    name = list(
      type = "string",
      description = "User's name (optional if 'user' is provided)",
      required = FALSE
    ),
    user = list(
      type = "string",
      description = "Alternative parameter for user's name",
      required = FALSE
    ),
    id = list(
      type = "string",
      description = "User's ID",
      required = TRUE
    ),
    directory = list(
      type = "string",
      description = "Optional data directory path",
      required = FALSE
    )
  ),
  handler = function(name = NULL, user = NULL, id, directory = NULL) {
    result <- svc_get_user_context(
      name = name,
      user = user,
      id = id,
      directory = directory
    )
    toJSON(result, auto_unbox = TRUE)
  }
)

# Get host and port from environment variables
host <- Sys.getenv("MCP_HOST", unset = "127.0.0.1")
port <- as.integer(Sys.getenv("MCP_PORT", unset = "3000"))

# Start the server
# Print a quick summary so operators know how the instance is configured.
cat(sprintf("Starting PortoEdu MCP server on %s:%d\n", host, port))
cat("Available tools:\n")
cat("  - create_user\n")
cat("  - add_user_data\n")
cat("  - get_user\n")
cat("  - delete_user\n")
cat("  - add_user_context\n")
cat("  - clear_user_context\n")
cat("  - get_user_context\n\n")

server$start(host = host, port = port)
