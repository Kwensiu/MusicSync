String joinRelativePath(String base, String name) {
  if (base.isEmpty) {
    return name;
  }
  return '$base/$name';
}
