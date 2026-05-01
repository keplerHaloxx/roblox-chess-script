<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import {
    ChevronDown,
    Cpu,
    Database,
    Download,
    Loader2,
    RefreshCcw,
    RotateCcw,
    Settings2,
    ShieldCheck,
    Sparkles,
    TestTube2,
  } from 'lucide-svelte';

  import {
    clearSyzygyFolders as clearSyzygyFoldersCommand,
    chooseSyzygyFolders as chooseSyzygyFoldersCommand,
    getSettings,
    redownloadStockfish,
    resetRecommendedSettings,
    restartEngine as restartEngineCommand,
    saveSettings as saveSettingsCommand,
    testConnection as testConnectionCommand,
  } from '$lib/tauriApi';
  import type { AppConfig, BotTimingPreset } from '$lib/types/app';

  type ToastType = 'success' | 'error' | 'info';

  const dispatch = createEventDispatcher<{
    notify: {
      message: string;
      type: ToastType;
    };
  }>();

  let loading = true;
  let saving = false;
  let advancedOpen = false;
  let connectionTesting = false;

  let settings: AppConfig = {
    server: {
      host: '127.0.0.1',
      port: 57250,
    },
    engine: {
      stockfish_path: null,
      hash_mb: 512,
      threads: 2,
      syzygy_paths: [],
      multipv: 4,
      auto_restart: true,
    },
    analysis: {
      difficulty_enabled: true,
      candidate_threshold_cp: 80,
      cancel_previous_on_new_request: true,
      min_delay_ms: 150,
      max_delay_ms: 2000,
      timing_preset: 'balanced',
    },
  };

  const presets: Array<{
    id: BotTimingPreset;
    name: string;
    description: string;
    badges?: string[];
  }> = [
    {
      id: 'quick',
      name: 'Quick',
      description: 'Moves faster with less extra checking.',
      badges: ['Fastest', 'Less accurate'],
    },
    {
      id: 'balanced',
      name: 'Balanced',
      description: 'Recommended for most users.',
      badges: ['Recommended'],
    },
    {
      id: 'careful',
      name: 'Careful',
      description: 'Takes a little more time on harder positions.',
    },
    {
      id: 'very_careful',
      name: 'Very Careful',
      description: 'Adds more time when the move is complicated.',
      badges: ['Slowest', 'Best results'],
    },
  ];

  function notify(message: string, type: ToastType = 'success') {
    dispatch('notify', { message, type });
  }

  async function safeCall<T>(label: string, fn: () => Promise<T>): Promise<T | null> {
    try {
      return await fn();
    } catch (error) {
      console.error(`Command failed: ${label}`, error);
      notify(String(error), 'error');
      return null;
    }
  }

  async function loadSettings() {
    loading = true;

    const result = await safeCall('get_settings', () => getSettings());

    if (result) {
      settings = result;
    }

    loading = false;
  }

  async function saveSettings(message = 'Settings saved.', restartEngine = false) {
    saving = true;

    const result = await safeCall('save_settings', () =>
      saveSettingsCommand(settings, restartEngine),
    );

    saving = false;

    if (result?.ok) {
      notify(message, 'success');
      await loadSettings();
    } else if (result?.message) {
      notify(result.message, 'error');
    }
  }

  async function setPreset(preset: BotTimingPreset) {
    settings = {
      ...settings,
      analysis: {
        ...settings.analysis,
        timing_preset: preset,
      },
    };

    await saveSettings('Bot timing updated.');
  }

  async function restartEngine() {
    const result = await safeCall('restart_engine', () => restartEngineCommand());

    if (result !== null) {
      notify('Engine restarted.', 'success');
    }
  }

  async function redownloadEngine() {
    const result = await safeCall('redownload_stockfish', () => redownloadStockfish());

    if (result !== null) {
      notify('Engine redownload started.', 'info');
    }
  }

  async function resetRecommended() {
    const result = await safeCall('reset_recommended_settings', () => resetRecommendedSettings());

    if (result?.ok) {
      notify('Recommended settings restored.', 'success');
      await loadSettings();
    } else if (result?.message) {
      notify(result.message, 'error');
      await loadSettings();
    }
  }

  async function chooseSyzygyFolders() {
    const result = await safeCall('choose_syzygy_folders', () => chooseSyzygyFoldersCommand());

    if (Array.isArray(result)) {
      settings = {
        ...settings,
        engine: {
          ...settings.engine,
          syzygy_paths: result,
        },
      };

      await saveSettings('Tablebase folders updated.');
    }
  }

  async function clearSyzygyFolders() {
    const result = await safeCall('clear_syzygy_folders', () => clearSyzygyFoldersCommand());

    if (Array.isArray(result)) {
      settings = {
        ...settings,
        engine: {
          ...settings.engine,
          syzygy_paths: result,
        },
      };
      notify('Tablebase folders cleared.', 'success');
    }
  }

  async function testConnection() {
    connectionTesting = true;

    const result = await safeCall('test_connection', () => testConnectionCommand());

    connectionTesting = false;

    if (result !== null) {
      notify('Local connection is working.', 'success');
    }
  }

  function enginePath() {
    return settings.engine.stockfish_path || 'Not configured';
  }

  onMount(loadSettings);
