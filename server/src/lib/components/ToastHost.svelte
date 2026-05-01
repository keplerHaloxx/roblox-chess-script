<script lang="ts">
  import { fly, fade } from 'svelte/transition';

  export let message: string | null = null;
  export let type: 'success' | 'error' | 'info' = 'success';

  $: tone =
    type === 'success'
      ? 'border-emerald-500/30 bg-emerald-500/10'
      : type === 'error'
        ? 'border-red-500/30 bg-red-500/10'
        : 'border-sky-500/30 bg-sky-500/10';
</script>

{#if message}
  <div class="pointer-events-none fixed bottom-5 right-5 z-50">
    <div
      class={`pointer-events-auto rounded-xl border px-4 py-3 text-sm text-slate-100 shadow-2xl ${tone}`}
      in:fly
      out:fade
    >
      {message}
    </div>
  </div>
{/if}
