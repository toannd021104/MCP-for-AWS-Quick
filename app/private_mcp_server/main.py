from __future__ import annotations

import json
import os
from typing import Any

import boto3
import jwt
import psycopg
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from jwt import PyJWKClient
from pydantic import BaseModel


APP_NAME = os.getenv("APP_NAME", "private-mcp")
APP_VERSION = os.getenv("APP_VERSION", "0.1.0")
MOCK_S3_BUCKET = os.getenv("MOCK_S3_BUCKET")
MOCK_S3_KEY = os.getenv("MOCK_S3_KEY", "mock/orders.json")
RDS_HOST = os.getenv("RDS_HOST")
RDS_PORT = int(os.getenv("RDS_PORT", "5432"))
RDS_DB_NAME = os.getenv("RDS_DB_NAME", "mockdata")
RDS_SECRET_JSON = os.getenv("RDS_SECRET_JSON")
OAUTH_ENABLED = os.getenv("OAUTH_ENABLED", "false").lower() == "true"
OAUTH_ISSUER = os.getenv("OAUTH_ISSUER")
OAUTH_AUDIENCES = [item.strip() for item in os.getenv("OAUTH_AUDIENCES", os.getenv("OAUTH_AUDIENCE", "")).split(",") if item.strip()]
OAUTH_JWKS_URL = os.getenv("OAUTH_JWKS_URL")
OAUTH_AUTH_URL = os.getenv("OAUTH_AUTH_URL")
OAUTH_TOKEN_URL = os.getenv("OAUTH_TOKEN_URL")
OAUTH_SCOPE = os.getenv("OAUTH_SCOPE", "private-mcp/invoke")
MCP_RESOURCE_URL = os.getenv("MCP_RESOURCE_URL")
JWK_CLIENT = PyJWKClient(OAUTH_JWKS_URL) if OAUTH_JWKS_URL else None

app = FastAPI(title=APP_NAME, version=APP_VERSION)


class JsonRpcRequest(BaseModel):
    jsonrpc: str = "2.0"
    id: int | str | None = None
    method: str
    params: dict[str, Any] | None = None


@app.on_event("startup")
async def startup() -> None:
    seed_rds_if_configured()


def jsonrpc_result(request_id: int | str | None, result: Any) -> JSONResponse:
    return JSONResponse({"jsonrpc": "2.0", "id": request_id, "result": result})


def jsonrpc_error(
    request_id: int | str | None,
    code: int,
    message: str,
    data: Any | None = None,
) -> JSONResponse:
    payload: dict[str, Any] = {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {
            "code": code,
            "message": message,
        },
    }
    if data is not None:
        payload["error"]["data"] = data
    return JSONResponse(payload, status_code=200)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "name": APP_NAME, "version": APP_VERSION}


@app.get("/")
async def root() -> dict[str, str]:
    return {"name": APP_NAME, "mcp": "/mcp", "health": "/health"}


@app.post("/mcp")
async def mcp_endpoint(request: Request) -> JSONResponse:
    if OAUTH_ENABLED:
        auth_error = verify_authorization(request)
        if auth_error is not None:
            return auth_error

    body = await request.json()

    if isinstance(body, list):
        return jsonrpc_error(None, -32600, "Batch requests are not supported")

    return await handle_jsonrpc(body)


def verify_authorization(request: Request) -> JSONResponse | None:
    authorization = request.headers.get("authorization", "")
    if not authorization.lower().startswith("bearer "):
        return oauth_challenge(request)

    token = authorization.split(" ", 1)[1].strip()
    try:
        if JWK_CLIENT is None or OAUTH_ISSUER is None:
            raise RuntimeError("OAuth issuer/JWKS is not configured")

        signing_key = JWK_CLIENT.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            issuer=OAUTH_ISSUER,
            options={"verify_aud": False},
        )
        token_use = claims.get("token_use")
        if token_use == "id" and OAUTH_AUDIENCES and claims.get("aud") not in OAUTH_AUDIENCES:
            raise RuntimeError("Invalid token audience")
        if token_use == "access" and OAUTH_AUDIENCES and claims.get("client_id") not in OAUTH_AUDIENCES:
            raise RuntimeError("Invalid token client_id")
    except Exception as exc:
        return oauth_challenge(request, str(exc))

    return None


