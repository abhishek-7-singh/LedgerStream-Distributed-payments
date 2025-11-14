import { z } from "zod";

const currencySchema = z
  .string()
  .trim()
  .toUpperCase()
  .regex(/^[A-Z]{3}$/u, "Currency must be a 3-letter ISO code");

export const moneySchema = z.object({
  currency: currencySchema,
  value_minor: z
    .number({ required_error: "Amount is required" })
    .int("Amount must be an integer")
    .nonnegative("Amount must be positive"),
});

export const paymentResponseSchema = z.object({
  transaction_id: z.string(),
  status: z.string(),
  reason: z.string().nullable().optional(),
});

export const paymentRecordSchema = z.object({
  transaction_id: z.string(),
  merchant_id: z.string(),
  customer_id: z.string(),
  amount: moneySchema,
  payment_method: z.string(),
  status: z.string(),
  reason: z.string().nullable().optional(),
  created_at: z.string().min(1),
  updated_at: z.string().min(1),
});

export const paymentCollectionSchema = z.object({
  items: z.array(paymentRecordSchema),
  total: z.number().int().nonnegative(),
});

export const paymentRequestSchema = z.object({
  transaction_id: z.string().min(8).max(64),
  merchant_id: z.string().min(4).max(64),
  customer_id: z.string().min(4).max(64),
  amount: moneySchema.refine((value) => value.value_minor > 0, {
    message: "Amount must be greater than zero",
  }),
  payment_method: z.string().min(2).max(32),
  reference: z
    .string()
    .max(128)
    .optional()
    .transform((value) => (value ? value.trim() : undefined)),
});

export const paymentFormSchema = z.object({
  transactionId: z.string().min(8).max(64),
  merchantId: z.string().min(4).max(64),
  customerId: z.string().min(4).max(64),
  amountMinor: z
    .coerce.number({ invalid_type_error: "Amount must be a number" })
    .int("Amount must be an integer")
    .positive("Amount must be greater than zero"),
  currency: currencySchema.default("INR"),
  paymentMethod: z.string().min(2).max(32),
  reference: z
    .string()
    .max(128)
    .optional()
    .transform((value) => (value ? value.trim() : undefined)),
});

export type PaymentRequestPayload = z.infer<typeof paymentRequestSchema>;
export type PaymentResponse = z.infer<typeof paymentResponseSchema>;
export type PaymentRecord = z.infer<typeof paymentRecordSchema>;
export type PaymentCollection = z.infer<typeof paymentCollectionSchema>;
export type PaymentFormValues = z.infer<typeof paymentFormSchema>;
