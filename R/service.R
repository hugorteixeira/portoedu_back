# Core service and storage helpers for PortoEdu API

options(stringsAsFactors = FALSE)

# ---- Storage helpers ----
.default_base_dir <- function() {
  Sys.getenv("PORTOEDU_DATA_DIR", unset = "data")
}

.safe_dir <- function(directory = NULL) {
  if (is.null(directory) || is.na(directory) || directory == "") {
    directory <- .default_base_dir()
  }
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  directory
}

.users_csv_path <- function(directory) file.path(directory, "users.csv")

.read_users <- function(path) {
  if (!file.exists(path)) {
    df <- data.frame(name = character(), id = character(), stringsAsFactors = FALSE)
    utils::write.table(df, file = path, sep = ";", row.names = FALSE, col.names = TRUE, quote = TRUE, fileEncoding = "UTF-8")
    return(df)
  }
  df <- tryCatch(
    utils::read.csv(path, sep = ";", stringsAsFactors = FALSE, encoding = "UTF-8", check.names = FALSE),
    error = function(e) data.frame(stringsAsFactors = FALSE)
  )
  if (!("name" %in% names(df))) df$name <- NA_character_
  if (!("id" %in% names(df))) df$id <- NA_character_
  cols <- names(df)
  head_cols <- intersect(c("name", "id"), cols)
  other_cols <- setdiff(cols, head_cols)
  df[c(head_cols, other_cols)]
}

.write_users <- function(df, path) {
  cols <- names(df)
  head_cols <- intersect(c("name", "id"), cols)
  other_cols <- setdiff(cols, head_cols)
  df <- df[c(head_cols, other_cols)]
  utils::write.table(df, file = path, sep = ";", row.names = FALSE, col.names = TRUE, quote = TRUE, fileEncoding = "UTF-8")
}

.find_user_idx <- function(df, name, id) {
  which(tolower(df$name) == tolower(name) & as.character(df$id) == as.character(id))
}

.to_bool <- function(x, default = FALSE) {
  if (is.null(x) || (length(x) == 0)) return(default)
  if (is.logical(x)) return(ifelse(is.na(x), default, x))
  xv <- tolower(as.character(x))
  if (is.na(xv)) return(default)
  xv %in% c("1", "true", "t", "yes", "y", "on")
}

.ensure_user_row <- function(df, name, id) {
  idx <- .find_user_idx(df, name, id)
  if (length(idx) == 0) {
    new_row <- as.list(rep(NA_character_, length(names(df))))
    names(new_row) <- names(df)
    new_row$name <- as.character(name)
    new_row$id <- as.character(id)
    df <- rbind(df, new_row, stringsAsFactors = FALSE)
    idx <- nrow(df)
  }
  list(df = df, idx = idx)
}

.sanitize_for_filename <- function(x) {
  x <- as.character(x)
  # Allow letters, digits, underscore, hyphen; replace others with underscore
  x <- gsub("[^A-Za-z0-9_-]", "_", x)
  x <- gsub("_+", "_", x)
  x
}

.context_file <- function(directory, name, id) {
  ctx_dir <- file.path(directory, "contexts")
  dir.create(ctx_dir, recursive = TRUE, showWarnings = FALSE)
  fname <- paste0(.sanitize_for_filename(name), "_", .sanitize_for_filename(id), ".txt")
  file.path(ctx_dir, fname)
}

# ---- Service functions (called by endpoints) ----

svc_create_user <- function(name, id, directory = NULL) {
  base <- .safe_dir(directory)
  path <- .users_csv_path(base)
  users <- .read_users(path)

  name <- as.character(name)
  id <- as.character(id)

  res <- .ensure_user_row(users, name, id)
  users <- res$df
  idx <- res$idx

  dups <- .find_user_idx(users, name, id)
  if (length(dups) > 1) {
    users <- users[-dups[-1], , drop = FALSE]
    idx <- .find_user_idx(users, name, id)
  }

  .write_users(users, path)
  list(status = "created", user = as.list(users[idx, , drop = FALSE]))
}

svc_add_user_data <- function(column_name, data, name, id, directory = NULL) {
  base <- .safe_dir(directory)
  path <- .users_csv_path(base)
  users <- .read_users(path)

  name <- as.character(name)
  id <- as.character(id)
  column_name <- as.character(column_name)
  data <- as.character(data)

  res <- .ensure_user_row(users, name, id)
  users <- res$df
  idx <- res$idx

  if (!(column_name %in% names(users))) {
    users[[column_name]] <- NA_character_
  }

  users[idx, column_name] <- data
  .write_users(users, path)
  list(status = "updated", user = as.list(users[idx, , drop = FALSE]))
}

svc_get_user <- function(name, id, directory = NULL, res = NULL) {
  base <- .safe_dir(directory)
  path <- .users_csv_path(base)
  if (!file.exists(path)) {
    if (!is.null(res)) res$status <- 404
    return(list(error = "users.csv not found"))
  }

  users <- .read_users(path)
  idx <- .find_user_idx(users, name, id)
  if (length(idx) == 0) {
    if (!is.null(res)) res$status <- 404
    return(list(error = "user not found"))
  }
  as.list(users[idx[1], , drop = FALSE])
}

svc_delete_user <- function(name, id, rm_context = FALSE, directory = NULL, res = NULL) {
  base <- .safe_dir(directory)
  path <- .users_csv_path(base)
  if (!file.exists(path)) {
    if (!is.null(res)) res$status <- 404
    return(list(error = "users.csv not found"))
  }

  users <- .read_users(path)
  idx <- .find_user_idx(users, name, id)
  if (length(idx) == 0) {
    if (!is.null(res)) res$status <- 404
    return(list(error = "user not found"))
  }
  users <- users[-idx, , drop = FALSE]
  .write_users(users, path)
  # Optionally remove the user's context file
  if (.to_bool(rm_context, default = FALSE)) {
    ctx_file <- .context_file(base, name, id)
    if (file.exists(ctx_file)) {
      try(unlink(ctx_file), silent = TRUE)
    }
  }
  list(status = "deleted", name = name, id = as.character(id), rm_context = .to_bool(rm_context))
}

svc_add_user_context <- function(context, user, id, directory = NULL) {
  base <- .safe_dir(directory)
  ctx_file <- .context_file(base, user, id)
  cat(paste0(as.character(context), "\n"), file = ctx_file, append = TRUE)
  list(status = "appended", file = ctx_file)
}

svc_clear_user_context <- function(name, id, directory = NULL) {
  base <- .safe_dir(directory)
  ctx_file <- .context_file(base, name, id)
  if (file.exists(ctx_file)) file.remove(ctx_file)
  file.create(ctx_file)
  list(status = "cleared", file = ctx_file)
}

svc_get_user_context <- function(name = NULL, user = NULL, id, directory = NULL) {
  # Support either 'name' or 'user' as the name parameter
  if (is.null(name) || is.na(name) || name == "") {
    name <- user
  }
  base <- .safe_dir(directory)
  ctx_file <- .context_file(base, name, id)
  lines <- if (file.exists(ctx_file)) readLines(ctx_file, warn = FALSE, encoding = "UTF-8") else character(0)
  list(name = as.character(name), id = as.character(id), context = lines)
}
