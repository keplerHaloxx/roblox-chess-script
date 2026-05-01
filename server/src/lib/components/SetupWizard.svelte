<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { Download, FileUp, Loader2, Search } from 'lucide-svelte';
  import Button from '$lib/components/ui/Button.svelte';
  import Card from '$lib/components/ui/Card.svelte';
  import Badge from '$lib/components/ui/Badge.svelte';
  import type { DetectStockfishResponse } from '$lib/types/app';
  import { chooseStockfishManually, detectStockfish, downloadStockfish } from '$lib/tauriApi';

  const dispatch = createEventDispatcher<{ refresh: void; notice: string; error: string }>();
  let busy: 'detect' | 'download' | 'choose' | null = null;
  let message = '';

  async function run(action: 'detect' | 'download' | 'choose') {
    busy = action;
    message = '';
    try {
      const response: DetectStockfishResponse =
        action === 'detect'
          ? await detectStockfish()
          : action === 'download'
            ? await downloadStockfish()
            : await chooseStockfishManually();
      message = response.message;
      if (response.ok) {
        dispatch('notice', response.message);
        dispatch('refresh');
      }
    } catch (err) {
      dispatch('error', String(err));
    } finally {
      busy = null;
    }
  }
</script>

<Card className="h-full p-8">
  <div class="flex h-full flex-col justify-between">
    <div class="space-y-6">
      <div class="flex items-center gap-3">
        <Badge tone="warning">Setup</Badge>
        <span class="text-sm text-muted-foreground">One-time setup</span>
      </div>

      <div class="max-w-xl space-y-3">
        <h1 class="text-3xl font-semibold tracking-tight">Install the chess engine</h1>
        <p class="text-sm leading-6 text-muted-foreground">
          Download automatically to get ready with the recommended setup. If you already have an
          engine file, choose it manually instead.
        </p>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <button
          class="group rounded-2xl border border-primary/20 bg-primary/5 p-5 text-left transition hover:border-primary/40 hover:bg-primary/10"
          on:click={() => run('download')}
          disabled={busy !== null}
        >
          <div
            class="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-primary text-primary-foreground"
          >
            {#if busy === 'download'}
              <Loader2 class="h-5 w-5 animate-spin" />
            {:else}
              <Download class="h-5 w-5" />
            {/if}
          </div>
          <div class="font-semibold">Download Automatically</div>
          <div class="mt-1 text-xs leading-5 text-muted-foreground">
            Recommended. Installs the latest compatible engine and applies safe defaults.
          </div>
        </button>

        <button
          class="group rounded-2xl border border-border bg-white p-5 text-left transition hover:border-primary/30 hover:bg-muted/40"
          on:click={() => run('choose')}
          disabled={busy !== null}
        >
          <div
            class="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-muted text-foreground"
          >
            {#if busy === 'choose'}
              <Loader2 class="h-5 w-5 animate-spin" />
            {:else}
              <FileUp class="h-5 w-5" />
            {/if}
          </div>
          <div class="font-semibold">Choose Existing File</div>
          <div class="mt-1 text-xs leading-5 text-muted-foreground">
            Use this only if you already downloaded a compatible chess engine.
          </div>
        </button>
      </div>

      <div class="rounded-2xl border border-border bg-muted/40 p-4">
        <div class="flex items-start gap-3">
          <Search class="mt-0.5 h-4 w-4 text-muted-foreground" />
          <div class="space-y-2">
            <div class="text-sm font-medium">Already installed?</div>
            <p class="text-xs leading-5 text-muted-foreground">
              The app can check common locations and previously downloaded files.
            </p>
            <Button
              variant="secondary"
              size="sm"
              disabled={busy !== null}
              on:click={() => run('detect')}
            >
              {#if busy === 'detect'}<Loader2 class="h-4 w-4 animate-spin" />{/if}
              Detect Automatically
            </Button>
          </div>
        </div>
      </div>
    </div>

    <div class="min-h-6 text-sm text-muted-foreground">{message}</div>
  </div>
</Card>
