extension EventStatusUi on String {
  String get labelEs {
    switch (this) {
      case 'draft':
        return 'Borrador';
      case 'published':
        return 'Publicado';
      case 'closed':
        return 'Cerrado';
      default:
        return this;
    }
  }
}
