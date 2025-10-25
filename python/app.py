import os
from fastapi import FastAPI, Depends, Header, HTTPException, Query
from fastapi.responses import JSONResponse
import uvicorn

from service import (
    svc_create_user,
    svc_add_user_data,
    svc_get_user,
    svc_delete_user,
    svc_add_user_context,
    svc_clear_user_context,
    svc_get_user_context,
)

app = FastAPI(
    title="PortoEdu Mock API",
    description="Simple CSV-backed mock DB with API key auth",
    version="0.2.0",
)


def get_api_key(x_api_key: str | None = Header(default=None), api_key: str | None = Query(default=None)):
    expected = os.environ.get("PORTOEDU_API_KEY", "devkey")
    provided = x_api_key or api_key
    if not provided or str(provided) != str(expected):
        raise HTTPException(status_code=401, detail="unauthorized: provide X-API-Key header")
    return provided


@app.get("/health")
def health(_: str = Depends(get_api_key)):
    return {"status": "ok"}


@app.post("/create_user")
def create_user(
    name: str,
    id: str,
    directory: str | None = None,
    _: str = Depends(get_api_key),
):
    return svc_create_user(name, id, directory)


@app.post("/add_user_data")
def add_user_data(
    column_name: str,
    data: str,
    name: str,
    id: str,
    directory: str | None = None,
    _: str = Depends(get_api_key),
):
    return svc_add_user_data(column_name, data, name, id, directory)


@app.get("/get_user")
def get_user(
    name: str,
    id: str,
    directory: str | None = None,
    _: str = Depends(get_api_key),
):
    body, code = svc_get_user(name, id, directory)
    return JSONResponse(content=body, status_code=code)


@app.delete("/delete_user")
def delete_user(
    name: str,
    id: str,
    rm_context: bool | str = False,
    directory: str | None = None,
    _: str = Depends(get_api_key),
):
    body, code = svc_delete_user(name, id, rm_context=rm_context, directory=directory)
    return JSONResponse(content=body, status_code=code)


@app.post("/add_user_context")
def add_user_context(
    context: str,
    user: str,
    id: str,
    directory: str | None = None,
    _: str = Depends(get_api_key),
):
    return svc_add_user_context(context, user, id, directory)


@app.post("/clear_user_context")
def clear_user_context(
    name: str,
    id: str,
    directory: str | None = None,
    _: str = Depends(get_api_key),
):
    return svc_clear_user_context(name, id, directory)


@app.get("/get_user_context")
def get_user_context(
    name: str | None = None,
    user: str | None = None,
    id: str = Query(...),
    directory: str | None = None,
    _: str = Depends(get_api_key),
):
    return svc_get_user_context(name, user, id, directory)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8001"))  # use different default to avoid clashing with R
    print(f"[portoedu-python] API key via X-API-Key; current key: '{os.environ.get('PORTOEDU_API_KEY', 'devkey')}'")
    uvicorn.run(app, host="0.0.0.0", port=port, reload=False)
