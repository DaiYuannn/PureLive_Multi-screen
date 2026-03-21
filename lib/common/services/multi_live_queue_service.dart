import 'package:get/get.dart';
import 'package:pure_live/common/models/live_room.dart';

class MultiLiveQueueService extends GetxService {
  final RxList<LiveRoom> rooms = <LiveRoom>[].obs;

  bool contains(LiveRoom room) {
    return rooms.any(
      (item) => item.platform == room.platform && item.roomId == room.roomId,
    );
  }

  void addRoom(LiveRoom room) {
    if (contains(room)) {
      return;
    }
    rooms.add(room);
  }

  void removeRoom(LiveRoom room) {
    rooms.removeWhere(
      (item) => item.platform == room.platform && item.roomId == room.roomId,
    );
  }

  void toggleRoom(LiveRoom room) {
    if (contains(room)) {
      removeRoom(room);
      return;
    }
    addRoom(room);
  }

  void clear() {
    rooms.clear();
  }
}
