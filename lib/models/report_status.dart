enum ReportStatus {
  pending('pending'),
  underReview('under_review'),
  inProgress('in_progress'),
  resolved('resolved'),
  rejected('rejected');

  final String value;
  const ReportStatus(this.value);

  static ReportStatus fromString(String status) {
    return ReportStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => ReportStatus.pending,
    );
  }

  @override
  String toString() => value;
}
