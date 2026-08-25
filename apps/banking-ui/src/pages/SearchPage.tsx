import { FormEvent, useState } from "react";
import { ApiError, searchAccounts, type AccountSearchResult } from "../api";
import { loadSession } from "../auth";

export function SearchPage() {
  const session = loadSession();
  const [query, setQuery] = useState("デモ花子");
  const [results, setResults] = useState<AccountSearchResult[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  if (!session) {
    return null;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError("");
    setLoading(true);
    setSearched(true);
    try {
      const items = await searchAccounts(session!, query.trim());
      setResults(items);
    } catch (caught) {
      const message =
        caught instanceof ApiError ? caught.message : "検索に失敗しました";
      setError(message);
      setResults([]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-stack">
      <div className="page-header">
        <h1>名義検索</h1>
        <p className="subtitle">
          漢字・ひらがなの検索語は Java / Python log と APM span（
          <code>banking.search_query</code>）に記録されます。
        </p>
      </div>
      <form className="card" onSubmit={onSubmit}>
        <label htmlFor="search-q">名義で検索</label>
        <div className="search-row">
          <input
            id="search-q"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="例: デモ花子"
            required
          />
          <button type="submit" className="btn" disabled={loading}>
            {loading ? "検索中…" : "検索"}
          </button>
        </div>
        {error ? <p className="error">{error}</p> : null}
      </form>
      {searched ? (
        <section className="card">
          <h2>検索結果（{results.length} 件）</h2>
          {results.length === 0 ? (
            <p className="muted">該当する口座がありません</p>
          ) : (
            <ul className="tx-list">
              {results.map((item) => (
                <li key={item.accountNumber}>
                  <div>
                    <strong>{item.holderNameKanji}</strong>
                    <span className="muted">{item.holderNameHiragana}</span>
                  </div>
                  <span className="mono">{item.accountNumber}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}
    </div>
  );
}
