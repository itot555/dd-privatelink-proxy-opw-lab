import { NavLink, Navigate, Outlet, useNavigate } from "react-router-dom";
import { clearSession, loadSession } from "../auth";
import { clearRumUser } from "../rum";

export function AppShell() {
  const session = loadSession();
  const navigate = useNavigate();

  if (!session) {
    return <Navigate to="/login" replace />;
  }

  function logout() {
    clearSession();
    clearRumUser();
    navigate("/login", { replace: true });
  }

  return (
    <>
      <header className="app-header">
        <div className="app-header-inner">
          <div className="logo">
            <div className="logo-mark">MB</div>
            <span>Mock Net Banking</span>
          </div>
          <div>
            {session.displayName} さん{" "}
            <button type="button" className="btn btn-secondary" onClick={logout}>
              ログアウト
            </button>
          </div>
        </div>
      </header>
      <nav className="nav">
        <div className="nav-inner">
          <NavLink to="/" end>
            ホーム
          </NavLink>
          <NavLink to="/transfer">振込</NavLink>
          <NavLink to="/history">取引履歴</NavLink>
        </div>
      </nav>
      <main className="main">
        <Outlet />
      </main>
    </>
  );
}
