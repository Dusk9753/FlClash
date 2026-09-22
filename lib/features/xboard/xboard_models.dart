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

class XboardAnnouncement {
  const XboardAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    this.createdAt,
    this.tags = const [],
  });
  final int id;
  final String title;
  final String content;
  final DateTime? createdAt;
  final List<String> tags;

  factory XboardAnnouncement.fromJson(Map<String, dynamic> json) =>
      XboardAnnouncement(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        content: json['content']?.toString() ?? json['body']?.toString() ?? '',
        createdAt: _parseDate(json['created_at']),
        tags: (json['tags'] is List)
            ? (json['tags'] as List).map((tag) => tag.toString()).toList()
            : const [],
      );

  static DateTime? _parseDate(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class XboardAnnouncementPage {
  const XboardAnnouncementPage({required this.items, required this.total});

  final List<XboardAnnouncement> items;
  final int total;

  factory XboardAnnouncementPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) throw const FormatException('公告响应格式错误');
    return XboardAnnouncementPage(
      items: data
          .whereType<Map>()
          .map(
            (item) =>
                XboardAnnouncement.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? data.length,
    );
  }
}

class XboardPaymentMethod {
  const XboardPaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.fixedFee,
    required this.percentFee,
  });

  final int id;
  final String name;
  final String icon;
  final int fixedFee;
  final double percentFee;

  factory XboardPaymentMethod.fromJson(Map<String, dynamic> json) =>
      XboardPaymentMethod(
        id: _parseInt(json['num'] ?? json['id'] ?? json['method']),
        name:
            (json['name'] ?? json['title'] ?? json['label'])?.toString() ??
            '支付方式',
        icon: json['icon']?.toString() ?? '',
        fixedFee: _parseInt(json['handling_fee_fixed']),
        percentFee: _parseDouble(json['handling_fee_percent']),
      );

  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class XboardCheckoutResult {
  const XboardCheckoutResult({required this.type, required this.data});

  final int type;
  final dynamic data;

  factory XboardCheckoutResult.fromJson(Map<String, dynamic> json) =>
      XboardCheckoutResult(
        type: (json['type'] as num?)?.toInt() ?? -99,
        data: json['data'],
      );
}

class XboardPlan {
  const XboardPlan({
    required this.id,
    required this.name,
    required this.content,
    required this.prices,
    required this.sell,
  });
  final int id;
  final String name;
  final String content;
  final Map<String, int> prices;
  final bool sell;

  String orderPeriodFor(String priceKey) => priceKey;

  factory XboardPlan.fromJson(Map<String, dynamic> json) {
    final prices = <String, int>{};
    const legacyKeys = [
      'month_price',
      'quarter_price',
      'half_year_price',
      'year_price',
      'two_year_price',
      'three_year_price',
      'onetime_price',
      'reset_price',
    ];
    const currentToLegacy = {
      'monthly': 'month_price',
      'quarterly': 'quarter_price',
      'half_yearly': 'half_year_price',
      'yearly': 'year_price',
      'two_yearly': 'two_year_price',
      'three_yearly': 'three_year_price',
      'onetime': 'onetime_price',
      'reset_traffic': 'reset_price',
    };

    for (final key in legacyKeys) {
      final value = json[key];
      if (value is num && value > 0) prices[key] = value.toInt();
    }
    final nestedPrices = json['prices'];
    if (nestedPrices is Map) {
      for (final entry in nestedPrices.entries) {
        final legacyKey = currentToLegacy[entry.key.toString()];
        final value = entry.value;
        if (legacyKey != null && value is num && value > 0) {
          prices[legacyKey] = (value * 100).round();
        }
      }
    }
    return XboardPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '套餐',
      content: json['content']?.toString() ?? '',
      prices: prices,
      sell: json['sell'] != false,
    );
  }
}
