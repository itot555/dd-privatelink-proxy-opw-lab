"""banking demo API — 削除時は本 Blueprint と app.py の register 行を除去する。"""

from __future__ import annotations

import logging
import os
from decimal import Decimal, InvalidOperation
from typing import Any

from flask import Blueprint, jsonify, request
from opentelemetry import trace

logger = logging.getLogger("dd-lab-python.banking")
tracer = trace.get_tracer("dd-lab-python.banking")

banking_bp = Blueprint("banking", __name__)


def _banking_enabled() -> bool:
    return os.getenv("ENABLE_BANKING_DEMO", "false").lower() == "true"


def _connection_factory():
    # app.py から注入（循環 import 回避）
    from app import database_connection

    return database_connection


@banking_bp.before_request
def require_banking_enabled():
    if not _banking_enabled():
        return jsonify({"error": "banking demo disabled"}), 404


@banking_bp.get("/api/banking/users/by-login/<login_id>")
def get_user_by_login(login_id: str):
    with _connection_factory()() as connection:
        row = connection.execute(
            """
            SELECT u.login_id, u.display_name, a.account_number
            FROM bank_users u
            LEFT JOIN bank_accounts a ON a.user_id = u.id
            WHERE u.login_id = %s
            """,
            (login_id,),
        ).fetchone()

    if row is None:
        return jsonify({"error": "user not found"}), 404

    return jsonify(
        {
            "loginId": row[0],
            "displayName": row[1],
            "accountNumber": row[2],
        }
    )


@banking_bp.get("/api/banking/balance")
def get_balance():
    login_id = request.args.get("login_id", "")
    if not login_id:
        return jsonify({"error": "login_id is required"}), 400

    with _connection_factory()() as connection:
        row = connection.execute(
            """
            SELECT a.account_number, a.balance, a.holder_name_kanji, a.holder_name_hiragana
            FROM bank_accounts a
            JOIN bank_users u ON u.id = a.user_id
            WHERE u.login_id = %s
            """,
            (login_id,),
        ).fetchone()

    if row is None:
        return jsonify({"error": "account not found"}), 404

    holder_kanji = row[2]
    holder_hiragana = row[3]

    with tracer.start_as_current_span("banking.get_balance") as span:
        span.set_attribute("banking.login_id", login_id)
        span.set_attribute("banking.holder_name_kanji", holder_kanji)
        span.set_attribute("banking.holder_name_hiragana", holder_hiragana)
        logger.info(
            "Balance lookup login_id=%s holder_kanji=%s holder_hiragana=%s",
            login_id,
            holder_kanji,
            holder_hiragana,
        )

    return jsonify(
        {
            "accountNumber": row[0],
            "balance": float(row[1]),
            "holderNameKanji": holder_kanji,
            "holderNameHiragana": holder_hiragana,
        }
    )


def _fetch_profile_row(connection, login_id: str):
    return connection.execute(
        """
        SELECT a.account_number,
               a.balance,
               a.holder_name_kanji,
               a.holder_name_hiragana,
               a.address_kanji,
               a.address_hiragana,
               a.postal_code
        FROM bank_accounts a
        JOIN bank_users u ON u.id = a.user_id
        WHERE u.login_id = %s
        """,
        (login_id,),
    ).fetchone()


def _profile_payload(row) -> dict[str, Any]:
    return {
        "accountNumber": row[0],
        "balance": float(row[1]),
        "holderNameKanji": row[2],
        "holderNameHiragana": row[3],
        "addressKanji": row[4],
        "addressHiragana": row[5],
        "postalCode": row[6],
    }


