import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { fetchBalance, type BalanceResponse } from "../api";
import { loadSession } from "../auth";

export function DashboardPage() {
  const session = loadSession();
  const sessionToken = session?.token;
  const [balance, setBalance] = useState<BalanceResponse | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    const activeSession = loadSession();
    if (!activeSession?.token) {
      return;
    }

    let cancelled = false;
    fetchBalance(activeSession)
      .then((response) => {
        if (!cancelled) {
          setBalance(response);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setError("残高の取得に失敗しました");
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
    <>
      {balance ? (
        <div className="balance-hero">
          <div className="balance-label">普通預金 残高</div>
          <div className="balance-amount">
            <span className="yen">¥</span>
            {balance.balance.toLocaleString("ja-JP")}
          </div>
          <div className="account-meta">
            口座番号 <strong>{balance.accountNumber}</strong> | 名義{" "}
            <strong>{balance.holderNameKanji}</strong>（{balance.holderNameHiragana}）
          </div>
        </div>
      ) : null}
      <div className="card">
        <h1>ようこそ、{session.displayName} さん</h1>
        <p className="subtitle">CloudFront → Java → Python → PostgreSQL の E2E デモ</p>
        {error ? <p className="error">{error}</p> : null}
        <div className="quick-actions">
          <Link to="/transfer" className="btn">
            振込する
          </Link>
          <Link to="/history" className="btn btn-secondary">
            取引履歴
          </Link>
        </div>
      </div>
    </>
  );
}
