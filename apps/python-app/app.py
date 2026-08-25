import logging
import os
from contextlib import contextmanager

import psycopg
from banking import banking_bp
from flask import Flask, jsonify, request
from opentelemetry import trace

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("dd-lab-python")

app = Flask(__name__)
tracer = trace.get_tracer("dd-lab-python.manual")

if os.getenv("ENABLE_BANKING_DEMO", "false").lower() == "true":
    app.register_blueprint(banking_bp)


def database_config() -> dict[str, str | int]:
    return {
        "host": os.environ["DB_HOST"],
        "port": int(os.getenv("DB_PORT", "5432")),
        "dbname": os.environ["DB_NAME"],
        "user": os.environ["DB_USER"],
        "password": os.environ["DB_PASSWORD"],
        "connect_timeout": 5,
    }


@contextmanager
def database_connection():
    with psycopg.connect(**database_config()) as connection:
        yield connection


@app.get("/api/items")
def list_items():
    logger.info("Reading demo items from PostgreSQL")
    with database_connection() as connection:
        rows = connection.execute(
            "SELECT id, name, created_at FROM demo_items ORDER BY id DESC LIMIT 20"
        ).fetchall()

    return jsonify(
        {
            "service": "dd-lab-python",
            "instrumentation": "opentelemetry-sdk",
            "items": [
                {"id": row[0], "name": row[1], "created_at": row[2].isoformat()}
                for row in rows
            ],
        }
    )


@app.post("/api/items")
def create_item():
    name = request.args.get("name", "sample-item")

    # OpenTelemetry API で手動スパンを追加（Lab 検証用）
    with tracer.start_as_current_span("create_item_otel_api") as span:
        span.set_attribute("demo.item.name", name)
        span.set_attribute("demo.instrumentation", "otel-api")

        logger.info("Creating demo item via OTel API span")
        with database_connection() as connection:
            row = connection.execute(
                "INSERT INTO demo_items (name) VALUES (%s) RETURNING id, name, created_at",
                (name,),
            ).fetchone()
            connection.commit()

    return (
        jsonify(
            {
                "id": row[0],
                "name": row[1],
                "created_at": row[2].isoformat(),
            }
        ),
        201,
    )


@app.get("/api/timeout")
def delayed_query():
    logger.warning("Executing a deliberately slow PostgreSQL query")
    with database_connection() as connection:
        connection.execute("SELECT pg_sleep(2)")
        current_time = connection.execute("SELECT NOW()").fetchone()[0]

    return jsonify({"status": "completed", "database_time": current_time.isoformat()})


@app.get("/api/error")
def database_error():
    logger.error("Executing a deliberately invalid PostgreSQL query")
    with database_connection() as connection:
        connection.execute("SELECT * FROM table_that_does_not_exist")
    return jsonify({"status": "unexpected"})


@app.get("/health")
def health():
    return jsonify(
        {
            "status": "ok",
            "service": "dd-lab-python",
            "instrumentation": "opentelemetry-sdk",
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
