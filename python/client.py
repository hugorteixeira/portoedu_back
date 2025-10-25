import os
from typing import Optional

import requests


class PortoEduClient:
    def __init__(self, base_url: str = "http://localhost:8001", api_key: Optional[str] = None):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key or os.environ.get("PORTOEDU_API_KEY", "devkey")
        self._stopped = False

    def _headers(self):
        return {"X-API-Key": self.api_key}

    def _check(self):
        if self._stopped:
            raise RuntimeError("Client is disconnected")

    def health(self):
        self._check()
        r = requests.get(f"{self.base_url}/health", headers=self._headers())
        return r.status_code, r.json() if r.headers.get("content-type", "").startswith("application/json") else r.text

    def create_user(self, name, id, directory=None):
        self._check()
        data = {"name": name, "id": id}
        if directory:
            data["directory"] = directory
        r = requests.post(f"{self.base_url}/create_user", headers=self._headers(), data=data)
        return r.status_code, r.json()

    def add_user_data(self, column_name, data, name, id, directory=None):
        self._check()
        payload = {"column_name": column_name, "data": data, "name": name, "id": id}
        if directory:
            payload["directory"] = directory
        r = requests.post(f"{self.base_url}/add_user_data", headers=self._headers(), data=payload)
        return r.status_code, r.json()

    def get_user(self, name, id, directory=None):
        self._check()
        params = {"name": name, "id": id}
        if directory:
            params["directory"] = directory
        r = requests.get(f"{self.base_url}/get_user", headers=self._headers(), params=params)
        return r.status_code, r.json()

    def delete_user(self, name, id, rm_context=False, directory=None):
        self._check()
        params = {"name": name, "id": id, "rm_context": str(bool(rm_context)).lower()}
        if directory:
            params["directory"] = directory
        r = requests.delete(f"{self.base_url}/delete_user", headers=self._headers(), params=params)
        return r.status_code, r.json()

    def add_user_context(self, context, user, id, directory=None):
        self._check()
        payload = {"context": context, "user": user, "id": id}
        if directory:
            payload["directory"] = directory
        r = requests.post(f"{self.base_url}/add_user_context", headers=self._headers(), data=payload)
        return r.status_code, r.json()

    def clear_user_context(self, name, id, directory=None):
        self._check()
        payload = {"name": name, "id": id}
        if directory:
            payload["directory"] = directory
        r = requests.post(f"{self.base_url}/clear_user_context", headers=self._headers(), data=payload)
        return r.status_code, r.json()

    def get_user_context(self, name=None, user=None, id=None, directory=None):
        self._check()
        params = {"id": id}
        if name is not None:
            params["name"] = name
        if user is not None:
            params["user"] = user
        if directory:
            params["directory"] = directory
        r = requests.get(f"{self.base_url}/get_user_context", headers=self._headers(), params=params)
        return r.status_code, r.json()

    def disconnect(self):
        self._stopped = True


if __name__ == "__main__":
    client = PortoEduClient(api_key=os.environ.get("PORTOEDU_API_KEY", "devkey"))
    print("Health:", client.health())
    print("Create:", client.create_user("Alice", 123))
    print("Add data:", client.add_user_data("grade", "A", "Alice", 123))
    print("Get user:", client.get_user("Alice", 123))
    print("Add ctx:", client.add_user_context("First note", "Alice", 123))
    print("Get ctx:", client.get_user_context(name="Alice", id=123))
    print("Clear ctx:", client.clear_user_context("Alice", 123))
    print("Delete:", client.delete_user("Alice", 123, rm_context=True))
    client.disconnect()

