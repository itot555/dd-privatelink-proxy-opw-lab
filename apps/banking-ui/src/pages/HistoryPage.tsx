import { useEffect, useState } from "react";
import { fetchTransactions, type Transaction } from "../api";
import { loadSession } from "../auth";

function formatDate(value: string): string {
  return new Date(value).toLocaleString("ja-JP", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function HistoryPage() {
  const session = loadSession();
  const sessionToken = session?.token;
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [error, setError] = useState("");

  useEffect(() => {
    const activeSession = loadSession();
    if (!activeSession?.token) {
      return;
    }

    let cancelled = false;
    fetchTransactions(activeSession)
      .then((response) => {
        if (!cancelled) {
          setTransactions(response);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setError("取引履歴の取得に失敗しました");
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
    <div className="card">
      <h1>取引履歴</h1>
      <p className="subtitle">直近の振込（DBM query sample 相関用）</p>
      {error ? <p className="error">{error}</p> : null}
      <table>
        <thead>
          <tr>
            <th>日時</th>
            <th>内容</th>
            <th>相手先</th>
            <th>金額</th>
          </tr>
        </thead>
        <tbody>
          {transactions.map((tx) => (
            <tr key={`${tx.createdAt}-${tx.amount}-${tx.beneficiaryKanji}`}>
              <td>{formatDate(tx.createdAt)}</td>
              <td>
                <span className="badge">{tx.type === "transfer" ? "振込" : tx.type}</span>
              </td>
              <td>{tx.beneficiaryKanji}</td>
              <td className="amount-out">- ¥{tx.amount.toLocaleString("ja-JP")}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
