import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/multi_live_controller.dart';

class MultiLiveBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [
      Bind.lazyPut(() {
        final args = Get.arguments;
        final List<LiveRoom> rooms = args is List<LiveRoom>
            ? args
            : <LiveRoom>[];
        return MultiLiveController(initialRooms: rooms);
      }),
    ];
  }
}
