#!/usr/bin/env Rscript
# Installation script for PortoEdu MCP Server

cat("=== PortoEdu MCP Server Installation ===\n\n")

# Check R version
r_version <- getRversion()
if (r_version < "4.0") {
  cat("WARNING: R version 4.0 or higher is recommended. You have:", R.version.string, "\n")
} else {
  cat("✓ R version OK:", R.version.string, "\n")
}

# Install required packages
cat("\nInstalling required packages...\n")

required_packages <- c("jsonlite")
optional_packages <- c("mcptools")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg, repos = "https://cloud.r-project.org/")
  } else {
    cat("✓", pkg, "already installed\n")
  }
}

cat("\nOptional packages:\n")
for (pkg in optional_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("  -", pkg, "(not installed - needed for mcp_server.R only)\n")
  } else {
    cat("  ✓", pkg, "installed\n")
  }
}

# Create data directory
if (!dir.exists("data")) {
  dir.create("data", recursive = TRUE)
  cat("\n✓ Created data directory\n")
} else {
  cat("\n✓ Data directory exists\n")
}

# Make scripts executable (Unix-like systems)
if (.Platform$OS.type == "unix") {
  system("chmod +x mcp_server.R mcp_server_stdio.R")
  cat("✓ Made scripts executable\n")
}

cat("\n=== Installation Complete ===\n\n")
cat("Next steps:\n")
cat("1. Read SETUP.md for configuration instructions\n")
cat("2. Configure your MCP-compatible client to use this MCP server\n")
cat("3. For your config, use this path:\n")
cat("   ", normalizePath(getwd()), "/mcp_server_stdio.R\n\n")

# Show sample client config
cat("Sample MCP client config snippet:\n")
cat('{\n')
cat('  "mcpServers": {\n')
cat('    "portoedu": {\n')
cat('      "command": "Rscript",\n')
cat('      "args": ["', normalizePath(file.path(getwd(), "mcp_server_stdio.R")), '"],\n', sep = "")
cat('      "env": {\n')
cat('        "PORTOEDU_DATA_DIR": "', normalizePath(file.path(getwd(), "data")), '"\n', sep = "")
cat('      }\n')
cat('    }\n')
cat('  }\n')
cat('}\n\n')
