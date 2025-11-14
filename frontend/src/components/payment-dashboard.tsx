"use client";

import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";

import { listPayments, paymentsQueryKey } from "@/lib/api/payments";
import type { PaymentResponse } from "@/lib/schemas/payment";
import { cn } from "@/lib/utils";
import { PaymentForm } from "@/components/payment-form";
import { PaymentsTable } from "@/components/payments-table";

const STATUS_OPTIONS = ["all", "pending", "confirmed", "declined", "retry"] as const;

type StatusOption = (typeof STATUS_OPTIONS)[number];

export function PaymentDashboard() {
  const [statusFilter, setStatusFilter] = useState<StatusOption>("all");
  const [lastSubmission, setLastSubmission] = useState<PaymentResponse | null>(null);

  const { data, isLoading, isFetching, refetch } = useQuery({
    queryKey: paymentsQueryKey(
      statusFilter === "all"
        ? undefined
        : {
            status: statusFilter,
            limit: 25,
          },
    ),
    queryFn: () =>
      listPayments(
        statusFilter === "all"
          ? { limit: 25 }
          : {
              status: statusFilter,
              limit: 25,
            },
      ),
    refetchInterval: 15_000,
  });

  const statusSummary = useMemo(() => {
    if (!lastSubmission) return null;
    return `${lastSubmission.transaction_id} · ${lastSubmission.status}`;
  }, [lastSubmission]);

  return (
    <div className="grid gap-6 lg:grid-cols-[360px_1fr]">
      <section className="rounded-2xl border border-zinc-200 bg-white/80 p-6 shadow-sm backdrop-blur">
        <h2 className="text-lg font-semibold text-zinc-900">Submit a payment</h2>
        <p className="mt-1 text-sm text-zinc-500">
          Provide the transaction details and let the fraud service evaluate the risk.
        </p>
        <div className="mt-6">
          <PaymentForm onCreated={(payload) => setLastSubmission(payload)} />
        </div>

        {statusSummary && (
          <div className="mt-6 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
            Last submission — {statusSummary}
          </div>
        )}
      </section>

      <section className="rounded-2xl border border-zinc-200 bg-white/80 p-6 shadow-sm backdrop-blur">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold text-zinc-900">Recent payments</h2>
            <p className="text-sm text-zinc-500">Monitor processing outcomes and fraud decisions.</p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            {STATUS_OPTIONS.map((option) => {
              const isActive = option === statusFilter;
              const label = option === "all" ? "All" : option;
              return (
                <button
                  key={option}
                  type="button"
                  onClick={() => setStatusFilter(option)}
                  className={cn(
                    "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold transition",
                    isActive
                      ? "bg-zinc-900 text-white shadow"
                      : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200",
                  )}
                >
                  {label}
                </button>
              );
            })}
          </div>
        </div>

        <PaymentsTable
          collection={data}
          isLoading={isLoading}
          isRefetching={isFetching}
          onRefresh={refetch}
        />
      </section>
    </div>
  );
}
