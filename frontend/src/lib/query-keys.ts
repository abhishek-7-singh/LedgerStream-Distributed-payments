export type PaymentsListFilters = {
  status?: string;
  limit?: number;
};

const paymentsBaseKey = ["payments"] as const;

export const queryKeys = {
  paymentsBase: paymentsBaseKey,
  payments: (filters?: PaymentsListFilters) =>
    [...paymentsBaseKey, filters ?? {}] as const,
  payment: (transactionId: string) => ["payment", transactionId] as const,
} as const;
