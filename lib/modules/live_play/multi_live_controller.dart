import 'dart:async';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/huya_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/player/fijk_adapter.dart';
import 'package:pure_live/player/media_kit_adapter.dart';
import 'package:pure_live/player/video_player_adapter.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/player/unified_player_interface.dart';
import 'package:pure_live/common/global/platform_utils.dart';

enum MultiLiveTileStatus { loading, ready, error }

enum MultiLiveTileErrorType { network, auth, sourceParse, timeout, unknown }

enum MultiLiveQueueConsumeMode { keep, removeAdded, clearAll }

enum MultiLiveAudioMode { focus, mix, mainPriority }

class AddRoomsResult {
  final List<LiveRoom> added = <LiveRoom>[];
  final List<LiveRoom> duplicated = <LiveRoom>[];
  final List<LiveRoom> blockedByLimit = <LiveRoom>[];

  bool get hasAdded => added.isNotEmpty;
}

class RemovedTileSnapshot {
  RemovedTileSnapshot({
    required this.room,
    required this.index,
    required this.wasActive,
  });

  final LiveRoom room;
  final int index;
  final bool wasActive;
}

class MultiLiveTileState {
  MultiLiveTileState({required this.room})
    : tileId =
          '${room.platform}_${room.roomId}_${DateTime.now().microsecondsSinceEpoch}';

  final String tileId;
  final LiveRoom room;

  final status = MultiLiveTileStatus.loading.obs;
  final errorMessage = ''.obs;
  final detail = Rxn<LiveRoom>();
  final qualities = <LivePlayQuality>[].obs;
  final playUrls = <String>[].obs;
  final currentQuality = 0.obs;
  final currentLineIndex = 0.obs;
  final isMuted = false.obs;
  final volume = 1.0.obs;
  final videoWidget = Rxn<Widget>();
  final showControls = false.obs;
  final errorType = Rxn<MultiLiveTileErrorType>();

  UnifiedPlayer? _player;
  StreamSubscription<String?>? _errorSub;
  StreamSubscription<bool>? _completeSub;

  Future<void> init(SettingsService settings) async {
    status.value = MultiLiveTileStatus.loading;
    errorMessage.value = '';
    errorType.value = null;
    videoWidget.value = null;

    try {
      await _initInternal(settings).timeout(const Duration(seconds: 15));
      status.value = MultiLiveTileStatus.ready;
    } on TimeoutException {
      status.value = MultiLiveTileStatus.error;
      errorType.value = MultiLiveTileErrorType.timeout;
      errorMessage.value = '初始化超时';
      await _disposePlayer();
    } catch (e) {
      status.value = MultiLiveTileStatus.error;
      errorType.value = _classifyError(e);
      errorMessage.value = e.toString().replaceAll('Exception:', '').trim();
      await _disposePlayer();
    }
  }

  Future<void> _initInternal(SettingsService settings) async {
    final currentSite = Sites.of(room.platform ?? '');
    var liveRoom = await currentSite.liveSite.getRoomDetail(
      roomId: room.roomId!,
      platform: room.platform!,
    );
    if (currentSite.id == Sites.iptvSite) {
      liveRoom = liveRoom.copyWith(
        title: room.title ?? '',
        nick: room.nick ?? '',
      );
    }

    final bool isLiving = liveRoom.status == true || liveRoom.isRecord == true;
    if (!isLiving || liveRoom.liveStatus == LiveStatus.unknown) {
      throw Exception('该房间当前不可播放');
    }

    detail.value = liveRoom;
    final playQualities = await currentSite.liveSite.getPlayQualites(
      detail: liveRoom,
    );
    if (playQualities.isEmpty) {
      throw Exception('无法读取清晰度信息');
    }
    qualities.assignAll(playQualities);
    _chooseQualityByPreference(settings);

    final urls = await currentSite.liveSite.getPlayUrls(
      detail: liveRoom,
      quality: qualities[currentQuality.value],
    );
    if (urls.isEmpty) {
      throw Exception('无法读取播放地址');
    }
    playUrls.assignAll(urls);
    currentLineIndex.value = 0;

    final headers = await _buildHeaders(currentSite.id, settings);
    await _initPlayer(settings, urls[currentLineIndex.value], urls, headers);
  }

