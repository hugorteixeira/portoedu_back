PortoEdu Mock API (Python + FastAPI)

Python version of the mock education API. Uses a semicolon-separated CSV for users and per-user context files. Mirrors the R plumber version's routes and behavior, including API-key auth.

Run
- Python 3.10+
- In a terminal: `cd python`
- Install deps: `pip install -r requirements.txt`
- Set an API key (default is `devkey`):
  - macOS/Linux: `export PORTOEDU_API_KEY=devkey`
  - Windows (PowerShell): `$env:PORTOEDU_API_KEY='devkey'`
- Start server: `python app.py`
- Defaults: port `8001`, data dir `data` (override with env var `PORTOEDU_DATA_DIR`).

Auth
- All endpoints require `X-API-Key: <PORTOEDU_API_KEY>` header or `?api_key=<PORTOEDU_API_KEY>` query param.

Endpoints
- GET `/health` → `{ "status": "ok" }`
- POST `/create_user` params: `name`, `id`, optional `directory`
- POST `/add_user_data` params: `column_name`, `data`, `name`, `id`, optional `directory`
- GET `/get_user` params: `name`, `id`, optional `directory`
- DELETE `/delete_user` params: `name`, `id`, `rm_context` (boolean), optional `directory`
- POST `/add_user_context` params: `context`, `user`, `id`, optional `directory`
- POST `/clear_user_context` params: `name`, `id`, optional `directory`
- GET `/get_user_context` params: `name` or `user`, `id`, optional `directory`

Curl Examples
```sh
# Health
curl -s -H 'X-API-Key: devkey' http://localhost:8001/health

# Create user
curl -s -H 'X-API-Key: devkey' -X POST "http://localhost:8001/create_user" \
  -d name=Alice -d id=123

# Add user data
curl -s -H 'X-API-Key: devkey' -X POST "http://localhost:8001/add_user_data" \
  -d column_name=grade -d data=A -d name=Alice -d id=123

# Get user
curl -s -H 'X-API-Key: devkey' "http://localhost:8001/get_user?name=Alice&id=123"

# Delete user and remove context
curl -s -H 'X-API-Key: devkey' -X DELETE "http://localhost:8001/delete_user?name=Alice&id=123&rm_context=true"

# Add user context line
curl -s -H 'X-API-Key: devkey' -X POST "http://localhost:8001/add_user_context" \
  -d context="This is a note" -d user=Alice -d id=123

# Clear user context
curl -s -H 'X-API-Key: devkey' -X POST "http://localhost:8001/clear_user_context" \
  -d name=Alice -d id=123

# Get user context lines
curl -s -H 'X-API-Key: devkey' "http://localhost:8001/get_user_context?name=Alice&id=123"
```

Python Client
- Optional helper to test endpoints: `client.py`
```bash
python client.py
```

Repo layout (Python)
- `app.py` — FastAPI router and auth
- `service.py` — CSV/context helpers and service functions
- `client.py` — small testing client
- `requirements.txt` — dependencies
