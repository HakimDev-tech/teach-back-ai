"use client";

import { useId, type InputHTMLAttributes, type TextareaHTMLAttributes } from "react";

import { cn } from "@/components/ui/cn";

type SharedFieldProps = {
  label: string;
  hint?: string;
  error?: string;
};

type InputFieldProps = Omit<InputHTMLAttributes<HTMLInputElement>, "size"> &
  SharedFieldProps & {
    inputSize?: "md" | "lg";
  };

type TextareaFieldProps = TextareaHTMLAttributes<HTMLTextAreaElement> & SharedFieldProps;

const inputBase =
  "block w-full rounded-xl border border-line bg-surface px-3.5 text-sm text-ink shadow-sm transition-colors placeholder:text-ink-muted/75 hover:border-ink-muted/50 focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/15 disabled:cursor-not-allowed disabled:bg-surface-muted disabled:text-ink-muted";

function FieldMessages({
  error,
  hint,
  id,
}: {
  error?: string;
  hint?: string;
  id: string;
}) {
  return (
    <>
      {hint ? (
        <p className="mt-1.5 text-xs leading-5 text-ink-muted" id={`${id}-hint`}>
          {hint}
        </p>
      ) : null}
      {error ? (
        <p className="mt-1.5 text-xs leading-5 text-danger" id={`${id}-error`} role="alert">
          {error}
        </p>
      ) : null}
    </>
  );
}

export function InputField({
  className,
  error,
  hint,
  id,
  inputSize = "md",
  label,
  ...props
}: InputFieldProps) {
  const generatedId = useId();
  const fieldId = id ?? generatedId;
  const describedBy = [
    props["aria-describedby"],
    hint ? `${fieldId}-hint` : undefined,
    error ? `${fieldId}-error` : undefined,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div>
      <label className="mb-1.5 block text-sm font-semibold text-ink" htmlFor={fieldId}>
        {label}
        {props.required ? <span className="ms-1 text-accent" aria-hidden="true">*</span> : null}
      </label>
      <input
        {...props}
        aria-describedby={describedBy || undefined}
        aria-invalid={Boolean(error) || props["aria-invalid"]}
        className={cn(inputBase, inputSize === "lg" ? "min-h-12" : "min-h-11", className)}
        id={fieldId}
      />
      <FieldMessages error={error} hint={hint} id={fieldId} />
    </div>
  );
}

export function TextareaField({
  className,
  error,
  hint,
  id,
  label,
  ...props
}: TextareaFieldProps) {
  const generatedId = useId();
  const fieldId = id ?? generatedId;
  const describedBy = [
    props["aria-describedby"],
    hint ? `${fieldId}-hint` : undefined,
    error ? `${fieldId}-error` : undefined,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div>
      <label className="mb-1.5 block text-sm font-semibold text-ink" htmlFor={fieldId}>
        {label}
        {props.required ? <span className="ms-1 text-accent" aria-hidden="true">*</span> : null}
      </label>
      <textarea
        {...props}
        aria-describedby={describedBy || undefined}
        aria-invalid={Boolean(error) || props["aria-invalid"]}
        className={cn(inputBase, "min-h-32 resize-y py-3", className)}
        id={fieldId}
      />
      <FieldMessages error={error} hint={hint} id={fieldId} />
    </div>
  );
}
