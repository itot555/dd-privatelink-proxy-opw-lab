import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { fetchProfile, type ProfileResponse } from "../api";
import { loadSession } from "../auth";
import { maskAccount } from "../utils/format";

export function BalancePage() {
  const session = loadSession();
  const sessionToken = session?.token;
  const [profile, setProfile] = useState<ProfileResponse | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    const activeSession = loadSession();
    if (!activeSession?.token) {
      return;
    }

    let cancelled = false;
    fetchProfile(activeSession)
      .then((response) => {
        if (!cancelled) {
          setProfile(response);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setError("残高詳細の取得に失敗しました");
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
        <h1>残高詳細</h1>
        <p className="subtitle">口座情報と名義の確認</p>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {profile ? (
        <>
          <div className="balance-card">
            <div className="balance-card-label">普通預金</div>
            <div className="balance-card-account mono">{maskAccount(profile.accountNumber)}</div>
            <div className="balance-card-amount mono">
              {profile.balance.toLocaleString("ja-JP")}
              <small>円</small>
            </div>
          </div>
          <div className="card">
            <h2>口座情報</h2>
            <dl className="stat-rows">
              <div className="stat-row">
                <dt>口座番号</dt>
                <dd className="mono">{profile.accountNumber}</dd>
              </div>
              <div className="stat-row">
                <dt>名義（漢字）</dt>
                <dd>{profile.holderNameKanji}</dd>
              </div>
              <div className="stat-row">
                <dt>名義（ひらがな）</dt>
                <dd>{profile.holderNameHiragana}</dd>
              </div>
              <div className="stat-row">
                <dt>ご住所（漢字）</dt>
                <dd>{profile.addressKanji || "—"}</dd>
              </div>
              <div className="stat-row">
                <dt>ご住所（ひらがな）</dt>
                <dd>{profile.addressHiragana || "—"}</dd>
              </div>
              <div className="stat-row">
                <dt>郵便番号</dt>
                <dd className="mono">{profile.postalCode || "—"}</dd>
              </div>
            </dl>
            <Link to="/profile" className="btn">
              お客様情報を編集
            </Link>
          </div>
        </>
      ) : null}
    </div>
  );
}
