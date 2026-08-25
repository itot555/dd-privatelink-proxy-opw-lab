import { authHeader, type Session } from "./auth";

export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(
  path: string,
  session: Session | null,
  init: RequestInit = {},
): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...authHeader(session),
      ...(init.headers ?? {}),
    },
  });

  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try {
      const body = (await response.json()) as { error?: string };
      if (body.error) {
        message = body.error;
      }
    } catch {
      // ignore parse errors
    }
    throw new ApiError(response.status, message);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}

export type LoginResponse = {
  token: string;
  loginId: string;
  displayName: string;
};

export type BalanceResponse = {
  accountNumber: string;
  balance: number;
  holderNameKanji: string;
  holderNameHiragana: string;
};

export type ProfileResponse = BalanceResponse & {
  addressKanji: string;
  addressHiragana: string;
  postalCode: string;
};

export type ProfilePayload = {
  holderNameKanji: string;
  holderNameHiragana: string;
  addressKanji: string;
  addressHiragana: string;
  postalCode: string;
};

export type AccountSearchResult = {
  accountNumber: string;
  holderNameKanji: string;
  holderNameHiragana: string;
};

export type TransferPayload = {
  toAccountNumber: string;
  beneficiaryKanji: string;
  beneficiaryHiragana: string;
  amount: number;
};

export type TransferResponse = {
  transferId: number;
  createdAt: string;
  balance: number;
};

export type Transaction = {
  createdAt: string;
  beneficiaryKanji: string;
  amount: number;
  toAccountNumber: string;
  type: string;
};

export function login(loginId: string, password: string) {
  return request<LoginResponse>("/api/auth/login", null, {
    method: "POST",
    body: JSON.stringify({ loginId, password }),
  });
}

export function fetchBalance(session: Session) {
  return request<BalanceResponse>("/api/accounts/balance", session);
}

export function createTransfer(session: Session, payload: TransferPayload) {
  return request<TransferResponse>("/api/transfers", session, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function fetchTransactions(session: Session) {
  return request<Transaction[]>("/api/transactions", session);
}

export function fetchProfile(session: Session) {
  return request<ProfileResponse>("/api/profile", session);
}

export function updateProfile(session: Session, payload: ProfilePayload) {
  return request<ProfileResponse>("/api/profile", session, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function searchAccounts(session: Session, query: string) {
  const params = new URLSearchParams({ q: query });
  return request<AccountSearchResult[]>(`/api/accounts/search?${params}`, session);
}
