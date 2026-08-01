import 'package:openapi/api.dart';

class Tag {
  final String id;
  final String value;
  final int? assetCount;

  const Tag({required this.id, required this.value, this.assetCount});

  @override
  String toString() {
    return 'Tag(id: $id, value: $value, assetCount: $assetCount)';
  }

  @override
  bool operator ==(covariant Tag other) {
    if (identical(this, other)) {
      return true;
    }

    return other.id == id && other.value == value && other.assetCount == assetCount;
  }

  @override
  int get hashCode {
    return id.hashCode ^ value.hashCode ^ (assetCount?.hashCode ?? 0);
  }

  static Tag fromDto(TagResponseDto dto) {
    return Tag(id: dto.id, value: dto.value, assetCount: dto.assetCount);
  }
}
