<script lang="ts">
  import Badge from '$lib/components/ui/Badge.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { titleCase } from '$lib/utils';
  import type { HistoryItem } from '$lib/types/app';

  export let history: HistoryItem[] = [];
</script>

<Card className="h-full p-5">
  <div class="mb-4 flex items-center justify-between">
    <div>
      <h2 class="text-lg font-semibold">Output</h2>
      <p class="text-xs text-muted-foreground">
        Recent requests and results stay here so the main screen stays clean.
      </p>
    </div>
    <Badge tone="muted">{history.length} events</Badge>
  </div>

  <div class="no-scrollbar h-125 space-y-3 overflow-y-auto pr-1">
    {#if history.length === 0}
      <div
        class="rounded-2xl border border-dashed border-border p-8 text-center text-sm text-muted-foreground"
      >
        No requests yet. Open Roblox and the latest results will appear here.
      </div>
    {:else}
      {#each [...history].reverse() as item (item.id)}
        <div class="rounded-2xl border border-border bg-white p-4">
          <div class="mb-3 flex items-center justify-between gap-3">
            <div class="flex items-center gap-2">
              <Badge tone={item.status === 'ok' ? 'success' : 'danger'}
                >{titleCase(item.status)}</Badge
              >
              <span class="text-xs text-muted-foreground"
                >{new Date(item.timestamp).toLocaleTimeString()}</span
              >
            </div>
            {#if item.time_taken_ms !== null}
              <span class="text-xs font-medium text-muted-foreground">{item.time_taken_ms}ms</span>
            {/if}
          </div>

          <div class="grid grid-cols-3 gap-3 text-sm">
            <div>
              <div class="text-xs text-muted-foreground">Best move</div>
              <div class="font-semibold">{item.best_move ?? '—'}</div>
            </div>
            <div>
              <div class="text-xs text-muted-foreground">Difficulty</div>
              <div class="font-semibold">{item.difficulty?.label ?? '—'}</div>
            </div>
            <div>
              <div class="text-xs text-muted-foreground">Delay</div>
              <div class="font-semibold">
                {item.difficulty ? `${item.difficulty.recommended_delay_ms}ms` : '—'}
              </div>
            </div>
          </div>

          {#if item.error}
            <div class="mt-3 rounded-xl bg-danger/5 p-3 text-xs leading-5 text-danger">
              {item.error}
            </div>
          {/if}

          <details class="mt-3 text-xs text-muted-foreground">
            <summary class="cursor-pointer select-none font-medium text-foreground"
              >Technical details</summary
            >
            <pre
              class="mt-2 max-h-28 overflow-auto rounded-xl bg-muted p-3 text-[11px] leading-5">{item.fen}</pre>
          </details>
        </div>
      {/each}
    {/if}
  </div>
</Card>
