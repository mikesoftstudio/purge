"use client";

import { ReactNode, useEffect, useId, useRef, useState } from "react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

export type DialogTone = "default" | "critical";

function WarningIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M12 9v4.5M12 16.5h.01M10.29 4.86 2.82 17.5A2 2 0 0 0 4.53 20.5h14.94a2 2 0 0 0 1.71-3L13.71 4.86a2 2 0 0 0-3.42 0Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function InfoIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.8" />
      <path d="M12 11v6M12 8h.01" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

export function Dialog({
  open,
  onClose,
  tone = "default",
  dismissible,
  children,
  className,
  labelledBy,
  describedBy,
}: {
  open: boolean;
  onClose: () => void;
  tone?: DialogTone;
  dismissible?: boolean;
  children: ReactNode;
  className?: string;
  labelledBy?: string;
  describedBy?: string;
}) {
  const canDismiss = dismissible ?? tone !== "critical";
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && canDismiss) onClose();
    };
    window.addEventListener("keydown", onKey);
    panelRef.current?.focus();
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener("keydown", onKey);
    };
  }, [open, canDismiss, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center sm:items-center sm:p-4">
      <button
        type="button"
        aria-label="Close dialog"
        className="absolute inset-0 bg-foreground/45 backdrop-blur-sm animate-fade-in"
        onClick={canDismiss ? onClose : undefined}
        tabIndex={canDismiss ? 0 : -1}
      />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledBy}
        aria-describedby={describedBy}
        tabIndex={-1}
        className={cn(
          "relative z-10 flex max-h-[88vh] w-full max-w-lg flex-col overflow-hidden rounded-t-2xl border bg-card shadow-2xl outline-none sm:rounded-2xl",
          "animate-sheet-in sm:animate-dialog-in",
          tone === "critical" ? "border-destructive/25" : "border-border",
          className
        )}
      >
        <div
          className={cn(
            "absolute inset-x-0 top-0 h-1",
            tone === "critical" ? "bg-destructive" : "bg-primary"
          )}
        />
        <div className="mx-auto mt-3 h-1 w-10 rounded-full bg-muted sm:hidden" />
        {children}
      </div>
    </div>
  );
}

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  tone = "default",
  title,
  description,
  confirmLabel = "Continue",
  cancelLabel = "Cancel",
  hideCancel = false,
  confirmDisabled = false,
  acknowledge,
  children,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  tone?: DialogTone;
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  hideCancel?: boolean;
  confirmDisabled?: boolean;
  acknowledge?: { label: string };
  children?: ReactNode;
}) {
  const titleId = useId();
  const descId = useId();
  const [acked, setAcked] = useState(false);

  useEffect(() => {
    if (open) setAcked(false);
  }, [open]);

  const blocked = confirmDisabled || (acknowledge ? !acked : false);

  return (
    <Dialog open={open} onClose={onClose} tone={tone} labelledBy={titleId} describedBy={description ? descId : undefined}>
      <div className="flex flex-col gap-5 overflow-y-auto px-5 pb-5 pt-4 sm:px-6 sm:pt-6">
        <div className="flex items-start gap-3">
          <span
            className={cn(
              "mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl",
              tone === "critical" ? "bg-destructive/10 text-destructive" : "bg-accent text-accent-foreground"
            )}
          >
            {tone === "critical" ? <WarningIcon className="h-6 w-6" /> : <InfoIcon className="h-6 w-6" />}
          </span>
          <div className="min-w-0 space-y-1">
            <h2 id={titleId} className="text-lg font-semibold tracking-tight sm:text-xl">
              {title}
            </h2>
            {description && (
              <p id={descId} className="text-sm text-muted-foreground">
                {description}
              </p>
            )}
          </div>
        </div>

        {children}

        {acknowledge && (
          <label className="flex cursor-pointer items-start gap-3 rounded-xl border bg-muted/50 px-3 py-3 text-sm">
            <input
              type="checkbox"
              className="mt-0.5 h-4 w-4 rounded border-input text-primary focus:ring-ring"
              checked={acked}
              onChange={(e) => setAcked(e.target.checked)}
            />
            <span className="text-foreground">{acknowledge.label}</span>
          </label>
        )}

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end sm:gap-3">
          {!hideCancel && (
            <Button variant="ghost" className="sm:min-w-24" onClick={onClose}>
              {cancelLabel}
            </Button>
          )}
          <Button
            variant={tone === "critical" ? "destructive" : "default"}
            className="sm:min-w-32"
            disabled={blocked}
            onClick={() => {
              if (blocked) return;
              onConfirm();
              onClose();
            }}
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
