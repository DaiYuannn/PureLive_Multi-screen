import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/multi_live_queue_service.dart';

void main() {
  group('LiveRoom model', () {
    test('copyWith keeps identity fields and updates target field', () {
      final room = LiveRoom(
        roomId: '1001',
        platform: 'bilibili',
        title: 'old',
        nick: '主播A',
      );

      final next = room.copyWith(title: 'new');

      expect(next.roomId, '1001');
      expect(next.platform, 'bilibili');
      expect(next.title, 'new');
      expect(next.nick, '主播A');
      expect(next, room);
    });
  });

  group('MultiLiveQueueService', () {
    test('add/remove/toggle should keep unique rooms', () {
      final service = MultiLiveQueueService();
      final room = LiveRoom(roomId: '2001', platform: 'douyu', title: 'test');

      service.addRoom(room);
      service.addRoom(room);
      expect(service.rooms.length, 1);

      service.toggleRoom(room);
      expect(service.rooms, isEmpty);

      service.toggleRoom(room);
      expect(service.rooms.length, 1);

      service.removeRoom(room);
      expect(service.rooms, isEmpty);
    });
  });
}
