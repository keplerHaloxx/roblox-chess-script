<script lang="ts">
  import { cn } from '$lib/utils';
  export let value: string;
  export let items: { value: string; label: string }[] = [];
</script>

<div class="inline-flex rounded-2xl border border-border bg-muted p-1">
  {#each items as item (item.value)}
    <button
      class={cn(
        'h-9 rounded-xl px-4 text-sm font-medium transition',
        value === item.value
          ? 'bg-white text-foreground shadow-sm'
          : 'text-muted-foreground hover:text-foreground',
      )}
      on:click={() => (value = item.value)}
    >
      {item.label}
    </button>
  {/each}
</div>
