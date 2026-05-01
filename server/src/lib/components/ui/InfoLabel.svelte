<script lang="ts">
  export let label: string;
  export let help = '';
</script>

<div class="space-y-1">
  <div class="text-sm font-medium text-foreground">{label}</div>
  {#if help}
    <div class="text-xs leading-relaxed text-muted-foreground">{help}</div>
  {/if}
  <slot />
</div>
