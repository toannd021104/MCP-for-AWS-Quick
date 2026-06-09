FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY private_mcp_server ./private_mcp_server

EXPOSE 8080

CMD ["sh", "-c", "uvicorn private_mcp_server.main:app --host 0.0.0.0 --port ${PORT}"]

