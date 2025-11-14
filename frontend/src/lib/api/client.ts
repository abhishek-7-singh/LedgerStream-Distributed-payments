import { z } from "zod";

import { API_BASE_URL } from "@/lib/config";

export class ApiError extends Error {
  status: number;
  detail: unknown;

  constructor(status: number, message: string, detail: unknown = undefined) {
    super(message);
    this.status = status;
    this.detail = detail;
  }
}

const defaultHeaders = {
  "Content-Type": "application/json",
};

export async function apiFetch<T>(
  path: string,
  init?: RequestInit,
  schema?: z.ZodSchema<T>,
): Promise<T> {
  const url = `${API_BASE_URL}${path}`;
  const response = await fetch(url, {
    cache: "no-store",
    credentials: "omit",
    ...init,
    headers: {
      ...defaultHeaders,
      ...init?.headers,
    },
  });

  const text = await response.text();
  let data: unknown;

  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }

  if (!response.ok) {
    const message =
      typeof data === "object" && data !== null && "detail" in data
        ? String((data as { detail: unknown }).detail)
        : response.statusText || "Request failed";
    throw new ApiError(response.status, message, data);
  }

  if (schema) {
    return schema.parse(data);
  }

  return data as T;
}
