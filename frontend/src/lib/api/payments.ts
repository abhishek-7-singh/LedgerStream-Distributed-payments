import { apiFetch } from "@/lib/api/client";
import { queryKeys, type PaymentsListFilters } from "@/lib/query-keys";
import {
  paymentCollectionSchema,
  paymentRecordSchema,
  paymentRequestSchema,
  paymentResponseSchema,
  type PaymentCollection,
  type PaymentRecord,
  type PaymentRequestPayload,
  type PaymentResponse,
} from "@/lib/schemas/payment";

export type { PaymentCollection, PaymentRecord, PaymentRequestPayload, PaymentResponse };

export function paymentsQueryKey(filters?: PaymentsListFilters) {
  return queryKeys.payments(filters);
}

export async function listPayments(filters?: PaymentsListFilters): Promise<PaymentCollection> {
  const search = new URLSearchParams();

  if (filters?.status) {
    search.append("status", filters.status);
  }

  if (filters?.limit) {
    search.append("limit", String(filters.limit));
  }

  const query = search.toString();
  const path = query ? `/payments?${query}` : "/payments";
  return apiFetch(path, undefined, paymentCollectionSchema);
}

export async function getPayment(transactionId: string): Promise<PaymentRecord> {
  return apiFetch(`/payments/${transactionId}`, undefined, paymentRecordSchema);
}

export async function createPayment(payload: PaymentRequestPayload): Promise<PaymentResponse> {
  const validated = paymentRequestSchema.parse(payload);
  return apiFetch(
    "/payments",
    {
      method: "POST",
      body: JSON.stringify(validated),
    },
    paymentResponseSchema,
  );
}
