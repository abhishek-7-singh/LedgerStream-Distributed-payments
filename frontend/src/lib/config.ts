export const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000/api";

if (
  typeof window !== "undefined" &&
  !process.env.NEXT_PUBLIC_API_BASE_URL &&
  process.env.NODE_ENV !== "production"
) {
  console.warn("NEXT_PUBLIC_API_BASE_URL is not defined; falling back to http://localhost:8000/api");
}
