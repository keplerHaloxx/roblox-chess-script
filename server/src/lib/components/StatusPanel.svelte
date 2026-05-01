<script lang="ts">
  import { Activity, Brain, Clock, Gauge, Radio, RotateCcw } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import { formatRelative, titleCase } from '$lib/utils';
  import type { UiStatusResponse } from '$lib/types/app';

  export let status: UiStatusResponse;
  export let busy = false;
  export let onRestart: () => Promise<void>;

  $: last = status.last_activity;
  $: difficulty = last?.difficulty;
  let readyTone: 'success' | 'warning' | 'danger';
  $: readyTone = status.ready_for_roblox ? 'success' : status.setup_required ? 'warning' : 'danger';
</script>

<div class="grid h-full grid-cols-[1.1fr_0.9fr] gap-5">
  <Card className="p-6">
    <div class="flex h-full flex-col justify-between">
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <Badge tone={readyTone}>{status.status_label}</Badge>
          <Button variant="ghost" size="sm" disabled={busy} on:click={onRestart}>
            <RotateCcw class="h-4 w-4" /> Restart
          </Button>
        </div>

        <div class="space-y-3">
          <h1 class="text-3xl font-semibold tracking-tight">{status.status_label}</h1>
          <p class="max-w-md text-sm leading-6 text-muted-foreground">{status.helper_text}</p>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div class="rounded-2xl bg-muted/60 p-4">
            <div class="mb-2 flex items-center gap-2 text-xs font-medium text-muted-foreground">
              <Radio class="h-4 w-4" /> Last request
            </div>
            <div class="text-lg font-semibold">{formatRelative(last?.timestamp)}</div>
          </div>

          <div class="rounded-2xl bg-muted/60 p-4">
            <div class="mb-2 flex items-center gap-2 text-xs font-medium text-muted-foreground">
              <Activity class="h-4 w-4" /> Last move
            </div>
            <div class="text-lg font-semibold">{last?.best_move ?? '—'}</div>
          </div>
        </div>
      </div>

      <div class="rounded-2xl border border-border bg-white p-4">
        <div class="mb-3 flex items-center justify-between">
          <span class="text-sm font-semibold">Engine</span>
          <Badge tone="muted">{titleCase(status.engine.status)}</Badge>
        </div>
        <div class="space-y-1 text-xs text-muted-foreground">
          <div>{status.engine.name ?? 'Chess engine not identified yet'}</div>
          {#if status.engine.last_error}
            <div class="text-danger">{status.engine.last_error}</div>
          {/if}
        </div>
      </div>
    </div>
  </Card>

  <div class="grid grid-rows-2 gap-5">
    <Card className="p-5">
      <div class="mb-4 flex items-center gap-2">
        <Brain class="h-5 w-5 text-primary" />
        <div class="font-semibold">Move difficulty</div>
      </div>
      <div class="text-3xl font-semibold">{difficulty?.label ?? '—'}</div>
      <p class="mt-2 text-xs leading-5 text-muted-foreground">
        {difficulty?.reason ?? 'Difficulty appears after Roblox sends a position.'}
      </p>
    </Card>

    <Card className="p-5">
      <div class="mb-4 flex items-center gap-2">
        <Clock class="h-5 w-5 text-primary" />
        <div class="font-semibold">Suggested bot delay</div>
      </div>
      <div class="text-3xl font-semibold">
        {difficulty ? `${difficulty.recommended_delay_ms}ms` : '—'}
      </div>
      <p class="mt-2 text-xs leading-5 text-muted-foreground">
        Returned to the client with the best move, so the client can use or override it.
      </p>
    </Card>
  </div>
</div>
