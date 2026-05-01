<script lang="ts">
  import '../app.css';
  import TitleBar from '$lib/components/TitleBar.svelte';
</script>

<div class="flex h-screen w-screen flex-col overflow-hidden bg-slate-950 text-slate-100">
  <TitleBar />

  <main class="relative min-h-0 flex-1 overflow-hidden">
    <slot />
  </main>
</div>
