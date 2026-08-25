import { NavLink, Navigate, Outlet, useLocation, useNavigate } from "react-router-dom";
import { useEffect } from "react";
import { clearSession, loadSession } from "../auth";
import { clearRumUser, trackRumView } from "../rum";
import { initials } from "../utils/format";

const NAV = [
  { to: "/", label: "ホーム", end: true },
  { to: "/balance", label: "残高" },
  { to: "/transfer", label: "振込" },
  { to: "/history", label: "履歴" },
  { to: "/profile", label: "お客様情報" },
  { to: "/search", label: "名義検索" },
];

export function BankingLayout() {
  const session = loadSession();
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    const page = location.pathname === "/" ? "home" : location.pathname.slice(1);
    trackRumView(`direct-banking/${page}`);
  }, [location.pathname]);

  if (!session) {
    return <Navigate to="/login" replace />;
  }

  function logout() {
    clearSession();
    clearRumUser();
    navigate("/login", { replace: true });
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="logo-mark">MB</div>
          <div>
            <div className="sidebar-title">Direct Banking</div>
            <div className="sidebar-sub">dd-lab Demo</div>
          </div>
        </div>
        <nav className="sidebar-nav">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                `sidebar-link${isActive ? " active" : ""}`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-user">
          <div className="user-avatar">{initials(session.displayName)}</div>
          <div>
            <div className="user-name">{session.displayName}</div>
            <div className="user-id">{session.loginId}</div>
          </div>
        </div>
        <button type="button" className="btn btn-secondary sidebar-logout" onClick={logout}>
          ログアウト
        </button>
      </aside>
      <div className="main-area">
        <header className="mobile-header">
          <div className="logo-mark">MB</div>
          <span>{session.displayName} さん</span>
        </header>
        <main className="main-content">
          <Outlet />
        </main>
        <nav className="bottom-nav">
          {NAV.slice(0, 4).map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => (isActive ? "active" : "")}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
      </div>
    </div>
  );
}
