"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { getAccessToken } from "@/lib/client/session";
import { signIn } from "@/lib/client/pomlist-api";

const PASSCODE_LENGTH = 4;
const SHAKE_DURATION_MS = 780;

export default function AuthPage() {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement | null>(null);

  const [passcode, setPasscode] = useState("");
  const [isFocused, setIsFocused] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isError, setIsError] = useState(false);

  useEffect(() => {
    if (getAccessToken()) {
      router.replace("/today");
    }
  }, [router]);

  const isExpanded = useMemo(
    () => isFocused || passcode.length > 0 || isSubmitting,
    [isFocused, passcode.length, isSubmitting],
  );

  const submitPasscode = useCallback(async (currentPasscode: string) => {
    if (isSubmitting) {
      return;
    }

    setIsSubmitting(true);
    try {
      await signIn({ passcode: currentPasscode });
      router.replace("/today");
    } catch {
      setIsError(true);
      setPasscode("");
      window.setTimeout(() => {
        setIsError(false);
        inputRef.current?.focus();
      }, SHAKE_DURATION_MS);
    } finally {
      setIsSubmitting(false);
    }
  }, [isSubmitting, router]);

  useEffect(() => {
    if (passcode.length === PASSCODE_LENGTH && !isSubmitting) {
      void submitPasscode(passcode);
    }
  }, [passcode, isSubmitting, submitPasscode]);

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (passcode.length === PASSCODE_LENGTH) {
            void submitPasscode(passcode);
          }
        }}
      >
        <input
          ref={inputRef}
          type="password"
          autoComplete="off"
          value={passcode}
          disabled={isSubmitting}
          maxLength={PASSCODE_LENGTH}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          onChange={(event) => {
            const nextValue = event.target.value.slice(0, PASSCODE_LENGTH);
            setPasscode(nextValue);
          }}
          aria-label="登录口令"
          className={[
            "auth-passcode-input",
            isExpanded ? "auth-passcode-input-expanded" : "",
            isError ? "auth-passcode-input-error" : "",
          ]
            .filter((className) => className.length > 0)
            .join(" ")}
        />
      </form>
    </main>
  );
}
