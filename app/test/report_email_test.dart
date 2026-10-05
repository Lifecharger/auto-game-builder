// Optional contact e-mail on reports (owner 2026-10-05): players use the
// in-game report form as a support ticket, so a report can carry the
// address they typed and the reports list offers a Reply button.

import 'package:flutter_test/flutter_test.dart';

import 'package:app_manager_mobile/models/report_model.dart';
import 'package:app_manager_mobile/screens/reports_screen.dart';
import 'package:app_manager_mobile/services/report_service.dart';

void main() {
  test('cleanEmail: empty is fine, an address is trimmed, junk is refused',
      () {
    expect(ReportService.cleanEmail(''), '');
    expect(ReportService.cleanEmail('   '), '');
    expect(ReportService.cleanEmail('  a.b+c@mail.example.com '),
        'a.b+c@mail.example.com');
    for (final bad in ['not an address', 'a@b', '@b.com', 'a b@c.com', 'a@b.c']) {
      expect(ReportService.cleanEmail(bad), isNull, reason: bad);
    }
  });

  test('the address rides in meta only when a valid one was typed', () {
    const device = <String, dynamic>{'model': 'X'};
    expect(ReportService.metaWithContact(device, ''), device);
    expect(ReportService.metaWithContact(device, 'junk'), device);
    expect(ReportService.metaWithContact(device, ' me@example.com '),
        {'model': 'X', 'contact_email': 'me@example.com'});
  });

  test('a report exposes the address from the server field or from meta', () {
    final top = ReportModel.fromJson({
      'id': 'r1',
      'contact_email': 'top@example.com',
      'meta': {'contact_email': 'meta@example.com'},
    });
    expect(top.contactEmail, 'top@example.com');
    final meta = ReportModel.fromJson({
      'id': 'r2',
      'meta': {'contact_email': 'meta@example.com'},
    });
    expect(meta.contactEmail, 'meta@example.com');
    expect(ReportModel.fromJson({'id': 'r3'}).contactEmail, '');
  });

  test('Reply opens a mail to the reporter with the report quoted', () {
    final report = ReportModel.fromJson({
      'id': 'r1',
      'app_name': 'Sentience',
      'message': 'it broke\nwhen I tapped & held',
      'contact_email': 'me@example.com',
    });
    final uri = ReportCardLinks.replyUri(report, 'About your Sentience report');
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'me@example.com');
    expect(uri.queryParameters['subject'], 'About your Sentience report');
    expect(uri.queryParameters['body'],
        '\n\n> it broke\n> when I tapped & held\n');
  });
}
