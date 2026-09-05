class XboardConfig {
  const XboardConfig({
    required this.domains,
    required this.apiPath,
    required this.versions,
    required this.download,
    required this.notes,
    required this.inviteCode,
    required this.logo,
  });

  final List<String> domains;
  final String apiPath;
  final Map<String, String> versions;
  final String download;
  final String notes;
  final String inviteCode;
  final String logo;

  String get primaryBaseUrl => '${domains.first}/$apiPath';

  List<String> get baseUrls => domains.map((d) => '$d/$apiPath').toList();

  factory XboardConfig.fromJson(Map<String, dynamic> json) {
    return XboardConfig(
      domains: (json['domain'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      apiPath: json['api_path'] as String? ?? 'api/v1',
      versions: (json['version'] as Map<String, dynamic>? ?? const {}).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      download: json['download'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      inviteCode: json['invite_code'] as String? ?? '',
      logo: (json['logo'] ?? json['logo_url']) as String? ?? '',
    );
  }
}

class XboardAuthData {
  const XboardAuthData({
    required this.token,
    required this.authData,
    required this.isAdmin,
  });

  final String token;
  final String authData;
  final bool isAdmin;

  factory XboardAuthData.fromJson(Map<String, dynamic> json) {
    return XboardAuthData(
      token: json['token'] as String? ?? '',
      authData: json['auth_data'] as String? ?? '',
      isAdmin: json['is_admin'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'auth_data': authData,
    'is_admin': isAdmin,
  };
}

class XboardSubscribeInfo {
  const XboardSubscribeInfo({
    required this.subscribeUrl,
    this.token = '',
    this.email = '',
    this.u = 0,
    this.d = 0,
    this.transferEnable = 0,
    this.expiredAt = 0,
    this.planId,
  });

  final String subscribeUrl;
  final String token;
  final String email;
  final int u;
  final int d;
  final int transferEnable;
  final int expiredAt;
  final int? planId;

  factory XboardSubscribeInfo.fromJson(Map<String, dynamic> json) {
    return XboardSubscribeInfo(
      subscribeUrl: json['subscribe_url'] as String? ?? '',
      token: json['token'] as String? ?? '',
      email: json['email'] as String? ?? '',
      u: (json['u'] as num?)?.toInt() ?? 0,
      d: (json['d'] as num?)?.toInt() ?? 0,
      transferEnable: (json['transfer_enable'] as num?)?.toInt() ?? 0,
      expiredAt: (json['expired_at'] as num?)?.toInt() ?? 0,
      planId: (json['plan_id'] as num?)?.toInt(),
    );
  }
}