  MultiLiveTileErrorType _classifyError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('超时')) {
      return MultiLiveTileErrorType.timeout;
    }
    if (msg.contains('auth') ||
        msg.contains('login') ||
        msg.contains('cookie')) {
      return MultiLiveTileErrorType.auth;
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('dns')) {
      return MultiLiveTileErrorType.network;
    }
    if (msg.contains('quality') ||
        msg.contains('url') ||
        msg.contains('播放地址')) {
      return MultiLiveTileErrorType.sourceParse;
    }
    return MultiLiveTileErrorType.unknown;
  }

  void _chooseQualityByPreference(SettingsService settings) {
    final userPrefer = settings.preferResolution.value;
    final available = qualities.map((e) => e.quality).toList();
    final matchedIndex = available.indexOf(userPrefer);
    if (matchedIndex != -1) {
      currentQuality.value = matchedIndex;
      return;
    }

    final systemResolutions = settings.resolutionsList;
    final preferLevel = systemResolutions.indexOf(userPrefer);
    if (preferLevel < 0 || systemResolutions.length <= 1) {
      currentQuality.value = 0;
      return;
    }

    final preferRatio = preferLevel / (systemResolutions.length - 1);
    final targetIndex = (preferRatio * (available.length - 1)).round().clamp(
      0,
      available.length - 1,
    );
    currentQuality.value = targetIndex;
  }

  Future<void> _initPlayer(
    SettingsService settings,
    String url,
    List<String> urls,
    Map<String, String> headers,
  ) async {
    await _disposePlayer();

    _player = _createPlayer(settings);
    await _player!.init();
    await _player!.setDataSource(url, urls, headers);

    _errorSub = _player!.onError.listen((msg) {
      if (msg != null &&
          msg.isNotEmpty &&
          status.value != MultiLiveTileStatus.error) {
        status.value = MultiLiveTileStatus.error;
        errorMessage.value = msg;
        errorType.value = _classifyError(msg);
      }
    });

    _completeSub = _player!.onComplete.listen((isComplete) {
      if (isComplete) {
        unawaited(retry(settings));
      }
    });

    videoWidget.value = _player!.getVideoWidget(0, null);
    await applyOutputVolume(0.0);
  }

  UnifiedPlayer _createPlayer(SettingsService settings) {
    if (PlatformUtils.isDesktop) {
      return MediaKitPlayerAdapter();
    }

    final index = settings.videoPlayerIndex.value;
    if (index == 1) {
      return FijkPlayerAdapter();
    }
    if (index == 2) {
      return VideoPlayerAdapter();
    }
    return MediaKitPlayerAdapter();
  }

  Future<Map<String, String>> _buildHeaders(
    String siteId,
    SettingsService settings,
  ) async {
    if (siteId == Sites.bilibiliSite) {
      return {
        'cookie': settings.bilibiliCookie.value,
        'authority': 'api.bilibili.com',
        'referer': 'https://live.bilibili.com',
        'user-agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      };
    }
    if (siteId == Sites.huyaSite) {
      final ua = await HuyaSite().getHuYaUA();
      return {'user-agent': ua, 'origin': 'https://www.huya.com'};
    }
    return <String, String>{};
  }

  Future<void> setMuted(bool muted) async {
    isMuted.value = muted;
  }

  Future<void> setVolume(double value) async {
    volume.value = value.clamp(0.0, 1.0);
  }

  Future<void> applyOutputVolume(double value) async {
    await _player?.setVolume(value.clamp(0.0, 1.0));
  }

  Future<void> switchQuality(SettingsService settings, int index) async {
    if (index < 0 || index >= qualities.length) {
      return;
    }
    currentQuality.value = index;
    final site = Sites.of(room.platform ?? '');
    final d = detail.value;
    if (d == null) return;
    final urls = await site.liveSite.getPlayUrls(
      detail: d,
      quality: qualities[index],
    );
    if (urls.isEmpty) return;
    playUrls.assignAll(urls);
    currentLineIndex.value = 0;
    final headers = await _buildHeaders(site.id, settings);
    await _initPlayer(settings, urls[0], urls, headers);
    status.value = MultiLiveTileStatus.ready;
  }

  Future<void> switchLine(SettingsService settings, int index) async {
    if (index < 0 || index >= playUrls.length) {
      return;
    }
    currentLineIndex.value = index;
    final site = Sites.of(room.platform ?? '');
    final headers = await _buildHeaders(site.id, settings);
    await _initPlayer(settings, playUrls[index], playUrls.toList(), headers);
    status.value = MultiLiveTileStatus.ready;
  }

  Future<void> retry(SettingsService settings) async {
    await init(settings);
  }

  Future<void> _disposePlayer() async {
    await _errorSub?.cancel();
    await _completeSub?.cancel();
    _errorSub = null;
    _completeSub = null;
    _player?.stop();
    _player?.dispose();
    _player = null;
  }

  Future<void> dispose() async {
    await _disposePlayer();
  }
}