@banking_bp.get("/api/banking/profile")
def get_profile():
    login_id = request.args.get("login_id", "")
    if not login_id:
        return jsonify({"error": "login_id is required"}), 400

    with _connection_factory()() as connection:
        row = _fetch_profile_row(connection, login_id)

    if row is None:
        return jsonify({"error": "profile not found"}), 404

    holder_kanji = row[2]
    holder_hiragana = row[3]
    address_kanji = row[4]
    address_hiragana = row[5]
    postal_code = row[6]

    with tracer.start_as_current_span("banking.get_profile") as span:
        span.set_attribute("banking.login_id", login_id)
        span.set_attribute("banking.holder_name_kanji", holder_kanji)
        span.set_attribute("banking.holder_name_hiragana", holder_hiragana)
        span.set_attribute("banking.address_kanji", address_kanji)
        span.set_attribute("banking.address_hiragana", address_hiragana)
        span.set_attribute("banking.postal_code", postal_code)
        logger.info(
            "Profile lookup login_id=%s holder_kanji=%s holder_hiragana=%s "
            "address_kanji=%s address_hiragana=%s postal_code=%s",
            login_id,
            holder_kanji,
            holder_hiragana,
            address_kanji,
            address_hiragana,
            postal_code,
        )

    return jsonify(_profile_payload(row))


@banking_bp.put("/api/banking/profile")
def update_profile():
    payload = request.get_json(silent=True) or {}
    login_id = str(payload.get("loginId", "")).strip()
    holder_kanji = str(payload.get("holderNameKanji", "")).strip()
    holder_hiragana = str(payload.get("holderNameHiragana", "")).strip()
    address_kanji = str(payload.get("addressKanji", "")).strip()
    address_hiragana = str(payload.get("addressHiragana", "")).strip()
    postal_code = str(payload.get("postalCode", "")).strip()

    if not all([login_id, holder_kanji, holder_hiragana, address_kanji, address_hiragana]):
        return jsonify({"error": "invalid profile payload"}), 400

    with tracer.start_as_current_span("banking.update_profile") as span:
        span.set_attribute("banking.login_id", login_id)
        span.set_attribute("banking.holder_name_kanji", holder_kanji)
        span.set_attribute("banking.holder_name_hiragana", holder_hiragana)
        span.set_attribute("banking.address_kanji", address_kanji)
        span.set_attribute("banking.address_hiragana", address_hiragana)
        span.set_attribute("banking.postal_code", postal_code)
        logger.info(
            "Profile update login_id=%s holder_kanji=%s holder_hiragana=%s "
            "address_kanji=%s address_hiragana=%s postal_code=%s",
            login_id,
            holder_kanji,
            holder_hiragana,
            address_kanji,
            address_hiragana,
            postal_code,
        )

        with _connection_factory()() as connection:
            updated = connection.execute(
                """
                UPDATE bank_accounts a
                SET holder_name_kanji = %s,
                    holder_name_hiragana = %s,
                    address_kanji = %s,
                    address_hiragana = %s,
                    postal_code = %s
                FROM bank_users u
                WHERE u.id = a.user_id AND u.login_id = %s
                RETURNING a.account_number, a.balance, a.holder_name_kanji,
                          a.holder_name_hiragana, a.address_kanji,
                          a.address_hiragana, a.postal_code
                """,
                (
                    holder_kanji,
                    holder_hiragana,
                    address_kanji,
                    address_hiragana,
                    postal_code,
                    login_id,
                ),
            ).fetchone()
            connection.commit()

    if updated is None:
        return jsonify({"error": "profile not found"}), 404

    return jsonify(_profile_payload(updated))


@banking_bp.get("/api/banking/accounts/search")
def search_accounts():
    query_text = request.args.get("q", "").strip()
    if not query_text:
        return jsonify({"error": "q is required"}), 400

    with tracer.start_as_current_span("banking.search_accounts") as span:
        span.set_attribute("banking.search_query", query_text)
        logger.info("search_accounts q=%s", query_text)

        with _connection_factory()() as connection:
            rows = connection.execute(
                """
                SELECT account_number, holder_name_kanji, holder_name_hiragana
                FROM bank_accounts
                WHERE holder_name_kanji ILIKE %s
                   OR holder_name_hiragana ILIKE %s
                ORDER BY account_number
                LIMIT 20
                """,
                (f"%{query_text}%", f"%{query_text}%"),
            ).fetchall()

    return jsonify(
        {
            "results": [
                {
                    "accountNumber": row[0],
                    "holderNameKanji": row[1],
                    "holderNameHiragana": row[2],
                }
                for row in rows
            ]
        }
    )

