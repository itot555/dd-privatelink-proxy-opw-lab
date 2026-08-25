import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ApiError, createTransfer } from "../api";
import { loadSession } from "../auth";

export function TransferPage() {
  const session = loadSession();
  const navigate = useNavigate();
  const [toAccountNumber, setToAccountNumber] = useState("9876543");
  const [beneficiaryKanji, setBeneficiaryKanji] = useState("デモ花子");
  const [beneficiaryHiragana, setBeneficiaryHiragana] = useState("でもはなこ");
  const [amount, setAmount] = useState("10000");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  if (!session) {
    return null;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError("");
    setLoading(true);
    try {
      await createTransfer(session!, {
        toAccountNumber,
        beneficiaryKanji,
        beneficiaryHiragana,
        amount: Number(amount),
      });
      navigate("/history");
    } catch (caught) {
      const message =
        caught instanceof ApiError ? caught.message : "振込に失敗しました";
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="card">
      <h1>振込</h1>
      <p className="subtitle">振込先情報は trace / log に記録されます（マスク検証用）</p>
      {error ? <p className="error">{error}</p> : null}
      <form onSubmit={onSubmit}>
        <label htmlFor="to-account">振込先口座番号</label>
        <input
          id="to-account"
          value={toAccountNumber}
          onChange={(event) => setToAccountNumber(event.target.value)}
          required
        />
        <div className="grid-2">
          <div>
            <label htmlFor="name-kanji">お名前（漢字）</label>
            <input
              id="name-kanji"
              value={beneficiaryKanji}
              onChange={(event) => setBeneficiaryKanji(event.target.value)}
              required
            />
          </div>
          <div>
            <label htmlFor="name-hira">お名前（ひらがな）</label>
            <input
              id="name-hira"
              value={beneficiaryHiragana}
              onChange={(event) => setBeneficiaryHiragana(event.target.value)}
              required
            />
          </div>
        </div>
        <label htmlFor="amount">振込金額（円）</label>
        <input
          id="amount"
          type="number"
          min="1"
          value={amount}
          onChange={(event) => setAmount(event.target.value)}
          required
        />
        <button type="submit" className="btn" disabled={loading}>
          {loading ? "送信中…" : "振込する"}
        </button>
      </form>
    </div>
  );
}
