<script lang="ts">
  import { onMount } from 'svelte';
  import { fade, fly } from 'svelte/transition';
  import {
    Activity,
    Bot,
    CheckCircle2,
    Clock3,
    Download,
    FileUp,
    FileText,
    History,
    Loader2,
    RefreshCcw,
    Search,
    Settings,
    Signal,
    Zap,
  } from 'lucide-svelte';

  import SettingsPanel from '$lib/components/SettingsPanel.svelte';
  import {
    chooseStockfishManually,
    detectStockfish,
    downloadStockfish,
    getHistory,
    getUiStatus,
    restartEngine as restartEngineCommand,
  } from '$lib/tauriApi';
  import type { DetectStockfishResponse, HistoryItem, UiStatusResponse } from '$lib/types/app';

  type Tab = 'status' | 'output' | 'settings';

  type Toast = {
    id: number;
    message: string;
    type: 'success' | 'error' | 'info';
  };

  let activeTab: Tab = 'status';

  let status: UiStatusResponse | null = null;
  let history: HistoryItem[] = [];

  let loadingStatus = true;
  let loadingHistory = true;
  let setupBusy: 'detect' | 'download' | 'choose' | null = null;
  let forceSetupWizard = false;
  let setupError: string | null = null;
  let restarting = false;

  let toast: Toast | null = null;
  let toastTimer: number | undefined;

  function showToast(message: string, type: Toast['type'] = 'success') {
    if (toastTimer) {
      window.clearTimeout(toastTimer);
    }

    toast = {
      id: Date.now(),
      message,
      type,
    };

    toastTimer = window.setTimeout(() => {
      toast = null;
    }, 2400);
  }

  async function safeCall<T>(label: string, fn: () => Promise<T>): Promise<T | null> {
    try {
      return await fn();
    } catch (error) {
      console.error(`Command failed: ${label}`, error);
      showToast(String(error), 'error');
      return null;
    }
  }

  async function refreshStatus() {
    const result = await safeCall('get_ui_status', () => getUiStatus());

    if (result) {
      status = result;
    }

    loadingStatus = false;
  }

  async function refreshHistory() {
    const result = await safeCall('get_history', () => getHistory());

    if (Array.isArray(result)) {
      history = result;
    }

    loadingHistory = false;
  }

  async function refreshAll() {
    await Promise.all([refreshStatus(), refreshHistory()]);
  }

  async function restartEngine() {
    restarting = true;

    const result = await safeCall('restart_engine', () => restartEngineCommand());

    restarting = false;

    if (result?.ok) {
      showToast(result.message || 'Engine restarted.', 'success');
    }

    await refreshAll();
  }

  async function setupEngine(action: 'detect' | 'download' | 'choose') {
    setupBusy = action;
    setupError = null;

    const result = await safeCall<DetectStockfishResponse>(
      action === 'detect'
        ? 'detect_stockfish'
        : action === 'download'
          ? 'download_stockfish'
          : 'choose_stockfish_manually',
      () =>
        action === 'detect'
          ? detectStockfish()
          : action === 'download'
            ? downloadStockfish()
            : chooseStockfishManually(),
    );

    setupBusy = null;

    if (result?.ok) {
      setupError = null;
      forceSetupWizard = false;
      showToast(result.message || 'Chess engine is ready.', 'success');
    } else {
      setupError =
        result?.message ||
        'No compatible chess engine was found. You can download it automatically or choose a file manually.';

      forceSetupWizard = true;

      showToast(setupError, 'error');
    }

    await refreshAll();
  }

  function shouldShowSetupWizard() {
    return forceSetupWizard || Boolean(status?.setup_required);
  }

  function openSetupWizard() {
    activeTab = 'status';
    forceSetupWizard = true;
    setupError = null;
  }

  function closeSetupWizard() {
    if (!status?.setup_required) {
      forceSetupWizard = false;
      setupError = null;
    }
  }

  function statusLabel() {
    if (loadingStatus) return 'Starting';
    return status?.status_label ?? 'Starting';
  }

  function statusDescription() {
    if (loadingStatus) return 'Checking the local service and chess engine.';
    return status?.helper_text ?? 'The app is getting ready.';
  }

  function latestMove() {
    return status?.last_activity?.best_move ?? 'None yet';
  }

  function latestDifficulty() {
    return status?.last_activity?.difficulty?.label ?? 'None yet';
  }

  function latestDelay() {
    const delay = status?.last_activity?.difficulty?.recommended_delay_ms;

    if (delay === null || delay === undefined) return 'None yet';
    return `${delay}ms`;
  }

  function lastActivity() {
    if (!status?.last_activity?.timestamp) return 'No requests yet';

    try {
      return new Date(status.last_activity.timestamp).toLocaleTimeString();
    } catch {
      return status.last_activity.timestamp;
    }
  }

  function tabClass(tab: Tab) {
    return activeTab === tab
      ? 'bg-slate-800 text-slate-50 shadow-sm'
      : 'text-slate-400 hover:bg-slate-900 hover:text-slate-100';
  }

  onMount(() => {
    refreshAll();

    const timer = window.setInterval(refreshAll, 1500);

    return () => {
      window.clearInterval(timer);
      if (toastTimer) window.clearTimeout(toastTimer);
    };
  });
