/// Where a catalog file lives: in the app bundle or in the documents dir.
sealed class ContentRef {
  const ContentRef();
}

class AssetRef extends ContentRef {
  const AssetRef(this.asset);
  final String asset;
  @override
  bool operator ==(Object other) => other is AssetRef && other.asset == asset;
  @override
  int get hashCode => asset.hashCode;
  @override
  String toString() => 'AssetRef($asset)';
}

class FileRef extends ContentRef {
  const FileRef(this.path);
  final String path;
  @override
  bool operator ==(Object other) => other is FileRef && other.path == path;
  @override
  int get hashCode => path.hashCode;
  @override
  String toString() => 'FileRef($path)';
}
