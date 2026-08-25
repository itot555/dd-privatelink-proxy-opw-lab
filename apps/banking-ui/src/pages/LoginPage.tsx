import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ApiError, login } from "../api";
import { saveSession } from "../auth";
import { setRumUser } from "../rum";

export function LoginPage() {
  const navigate = useNavigate();
  const [loginId, setLoginId] = useState("demo_user");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError("");
    setLoading(true);
    try {
      const session = await login(loginId, password);
      saveSession(session);
      setRumUser(session.loginId, session.displayName);
      navigate("/", { replace: true });
    } catch (caught) {
      const message =
        caught instanceof ApiError ? caught.message : "ログインに失敗しました";
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-visual">
        <div className="login-brand">
          <div className="logo-mark">MB</div>
          <span>Direct Banking Demo</span>
        </div>
        <div className="login-hero-copy">
          <h1>ネットバンキング Sandbox</h1>
          <p>
            RUM + 分散 trace + OP マスキング検証用デモ。ログイン情報とお客様情報は
            意図的に APM / Logs に平文で記録されます。
          </p>
        </div>
      </div>
      <div className="login-panel">
        <form className="login-form" onSubmit={onSubmit}>
          <h1>ログイン</h1>
          <p className="subtitle">デモ口座: demo_user</p>
          {error ? <p className="error">{error}</p> : null}
          <label htmlFor="login-id">ログイン ID</label>
          <input
            id="login-id"
            value={loginId}
            onChange={(event) => setLoginId(event.target.value)}
            autoComplete="username"
            required
          />
          <label htmlFor="password">パスワード</label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="current-password"
            required
          />
          <button type="submit" className="btn" disabled={loading}>
            {loading ? "ログイン中…" : "ログイン"}
          </button>
        </form>
      </div>
    </div>
  );
}
