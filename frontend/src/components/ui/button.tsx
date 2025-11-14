"use client";

import * as React from "react";

import { cn } from "@/lib/utils";

type ButtonVariant = "default" | "outline" | "ghost";

const variantStyles: Record<ButtonVariant, string> = {
  default:
    "bg-zinc-900 text-white hover:bg-zinc-800 focus-visible:outline-zinc-900 disabled:bg-zinc-400 disabled:text-zinc-100",
  outline:
    "border border-zinc-300 text-zinc-900 hover:bg-zinc-100 focus-visible:outline-zinc-900 disabled:text-zinc-400",
  ghost:
    "text-zinc-700 hover:bg-zinc-100 focus-visible:outline-zinc-900 disabled:text-zinc-400",
};

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  isLoading?: boolean;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, children, variant = "default", isLoading = false, disabled, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          "inline-flex items-center justify-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
          variantStyles[variant],
          className,
        )}
        disabled={disabled ?? isLoading}
        {...props}
      >
        {isLoading && (
          <span
            className="inline-flex h-4 w-4 animate-spin rounded-full border-2 border-current/50 border-t-transparent"
            aria-hidden="true"
          />
        )}
        {children}
      </button>
    );
  },
);

Button.displayName = "Button";
