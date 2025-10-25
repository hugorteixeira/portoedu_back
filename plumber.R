#!/usr/bin/env Rscript

# Minimal education service mock API using plumber (modular)
library(plumber)

options(stringsAsFactors = FALSE)

# Load service functions
if (file.exists("R/service.R")) source("R/service.R")

# ===== API Metadata =====

#* @apiTitle PortoEdu Mock API
#* @apiDescription CSV-backed mock DB with API key auth
#* @apiVersion 0.2.0

# ===== Auth Filter =====

.get_api_key <- function() {
  key <- Sys.getenv("PORTOEDU_API_KEY", unset = "devkey")
  key
}

.parse_query <- function(qs) {
  if (is.null(qs) || qs == "") return(list())
  parts <- strsplit(qs, "&", fixed = TRUE)[[1]]
  out <- list()
  for (p in parts) {
    kv <- strsplit(p, "=", fixed = TRUE)[[1]]
    k <- utils::URLdecode(kv[1])
    v <- if (length(kv) > 1) utils::URLdecode(kv[2]) else ""
    out[[k]] <- v
  }
  out
}

#* Require X-API-Key or api_key query param
#* @filter auth
function(req, res) {
  expected <- .get_api_key()
  provided <- req$HTTP_X_API_KEY
  if (is.null(provided) || provided == "") {
    q <- .parse_query(req$QUERY_STRING)
    provided <- q$api_key
  }
  if (is.null(provided) || !identical(as.character(provided), as.character(expected))) {
    res$status <- 401
    return(list(error = "unauthorized", hint = "provide X-API-Key header"))
  }
  forward()
}

# ===== Health =====

#* Health check
#* @get /health
function() {
  list(status = "ok")
}

# ===== Users =====

#* Create user
#* @param name:string User name
#* @param id:string User ID
#* @param directory:string Optional base directory for storage
#* @post /create_user
function(name, id, directory = NULL) {
  svc_create_user(name, id, directory)
}

#* Add or update user data column
#* @param column_name:string Column to set
#* @param data:string Value to assign
#* @param name:string User name
#* @param id:string User ID
#* @param directory:string Optional base directory for storage
#* @post /add_user_data
function(column_name, data, name, id, directory = NULL) {
  svc_add_user_data(column_name, data, name, id, directory)
}

#* Get user data as a list
#* @param name:string User name
#* @param id:string User ID
#* @param directory:string Optional base directory for storage
#* @get /get_user
function(name, id, directory = NULL, res) {
  svc_get_user(name, id, directory, res)
}

#* Delete user by name and id
#* Optionally remove context file with rm_context=true
#* If directory not provided, uses default base dir
#* @param name:string User name
#* @param id:string User ID
#* @param rm_context:boolean Remove context file if TRUE
#* @param directory:string Optional base directory for storage
#* @delete /delete_user
function(name, id, rm_context = FALSE, directory = NULL, res) {
  svc_delete_user(name, id, rm_context = rm_context, directory = directory, res = res)
}

# ===== Context =====

#* Append context line for a user (per-user text file)
#* @param context:string Context text to append
#* @param user:string User name
#* @param id:string User ID
#* @param directory:string Optional base directory for storage
#* @post /add_user_context
function(context, user, id, directory = NULL) {
  svc_add_user_context(context, user, id, directory)
}

#* Clear all context lines for a user
#* @param name:string User name
#* @param id:string User ID
#* @param directory:string Optional base directory for storage
#* @post /clear_user_context
function(name, id, directory = NULL) {
  svc_clear_user_context(name, id, directory)
}

#* Get all context lines for a user
#* Accepts either 'name' or 'user' as name
#* @param name:string User name
#* @param user:string User name (alias)
#* @param id:string User ID
#* @param directory:string Optional base directory for storage
#* @get /get_user_context
function(name = NULL, user = NULL, id, directory = NULL) {
  svc_get_user_context(name = name, user = user, id = id, directory = directory)
}

# ===== Plumber router (optional for Rscript execution) =====
if (identical(environment(), globalenv())) {
  # Allow running as `Rscript plumber.R`
  pr <- plumb("plumber.R")
  key <- .get_api_key()
  message(sprintf("[portoedu] API key required via X-API-Key. Current key: '%s'", key))
  pr$run(host = "0.0.0.0", port = as.integer(Sys.getenv("PORT", unset = 8000)))
}