def oauth_challenge(request: Request, error_description: str | None = None) -> JSONResponse:
    metadata_url = str(request.url_for("oauth_protected_resource_metadata"))
    headers = {
        "WWW-Authenticate": f'Bearer realm="private-mcp", resource_metadata="{metadata_url}"'
    }
    payload: dict[str, Any] = {"error": "unauthorized"}
    if error_description:
        payload["error_description"] = error_description
    return JSONResponse(payload, status_code=status.HTTP_401_UNAUTHORIZED, headers=headers)


@app.get("/.well-known/oauth-protected-resource")
async def oauth_protected_resource_metadata(request: Request) -> dict[str, Any]:
    resource_url = MCP_RESOURCE_URL or str(request.url_for("mcp_endpoint"))
    return {
        "resource": resource_url,
        "authorization_servers": [OAUTH_ISSUER] if OAUTH_ISSUER else [],
        "scopes_supported": [OAUTH_SCOPE],
        "bearer_methods_supported": ["header"],
    }


async def handle_jsonrpc(raw: Any) -> JSONResponse:
    try:
        request = JsonRpcRequest.model_validate(raw)
    except Exception as exc:
        return jsonrpc_error(None, -32600, "Invalid Request", str(exc))

    if request.method == "initialize":
        return jsonrpc_result(
            request.id,
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": APP_NAME,
                    "version": APP_VERSION,
                },
                "oauth": {
                    "enabled": OAUTH_ENABLED,
                    "authorizationUrl": OAUTH_AUTH_URL,
                    "tokenUrl": OAUTH_TOKEN_URL,
                },
            },
        )

    if request.method == "notifications/initialized":
        return jsonrpc_result(request.id, {})

    if request.method == "tools/list":
        return jsonrpc_result(
            request.id,
            {
                "tools": [
                    {
                        "name": "echo",
                        "description": "Echo back a message for connectivity testing.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "message": {
                                    "type": "string",
                                    "description": "Message to echo.",
                                }
                            },
                            "required": ["message"],
                        },
                    },
                    {
                        "name": "environment",
                        "description": "Return basic runtime environment metadata.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {},
                        },
                    },
                    {
                        "name": "s3_list_orders",
                        "description": "List mock orders from the private S3 data bucket.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {},
                        },
                    },
                    {
                        "name": "s3_get_order",
                        "description": "Get one mock order from S3 by order_id.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {
                                "order_id": {
                                    "type": "string",
                                    "description": "Order ID, for example ORD-1001.",
                                }
                            },
                            "required": ["order_id"],
                        },
                    },
                    {
                        "name": "rds_list_customers",
                        "description": "List mock customers from private RDS PostgreSQL.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {},
                        },
                    },
                    {
                        "name": "rds_revenue_summary",
                        "description": "Summarize mock paid order revenue from private RDS PostgreSQL.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {},
                        },
                    },
                ]
            },
        )

    if request.method == "tools/call":
        try:
            return handle_tool_call(request)
        except Exception as exc:
            return jsonrpc_error(request.id, -32000, "Tool execution failed", str(exc))

    return jsonrpc_error(request.id, -32601, f"Method not found: {request.method}")


