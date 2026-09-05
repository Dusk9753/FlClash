import 'package:fl_clash/features/xboard/xboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses XBoard plan prices and exposes legacy order periods', () {
    final plan = XboardPlan.fromJson({
      'id': 7,
      'name': '标准套餐',
      'prices': {'monthly': 12.5, 'yearly': 120},
      'sell': true,
    });

    expect(plan.prices['month_price'], 1250);
    expect(plan.prices['year_price'], 12000);
    expect(plan.orderPeriodFor('month_price'), 'month_price');
  });

  test('parses paged notices from the XBoard notice endpoint', () {
    final page = XboardAnnouncementPage.fromJson({
      'data': [
        {'id': 4, 'title': '维护通知', 'content': '今晚维护'},
      ],
      'total': 6,
    });

    expect(page.total, 6);
    expect(page.items.single.title, '维护通知');
  });
}