</script>

<svelte:head>
  <title>roblox-chess-script</title>
</svelte:head>

<div class="flex h-full min-h-0 overflow-hidden bg-slate-950">
  <aside class="flex w-56 shrink-0 flex-col border-r border-slate-800 bg-slate-950 px-4 py-5">
    <div class="mb-6">
      <p class="text-[11px] font-medium uppercase tracking-[0.28em] text-slate-500 ml-6">
        Control Panel
      </p>
      <!-- <p class="mt-2 text-sm leading-5 text-slate-400">
                Local Roblox companion
            </p> -->
    </div>

    <nav class="space-y-2">
      <button
        type="button"
        class={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition ${tabClass(
          'status',
        )}`}
        on:click={() => (activeTab = 'status')}
      >
        <Signal size={17} />
        Status
      </button>

      <button
        type="button"
        class={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition ${tabClass(
          'output',
        )}`}
        on:click={() => (activeTab = 'output')}
      >
        <FileText size={17} />
        Output
      </button>

      <button
        type="button"
        class={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-medium transition ${tabClass(
          'settings',
        )}`}
        on:click={() => (activeTab = 'settings')}
      >
        <Settings size={17} />
        Settings
      </button>

      <button
        type="button"
        class="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-medium text-slate-400 transition hover:bg-slate-900 hover:text-slate-100"
        on:click={openSetupWizard}
      >
        <FileUp size={17} />
        Change Stockfish File
      </button>
    </nav>

    <div class="mt-auto rounded-2xl border border-slate-800 bg-slate-900/50 p-3">
      <div class="flex items-center gap-2">
        {#if loadingStatus}
          <Loader2 size={15} class="animate-spin text-slate-400" />
        {:else if status?.ready_for_roblox}
          <CheckCircle2 size={15} class="text-emerald-400" />
        {:else}
          <Activity size={15} class="text-amber-400" />
        {/if}

        <p class="text-xs font-medium text-slate-200">
          {statusLabel()}
        </p>
      </div>

      <p class="mt-2 line-clamp-2 text-xs leading-5 text-slate-500">
        {statusDescription()}
      </p>
    </div>
  </aside>

  <section class="relative min-w-0 flex-1 overflow-hidden p-5">
    {#if shouldShowSetupWizard()}
      <div
        class="flex h-full min-h-0 flex-col justify-between rounded-3xl border border-slate-800 bg-slate-900/60 p-7"
      >
        <div>
          <div
            class="inline-flex rounded-full border border-amber-400/30 bg-amber-400/10 px-3 py-1 text-xs font-medium text-amber-200"
          >
            Setup needed
          </div>

          <h1 class="mt-5 text-3xl font-semibold tracking-tight text-slate-50">
            Install the chess engine
          </h1>

          {#if setupError}
            <div
              class="mt-4 rounded-2xl border border-red-500/25 bg-red-500/10 px-4 py-3 text-sm leading-6 text-red-100"
            >
              {setupError}
            </div>
          {/if}

          <div class="mt-6 grid grid-cols-2 gap-4">
            <button
              type="button"
              class="rounded-2xl border border-emerald-400/30 bg-emerald-400/10 p-5 text-left transition hover:bg-emerald-400/15 disabled:opacity-60"
              disabled={setupBusy !== null}
              on:click={() => setupEngine('download')}
            >
              <div
                class="mb-4 grid h-11 w-11 place-items-center rounded-xl bg-emerald-400 text-slate-950"
              >
                {#if setupBusy === 'download'}
                  <Loader2 size={20} class="animate-spin" />
                {:else}
                  <Download size={20} />
                {/if}
              </div>

              <p class="font-semibold text-slate-50">Download Automatically</p>
              <p class="mt-1 text-xs leading-5 text-slate-400">
                Recommended. Installs the latest compatible engine and applies safe defaults.
              </p>
            </button>

            <button
              type="button"
              class="rounded-2xl border border-slate-800 bg-slate-950/60 p-5 text-left transition hover:border-slate-700 hover:bg-slate-900 disabled:opacity-60"
              disabled={setupBusy !== null}
              on:click={() => setupEngine('choose')}
            >
              <div
                class="mb-4 grid h-11 w-11 place-items-center rounded-xl bg-slate-800 text-slate-100"
              >
                {#if setupBusy === 'choose'}
                  <Loader2 size={20} class="animate-spin" />
                {:else}
                  <FileUp size={20} />
                {/if}
              </div>

              <p class="font-semibold text-slate-50">Choose Existing File</p>
              <p class="mt-1 text-xs leading-5 text-slate-400">
                Use this only if you already downloaded a compatible chess engine.
              </p>
            </button>
          </div>

          <div class="mt-4 rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
            <div class="flex items-start gap-3">
              <Search size={17} class="mt-0.5 text-slate-500" />
              <div>
                <p class="text-sm font-medium text-slate-100">Already installed?</p>
                <p class="mt-1 text-xs leading-5 text-slate-500">
                  The app can check common locations and previously downloaded files.
                </p>

                <button
                  type="button"
                  class="mt-3 rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm font-medium text-slate-200 hover:bg-slate-800 disabled:opacity-60"
                  disabled={setupBusy !== null}
                  on:click={() => setupEngine('detect')}
                >
                  {#if setupBusy === 'detect'}
                    <span class="inline-flex items-center gap-2">
                      <Loader2 size={15} class="animate-spin" />
                      Detecting...
                    </span>
                  {:else}
                    Detect Automatically
                  {/if}
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between gap-3">
          <p class="text-xs text-slate-500">
            Roblox will connect automatically once setup is complete.
          </p>

          {#if forceSetupWizard && !status?.setup_required}
            <button
              type="button"
              class="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs font-medium text-slate-300 hover:bg-slate-900"
              on:click={closeSetupWizard}
            >
              Back to main menu
            </button>
          {/if}
        </div>
      </div>
    {:else if activeTab === 'status'}
      <div class="flex h-full min-h-0 flex-col gap-4">
        <div
          class="rounded-3xl border border-slate-800 bg-slate-900/60 p-6 shadow-2xl shadow-black/20"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <div class="flex items-center gap-3">
                <div
                  class={`grid h-11 w-11 place-items-center rounded-2xl ${
                    status?.ready_for_roblox
                      ? 'bg-emerald-400/10 text-emerald-300'
                      : 'bg-amber-400/10 text-amber-300'
                  }`}
                >
                  {#if loadingStatus}
                    <Loader2 size={22} class="animate-spin" />
                  {:else if status?.ready_for_roblox}
                    <CheckCircle2 size={22} />
                  {:else}
                    <Bot size={22} />
                  {/if}
                </div>

                <div>
                  <p class="text-sm font-medium text-slate-400">Current status</p>
                  <h2 class="text-2xl font-semibold tracking-tight text-slate-50">
                    {statusLabel()}
                  </h2>
                </div>
              </div>

              <p class="mt-4 max-w-xl text-sm leading-6 text-slate-400">
                {statusDescription()}
              </p>

              {#if status?.engine?.last_error}
                <p
                  class="mt-3 rounded-xl border border-red-500/20 bg-red-500/10 px-3 py-2 text-sm text-red-200"
                >
                  {status.engine.last_error}
                </p>
              {/if}
            </div>

            <button
              type="button"
              class="rounded-xl border border-slate-700 bg-slate-950 px-4 py-2 text-sm font-medium text-slate-200 hover:bg-slate-900 disabled:opacity-60"
              disabled={restarting}
              on:click={restartEngine}
            >
              {#if restarting}
                <span class="inline-flex items-center gap-2">
                  <Loader2 size={15} class="animate-spin" />
                  Restarting
                </span>
              {:else}
                <span class="inline-flex items-center gap-2">
                  <RefreshCcw size={15} />
                  Restart
                </span>
              {/if}
            </button>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="rounded-2xl border border-slate-800 bg-slate-900/50 p-4">
            <div class="flex items-center gap-2 text-slate-400">
              <Clock3 size={16} />
              <p class="text-xs font-medium uppercase tracking-wide">Last activity</p>
            </div>
            <p class="mt-3 text-lg font-semibold text-slate-100">
              {lastActivity()}
            </p>
          </div>

          <div class="rounded-2xl border border-slate-800 bg-slate-900/50 p-4">
            <div class="flex items-center gap-2 text-slate-400">
              <Zap size={16} />
              <p class="text-xs font-medium uppercase tracking-wide">Latest move</p>
            </div>
            <p class="mt-3 text-lg font-semibold text-slate-100">
              {latestMove()}
            </p>
          </div>

          <div class="rounded-2xl border border-slate-800 bg-slate-900/50 p-4">
            <div class="flex items-center gap-2 text-slate-400">
              <Activity size={16} />
              <p class="text-xs font-medium uppercase tracking-wide">Difficulty</p>
            </div>
            <p class="mt-3 text-lg font-semibold text-slate-100">
              {latestDifficulty()}
            </p>
          </div>

          <div class="rounded-2xl border border-slate-800 bg-slate-900/50 p-4">
            <div class="flex items-center gap-2 text-slate-400">
              <History size={16} />
              <p class="text-xs font-medium uppercase tracking-wide">Suggested delay</p>
            </div>
            <p class="mt-3 text-lg font-semibold text-slate-100">
              {latestDelay()}
            </p>
          </div>
        </div>
      </div>
    {:else if activeTab === 'output'}
      <div class="flex h-full min-h-0 flex-col">
        <div class="mb-4 shrink-0">
          <p class="text-sm font-medium text-slate-400">Recent activity</p>
          <h2 class="text-2xl font-semibold tracking-tight text-slate-50">Output</h2>
        </div>

        <div
          class="min-h-0 flex-1 overflow-y-auto rounded-3xl border border-slate-800 bg-slate-900/50 p-4"
        >
          {#if loadingHistory}
            <div class="flex h-full items-center justify-center text-sm text-slate-500">
              <Loader2 size={17} class="mr-2 animate-spin" />
              Loading output...
            </div>
          {:else if history.length === 0}
            <div class="flex h-full items-center justify-center text-sm text-slate-500">
              No activity yet.
            </div>
          {:else}
            <div class="space-y-3">
              {#each history as item (item.id)}
                <article class="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <p class="text-sm font-semibold text-slate-100">
                        Best move: {item.best_move ?? 'Unknown'}
                      </p>
                      <p class="mt-1 text-xs text-slate-500">
                        {new Date(item.timestamp).toLocaleTimeString()}
                      </p>
                    </div>

                    <span class="rounded-full bg-slate-800 px-2.5 py-1 text-xs text-slate-300">
                      {item.difficulty?.label ?? item.status ?? 'Complete'}
                    </span>
                  </div>

                  <div class="mt-3 grid grid-cols-2 gap-3 text-xs text-slate-400">
                    <p>
                      Delay: {item.difficulty?.recommended_delay_ms ?? '—'}ms
                    </p>
                    <p>
                      Time: {item.time_taken_ms ?? '—'}ms
                    </p>
                  </div>

                  {#if item.error}
                    <p
                      class="mt-3 rounded-xl border border-red-500/20 bg-red-500/10 px-3 py-2 text-xs text-red-200"
                    >
                      {item.error}
                    </p>
                  {/if}

                  {#if item.fen}
                    <details class="mt-3">
                      <summary class="cursor-pointer text-xs text-slate-500 hover:text-slate-300">
                        Show position
                      </summary>
                      <p
                        class="mt-2 break-all rounded-xl bg-slate-900 p-3 font-mono text-[11px] leading-5 text-slate-400"
                      >
                        {item.fen}
                      </p>
                    </details>
                  {/if}
                </article>
              {/each}
            </div>
          {/if}
        </div>
      </div>
    {:else}
      <SettingsPanel on:notify={(event) => showToast(event.detail.message, event.detail.type)} />
    {/if}
  </section>
</div>

{#if toast}
  <div class="pointer-events-none fixed bottom-5 right-5 z-50">
    <div
      class={`pointer-events-auto rounded-2xl border px-4 py-3 text-sm shadow-2xl ${
        toast.type === 'error'
          ? 'border-red-500/30 bg-red-950 text-red-100'
          : toast.type === 'info'
            ? 'border-sky-500/30 bg-sky-950 text-sky-100'
            : 'border-emerald-500/30 bg-emerald-950 text-emerald-100'
      }`}
      in:fly={{ y: 10, duration: 140 }}
      out:fade={{ duration: 100 }}
    >
      {toast.message}
    </div>
  </div>
{/if}
