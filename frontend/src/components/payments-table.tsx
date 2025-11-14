"use client";

import { ArrowRight, RefreshCcw } from "lucide-react";

import { type PaymentCollection } from "@/lib/schemas/payment";
import { cn } from "@/lib/utils";
import { StatusBadge } from "@/components/status-badge";

interface PaymentsTableProps {
  collection?: PaymentCollection;
  isLoading: boolean;
  isRefetching: boolean;
  onRefresh: () => void;
  onSelect?: (transactionId: string) => void;
}

export function PaymentsTable({
  collection,
  isLoading,
  isRefetching,
  onRefresh,
  onSelect,
}: PaymentsTableProps) {
  const rows = collection?.items ?? [];

  if (isLoading) {
    const placeholders = ["one", "two", "three", "four", "five"] as const;
    return (
      <div className="mt-4 space-y-3">
        {placeholders.map((placeholder) => (
          <div
            key={placeholder}
            className="flex items-center justify-between rounded-lg border border-zinc-200 bg-white px-4 py-3 shadow-sm"
          >
            <div className="h-4 w-1/5 animate-pulse rounded bg-zinc-200" />
            <div className="h-4 w-1/6 animate-pulse rounded bg-zinc-200" />
            <div className="h-4 w-1/12 animate-pulse rounded bg-zinc-200" />
          </div>
        ))}
      </div>
    );
  }

  if (!rows.length) {
    return (
      <div className="mt-4 rounded-lg border border-dashed border-zinc-300 bg-zinc-50 px-6 py-12 text-center text-sm text-zinc-500">
        No payments captured yet. Submit a transaction to see it here.
      </div>
    );
  }

  return (
    <div className="mt-4 space-y-3">
      <div className="flex items-center justify-between text-xs font-medium text-zinc-500 uppercase">
        <button
          type="button"
          onClick={onRefresh}
          className={cn(
            "inline-flex items-center gap-1 rounded-md border border-transparent px-2 py-1 transition",
            isRefetching
              ? "text-zinc-400"
              : "text-zinc-500 hover:border-zinc-200 hover:bg-white hover:text-zinc-900",
          )}
          aria-label="Refresh payments"
        >
          <RefreshCcw className={cn("h-3.5 w-3.5", isRefetching && "animate-spin")} />
          Refresh
        </button>
        <span>{collection?.total ?? rows.length} records</span>
      </div>

      <div className="divide-y divide-zinc-200 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {rows.map((row) => {
          const formatter = new Intl.NumberFormat("en-US", {
            style: "currency",
            currency: row.amount.currency,
            minimumFractionDigits: 2,
          });
          const amount = formatter.format(row.amount.value_minor / 100);
          const updated = new Date(row.updated_at).toLocaleString();

          return (
            <button
              key={row.transaction_id}
              type="button"
              onClick={() => onSelect?.(row.transaction_id)}
              className="flex w-full items-center gap-6 px-6 py-4 text-left transition hover:bg-zinc-50"
            >
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
                  <span className="truncate text-sm font-semibold text-zinc-900">
                    {row.transaction_id}
                  </span>
                  <StatusBadge status={row.status} />
                </div>
                <div className="mt-1 flex flex-wrap items-center gap-x-4 text-xs text-zinc-500">
                  <span>Merchant · {row.merchant_id}</span>
                  <span>Customer · {row.customer_id}</span>
                  <span>Updated · {updated}</span>
                </div>
              </div>

              <div className="text-right text-sm font-semibold text-zinc-900">{amount}</div>

              <div className="text-zinc-400">
                <ArrowRight className="h-5 w-5" aria-hidden="true" />
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
