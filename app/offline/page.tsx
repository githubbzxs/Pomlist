export default function OfflinePage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <section className="panel w-full max-w-md p-6 text-center">
        <h1 className="page-title text-2xl font-bold text-main">当前离线</h1>
        <p className="mt-2 text-sm text-subtle">
          你可以稍后重试联网。基础页面已缓存，但业务数据同步仍需要网络连接。
        </p>
      </section>
    </main>
  );
}
