<script lang="ts">
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import { Minus, X } from 'lucide-svelte';

  const appWindow = getCurrentWindow();

  function startDrag(event: MouseEvent) {
    const target = event.target as HTMLElement;
    if (target.closest('button')) return;
    appWindow.startDragging();
  }
</script>

<header
  class="flex h-10 shrink-0 items-center justify-between border-b border-slate-800 bg-slate-950/95 px-3"
  on:mousedown={startDrag}
  role="menubar"
  tabindex="0"
>
  <div class="flex items-center gap-2">
    <div class="h-2.5 w-2.5 rounded-full bg-emerald-400"></div>
    <span class="text-sm font-semibold tracking-wide text-slate-100"> roblox-chess-script </span>
  </div>

  <div class="flex items-center gap-1">
    <button
      type="button"
      class="grid h-7 w-8 place-items-center rounded-md text-slate-400 hover:bg-slate-800 hover:text-slate-100"
      aria-label="Minimize"
      on:click={() => appWindow.minimize()}
    >
      <Minus size={15} />
    </button>

    <button
      type="button"
      class="grid h-7 w-8 place-items-center rounded-md text-slate-400 hover:bg-red-500/20 hover:text-red-300"
      aria-label="Close"
      on:click={() => appWindow.close()}
    >
      <X size={15} />
    </button>
  </div>
</header>
