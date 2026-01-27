class AdminStats {
  final int activeUsers;
  final int createdEvents;
  final int pendingRequests;

  const AdminStats({
    required this.activeUsers,
    required this.createdEvents,
    required this.pendingRequests,
  });
}
