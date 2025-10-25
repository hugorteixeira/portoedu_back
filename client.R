# Simple R client for PortoEdu Mock API

portoedu_client <- function(base_url = "http://localhost:8000", api_key = Sys.getenv("PORTOEDU_API_KEY", unset = "devkey")) {
  base <- sub("/$", "", base_url)
  key <- as.character(api_key)
  stopped <- FALSE

  req <- function(verb, path, query = list(), body = list()) {
    if (stopped) stop("Client is disconnected", call. = FALSE)
    url <- sprintf("%s/%s", base, sub("^/", "", path))
    headers <- httr::add_headers(`X-API-Key` = key)
    if (identical(verb, "GET")) {
      httr::GET(url, headers, query = query)
    } else if (identical(verb, "POST")) {
      httr::POST(url, headers, body = body, encode = "form")
    } else if (identical(verb, "DELETE")) {
      httr::DELETE(url, headers, query = query)
    } else {
      stop("Unsupported verb")
    }
  }

  parse <- function(resp) {
    ct <- httr::http_type(resp)
    txt <- httr::content(resp, as = "text", encoding = "UTF-8")
    if (nzchar(txt) && grepl("json", ct, fixed = TRUE)) {
      jsonlite::fromJSON(txt, simplifyVector = FALSE)
    } else {
      txt
    }
  }

  list(
    base_url = base,
    api_key = key,
    health = function() {
      r <- req("GET", "/health")
      list(status = httr::status_code(r), body = parse(r))
    },
    create_user = function(name, id, directory = NULL) {
      body <- list(name = name, id = id)
      if (!is.null(directory)) body$directory <- directory
      r <- req("POST", "/create_user", body = body)
      list(status = httr::status_code(r), body = parse(r))
    },
    add_user_data = function(column_name, data, name, id, directory = NULL) {
      body <- list(column_name = column_name, data = data, name = name, id = id)
      if (!is.null(directory)) body$directory <- directory
      r <- req("POST", "/add_user_data", body = body)
      list(status = httr::status_code(r), body = parse(r))
    },
    get_user = function(name, id, directory = NULL) {
      query <- list(name = name, id = id)
      if (!is.null(directory)) query$directory <- directory
      r <- req("GET", "/get_user", query = query)
      list(status = httr::status_code(r), body = parse(r))
    },
    get_user_context = function(name = NULL, user = NULL, id, directory = NULL) {
      query <- list(id = id)
      if (!is.null(name)) query$name <- name
      if (!is.null(user)) query$user <- user
      if (!is.null(directory)) query$directory <- directory
      r <- req("GET", "/get_user_context", query = query)
      list(status = httr::status_code(r), body = parse(r))
    },
    delete_user = function(name, id, rm_context = FALSE, directory = NULL) {
      query <- list(name = name, id = id, rm_context = tolower(as.character(isTRUE(rm_context) || tolower(as.character(rm_context)) %in% c("1","true","t","yes","y","on"))))
      if (!is.null(directory)) query$directory <- directory
      r <- req("DELETE", "/delete_user", query = query)
      list(status = httr::status_code(r), body = parse(r))
    },
    add_user_context = function(context, user, id, directory = NULL) {
      body <- list(context = context, user = user, id = id)
      if (!is.null(directory)) body$directory <- directory
      r <- req("POST", "/add_user_context", body = body)
      list(status = httr::status_code(r), body = parse(r))
    },
    clear_user_context = function(name, id, directory = NULL) {
      body <- list(name = name, id = id)
      if (!is.null(directory)) body$directory <- directory
      r <- req("POST", "/clear_user_context", body = body)
      list(status = httr::status_code(r), body = parse(r))
    },
    disconnect = function() {
      stopped <<- TRUE
      invisible(TRUE)
    }
  )
}

# Example usage (uncomment to try):
client <- portoedu_client(api_key = "devkey")
client$health()
client$create_user("Alice", 123)
client$add_user_data("grade", "A", "Alice", 123)
client$get_user("Alice", 123)
client$add_user_context("First note", "Alice", 123)
client$clear_user_context("Alice", 123)
client$delete_user("Alice", 123)
client$disconnect()
