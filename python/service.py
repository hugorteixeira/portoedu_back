import csv
import os
from typing import List, Dict, Tuple


def default_base_dir() -> str:
    return os.environ.get("PORTOEDU_DATA_DIR", "data")


def safe_dir(directory: str | None) -> str:
    if not directory:
        directory = default_base_dir()
    os.makedirs(directory, exist_ok=True)
    return directory


def users_csv_path(directory: str) -> str:
    return os.path.join(directory, "users.csv")


def _ensure_csv_exists(path: str) -> None:
    if not os.path.exists(path):
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f, delimiter=";")
            writer.writerow(["name", "id"])  # header only


def read_users(path: str) -> Tuple[List[Dict[str, str]], List[str]]:
    _ensure_csv_exists(path)
    rows: List[Dict[str, str]] = []
    with open(path, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=";")
        fieldnames = list(reader.fieldnames or [])
        # Ensure required columns exist
        if "name" not in fieldnames:
            fieldnames.insert(0, "name")
        if "id" not in fieldnames:
            fieldnames.insert(1 if "name" in fieldnames else 0, "id")
        for row in reader:
            rows.append({k: (row.get(k, "") or "") for k in fieldnames})
    # Reorder fieldnames so name,id first
    head = [c for c in ["name", "id"] if c in fieldnames]
    tail = [c for c in fieldnames if c not in head]
    fieldnames = head + tail
    return rows, fieldnames


def write_users(rows: List[Dict[str, str]], fieldnames: List[str], path: str) -> None:
    head = [c for c in ["name", "id"] if c in fieldnames]
    tail = [c for c in fieldnames if c not in head]
    fieldnames = head + tail
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=";")
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fieldnames})


def find_user_index(rows: List[Dict[str, str]], name: str, id_: str) -> int | None:
    name_l = (name or "").lower()
    id_s = str(id_)
    for i, r in enumerate(rows):
        if (r.get("name", "").lower() == name_l) and (str(r.get("id", "")) == id_s):
            return i
    return None


def ensure_user_row(rows: List[Dict[str, str]], fieldnames: List[str], name: str, id_: str) -> Tuple[List[Dict[str, str]], int]:
    idx = find_user_index(rows, name, id_)
    if idx is None:
        row = {k: "" for k in fieldnames}
        row["name"] = str(name)
        row["id"] = str(id_)
        rows.append(row)
        idx = len(rows) - 1
    return rows, idx


def sanitize_for_filename(x: str) -> str:
    x = str(x)
    out = []
    for ch in x:
        if ch.isalnum() or ch in ("_", "-"):
            out.append(ch)
        else:
            out.append("_")
    s = "".join(out)
    while "__" in s:
        s = s.replace("__", "_")
    return s


def context_file(directory: str, name: str, id_: str) -> str:
    ctx_dir = os.path.join(directory, "contexts")
    os.makedirs(ctx_dir, exist_ok=True)
    fname = f"{sanitize_for_filename(name)}_{sanitize_for_filename(id_)}.txt"
    return os.path.join(ctx_dir, fname)


def to_bool(x, default: bool = False) -> bool:
    if x is None:
        return default
    if isinstance(x, bool):
        return x
    xv = str(x).strip().lower()
    if xv in {"1", "true", "t", "yes", "y", "on"}:
        return True
    if xv in {"0", "false", "f", "no", "n", "off"}:
        return False
    return default


# ---- Service functions ----

def svc_create_user(name: str, id_: str, directory: str | None = None) -> dict:
    base = safe_dir(directory)
    path = users_csv_path(base)
    rows, fields = read_users(path)
    rows, idx = ensure_user_row(rows, fields, name, id_)
    # Deduplicate any duplicates beyond the first
    seen = False
    uniq: List[Dict[str, str]] = []
    for r in rows:
        if (r.get("name", "").lower(), str(r.get("id", ""))) == (name.lower(), str(id_)):
            if seen:
                continue
            seen = True
        uniq.append(r)
    rows = uniq
    write_users(rows, fields, path)
    i = find_user_index(rows, name, id_)
    return {"status": "created", "user": rows[i] if i is not None else {"name": name, "id": str(id_)}}


def svc_add_user_data(column_name: str, data: str, name: str, id_: str, directory: str | None = None) -> dict:
    base = safe_dir(directory)
    path = users_csv_path(base)
    rows, fields = read_users(path)
    rows, idx = ensure_user_row(rows, fields, name, id_)
    if column_name not in fields:
        fields.append(column_name)
        # Ensure every row has the new field
        for r in rows:
            r.setdefault(column_name, "")
    rows[idx][column_name] = str(data)
    write_users(rows, fields, path)
    return {"status": "updated", "user": rows[idx]}


def svc_get_user(name: str, id_: str, directory: str | None = None) -> tuple[dict, int]:
    base = safe_dir(directory)
    path = users_csv_path(base)
    if not os.path.exists(path):
        return {"error": "users.csv not found"}, 404
    rows, fields = read_users(path)
    idx = find_user_index(rows, name, id_)
    if idx is None:
        return {"error": "user not found"}, 404
    return rows[idx], 200


def svc_delete_user(name: str, id_: str, rm_context=False, directory: str | None = None) -> tuple[dict, int]:
    base = safe_dir(directory)
    path = users_csv_path(base)
    if not os.path.exists(path):
        return {"error": "users.csv not found"}, 404
    rows, fields = read_users(path)
    idx = find_user_index(rows, name, id_)
    if idx is None:
        return {"error": "user not found"}, 404
    del rows[idx]
    write_users(rows, fields, path)
    if to_bool(rm_context, False):
        try:
            cf = context_file(base, name, id_)
            if os.path.exists(cf):
                os.remove(cf)
        except Exception:
            pass
    return {"status": "deleted", "name": name, "id": str(id_), "rm_context": to_bool(rm_context, False)}, 200


def svc_add_user_context(context: str, user: str, id_: str, directory: str | None = None) -> dict:
    base = safe_dir(directory)
    cf = context_file(base, user, id_)
    with open(cf, "a", encoding="utf-8") as f:
        f.write(f"{context}\n")
    return {"status": "appended", "file": cf}


def svc_clear_user_context(name: str, id_: str, directory: str | None = None) -> dict:
    base = safe_dir(directory)
    cf = context_file(base, name, id_)
    # Truncate by recreating
    try:
        if os.path.exists(cf):
            os.remove(cf)
    except Exception:
        pass
    open(cf, "w", encoding="utf-8").close()
    return {"status": "cleared", "file": cf}


def svc_get_user_context(name: str | None, user: str | None, id_: str, directory: str | None = None) -> dict:
    if not name:
        name = user
    base = safe_dir(directory)
    cf = context_file(base, name, id_)
    lines: List[str] = []
    if os.path.exists(cf):
        with open(cf, "r", encoding="utf-8", errors="ignore") as f:
            lines = [ln.rstrip("\n") for ln in f.readlines()]
    return {"name": str(name), "id": str(id_), "context": lines}

