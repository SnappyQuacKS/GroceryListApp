"""
GroceryList API Server — standalone, no other files needed.

1. pip install fastapi uvicorn psycopg2-binary
2. Edit the DB_CONFIG block below with your PostgreSQL details
3. python server.py
"""

# ── Edit these to match your pgAdmin / PostgreSQL settings ───────────────────
DB_CONFIG = {
    "host":     "192.168.0.16",   # <-- IP of the computer running PostgreSQL
    "port":     5432,
    "dbname":   "grocerylist",
    "user":     "postgres",
    "password": "user123",   # <-- your PostgreSQL password
}
# ─────────────────────────────────────────────────────────────────────────────

import os
import psycopg2
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Any

# Allow overriding DB_CONFIG with environment variables
DB_CONFIG["host"]     = os.environ.get("PGHOST",     DB_CONFIG["host"])
DB_CONFIG["port"]     = int(os.environ.get("PGPORT", DB_CONFIG["port"]))
DB_CONFIG["dbname"]   = os.environ.get("PGDATABASE", DB_CONFIG["dbname"])
DB_CONFIG["user"]     = os.environ.get("PGUSER",     DB_CONFIG["user"])
DB_CONFIG["password"] = os.environ.get("PGPASSWORD", DB_CONFIG["password"])

app = FastAPI(title="GroceryList API")
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])


# ── Database connection ───────────────────────────────────────────────────────

def _conn():
    return psycopg2.connect(**DB_CONFIG)


# ── Topological sort (parents inserted before children for FK constraints) ───

def _topo_sort(lists: list) -> list:
    sorted_out, remaining = [], list(lists)
    while remaining:
        done = {l["listId"] for l in sorted_out}
        ready = [l for l in remaining if l.get("parentId") is None or l["parentId"] in done]
        if not ready:
            sorted_out.extend(remaining)
            break
        sorted_out.extend(ready)
        ready_ids = {l["listId"] for l in ready}
        remaining = [l for l in remaining if l["listId"] not in ready_ids]
    return sorted_out


# ── Request / response models (mirror Swift Codable structs) ─────────────────

class ItemModel(BaseModel):
    itemId: str
    itemName: str

class ListEntryModel(BaseModel):
    listId: str
    itemId: str
    isChecked: bool = False
    isMaskedHidden: bool = False
    customNameOverride: Optional[str] = None

class GroceryListModel(BaseModel):
    listId: str
    listName: str
    parentId: Optional[str] = None
    userId: Optional[str] = None
    theme: str = "natural"
    createdDate: Any = ""

class AppUserModel(BaseModel):
    username: str
    passwordHash: str = ""
    firstName: str = ""
    lastName: str = ""
    zipCode: str = ""

class StatePayload(BaseModel):
    lists: List[GroceryListModel]
    items: List[ItemModel]
    entries: List[ListEntryModel]
    users: List[AppUserModel]

class SignInRequest(BaseModel):
    username: str
    passwordHash: str


# ── GET /health ───────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"ok": True}


# ── GET /state ────────────────────────────────────────────────────────────────

@app.get("/state", response_model=StatePayload)
def get_state(user_id: str = Query("")):
    conn = _conn()
    cur = conn.cursor()
    try:
        # Users
        if user_id:
            cur.execute("SELECT username, password_hash, first_name, last_name, zip_code "
                        "FROM users WHERE username = %s", (user_id,))
        else:
            cur.execute("SELECT username, password_hash, first_name, last_name, zip_code FROM users")
        users = [AppUserModel(username=r[0], passwordHash=r[1],
                              firstName=r[2] or "", lastName=r[3] or "",
                              zipCode=r[4] or "") for r in cur.fetchall()]

        # Lists
        if user_id:
            cur.execute("SELECT list_id, list_name, parent_id, user_id, theme, created_date "
                        "FROM grocery_lists WHERE user_id = %s", (user_id,))
        else:
            cur.execute("SELECT list_id, list_name, parent_id, user_id, theme, created_date "
                        "FROM grocery_lists")
        lists = [GroceryListModel(listId=r[0], listName=r[1], parentId=r[2],
                                  userId=r[3], theme=r[4] or "natural",
                                  createdDate=str(r[5]) if r[5] else "")
                 for r in cur.fetchall()]

        # Entries — only for this user's lists
        list_ids = tuple(l.listId for l in lists)
        if list_ids:
            cur.execute("SELECT list_id, item_id, is_checked, is_masked_hidden, "
                        "custom_name_override FROM list_entries WHERE list_id IN %s",
                        (list_ids,))
        else:
            cur.execute("SELECT list_id, item_id, is_checked, is_masked_hidden, "
                        "custom_name_override FROM list_entries WHERE FALSE")
        entries = [ListEntryModel(listId=r[0], itemId=r[1], isChecked=bool(r[2]),
                                  isMaskedHidden=bool(r[3]), customNameOverride=r[4])
                   for r in cur.fetchall()]

        # Items — only those referenced by this user's entries
        item_ids = tuple(set(e.itemId for e in entries))
        if item_ids:
            cur.execute("SELECT item_id, item_name FROM items WHERE item_id IN %s",
                        (item_ids,))
        else:
            cur.execute("SELECT item_id, item_name FROM items WHERE FALSE")
        items = [ItemModel(itemId=r[0], itemName=r[1]) for r in cur.fetchall()]

        return StatePayload(lists=lists, items=items, entries=entries, users=users)
    finally:
        cur.close(); conn.close()