class MultiLiveController extends GetxController {
  MultiLiveController({required this.initialRooms});

  static const _kGridCountPrefKey = 'multi_live_grid_count';
  static const _kOrderPrefKey = 'multi_live_room_order';
  static const _kLayoutModePrefKey = 'multi_live_layout_mode';

  final List<LiveRoom> initialRooms;
  final settings = Get.find<SettingsService>();
  final queueService = Get.find<MultiLiveQueueService>();

  final tiles = <MultiLiveTileState>[].obs;
  final gridCount = 4.obs;
  final activeTileId = ''.obs;
  final layoutMode = 0.obs; // 0: equal, 1: one main, 2: two main
  final isEditMode = false.obs;
  final fullscreenTileId = ''.obs;
  final audioMode = MultiLiveAudioMode.focus.obs;
  final globalVolume = 1.0.obs;

  int get maxTiles {
    final configured = settings.multiLiveMaxTiles.value.clamp(1, 16);
    final systemLimit = PlatformUtils.isDesktop ? 16 : 4;
    return configured > systemLimit ? systemLimit : configured;
  }

  double get mainRatio => settings.multiLiveMainRatio.value.clamp(0.3, 0.7);

  MultiLiveAudioMode get currentAudioMode {
    switch (settings.multiLiveAudioMode.value) {
      case 'mix':
        return MultiLiveAudioMode.mix;
      case 'mainPriority':
        return MultiLiveAudioMode.mainPriority;
      default:
        return MultiLiveAudioMode.focus;
    }
  }

