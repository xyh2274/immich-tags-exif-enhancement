import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/models/search/search_filter.model.dart';
import 'package:immich_mobile/presentation/pages/search/paginated_search.provider.dart';
import 'package:immich_mobile/routing/router.dart';

/// 解析后端拼接的 pixiv 结构化 description 字符串，单独显示
/// PID、标题、作者、来源、用户评论 5 项。
///
/// 后端拼接格式（见飞牛 NAS volume 挂载的 metadata.service.js）：
///   `<ImageDescription> || Title: <XMP_Title> || Creator: <XMP_Creator>
///    || Software: <Software> || UserComment: <UserComment>`
///
/// 当 description 不包含 ` || ` 分隔符时，说明是普通图片，此组件返回空。
// ignore_for_file: unintended_html_in_doc_comment
class PixivDetails extends ConsumerWidget {
  final BaseAsset asset;
  final ExifInfo? exifInfo;

  const PixivDetails({super.key, required this.asset, required this.exifInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = exifInfo?.description;
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsed = _PixivMetadata.parse(description);
    if (parsed == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'pixiv_info'.t(context: context),
            style: context.textTheme.labelLarge?.copyWith(
              color: context.colorScheme.onSurfaceSecondary,
            ),
          ),
          if (parsed.pid != null)
            _PixivInfoRow(
              label: 'pid'.t(context: context),
              value: parsed.pid!,
              onTap: () => _navigateToSearch(context, ref, parsed.pid!),
            ),
          if (parsed.title != null)
            _PixivInfoRow(
              label: 'title'.t(context: context),
              value: parsed.title!,
              onTap: () => _navigateToSearch(context, ref, parsed.title!),
            ),
          if (parsed.creator != null)
            _PixivInfoRow(
              label: 'creator'.t(context: context),
              value: parsed.creator!,
              onTap: () => _navigateToSearch(context, ref, parsed.creator!),
            ),
          if (parsed.software != null)
            _PixivInfoRow(
              label: 'software'.t(context: context),
              value: parsed.software!,
              onTap: () => _navigateToSearch(context, ref, parsed.software!),
            ),
          if (parsed.userComment != null)
            _PixivInfoRow(
              label: 'user_comment'.t(context: context),
              value: parsed.userComment!,
              onTap: () => _navigateToSearch(context, ref, parsed.userComment!),
            ),
        ],
      ),
    );
  }

  /// 跳转到搜索页，按 description 字段模糊匹配
  void _navigateToSearch(BuildContext context, WidgetRef ref, String query) {
    ref.invalidate(paginatedSearchProvider);
    ref.read(searchPreFilterProvider.notifier)
      ..clear()
      ..setFilter(
        SearchFilter(
          people: {},
          location: SearchLocationFilter(),
          camera: SearchCameraFilter(),
          date: SearchDateFilter(),
          display: SearchDisplayFilters(
            isNotInAlbum: false,
            isArchive: false,
            isFavorite: false,
          ),
          rating: SearchRatingFilter(),
          mediaType: AssetType.other,
          description: query,
        ),
      );
    context.navigateTo(const DriftSearchRoute());
  }
}

/// 解析后的 pixiv 元数据
class _PixivMetadata {
  final String? pid;
  final String? title;
  final String? creator;
  final String? software;
  final String? userComment;

  const _PixivMetadata({
    this.pid,
    this.title,
    this.creator,
    this.software,
    this.userComment,
  });

  /// 解析 description 字符串。如果不是 pixiv 结构化格式，返回 null。
  /// 格式: `<pid> || Title: <title> || Creator: <creator> || Software: <software> || UserComment: <comment>`
  static _PixivMetadata? parse(String description) {
    if (!description.contains(' || ')) {
      return null;
    }

    final parts = description.split(' || ');
    if (parts.isEmpty) {
      return null;
    }

    String? pid;
    String? title;
    String? creator;
    String? software;
    String? userComment;

    // 第一段如果没有 "Key: " 前缀，视为 PID（来自 ImageDescription）
    final firstPart = parts.first.trim();
    if (firstPart.isNotEmpty && !_hasKeyPrefix(firstPart)) {
      pid = firstPart;
    }

    for (var i = 1; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) {
        continue;
      }
      final colonIdx = part.indexOf(': ');
      if (colonIdx <= 0) {
        continue;
      }
      final key = part.substring(0, colonIdx).trim();
      final value = part.substring(colonIdx + 2).trim();
      if (value.isEmpty) {
        continue;
      }
      switch (key) {
        case 'Title':
          title = value;
        case 'Creator':
          creator = value;
        case 'Software':
          software = value;
        case 'UserComment':
          userComment = value;
      }
    }

    // 至少要有一个字段才返回
    if (pid == null &&
        title == null &&
        creator == null &&
        software == null &&
        userComment == null) {
      return null;
    }

    return _PixivMetadata(
      pid: pid,
      title: title,
      creator: creator,
      software: software,
      userComment: userComment,
    );
  }

  static bool _hasKeyPrefix(String s) {
    return s.startsWith('Title: ') ||
        s.startsWith('Creator: ') ||
        s.startsWith('Software: ') ||
        s.startsWith('UserComment: ');
  }
}

class _PixivInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _PixivInfoRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = context.themeData.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceSecondary,
              ),
            ),
          ),
          Expanded(
            child: onTap == null
                ? Text(value, style: context.textTheme.bodyMedium)
                : InkWell(
                    onTap: onTap,
                    child: Text(
                      value,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: fg,
                        decoration: TextDecoration.underline,
                        decorationColor: fg.withAlpha(120),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