def _parse_amount(raw_amount: Any) -> Decimal | None:
    try:
        amount = Decimal(str(raw_amount))
    except (InvalidOperation, TypeError):
        return None
    if amount <= 0:
        return None
    return amount.quantize(Decimal("0.01"))


@banking_bp.post("/api/banking/transfers")
def create_transfer():
    payload = request.get_json(silent=True) or {}
    login_id = str(payload.get("loginId", "")).strip()
    to_account_number = str(payload.get("toAccountNumber", "")).strip()
    beneficiary_kanji = str(payload.get("beneficiaryKanji", "")).strip()
    beneficiary_hiragana = str(payload.get("beneficiaryHiragana", "")).strip()
    amount = _parse_amount(payload.get("amount"))

    if not all([login_id, to_account_number, beneficiary_kanji, beneficiary_hiragana, amount]):
        return jsonify({"error": "invalid transfer payload"}), 400

    with tracer.start_as_current_span("banking.create_transfer") as span:
        span.set_attribute("banking.login_id", login_id)
        span.set_attribute("banking.beneficiary_kanji", beneficiary_kanji)
        span.set_attribute("banking.beneficiary_hiragana", beneficiary_hiragana)
        span.set_attribute("banking.to_account_number", to_account_number)
        span.set_attribute("banking.amount", str(amount))
        logger.info(
            "Transfer login_id=%s to=%s beneficiary_kanji=%s beneficiary_hiragana=%s amount=%s",
            login_id,
            to_account_number,
            beneficiary_kanji,
            beneficiary_hiragana,
            amount,
        )

        with _connection_factory()() as connection:
            account_row = connection.execute(
                """
                SELECT a.id, a.balance
                FROM bank_accounts a
                JOIN bank_users u ON u.id = a.user_id
                WHERE u.login_id = %s
                FOR UPDATE
                """,
                (login_id,),
            ).fetchone()

            if account_row is None:
                return jsonify({"error": "account not found"}), 404

            account_id, current_balance = account_row
            if Decimal(current_balance) < amount:
                return jsonify({"error": "insufficient balance"}), 400

            transfer_row = connection.execute(
                """
                INSERT INTO bank_transfers (
                  from_account_id,
                  to_account_number,
                  beneficiary_kanji,
                  beneficiary_hiragana,
                  amount
                )
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id, created_at
                """,
                (account_id, to_account_number, beneficiary_kanji, beneficiary_hiragana, amount),
            ).fetchone()

            new_balance = Decimal(current_balance) - amount
            connection.execute(
                "UPDATE bank_accounts SET balance = %s WHERE id = %s",
                (new_balance, account_id),
            )
            connection.commit()

    return (
        jsonify(
            {
                "transferId": transfer_row[0],
                "createdAt": transfer_row[1].isoformat(),
                "balance": float(new_balance),
            }
        ),
        201,
    )


@banking_bp.get("/api/banking/transactions")
def list_transactions():
    login_id = request.args.get("login_id", "")
    if not login_id:
        return jsonify({"error": "login_id is required"}), 400

    with _connection_factory()() as connection:
        rows = connection.execute(
            """
            SELECT t.created_at, t.beneficiary_kanji, t.amount, t.to_account_number
            FROM bank_transfers t
            JOIN bank_accounts a ON a.id = t.from_account_id
            JOIN bank_users u ON u.id = a.user_id
            WHERE u.login_id = %s
            ORDER BY t.created_at DESC
            LIMIT 50
            """,
            (login_id,),
        ).fetchall()

    return jsonify(
        {
            "transactions": [
                {
                    "createdAt": row[0].isoformat(),
                    "beneficiaryKanji": row[1],
                    "amount": float(row[2]),
                    "toAccountNumber": row[3],
                    "type": "transfer",
                }
                for row in rows
            ]
        }
    )
