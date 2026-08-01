<script lang="ts">
  import { Route } from '$lib/route';
  import { type AssetResponseDto } from '@immich/sdk';
  import { Text } from '@immich/ui';
  import { mdiPalette } from '@mdi/js';
  import { Icon } from '@immich/ui';
  import { t } from 'svelte-i18n';

  type Props = {
    asset: AssetResponseDto;
  };

  const { asset }: Props = $props();

  type PixivMeta = {
    pid?: string;
    title?: string;
    creator?: string;
    software?: string;
    userComment?: string;
  };

  function parsePixiv(description: string): PixivMeta | null {
    if (!description.includes(' || ')) {
      return null;
    }
    const parts = description.split(' || ');
    if (parts.length === 0) {
      return null;
    }

    const meta: PixivMeta = {};
    const firstPart = parts[0].trim();
    const hasKeyPrefix = (s: string) =>
      s.startsWith('Title: ') ||
      s.startsWith('Creator: ') ||
      s.startsWith('Software: ') ||
      s.startsWith('UserComment: ');
    if (firstPart.length > 0 && !hasKeyPrefix(firstPart)) {
      meta.pid = firstPart;
    }

    for (let i = 1; i < parts.length; i++) {
      const part = parts[i].trim();
      if (part.length === 0) {
        continue;
      }
      const idx = part.indexOf(': ');
      if (idx <= 0) {
        continue;
      }
      const key = part.substring(0, idx).trim();
      const value = part.substring(idx + 2).trim();
      if (value.length === 0) {
        continue;
      }
      switch (key) {
        case 'Title': {
          meta.title = value;
          break;
        }
        case 'Creator': {
          meta.creator = value;
          break;
        }
        case 'Software': {
          meta.software = value;
          break;
        }
        case 'UserComment': {
          meta.userComment = value;
          break;
        }
      }
    }

    if (!meta.pid && !meta.title && !meta.creator && !meta.software && !meta.userComment) {
      return null;
    }
    return meta;
  }

  let meta = $derived(parsePixiv(asset.exifInfo?.description ?? ''));

  type Row = { label: string; value: string };

  let rows = $derived.by<Row[]>(() => {
    if (!meta) {
      return [];
    }
    const list: Row[] = [];
    if (meta.pid) {
      list.push({ label: $t('pid'), value: meta.pid });
    }
    if (meta.title) {
      list.push({ label: $t('title'), value: meta.title });
    }
    if (meta.creator) {
      list.push({ label: $t('creator'), value: meta.creator });
    }
    if (meta.software) {
      list.push({ label: $t('software'), value: meta.software });
    }
    if (meta.userComment) {
      list.push({ label: $t('user_comment'), value: meta.userComment });
    }
    return list;
  });
</script>

{#if rows.length > 0}
  <section class="px-4 py-4">
    <div class="flex place-items-center gap-2 pb-2">
      <Icon icon={mdiPalette} size="24" />
      <Text size="small" color="muted">{$t('pixiv_info')}</Text>
    </div>
    <div class="flex flex-col gap-1 pl-8">
      {#each rows as row (row.label)}
        <div class="flex gap-3 text-sm">
          <span class="w-28 shrink-0 text-immich-fg/60 dark:text-immich-dark-fg/60">{row.label}</span>
          <a
            href={Route.search({ description: row.value })}
            title={$t('search_for') + ' ' + row.value}
            class="flex-1 break-all text-left hover:text-primary dark:hover:text-immich-dark-primary"
          >
            {row.value}
          </a>
        </div>
      {/each}
    </div>
  </section>
{/if}
