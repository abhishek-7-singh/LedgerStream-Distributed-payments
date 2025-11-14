"use client";
import { useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

import { createPayment } from "@/lib/api/payments";
import { queryKeys } from "@/lib/query-keys";
import {
  paymentFormSchema,
  type PaymentFormValues,
  type PaymentRequestPayload,
  type PaymentResponse,
} from "@/lib/schemas/payment";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

interface PaymentFormProps {
  onCreated?: (payload: PaymentResponse) => void;
}

function toRequestPayload(values: PaymentFormValues): PaymentRequestPayload {
  return {
    transaction_id: values.transactionId,
    merchant_id: values.merchantId,
    customer_id: values.customerId,
    amount: {
      currency: values.currency.toUpperCase(),
      value_minor: values.amountMinor,
    },
    payment_method: values.paymentMethod,
    reference: values.reference || undefined,
  };
}

export function PaymentForm({ onCreated }: PaymentFormProps) {
  const queryClient = useQueryClient();

  const form = useForm<PaymentFormValues>({
    resolver: zodResolver(paymentFormSchema),
    defaultValues: {
      currency: "INR",
      paymentMethod: "card",
    },
  });

  const mutation = useMutation({
    mutationFn: async (values: PaymentFormValues) => {
      const payload = toRequestPayload(values);
      return createPayment(payload);
    },
    onSuccess: async (response) => {
      toast.success("Payment submitted", {
        description: `Transaction ${response.transaction_id} status: ${response.status}`,
      });
      await queryClient.invalidateQueries({ queryKey: queryKeys.paymentsBase });
      onCreated?.(response);
      form.reset({
        currency: form.getValues("currency") || "INR",
        paymentMethod: form.getValues("paymentMethod") || "card",
      });
    },
    onError: (error: unknown) => {
      const message = error instanceof Error ? error.message : "Unable to submit payment";
      toast.error("Payment failed", { description: message });
    },
  });

  const isSubmitting = mutation.isPending;
  const currencyRaw = useWatch({
    control: form.control,
    name: "currency",
    defaultValue: "INR",
  });
  const amountMinorRaw = useWatch({
    control: form.control,
    name: "amountMinor",
    defaultValue: 0,
  });
  const currencyValue = String(currencyRaw || "INR").toUpperCase();
  const amountMinorValue = Number(amountMinorRaw || 0);
  const amountHint = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currencyValue,
    minimumFractionDigits: 2,
  }).format(amountMinorValue / 100);

  return (
    <form
      onSubmit={form.handleSubmit((values) => mutation.mutate(values))}
      className="space-y-4"
      noValidate
    >
      <div className="grid gap-3">
        <label className="text-sm font-medium text-zinc-700" htmlFor="transactionId">
          Transaction ID
        </label>
        <input
          id="transactionId"
          type="text"
          autoComplete="off"
          className={cn(
            "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none",
            form.formState.errors.transactionId && "border-rose-500 focus:border-rose-500",
          )}
          placeholder="txn-123456"
          {...form.register("transactionId")}
        />
        {form.formState.errors.transactionId && (
          <p className="text-sm text-rose-600">{form.formState.errors.transactionId.message}</p>
        )}
      </div>

      <div className="grid gap-3">
        <label className="text-sm font-medium text-zinc-700" htmlFor="merchantId">
          Merchant ID
        </label>
        <input
          id="merchantId"
          type="text"
          autoComplete="off"
          className={cn(
            "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none",
            form.formState.errors.merchantId && "border-rose-500 focus:border-rose-500",
          )}
          placeholder="merchant-001"
          {...form.register("merchantId")}
        />
        {form.formState.errors.merchantId && (
          <p className="text-sm text-rose-600">{form.formState.errors.merchantId.message}</p>
        )}
      </div>

      <div className="grid gap-3">
        <label className="text-sm font-medium text-zinc-700" htmlFor="customerId">
          Customer ID
        </label>
        <input
          id="customerId"
          type="text"
          autoComplete="off"
          className={cn(
            "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none",
            form.formState.errors.customerId && "border-rose-500 focus:border-rose-500",
          )}
          placeholder="customer-001"
          {...form.register("customerId")}
        />
        {form.formState.errors.customerId && (
          <p className="text-sm text-rose-600">{form.formState.errors.customerId.message}</p>
        )}
      </div>

      <div className="grid gap-3 sm:grid-cols-[1fr_minmax(0,120px)] sm:items-end sm:gap-4">
        <div className="grid gap-2">
          <label className="text-sm font-medium text-zinc-700" htmlFor="amountMinor">
            Amount (minor units)
          </label>
          <input
            id="amountMinor"
            type="number"
            inputMode="numeric"
            min={1}
            className={cn(
              "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none",
              form.formState.errors.amountMinor && "border-rose-500 focus:border-rose-500",
            )}
            placeholder="2500"
            {...form.register("amountMinor")}
          />
          <p className="text-xs text-zinc-500">Approx. {amountHint}</p>
          {form.formState.errors.amountMinor && (
            <p className="text-sm text-rose-600">{form.formState.errors.amountMinor.message}</p>
          )}
        </div>
        <div className="grid gap-2">
          <label className="text-sm font-medium text-zinc-700" htmlFor="currency">
            Currency
          </label>
          <input
            id="currency"
            type="text"
            maxLength={3}
            className={cn(
              "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm uppercase text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none",
              form.formState.errors.currency && "border-rose-500 focus:border-rose-500",
            )}
            placeholder="USD"
            {...form.register("currency")}
          />
          {form.formState.errors.currency && (
            <p className="text-sm text-rose-600">{form.formState.errors.currency.message}</p>
          )}
        </div>
      </div>

      <div className="grid gap-3">
        <label className="text-sm font-medium text-zinc-700" htmlFor="paymentMethod">
          Payment Method
        </label>
        <input
          id="paymentMethod"
          type="text"
          autoComplete="off"
          className={cn(
            "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none",
            form.formState.errors.paymentMethod && "border-rose-500 focus:border-rose-500",
          )}
          placeholder="card"
          {...form.register("paymentMethod")}
        />
        {form.formState.errors.paymentMethod && (
          <p className="text-sm text-rose-600">{form.formState.errors.paymentMethod.message}</p>
        )}
      </div>

      <div className="grid gap-3">
        <label className="text-sm font-medium text-zinc-700" htmlFor="reference">
          Reference (optional)
        </label>
        <input
          id="reference"
          type="text"
          autoComplete="off"
          className={cn(
            "w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 shadow-sm focus:border-zinc-500 focus:outline-none",
            form.formState.errors.reference && "border-rose-500 focus:border-rose-500",
          )}
          placeholder="order-123"
          {...form.register("reference")}
        />
        {form.formState.errors.reference && (
          <p className="text-sm text-rose-600">{form.formState.errors.reference.message}</p>
        )}
      </div>

      <Button type="submit" className="w-full" isLoading={isSubmitting} disabled={isSubmitting}>
        Submit payment
      </Button>
    </form>
  );
}
