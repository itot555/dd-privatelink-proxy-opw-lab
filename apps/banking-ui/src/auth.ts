export type Session = {
  token: string;
  loginId: string;
  displayName: string;
};

const SESSION_KEY = "dd-lab-banking-session";

export function loadSession(): Session | null {
  const raw = sessionStorage.getItem(SESSION_KEY);
  if (!raw) {
    return null;
  }
  try {
    return JSON.parse(raw) as Session;
  } catch {
    return null;
  }
}

export function saveSession(session: Session): void {
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

export function clearSession(): void {
  sessionStorage.removeItem(SESSION_KEY);
}

export function authHeader(session: Session | null): HeadersInit {
  if (!session) {
    return {};
  }
  return { Authorization: `Bearer ${session.token}` };
}
