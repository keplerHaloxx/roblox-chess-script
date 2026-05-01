<script lang="ts">
  import { cn } from '$lib/utils';
  export let className = '';
</script>

<section
  class={cn('rounded-2xl border border-border bg-card text-card-foreground shadow-soft', className)}
>
  <slot />
</section>
