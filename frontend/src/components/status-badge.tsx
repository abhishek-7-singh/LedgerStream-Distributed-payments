import { cn } from "@/lib/utils";

type KnownStatus = "pending" | "confirmed" | "declined" | "retry";

const styleMap: Record<KnownStatus, string> = {
  pending: "bg-amber-100 text-amber-700 border border-amber-200",
  confirmed: "bg-emerald-100 text-emerald-700 border border-emerald-200",
  declined: "bg-rose-100 text-rose-700 border border-rose-200",
  retry: "bg-sky-100 text-sky-700 border border-sky-200",
};

export function StatusBadge({ status }: { status: string }) {
  const normalized = status.toLowerCase() as KnownStatus;
  const classes = styleMap[normalized] ?? "bg-zinc-100 text-zinc-700 border border-zinc-200";

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold uppercase tracking-wide",
        classes,
      )}
    >
      {status}
    </span>
  );
}
