PortoEdu Mock API (R + plumber)

Quick mock database-like API for a hackathon. Stores user data in a `users.csv` (semicolon-separated) and user context lines in per-user text files. Built with the `plumber` package.

Run
- Ensure R is installed and the packages are available:
  - `install.packages(c("plumber","httr","jsonlite"))`
- Set an API key (change this for real use):
  - macOS/Linux: `export PORTOEDU_API_KEY=devkey`
  - Windows (PowerShell): `$env:PORTOEDU_API_KEY='devkey'`
- Start the server: `Rscript plumber.R` (or `R -e "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"`).
- Defaults: port `8000`, data dir `data` (override with env var `PORTOEDU_DATA_DIR`).

Auth
- All endpoints require an API key.
- Send header `X-API-Key: <PORTOEDU_API_KEY>` or use `?api_key=<PORTOEDU_API_KEY>`.

Endpoints
- GET `/health` → `{ "status": "ok" }`
- POST `/create_user` params: `name`, `id`, optional `directory`
- POST `/add_user_data` params: `column_name`, `data`, `name`, `id`, optional `directory`
- GET `/get_user` params: `name`, `id`, optional `directory`
- DELETE `/delete_user` params: `name`, `id`, `rm_context` (boolean, default false), optional `directory`
- POST `/add_user_context` params: `context`, `user`, `id`, optional `directory`
- POST `/clear_user_context` params: `name`, `id`, optional `directory`
- GET `/get_user_context` params: `name` or `user`, `id`, optional `directory`

Notes
- The CSV is semicolon-separated and lives at `<directory>/users.csv`.
- Unknown columns are created on-the-fly by `/add_user_data`.
- If a user doesn’t exist when adding user data, it is created automatically.
- Context files live at `<directory>/contexts/<name>_<id>.txt`.

Curl Examples
```sh
# Health
curl -s -H 'X-API-Key: devkey' http://localhost:8000/health

# Create user
curl -s -X POST "http://localhost:8000/create_user" \
  -H 'X-API-Key: devkey' \
  -d name=Alice -d id=123

# Add user data (creates column if needed)
curl -s -X POST "http://localhost:8000/add_user_data" \
  -H 'X-API-Key: devkey' \
  -d column_name=grade -d data=A -d name=Alice -d id=123

# Get user
curl -s -H 'X-API-Key: devkey' "http://localhost:8000/get_user?name=Alice&id=123"

# Delete user (keep context)
curl -s -H 'X-API-Key: devkey' -X DELETE "http://localhost:8000/delete_user?name=Alice&id=123"

# Delete user and remove context file
curl -s -H 'X-API-Key: devkey' -X DELETE "http://localhost:8000/delete_user?name=Alice&id=123&rm_context=true"

# Add user context line
curl -s -H 'X-API-Key: devkey' -X POST "http://localhost:8000/add_user_context" \
  -d context="This is a note" -d user=Alice -d id=123

# Clear user context
curl -s -H 'X-API-Key: devkey' -X POST "http://localhost:8000/clear_user_context" \
  -d name=Alice -d id=123

# Get user context lines
curl -s -H 'X-API-Key: devkey' "http://localhost:8000/get_user_context?name=Alice&id=123"
```

Repo Layout
- `plumber.R` — router, auth filter, routes
- `R/service.R` — storage and service functions
- `client.R` — small R client to test endpoints
- `data/` — default storage folder (created at runtime)
- `python/` — Python FastAPI version (see `python/README.md`)

Client Example (R)
```r
source("client.R")
client <- portoedu_client(base_url = "http://localhost:8000", api_key = Sys.getenv("PORTOEDU_API_KEY", "devkey"))
client$health()
client$create_user("Alice", 123)
client$add_user_data("grade", "A", "Alice", 123)
client$get_user("Alice", 123)
client$add_user_context("This is a note", "Alice", 123)
client$get_user_context(name = "Alice", id = 123)
client$clear_user_context("Alice", 123)
client$delete_user("Alice", 123, rm_context = TRUE)
client$disconnect()
```
