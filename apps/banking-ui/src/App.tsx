import { Navigate, Route, Routes } from "react-router-dom";
import { BankingLayout } from "./components/BankingLayout";
import { loadSession } from "./auth";
import { BalancePage } from "./pages/BalancePage";
import { HistoryPage } from "./pages/HistoryPage";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { ProfilePage } from "./pages/ProfilePage";
import { SearchPage } from "./pages/SearchPage";
import { TransferPage } from "./pages/TransferPage";

export function App() {
  const session = loadSession();

  return (
    <Routes>
      <Route
        path="/login"
        element={session ? <Navigate to="/" replace /> : <LoginPage />}
      />
      <Route element={<BankingLayout />}>
        <Route path="/" element={<HomePage />} />
        <Route path="/balance" element={<BalancePage />} />
        <Route path="/transfer" element={<TransferPage />} />
        <Route path="/history" element={<HistoryPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route path="/search" element={<SearchPage />} />
      </Route>
      <Route path="*" element={<Navigate to={session ? "/" : "/login"} replace />} />
    </Routes>
  );
}
