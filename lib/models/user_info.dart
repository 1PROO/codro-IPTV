class UserInfo {
  final String username;
  final String status;
  final DateTime? expiryDate;
  final String maxConnections;
  final String message;
  final bool auth;

  UserInfo({
    required this.username,
    required this.status,
    this.expiryDate,
    required this.maxConnections,
    required this.message,
    required this.auth,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final userInfo = json['user_info'] ?? {};

    DateTime? expiry;
    if (userInfo['exp_date'] != null) {
      final timestamp = int.tryParse(userInfo['exp_date'].toString());
      if (timestamp != null) {
        expiry = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }

    return UserInfo(
      username: userInfo['username'] ?? '',
      status: userInfo['status'] ?? 'None',
      expiryDate: expiry,
      maxConnections: userInfo['max_connections'] ?? '0',
      message: userInfo['message'] ?? '',
      auth: json['user_info'] != null
          ? (int.tryParse(json['user_info']['auth'].toString()) == 1)
          : false,
    );
  }
}