# ── POST /state ───────────────────────────────────────────────────────────────

@app.post("/state")
def post_state(payload: StatePayload, user_id: str = Query("")):
    conn = _conn()
    cur = conn.cursor()
    try:
        cur.execute("SET CONSTRAINTS ALL DEFERRED")

        if user_id:
            # Delete only this user's lists and entries; leave other users untouched
            cur.execute("""
                DELETE FROM list_entries
                WHERE list_id IN (SELECT list_id FROM grocery_lists WHERE user_id = %s)
            """, (user_id,))
            cur.execute("DELETE FROM grocery_lists WHERE user_id = %s", (user_id,))

            # Upsert this user's profile
            for u in payload.users:
                if u.username == user_id:
                    cur.execute("""
                        INSERT INTO users (username, password_hash, first_name, last_name, zip_code)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (username) DO UPDATE SET
                            password_hash = EXCLUDED.password_hash,
                            first_name    = EXCLUDED.first_name,
                            last_name     = EXCLUDED.last_name,
                            zip_code      = EXCLUDED.zip_code
                    """, (u.username, u.passwordHash, u.firstName, u.lastName, u.zipCode))
        else:
            # Replace all (admin / migration use)
            cur.execute("DELETE FROM list_entries")
            cur.execute("DELETE FROM grocery_lists")
            cur.execute("DELETE FROM items")
            cur.execute("DELETE FROM users")
            for u in payload.users:
                cur.execute(
                    "INSERT INTO users (username, password_hash, first_name, last_name, zip_code) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (u.username, u.passwordHash, u.firstName, u.lastName, u.zipCode))

        # Upsert items — shared catalog, never delete other users' items
        for i in payload.items:
            cur.execute("""
                INSERT INTO items (item_id, item_name) VALUES (%s, %s)
                ON CONFLICT (item_id) DO UPDATE SET item_name = EXCLUDED.item_name
            """, (i.itemId, i.itemName))

        for lst in _topo_sort([l.model_dump() for l in payload.lists]):
            cur.execute(
                "INSERT INTO grocery_lists "
                "(list_id, list_name, parent_id, user_id, theme, created_date) "
                "VALUES (%s, %s, %s, %s, %s, %s)",
                (lst["listId"], lst["listName"], lst.get("parentId"),
                 lst.get("userId"), lst.get("theme", "natural"),
                 lst.get("createdDate", "")))

        for e in payload.entries:
            cur.execute(
                "INSERT INTO list_entries "
                "(list_id, item_id, is_checked, is_masked_hidden, custom_name_override) "
                "VALUES (%s, %s, %s, %s, %s)",
                (e.listId, e.itemId, e.isChecked, e.isMaskedHidden, e.customNameOverride))

        conn.commit()
        return {"ok": True}
    except Exception as exc:
        conn.rollback()
        raise HTTPException(500, str(exc))
    finally:
        cur.close(); conn.close()


# ── POST /auth/signin ─────────────────────────────────────────────────────────

@app.post("/auth/signin")
def signin(req: SignInRequest):
    conn = _conn()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT username, password_hash, first_name, last_name, zip_code "
            "FROM users WHERE username = %s AND password_hash = %s",
            (req.username, req.passwordHash))
        row = cur.fetchone()
        if not row:
            raise HTTPException(401, "Invalid credentials")
        return AppUserModel(username=row[0], passwordHash=row[1],
                            firstName=row[2] or "", lastName=row[3] or "",
                            zipCode=row[4] or "")
    finally:
        cur.close(); conn.close()


# ── POST /auth/signup ─────────────────────────────────────────────────────────

@app.post("/auth/signup")
def signup(req: SignInRequest):
    conn = _conn()
    cur = conn.cursor()
    try:
        cur.execute("SELECT username FROM users WHERE username = %s", (req.username,))
        if cur.fetchone():
            raise HTTPException(409, "Username already exists")
        cur.execute(
            "INSERT INTO users (username, password_hash, first_name, last_name, zip_code) "
            "VALUES (%s, %s, '', '', '')",
            (req.username, req.passwordHash))
        conn.commit()
        return AppUserModel(username=req.username, passwordHash=req.passwordHash)
    except HTTPException:
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(500, str(exc))
    finally:
        cur.close(); conn.close()


# ── Startup ───────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    print("\n=== GroceryList API Server ===")
    print(f"Connecting to PostgreSQL at {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print(f"Database: {DB_CONFIG['dbname']}  User: {DB_CONFIG['user']}")
    print(f"API running at http://0.0.0.0:{port}\n")
    uvicorn.run(app, host="0.0.0.0", port=port)
