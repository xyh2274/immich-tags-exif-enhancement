import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/tag.model.dart';
import 'package:immich_mobile/domain/services/tag.service.dart';
import 'package:immich_mobile/repositories/asset_api.repository.dart';

class TagNotifier extends AsyncNotifier<Set<Tag>> {
  @override
  Future<Set<Tag>> build() async {
    return ref.watch(tagServiceProvider).getAllTags();
  }

  Future<int> bulkTagAssets(List<String> assetIds, List<String> tagIds) async {
    return ref.read(tagServiceProvider).bulkTagAssets(assetIds, tagIds);
  }

  Future<List<Tag>> upsertTags(List<String> tags) async {
    final upsertedTags = await ref.read(tagServiceProvider).upsertTags(tags);

    state = AsyncValue.data({...?state.valueOrNull, ...upsertedTags});
    return upsertedTags;
  }
}

final tagProvider = AsyncNotifierProvider<TagNotifier, Set<Tag>>(TagNotifier.new);

/// Fetches the tags assigned to a single remote asset (by its remote id).
///
/// The server returns the asset's tags as part of the [AssetResponseDto],
/// so we resolve them through the asset info endpoint and map them to the
/// local [Tag] model. This mirrors how the web detail panel reads
/// `asset.tags`.
final assetTagsProvider = FutureProvider.autoDispose.family<List<Tag>, String>((ref, assetId) async {
  final asset = await ref.watch(assetApiRepositoryProvider).getAssetInfo(assetId);
  final tags = asset.tags.value ?? const [];
  return tags.map((dto) => Tag.fromDto(dto)).toList(growable: false);
});