  MultiLiveQueueConsumeMode get queueConsumeMode {
    switch (settings.multiLiveQueueConsumeMode.value) {
      case 'removeAdded':
        return MultiLiveQueueConsumeMode.removeAdded;
      case 'clearAll':
        return MultiLiveQueueConsumeMode.clearAll;
      default:
        return MultiLiveQueueConsumeMode.keep;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _restoreGridCount();
    _restoreLayoutMode();
    _restoreAudioConfig();
    final sourceRooms = initialRooms.isNotEmpty
        ? initialRooms
        : queueService.rooms.toList();
    if (sourceRooms.isEmpty) {
      SmartDialog.showToast('没有可播放的同屏房间');
      Future.microtask(() => Get.back());
      return;
    }

    final uniq = <String>{};
    for (final room in sourceRooms) {
      final key = '${room.platform}_${room.roomId}';
      if (uniq.contains(key)) {
        continue;
      }
      uniq.add(key);
      if (tiles.length >= maxTiles) {
        break;
      }
      tiles.add(MultiLiveTileState(room: room));
    }

    _restoreTileOrder();
    _syncGridCountWithTiles();
    _bootstrapTilesOptimized();
  }

  void _restoreGridCount() {
    final cached = HivePrefUtil.getInt(_kGridCountPrefKey);
    if (cached != null) {
      setGridCount(cached, persist: false);
    }
  }

  void _restoreLayoutMode() {
    final cached = HivePrefUtil.getInt(_kLayoutModePrefKey);
    if (cached != null && (cached == 0 || cached == 1 || cached == 2)) {
      layoutMode.value = cached;
    }
  }

  void _restoreAudioConfig() {
    audioMode.value = currentAudioMode;
    globalVolume.value = settings.multiLiveGlobalVolume.value.clamp(0.0, 1.0);
  }

  String _roomKeyByRoom(LiveRoom room) => '${room.platform}_${room.roomId}';

  void _restoreTileOrder() {
    final order = HivePrefUtil.getStringList(_kOrderPrefKey);
    if (order == null || order.isEmpty || tiles.isEmpty) return;

    final old = tiles.toList();
    final map = <String, MultiLiveTileState>{
      for (final item in old) _roomKeyByRoom(item.room): item,
    };

    final sorted = <MultiLiveTileState>[];
    for (final roomKey in order) {
      final hit = map.remove(roomKey);
      if (hit != null) {
        sorted.add(hit);
      }
    }
    sorted.addAll(map.values);
    tiles.assignAll(sorted);
  }

  Future<void> _persistTileOrder() async {
    final order = tiles.map((item) => _roomKeyByRoom(item.room)).toList();
    await HivePrefUtil.setStringList(_kOrderPrefKey, order);
  }

  Future<void> _bootstrapTilesOptimized() async {
    if (tiles.isEmpty) {
      return;
    }

    await tiles.first.init(settings);
    await focusTile(tiles.first.tileId);

    final remaining = tiles.skip(1).toList();
    const concurrency = 2;
    for (int i = 0; i < remaining.length; i += concurrency) {
      final batch = remaining.skip(i).take(concurrency);
      await Future.wait(batch.map((tile) => tile.init(settings)));
    }
    await _applyAudioPolicy();
  }

  Future<void> focusTile(String tileId) async {
    activeTileId.value = tileId;
    for (final tile in tiles) {
      tile.showControls.value = tile.tileId == tileId;
    }
    await _applyAudioPolicy();
  }

  Future<void> toggleMute(String tileId) async {
    final tile = tiles.firstWhereOrNull((item) => item.tileId == tileId);
    if (tile == null) return;

    if (tile.tileId == activeTileId.value) {
      await tile.setMuted(!tile.isMuted.value);
      await _applyAudioPolicy();
      return;
    }

    await focusTile(tileId);
  }

  Future<void> muteAll() async {
    activeTileId.value = '';
    for (final tile in tiles) {
      await tile.setMuted(true);
    }
    await _applyAudioPolicy();
  }

  Future<void> refreshAll() async {
    for (final tile in tiles) {
      await tile.retry(settings);
    }
    if (tiles.isNotEmpty) {
      await focusTile(tiles.first.tileId);
    }
    await _applyAudioPolicy();
  }

  Future<void> retryTile(String tileId) async {
    final tile = tiles.firstWhereOrNull((item) => item.tileId == tileId);
    if (tile == null) return;
    await tile.retry(settings);
    if (activeTileId.value.isEmpty || activeTileId.value == tileId) {
      await focusTile(tileId);
    }
    await _applyAudioPolicy();
  }

  Future<void> removeTile(String tileId) async {
    await removeTileWithUndoSnapshot(tileId: tileId, autoCloseWhenEmpty: true);
  }

  Future<RemovedTileSnapshot?> removeTileWithUndoSnapshot({
    required String tileId,
    bool autoCloseWhenEmpty = false,
  }) async {
    final index = tiles.indexWhere((item) => item.tileId == tileId);
    if (index < 0) {
      return null;
    }
    final tile = tiles[index];
    final snapshot = RemovedTileSnapshot(
      room: tile.room,
      index: index,
      wasActive: activeTileId.value == tileId,
    );

    await tile.dispose();
    tiles.removeAt(index);
    if (fullscreenTileId.value == tileId) {
      fullscreenTileId.value = '';
    }

    if (tiles.isNotEmpty && snapshot.wasActive) {
      await focusTile(tiles.first.tileId);
    }

    _syncGridCountWithTiles();
    await _persistTileOrder();

    if (autoCloseWhenEmpty && tiles.isEmpty) {
      Get.back();
    }
    await _applyAudioPolicy();
    return snapshot;
  }

  Future<void> restoreTileFromSnapshot(RemovedTileSnapshot snapshot) async {
    if (containsRoom(snapshot.room)) {
      return;
    }
    if (tiles.length >= maxTiles) {
      SmartDialog.showToast('同屏数量已达上限($maxTiles)');
      return;
    }

    final tile = MultiLiveTileState(room: snapshot.room);
    final insertIndex = snapshot.index.clamp(0, tiles.length);
    tiles.insert(insertIndex, tile);
    await _initNewTile(tile);

    if (snapshot.wasActive) {
      await focusTile(tile.tileId);
    }
    _syncGridCountWithTiles();
    await _persistTileOrder();
    await _applyAudioPolicy();
  }

  bool containsRoom(LiveRoom room) {
    return tiles.any(
      (item) =>
          item.room.platform == room.platform &&
          item.room.roomId == room.roomId,
    );
  }

  Future<AddRoomsResult> appendRooms(List<LiveRoom> rooms) async {
    final result = AddRoomsResult();
    for (final room in rooms) {
      if (containsRoom(room)) {
        result.duplicated.add(room);
        continue;
      }
      if (tiles.length >= maxTiles) {
        result.blockedByLimit.add(room);
        continue;
      }

      final tile = MultiLiveTileState(room: room);
      tiles.add(tile);
      await _initNewTile(tile);
      result.added.add(room);
    }

    if (result.hasAdded) {
      _syncGridCountWithTiles();
      await _persistTileOrder();
      await _applyAudioPolicy();
    }
    return result;
  }

  Future<void> addRoom(LiveRoom room) async {
    final result = await appendRooms(<LiveRoom>[room]);
    if (result.hasAdded) return;
    if (result.duplicated.isNotEmpty) {
      SmartDialog.showToast('该直播间已在同屏中');
      return;
    }
    SmartDialog.showToast('同屏数量已达上限($maxTiles)');
  }

  Future<void> addRoomsFromQueue() async {
    final queueRooms = queueService.rooms.toList();
    if (queueRooms.isEmpty) {
      SmartDialog.showToast('同屏队列为空');
      return;
    }

    final result = await appendRooms(queueRooms);
    if (result.hasAdded) {
      _applyQueueConsume(result);
      final tail = result.blockedByLimit.isNotEmpty
          ? '，${result.blockedByLimit.length} 个因上限未添加'
          : '';
      SmartDialog.showToast('已从队列添加 ${result.added.length} 个直播间$tail');
      return;
    }

    if (result.duplicated.isNotEmpty) {
      SmartDialog.showToast('队列房间已全部在同屏中');
      return;
    }

    SmartDialog.showToast('同屏数量已达上限($maxTiles)');
  }

  void _applyQueueConsume(AddRoomsResult result) {
    switch (queueConsumeMode) {
      case MultiLiveQueueConsumeMode.removeAdded:
        for (final room in result.added) {
          queueService.removeRoom(room);
        }
        break;
      case MultiLiveQueueConsumeMode.clearAll:
        queueService.clear();
        break;
      case MultiLiveQueueConsumeMode.keep:
        break;
    }
  }

  Future<void> _initNewTile(MultiLiveTileState tile) async {
    await tile.init(settings);
    if (activeTileId.value.isEmpty) {
      await focusTile(tile.tileId);
    } else {
      await tile.setMuted(false);
    }
    await _applyAudioPolicy();
  }

  Future<void> reorderTiles(String fromTileId, String toTileId) async {
    if (fromTileId == toTileId) return;
    final fromIndex = tiles.indexWhere((item) => item.tileId == fromTileId);
    final toIndex = tiles.indexWhere((item) => item.tileId == toTileId);
    if (fromIndex < 0 || toIndex < 0) return;

    final moving = tiles.removeAt(fromIndex);
    tiles.insert(toIndex, moving);
    await _persistTileOrder();
    await _applyAudioPolicy();
  }

  Future<void> promoteTileToMain(String tileId) async {
    final index = tiles.indexWhere((item) => item.tileId == tileId);
    if (index < 0) return;
    if (index > 0) {
      final moving = tiles.removeAt(index);
      tiles.insert(0, moving);
      await _persistTileOrder();
    }
    await focusTile(tileId);
    await _applyAudioPolicy();
  }

  void setGridCount(int value, {bool persist = true}) {
    const options = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 16];
    if (options.contains(value)) {
      gridCount.value = value;
      if (persist) {
        HivePrefUtil.setInt(_kGridCountPrefKey, value);
      }
    }
  }