</script>

<div class="flex h-full min-h-0 flex-col">
  <div class="mb-4 shrink-0">
    <p class="text-sm font-medium text-slate-400">Control how the app behaves</p>
    <h2 class="text-2xl font-semibold tracking-tight text-slate-50">Settings</h2>
  </div>

  {#if loading}
    <div
      class="flex min-h-0 flex-1 items-center justify-center rounded-3xl border border-slate-800 bg-slate-900/50"
    >
      <div class="flex items-center gap-2 text-sm text-slate-400">
        <Loader2 size={18} class="animate-spin" />
        Loading settings...
      </div>
    </div>
  {:else}
    <div class="min-h-0 flex-1 overflow-y-auto pr-2">
      <div class="space-y-4 pb-5">
        <section class="rounded-3xl border border-slate-800 bg-slate-900/60 p-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <div class="flex items-center gap-2">
                <Sparkles size={18} class="text-emerald-300" />
                <h3 class="text-base font-semibold text-slate-50">Bot timing</h3>
              </div>

              <p class="mt-1 text-sm leading-6 text-slate-400">
                Choose how quickly the Roblox bot should respond. Balanced is recommended.
              </p>
            </div>

            {#if saving}
              <div
                class="flex items-center gap-2 rounded-full bg-slate-800 px-3 py-1 text-xs text-slate-300"
              >
                <Loader2 size={13} class="animate-spin" />
                Saving
              </div>
            {/if}
          </div>

          <div class="mt-4 grid grid-cols-2 gap-3">
            {#each presets as preset (preset.id)}
              <button
                type="button"
                class={`rounded-2xl border p-4 text-left transition ${
                  settings.analysis.timing_preset === preset.id
                    ? 'border-emerald-400/50 bg-emerald-400/10'
                    : 'border-slate-800 bg-slate-950/60 hover:border-slate-700 hover:bg-slate-900'
                }`}
                on:click={() => setPreset(preset.id)}
              >
                <div class="flex items-start justify-between gap-2">
                  <p class="font-semibold text-slate-50">
                    {preset.name}
                  </p>

                  {#if settings.analysis.timing_preset === preset.id}
                    <span
                      class="rounded-full bg-emerald-400/20 px-2 py-0.5 text-[11px] font-medium text-emerald-200"
                    >
                      Active
                    </span>
                  {/if}
                </div>

                <p class="mt-1 text-xs leading-5 text-slate-400">
                  {preset.description}
                </p>

                {#if preset.badges}
                  <div class="mt-3 flex flex-wrap gap-1.5">
                    {#each preset.badges as badge (badge)}
                      <span
                        class="rounded-full bg-slate-800 px-2 py-0.5 text-[11px] text-slate-300"
                      >
                        {badge}
                      </span>
                    {/each}
                  </div>
                {/if}
              </button>
            {/each}
          </div>
        </section>

        <section class="rounded-3xl border border-slate-800 bg-slate-900/60 p-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <div class="flex items-center gap-2">
                <ShieldCheck size={18} class="text-sky-300" />
                <h3 class="text-base font-semibold text-slate-50">App actions</h3>
              </div>

              <p class="mt-1 text-sm leading-6 text-slate-400">
                Use these when the app needs a refresh or setup should be restored.
              </p>
            </div>
          </div>

          <div class="mt-4 grid grid-cols-3 gap-3">
            <button
              type="button"
              class="flex items-center justify-center gap-2 rounded-2xl border border-slate-800 bg-slate-950 px-3 py-3 text-sm font-medium text-slate-200 hover:bg-slate-900"
              on:click={restartEngine}
            >
              <RefreshCcw size={15} />
              Restart
            </button>

            <button
              type="button"
              class="flex items-center justify-center gap-2 rounded-2xl border border-slate-800 bg-slate-950 px-3 py-3 text-sm font-medium text-slate-200 hover:bg-slate-900"
              on:click={redownloadEngine}
            >
              <Download size={15} />
              Redownload
            </button>

            <button
              type="button"
              class="flex items-center justify-center gap-2 rounded-2xl border border-slate-800 bg-slate-950 px-3 py-3 text-sm font-medium text-slate-200 hover:bg-slate-900"
              on:click={resetRecommended}
            >
              <RotateCcw size={15} />
              Reset
            </button>
          </div>
        </section>

        <section class="rounded-3xl border border-slate-800 bg-slate-900/60 p-5">
          <button
            type="button"
            class="flex w-full items-center justify-between gap-4 text-left"
            on:click={() => (advancedOpen = !advancedOpen)}
          >
            <div>
              <div class="flex items-center gap-2">
                <Settings2 size={18} class="text-slate-300" />
                <h3 class="text-base font-semibold text-slate-50">Advanced settings</h3>
              </div>

              <p class="mt-1 text-sm leading-6 text-slate-400">
                Optional controls for users who want more control.
              </p>
            </div>

            <ChevronDown
              size={18}
              class={`shrink-0 text-slate-400 transition ${advancedOpen ? 'rotate-180' : ''}`}
            />
          </button>

          {#if advancedOpen}
            <div class="mt-5 space-y-4">
              <div class="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <div class="mb-4 flex items-center gap-2">
                  <Cpu size={17} class="text-slate-400" />
                  <h4 class="font-medium text-slate-100">Engine performance</h4>
                </div>

                <div class="grid grid-cols-3 gap-3">
                  <label class="space-y-1">
                    <span class="text-xs font-medium text-slate-400">Hash memory</span>
                    <input
                      class="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-400"
                      type="number"
                      min="16"
                      step="16"
                      bind:value={settings.engine!.hash_mb}
                      on:change={() => saveSettings('Hash memory updated.')}
                    />
                  </label>

                  <label class="space-y-1">
                    <span class="text-xs font-medium text-slate-400">Threads</span>
                    <input
                      class="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-400"
                      type="number"
                      min="1"
                      step="1"
                      bind:value={settings.engine!.threads}
                      on:change={() => saveSettings('Thread count updated.')}
                    />
                  </label>

                  <label class="space-y-1">
                    <span class="text-xs font-medium text-slate-400">Candidate moves</span>
                    <input
                      class="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-emerald-400"
                      type="number"
                      min="1"
                      max="8"
                      step="1"
                      bind:value={settings.engine!.multipv}
                      on:change={() => saveSettings('Candidate move count updated.')}
                    />
                  </label>
                </div>

                <label
                  class="mt-4 flex items-center justify-between rounded-xl border border-slate-800 bg-slate-900/60 px-3 py-3"
                >
                  <div>
                    <p class="text-sm font-medium text-slate-100">Auto restart engine</p>
                    <p class="text-xs text-slate-500">Restart automatically if the engine stops.</p>
                  </div>

                  <input
                    type="checkbox"
                    class="h-4 w-4 accent-emerald-400"
                    bind:checked={settings.engine!.auto_restart}
                    on:change={() => saveSettings('Auto restart updated.')}
                  />
                </label>
              </div>

              <div class="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <div class="mb-4 flex items-center gap-2">
                  <Database size={17} class="text-slate-400" />
                  <h4 class="font-medium text-slate-100">Tablebases</h4>
                </div>

                <p class="text-sm leading-6 text-slate-400">
                  Tablebases can improve endgame accuracy if you already have them. Most users do
                  not need this.
                </p>

                <div class="mt-4 flex gap-2">
                  <button
                    type="button"
                    class="rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm font-medium text-slate-200 hover:bg-slate-800"
                    on:click={chooseSyzygyFolders}
                  >
                    Add folders
                  </button>

                  <button
                    type="button"
                    class="rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-sm font-medium text-slate-300 hover:bg-slate-900"
                    on:click={clearSyzygyFolders}
                  >
                    Clear
                  </button>
                </div>

                <div class="mt-4 space-y-2">
                  {#if settings.engine?.syzygy_paths && settings.engine.syzygy_paths.length > 0}
                    {#each settings.engine.syzygy_paths as path (path)}
                      <div
                        class="break-all rounded-xl border border-slate-800 bg-slate-900 px-3 py-2 text-xs text-slate-400"
                      >
                        {path}
                      </div>
                    {/each}
                  {:else}
                    <div
                      class="rounded-xl border border-dashed border-slate-800 bg-slate-900/40 px-3 py-3 text-sm text-slate-500"
                    >
                      No tablebase folders configured.
                    </div>
                  {/if}
                </div>
              </div>

              <div class="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <h4 class="font-medium text-slate-100">Connection</h4>

                <div class="mt-3 grid grid-cols-2 gap-3">
                  <div class="rounded-xl border border-slate-800 bg-slate-900/60 p-3">
                    <p class="text-xs text-slate-500">Host</p>
                    <p class="mt-1 font-mono text-sm text-slate-200">
                      {settings.server?.host ?? '127.0.0.1'}
                    </p>
                  </div>

                  <div class="rounded-xl border border-slate-800 bg-slate-900/60 p-3">
                    <p class="text-xs text-slate-500">Port</p>
                    <p class="mt-1 font-mono text-sm text-slate-200">
                      {settings.server?.port ?? 57250}
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  class="mt-4 flex items-center gap-2 rounded-xl border border-slate-700 bg-slate-900 px-3 py-2 text-sm font-medium text-slate-200 hover:bg-slate-800"
                  on:click={testConnection}
                  disabled={connectionTesting}
                >
                  {#if connectionTesting}
                    <Loader2 size={15} class="animate-spin" />
                    Testing...
                  {:else}
                    <TestTube2 size={15} />
                    Test connection
                  {/if}
                </button>
              </div>

              <div class="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
                <h4 class="font-medium text-slate-100">Chess engine location</h4>

                <p
                  class="mt-2 break-all rounded-xl bg-slate-900 p-3 font-mono text-xs leading-5 text-slate-400"
                >
                  {enginePath()}
                </p>

                <p class="mt-2 text-xs text-slate-500">
                  Changing the engine file requires restarting the app.
                </p>
              </div>
            </div>
          {/if}
        </section>
      </div>
    </div>
  {/if}
</div>