def handle_tool_call(request: JsonRpcRequest) -> JSONResponse:
    params = request.params or {}
    tool_name = params.get("name")
    arguments = params.get("arguments") or {}

    if tool_name == "echo":
        message = str(arguments.get("message", ""))
        return jsonrpc_result(
            request.id,
            {
                "content": [
                    {
                        "type": "text",
                        "text": message,
                    }
                ]
            },
        )

    if tool_name == "environment":
        return jsonrpc_result(
            request.id,
            {
                "content": [
                    {
                        "type": "text",
                        "text": f"name={APP_NAME}, version={APP_VERSION}, aws_region={os.getenv('AWS_REGION', 'unknown')}",
                    }
                ]
            },
        )

    if tool_name == "s3_list_orders":
        orders = read_s3_orders()
        return jsonrpc_result(request.id, text_result(json.dumps(orders, indent=2)))

    if tool_name == "s3_get_order":
        order_id = str(arguments.get("order_id", ""))
        orders = read_s3_orders()
        for order in orders:
            if order.get("order_id") == order_id:
                return jsonrpc_result(request.id, text_result(json.dumps(order, indent=2)))
        return jsonrpc_error(request.id, -32602, f"Order not found: {order_id}")

    if tool_name == "rds_list_customers":
        rows = query_rds(
            """
            select customer_id, customer_name, segment, country
            from customers
            order by customer_id
            """
        )
        return jsonrpc_result(request.id, text_result(json.dumps(rows, indent=2, default=str)))

    if tool_name == "rds_revenue_summary":
        rows = query_rds(
            """
            select
              count(*) filter (where status = 'paid') as paid_orders,
              coalesce(sum(amount) filter (where status = 'paid'), 0) as paid_revenue,
              count(*) as total_orders
            from orders
            """
        )
        return jsonrpc_result(request.id, text_result(json.dumps(rows[0], indent=2, default=str)))

    return jsonrpc_error(request.id, -32602, f"Unknown tool: {tool_name}")


def text_result(text: str) -> dict[str, Any]:
    return {
        "content": [
            {
                "type": "text",
                "text": text,
            }
        ]
    }


def read_s3_orders() -> list[dict[str, Any]]:
    if not MOCK_S3_BUCKET:
        raise RuntimeError("MOCK_S3_BUCKET is not configured")

    client = boto3.client("s3")
    response = client.get_object(Bucket=MOCK_S3_BUCKET, Key=MOCK_S3_KEY)
    payload = json.loads(response["Body"].read().decode("utf-8"))
    return payload.get("orders", [])


def rds_credentials() -> tuple[str, str]:
    if not RDS_SECRET_JSON:
        raise RuntimeError("RDS_SECRET_JSON is not configured")

    secret = json.loads(RDS_SECRET_JSON)
    return secret["username"], secret["password"]


def rds_connection() -> psycopg.Connection:
    if not RDS_HOST:
        raise RuntimeError("RDS_HOST is not configured")

    username, password = rds_credentials()
    return psycopg.connect(
        host=RDS_HOST,
        port=RDS_PORT,
        dbname=RDS_DB_NAME,
        user=username,
        password=password,
        connect_timeout=5,
    )


def query_rds(sql: str) -> list[dict[str, Any]]:
    with rds_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(sql)
            columns = [column.name for column in cursor.description]
            return [dict(zip(columns, row, strict=False)) for row in cursor.fetchall()]


def seed_rds_if_configured() -> None:
    if not RDS_HOST or not RDS_SECRET_JSON:
        return

    with rds_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                create table if not exists customers (
                  customer_id text primary key,
                  customer_name text not null,
                  segment text not null,
                  country text not null
                )
                """
            )
            cursor.execute(
                """
                create table if not exists orders (
                  order_id text primary key,
                  customer_id text not null references customers(customer_id),
                  amount numeric(12, 2) not null,
                  currency text not null,
                  status text not null,
                  order_date date not null
                )
                """
            )
            cursor.execute(
                """
                insert into customers (customer_id, customer_name, segment, country)
                values
                  ('CUST-001', 'Acme Vietnam', 'Enterprise', 'VN'),
                  ('CUST-002', 'Lotus Retail', 'SMB', 'VN'),
                  ('CUST-003', 'Mekong Foods', 'Mid-market', 'VN')
                on conflict (customer_id) do nothing
                """
            )
            cursor.execute(
                """
                insert into orders (order_id, customer_id, amount, currency, status, order_date)
                values
                  ('ORD-1001', 'CUST-001', 1250.75, 'USD', 'paid', '2026-06-01'),
                  ('ORD-1002', 'CUST-002', 540.10, 'USD', 'processing', '2026-06-03'),
                  ('ORD-1003', 'CUST-001', 310.00, 'USD', 'paid', '2026-06-08'),
                  ('ORD-1004', 'CUST-003', 980.50, 'USD', 'paid', '2026-06-09')
                on conflict (order_id) do nothing
                """
            )
        connection.commit()