  void setLayoutMode(int mode, {bool persist = true}) {
    if (mode < 0 || mode > 2) return;
    layoutMode.value = mode;
    if (persist) {
      HivePrefUtil.setInt(_kLayoutModePrefKey, mode);
    }
  }

  void toggleEditMode() {
    isEditMode.value = !isEditMode.value;
  }

  void toggleFullscreenTile(String tileId) {
    if (fullscreenTileId.value == tileId) {
      fullscreenTileId.value = '';
      return;
    }
    fullscreenTileId.value = tileId;
  }

  void exitFullscreenTile() {
    fullscreenTileId.value = '';
  }

  void setMainRatio(double ratio) {
    settings.multiLiveMainRatio.value = ratio.clamp(0.3, 0.7);
  }

  Future<void> setGlobalVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    globalVolume.value = v;
    settings.multiLiveGlobalVolume.value = v;
    await _applyAudioPolicy();
  }

  Future<void> setTileVolume(String tileId, double value) async {
    final tile = tiles.firstWhereOrNull((item) => item.tileId == tileId);
    if (tile == null) return;
    await tile.setVolume(value);
    if (tile.isMuted.value && value > 0) {
      await tile.setMuted(false);
    }
    await _applyAudioPolicy();
  }

  Future<void> setAudioMode(MultiLiveAudioMode mode) async {
    audioMode.value = mode;
    settings.multiLiveAudioMode.value = switch (mode) {
      MultiLiveAudioMode.focus => 'focus',
      MultiLiveAudioMode.mix => 'mix',
      MultiLiveAudioMode.mainPriority => 'mainPriority',
    };
    await _applyAudioPolicy();
  }

  double _baseVolumeForTile(String tileId) {
    switch (audioMode.value) {
      case MultiLiveAudioMode.focus:
        return activeTileId.value == tileId ? 1.0 : 0.0;
      case MultiLiveAudioMode.mix:
        return 1.0;
      case MultiLiveAudioMode.mainPriority:
        final index = tiles.indexWhere((item) => item.tileId == tileId);
        if (index == 0) {
          return 1.0;
        }
        return 0.25;
    }
  }

  Future<void> _applyAudioPolicy() async {
    for (final tile in tiles) {
      final muted = tile.isMuted.value;
      final base = _baseVolumeForTile(tile.tileId);
      final out = muted ? 0.0 : (base * globalVolume.value * tile.volume.value);
      await tile.applyOutputVolume(out);
    }
  }

  void setMaxTiles(int value) {
    settings.multiLiveMaxTiles.value = value.clamp(1, 16);
    _syncGridCountWithTiles();
  }

  void _syncGridCountWithTiles() {
    const options = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 16];
    final count = tiles.length;
    final target =
        options.firstWhereOrNull((item) => item >= count) ?? options.last;
    if (target > gridCount.value) {
      setGridCount(target);
    }
  }

  @override
  void onClose() {
    for (final tile in tiles) {
      unawaited(tile.dispose());
    }
    super.onClose();
  }

  @override
  void onReady() {
    super.onReady();
    _restoreAudioConfig();
    unawaited(_applyAudioPolicy());
  }
}
