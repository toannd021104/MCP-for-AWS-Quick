# Private MCP Server

Minimal HTTP MCP server for the private Amazon Quick VPC connection setup.

Endpoints:

- `GET /health`
- `POST /mcp`

Tools:

- `echo`
- `environment`
- `s3_list_orders`
- `s3_get_order`
- `rds_list_customers`
- `rds_revenue_summary`

The S3/RDS tools read configuration from ECS environment variables:

- `MOCK_S3_BUCKET`
- `MOCK_S3_KEY`
- `RDS_HOST`
- `RDS_PORT`
- `RDS_DB_NAME`
- `RDS_SECRET_JSON`

Local run:

```bash
pip install -r requirements.txt
uvicorn private_mcp_server.main:app --host 0.0.0.0 --port 8080
```

Docker:

```bash
docker build -t private-mcp:latest .
docker run --rm -p 8080:8080 private-mcp:latest
```
