"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiClientError } from "@/lib/client/api-client";
import { getAccessToken } from "@/lib/client/session";
import { signIn, signOut, signUp } from "@/lib/client/pomlist-api";

type Mode = "sign-in" | "sign-up";

function getErrorMessage(error: unknown) {
  if (error instanceof ApiClientError) {
    return error.message;
  }
  return "操作失败，请稍后重试";
}

export default function AuthPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("sign-in");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [logoutLoading, setLogoutLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [hasToken, setHasToken] = useState(false);

  useEffect(() => {
    setHasToken(!!getAccessToken());
  }, []);

  const submitDisabled = useMemo(() => {
    if (!email || !password) {
      return true;
    }
    if (mode === "sign-up" && !confirmPassword) {
      return true;
    }
    return loading;
  }, [email, password, confirmPassword, mode, loading]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(null);

    if (mode === "sign-up" && password !== confirmPassword) {
      setMessage("两次密码输入不一致");
      return;
    }

    setLoading(true);
    try {
      if (mode === "sign-in") {
        await signIn({ email, password });
      } else {
        await signUp({ email, password });
      }
      const hasAuthToken = !!getAccessToken();
      setHasToken(hasAuthToken);
      if (hasAuthToken) {
        router.replace("/today");
      } else {
        setMessage("注册成功，请先登录。");
      }
    } catch (error) {
      setMessage(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function handleLogout() {
    setLogoutLoading(true);
    setMessage(null);
    try {
      await signOut();
      setHasToken(false);
      setMessage("已退出登录");
    } catch (error) {
      setMessage(getErrorMessage(error));
    } finally {
      setLogoutLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <section className="panel w-full max-w-md p-6">
        <h1 className="page-title text-3xl font-bold text-slate-900">Pomlist</h1>
        <p className="mt-2 text-sm text-subtle">任务驱动番茄钟：先任务，后计时</p>

        <div className="mt-5 grid grid-cols-2 rounded-xl border border-slate-200 bg-white/80 p-1">
          <button
            type="button"
            onClick={() => setMode("sign-in")}
            className={`rounded-lg px-3 py-2 text-sm font-semibold transition ${
              mode === "sign-in"
                ? "bg-orange-100 text-orange-800"
                : "text-slate-500 hover:text-slate-800"
            }`}
          >
            登录
          </button>
          <button
            type="button"
            onClick={() => setMode("sign-up")}
            className={`rounded-lg px-3 py-2 text-sm font-semibold transition ${
              mode === "sign-up"
                ? "bg-orange-100 text-orange-800"
                : "text-slate-500 hover:text-slate-800"
            }`}
          >
            注册
          </button>
        </div>

        <form onSubmit={handleSubmit} className="mt-4 space-y-3">
          <label className="block">
            <span className="mb-1 block text-sm text-slate-700">邮箱</span>
            <input
              type="email"
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="input-base"
              placeholder="you@example.com"
            />
          </label>
          <label className="block">
            <span className="mb-1 block text-sm text-slate-700">密码</span>
            <input
              type="password"
              autoComplete={mode === "sign-in" ? "current-password" : "new-password"}
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="input-base"
              placeholder="至少 6 位"
            />
          </label>
          {mode === "sign-up" ? (
            <label className="block">
              <span className="mb-1 block text-sm text-slate-700">确认密码</span>
              <input
                type="password"
                autoComplete="new-password"
                value={confirmPassword}
                onChange={(event) => setConfirmPassword(event.target.value)}
                className="input-base"
                placeholder="再次输入密码"
              />
            </label>
          ) : null}

          <button type="submit" disabled={submitDisabled} className="btn-primary h-11 w-full">
            {loading ? "提交中..." : mode === "sign-in" ? "登录并进入今日页" : "注册并进入今日页"}
          </button>
        </form>

        <section className="panel-solid mt-4 p-4">
          <p className="text-sm text-slate-700">
            当前状态：{hasToken ? "已登录" : "未登录"}
          </p>
          <div className="mt-3 grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={() => router.push("/today")}
              className="btn-muted h-10 text-sm"
            >
              前往今日概览
            </button>
            <button
              type="button"
              onClick={handleLogout}
              disabled={logoutLoading || !hasToken}
              className="btn-danger h-10 text-sm disabled:opacity-50"
            >
              {logoutLoading ? "退出中..." : "退出登录"}
            </button>
          </div>
        </section>

        {message ? (
          <p className="mt-4 rounded-lg bg-slate-100 px-3 py-2 text-sm text-slate-700">
            {message}
          </p>
        ) : null}
      </section>
    </main>
  );
}
