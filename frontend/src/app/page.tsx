"use client";

import { PaymentDashboard } from "@/components/payment-dashboard";

export default function HomePage() {
  return (
    <main className="relative min-h-screen overflow-x-hidden bg-gradient-to-br from-zinc-950 via-zinc-900 to-zinc-950 py-16">
      <div
        className="pointer-events-none absolute inset-0 opacity-80"
        aria-hidden="true"
        style={{
          backgroundImage:
            "radial-gradient(circle at top, rgba(74, 222, 128, 0.32), transparent 58%), radial-gradient(circle at bottom right, rgba(59, 130, 246, 0.22), transparent 48%)",
        }}
      />
      <div className="relative mx-auto flex w-full max-w-6xl flex-col gap-12 px-6 text-white">
        <header className="space-y-4">
          <span className="inline-flex items-center rounded-full border border-emerald-300/60 bg-emerald-300/10 px-4 py-1.5 text-sm font-semibold uppercase tracking-[0.3em] text-emerald-100">
            LedgerStream
          </span>
          <div className="space-y-3">
            <h1 className="text-5xl font-semibold tracking-tight sm:text-6xl">
              Distributed Payments control center for your payment gateway
            </h1>
            <p className="max-w-2xl text-base leading-relaxed text-zinc-200">
              Launch transactions, monitor fraud outcomes, and follow the full ledger lifecycle. This
              portal connects directly to the FastAPI gateway and distributed services running in
              your stack.
            </p>
          </div>
        </header>

        <PaymentDashboard />
      </div>
    </main>
  );
}
