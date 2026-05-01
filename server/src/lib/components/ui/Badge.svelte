<script lang="ts">
  import { cn } from '$lib/utils';
  export let tone: 'default' | 'success' | 'warning' | 'danger' | 'muted' = 'default';
  export let className = '';
</script>

<span
  class={cn(
    'inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-semibold leading-none',
    tone === 'default' && 'bg-primary/10 text-primary',
    tone === 'success' && 'bg-success/10 text-success',
    tone === 'warning' && 'bg-warning/15 text-yellow-700',
    tone === 'danger' && 'bg-danger/10 text-danger',
    tone === 'muted' && 'bg-muted text-muted-foreground',
    className,
  )}
>
  <slot />
</span>
