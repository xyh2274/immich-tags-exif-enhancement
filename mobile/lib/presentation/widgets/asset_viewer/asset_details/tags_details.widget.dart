import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/tag.model.dart';
import 'package:immich_mobile/domain/services/tag.service.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/presentation/pages/search/paginated_search.provider.dart';
import 'package:immich_mobile/providers/infrastructure/tag.provider.dart';
import 'package:immich_mobile/providers/infrastructure/user_metadata.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/common/tag_picker.dart';

/// Shows the tags assigned to the currently opened asset inside the info panel,
/// mirroring the web `DetailPanelTags` section:
///  - the asset's tags are rendered as tappable chips;
///  - tapping a chip jumps to the search view filtered by that tag;
///  - owners can remove a tag (chip trailing "x") and add tags ("+ Add");
///  - an empty state hints when the asset has no tags yet.
class TagsDetails extends HookConsumerWidget {
  final BaseAsset asset;

  const TagsDetails({super.key, required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = this.asset;
    if (asset is! RemoteAsset) {
      return const SizedBox.shrink();
    }

    final tagsEnabled = ref
        .watch(userMetadataPreferencesProvider)
        .maybeWhen(data: (prefs) => prefs?.tagsEnabled ?? false, orElse: () => false);
    if (!tagsEnabled) {
      return const SizedBox.shrink();
    }

    final remoteAsset = asset;
    final isOwner = remoteAsset.ownerId == ref.watch(currentUserProvider)?.id;
    final tagsAsync = ref.watch(assetTagsProvider(remoteAsset.id));
    final isProcessing = useState<bool>(false);

    Future<void> addTags() async {
      if (isProcessing.value) {
        return;
      }
      isProcessing.value = true;
      try {
        final result = await showTagPickerModal(context: context);
        if (result == null) {
          return;
        }
        final (selectedTagIds, newTagValues) = result;

        final tagService = ref.read(tagServiceProvider);
        final allTagIds = <String>{...selectedTagIds};
        if (newTagValues.isNotEmpty) {
          final created = await tagService.upsertTags(newTagValues.toList());
          allTagIds.addAll(created.map((t) => t.id));
        }
        if (allTagIds.isEmpty) {
          return;
        }

        final count = await tagService.bulkTagAssets([remoteAsset.id], allTagIds.toList());
        ref.invalidate(tagProvider);
        ref.invalidate(assetTagsProvider(remoteAsset.id));
        if (!context.mounted) {
        return;
      }
        ImmichToast.show(
          context: context,
          msg: 'tagged_assets'.t(context: context, args: {'count': count.toString()}),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.success,
        );
      } catch (e) {
        if (!context.mounted) {
        return;
      }
        ImmichToast.show(
          context: context,
          msg: 'errors.failed_to_tag_assets'.t(context: context),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.error,
        );
      } finally {
        isProcessing.value = false;
      }
    }

    Future<void> removeTag(Tag tag) async {
      if (isProcessing.value) {
        return;
      }
      isProcessing.value = true;
      try {
        await ref.read(tagServiceProvider).untagAssets(tag.id, [remoteAsset.id]);
        ref.invalidate(assetTagsProvider(remoteAsset.id));
        if (!context.mounted) {
        return;
      }
        ImmichToast.show(
          context: context,
          msg: 'tag_removed'.t(context: context),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.success,
        );
      } catch (e) {
        if (!context.mounted) {
        return;
      }
        ImmichToast.show(
          context: context,
          msg: 'errors.failed_to_remove_tag'.t(context: context),
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.error,
        );
      } finally {
        isProcessing.value = false;
      }
    }

    void navigateToTag(Tag tag) {
      ref.invalidate(paginatedSearchProvider);
      ref.read(searchPreFilterProvider.notifier)
        ..clear()
        ..setFilter(
          SearchFilter(
            people: {},
            location: SearchLocationFilter(),
            camera: SearchCameraFilter(),
            date: SearchDateFilter(),
            display: SearchDisplayFilters(isNotInAlbum: false, isArchive: false, isFavorite: false),
            rating: SearchRatingFilter(),
            mediaType: AssetType.other,
            tagIds: [tag.id],
          ),
        );
      context.navigateTo(const DriftSearchRoute());
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'tags'.t(context: context),
            style: context.textTheme.labelLarge?.copyWith(color: context.colorScheme.onSurfaceSecondary),
          ),
          tagsAsync.when(
            data: (tags) {
              if (tags.isEmpty) {
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'no_tags_yet'.t(context: context),
                      style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.onSurfaceSecondary),
                    ),
                    if (isOwner) _AddTagChip(isProcessing: isProcessing.value, onTap: addTags),
                  ],
                );
              }

              return Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in tags)
                    _TagChip(
                      tag: tag,
                      canDelete: isOwner && !isProcessing.value,
                      onTap: () => navigateToTag(tag),
                      onDelete: () => removeTag(tag),
                    ),
                  if (isOwner) _AddTagChip(isProcessing: isProcessing.value, onTap: addTags),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 24,
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, s) => Text(
              'error_loading_tags'.t(context: context),
              style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final Tag tag;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _TagChip({required this.tag, required this.canDelete, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fg = context.themeData.colorScheme.primary;

    return Material(
      color: fg.withAlpha(26),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: EdgeInsets.only(left: 10, top: 6, bottom: 6, right: canDelete ? 2 : 10),
              child: Text(
                tag.value,
                style: context.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.close_rounded, size: 16, color: fg),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              visualDensity: VisualDensity.compact,
              tooltip: 'remove_tag'.t(context: context),
            ),
        ],
      ),
    );
  }
}

class _AddTagChip extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onTap;

  const _AddTagChip({required this.isProcessing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = context.themeData.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isProcessing ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fg.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else
                Icon(Icons.add_rounded, size: 16, color: fg),
              const SizedBox(width: 4),
              Text(
                'add_tag'.t(context: context),
                style: context.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
