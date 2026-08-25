import { FormEvent, useEffect, useState } from "react";
import { fetchProfile, updateProfile } from "../api";
import { loadSession } from "../auth";

export function ProfilePage() {
  const session = loadSession();
  const sessionToken = session?.token;
  const [holderNameKanji, setHolderNameKanji] = useState("");
  const [holderNameHiragana, setHolderNameHiragana] = useState("");
  const [addressKanji, setAddressKanji] = useState("");
  const [addressHiragana, setAddressHiragana] = useState("");
  const [postalCode, setPostalCode] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const activeSession = loadSession();
    if (!activeSession?.token) {
      return;
    }

    let cancelled = false;
    fetchProfile(activeSession)
      .then((profile) => {
        if (!cancelled) {
          setHolderNameKanji(profile.holderNameKanji);
          setHolderNameHiragana(profile.holderNameHiragana);
          setAddressKanji(profile.addressKanji);
          setAddressHiragana(profile.addressHiragana);
          setPostalCode(profile.postalCode);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setError("お客様情報の取得に失敗しました");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [sessionToken]);

  if (!session) {
    return null;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError("");
    setMessage("");
    setLoading(true);
    try {
      await updateProfile(session!, {
        holderNameKanji,
        holderNameHiragana,
        addressKanji,
        addressHiragana,
        postalCode,
      });
      setMessage("お客様情報を更新しました。APM / Logs で PII が記録されます。");
    } catch {
      setError("更新に失敗しました");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="page-stack">
      <div className="page-header">
        <h1>お客様情報</h1>
        <p className="subtitle">
          氏名・住所（漢字 / ひらがな）を入力して更新。Java log / Python span attribute
          に平文載せし、OP マスキングを検証します。
        </p>
      </div>
      <form className="card" onSubmit={onSubmit}>
        {message ? <p className="success">{message}</p> : null}
        {error ? <p className="error">{error}</p> : null}
        <div className="grid-2">
          <div>
            <label htmlFor="holder-kanji">お名前（漢字）</label>
            <input
              id="holder-kanji"
              value={holderNameKanji}
              onChange={(event) => setHolderNameKanji(event.target.value)}
              placeholder="例: デモ太郎"
              required
            />
          </div>
          <div>
            <label htmlFor="holder-hira">お名前（ひらがな）</label>
            <input
              id="holder-hira"
              value={holderNameHiragana}
              onChange={(event) => setHolderNameHiragana(event.target.value)}
              placeholder="例: でもたろう"
              required
            />
          </div>
        </div>
        <label htmlFor="postal">郵便番号</label>
        <input
          id="postal"
          value={postalCode}
          onChange={(event) => setPostalCode(event.target.value)}
          placeholder="例: 100-0001"
          className="mono"
        />
        <label htmlFor="address-kanji">ご住所（漢字）</label>
        <input
          id="address-kanji"
          value={addressKanji}
          onChange={(event) => setAddressKanji(event.target.value)}
          placeholder="例: 東京都千代田区丸の内一丁目1番1号"
          required
        />
        <label htmlFor="address-hira">ご住所（ひらがな）</label>
        <input
          id="address-hira"
          value={addressHiragana}
          onChange={(event) => setAddressHiragana(event.target.value)}
          placeholder="例: とうきょうとちよだくまるのうち..."
          required
        />
        <button type="submit" className="btn" disabled={loading}>
          {loading ? "更新中…" : "お客様情報を更新"}
        </button>
      </form>
    </div>
  );
}
