<script lang="ts">
  import { cn } from '$lib/utils';

  export let variant: 'primary' | 'secondary' | 'ghost' | 'danger' = 'primary';
  export let size: 'sm' | 'md' | 'lg' = 'md';
  export let disabled = false;
  export let type: 'button' | 'submit' | 'reset' = 'button';
  export let className = '';
</script>

<button
  {type}
  {disabled}
  on:click
  class={cn(
    'inline-flex items-center justify-center gap-2 rounded-xl font-medium transition focus:outline-none focus:ring-2 focus:ring-primary/30 disabled:pointer-events-none disabled:opacity-50',
    size === 'sm' && 'h-8 px-3 text-xs',
    size === 'md' && 'h-10 px-4 text-sm',
    size === 'lg' && 'h-12 px-5 text-base',
    variant === 'primary' && 'bg-primary text-primary-foreground shadow-sm hover:bg-primary/90',
    variant === 'secondary' &&
      'border border-border bg-white text-foreground shadow-sm hover:bg-muted',
    variant === 'ghost' && 'text-muted-foreground hover:bg-muted hover:text-foreground',
    variant === 'danger' && 'bg-danger text-white shadow-sm hover:bg-danger/90',
    className,
  )}
>
  <slot />
</button>
