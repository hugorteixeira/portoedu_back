if (!requireNamespace("plumber", quietly = TRUE)) {
  cat("Installing plumber package...\n")
  install.packages("plumber", repos = "https://cloud.r-project.org/")
} else {
  cat("plumber already installed\n")
}
