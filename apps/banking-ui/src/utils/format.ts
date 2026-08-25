export function yen(value: number | null | undefined): string {
  return `¥${Number(value ?? 0).toLocaleString("ja-JP")}`;
}

export function maskAccount(num: string | null | undefined): string {
  if (!num) {
    return "—";
  }
  return num.replace(/\d(?=\d{4})/g, "•");
}

export function initials(name: string | null | undefined): string {
  return (name ?? "?").trim().charAt(0) || "?";
}
