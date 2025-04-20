class UserRanking {
  final String userId;
  final String name;
  double totalHours;
  int rank;

  UserRanking({
    required this.userId,
    required this.name,
    this.totalHours = 0,
    required this.rank,
  });
}
