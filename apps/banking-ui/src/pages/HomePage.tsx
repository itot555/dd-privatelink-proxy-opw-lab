import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  fetchBalance,
  fetchTransactions,
  type BalanceResponse,
  type Transaction,
} from "../api";
import { loadSession } from "../auth";
import { maskAccount, yen } from "../utils/format";

export function HomePage() {
  const session = loadSession();
  const sessionToken = session?.token;
  const [balance, setBalance] = useState<BalanceResponse | null>(null);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [error, setError] = useState("");

  useEffect(() => {
    const activeSession = loadSession();
    if (!activeSession?.token) {
      return;
    }

    let cancelled = false;
    Promise.all([
      fetchBalance(activeSession),
      fetchTransactions(activeSession),
    ])
      .then(([balanceResponse, txList]) => {
        if (!cancelled) {
          setBalance(balanceResponse);
          setTransactions(txList.slice(0, 3));
        }
      })
      .catch(() => {
        if (!cancelled) {
          setError("データの取得に失敗しました");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [sessionToken]);

  if (!session) {
    return null;
  }

  return (
    <div className="page-stack">
      <div className="page-header">
        <h1>おかえりなさい、{session.displayName} さん</h1>
        <p className="subtitle">CloudFront → Java → Python → PostgreSQL の E2E デモ</p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {balance ? (
        <div className="balance-card">
          <div className="balance-card-label">普通預金</div>
          <div className="balance-card-account mono">{maskAccount(balance.accountNumber)}</div>
          <div className="balance-card-amount mono">
            {balance.balance.toLocaleString("ja-JP")}
            <small>円</small>
          </div>
          <div className="balance-card-meta">
            {balance.holderNameKanji}（{balance.holderNameHiragana}）
          </div>
          <div className="quick-actions">
            <Link to="/transfer" className="quick-btn">
              振込・振替
            </Link>
            <Link to="/history" className="quick-btn">
              入出金明細
            </Link>
            <Link to="/profile" className="quick-btn">
              お客様情報
            </Link>
          </div>
        </div>
      ) : null}
      <div className="grid-2">
        <section className="card">
          <h2>最近の取引</h2>
          {transactions.length === 0 ? (
            <p className="muted">取引はまだありません</p>
          ) : (
            <ul className="tx-list">
              {transactions.map((tx) => (
                <li key={`${tx.createdAt}-${tx.amount}`}>
                  <div>
                    <strong>{tx.beneficiaryKanji}</strong>
                    <span className="muted">{tx.toAccountNumber}</span>
                  </div>
                  <span className="mono tx-amount">{yen(tx.amount)}</span>
                </li>
              ))}
            </ul>
          )}
          <Link to="/history" className="text-link">
            すべて見る →
          </Link>
        </section>
        <section className="card notice-card">
          <h2>OP マスキング検証</h2>
          <p>
            <strong>お客様情報</strong> で氏名・住所（漢字/ひらがな）を更新すると、Java / Python の
            log と APM span に平文で記録されます。
          </p>
          <p>
            <strong>名義検索</strong> の検索語も log / trace に載ります。OP カスタムルールでマスク後の
            結果を Preview 確認してください。
          </p>
          <Link to="/search" className="btn btn-secondary">
            名義検索へ
          </Link>
        </section>
      </div>
    </div>
  );
}
