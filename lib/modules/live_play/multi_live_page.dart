import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/modules/live_play/multi_live_controller.dart';

class _ActivateTileIntent extends Intent {
  const _ActivateTileIntent(this.index);
  final int index;
}

class _SimpleIntent extends Intent {
  const _SimpleIntent(this.action);
  final String action;
}

class _GridSpec {
  const _GridSpec({required this.columns, required this.rows});

  final int columns;
  final int rows;
}

class MultiLivePage extends StatefulWidget {
  const MultiLivePage({super.key});

  @override
  State<MultiLivePage> createState() => _MultiLivePageState();
}

class _MultiLivePageState extends State<MultiLivePage> {
  final controller = Get.find<MultiLiveController>();
  final FocusNode _focusNode = FocusNode();
  bool _showFullscreenToolbar = true;
  Timer? _fullscreenToolbarTimer;

  void _pokeFullscreenToolbar() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showFullscreenToolbar = true;
    });
    _fullscreenToolbarTimer?.cancel();
    _fullscreenToolbarTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showFullscreenToolbar = false;
      });
    });
  }

  int _equalColumns(int count) {
    if (count <= 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 2;
    if (count <= 6) return 3;
    if (count <= 9) return 3;
    if (count <= 12) return 3;
    return 4;
  }

  int _rowsBy(int count, int columns) {
    return ((count + columns - 1) ~/ columns).clamp(1, 99);
  }

  _GridSpec _oneMainSubGridSpec(int totalCount) {
    final subCount = (totalCount - 1).clamp(0, 99);
    if (subCount <= 0) {
      return const _GridSpec(columns: 1, rows: 1);
    }
    // 明确约束：4窗格时必须是一大三小且右侧纵向排列
    if (subCount <= 3) {
      return _GridSpec(columns: 1, rows: subCount);
    }
    if (subCount <= 6) {
      return _GridSpec(columns: 2, rows: _rowsBy(subCount, 2));
    }
    if (subCount <= 10) {
      return _GridSpec(columns: 3, rows: _rowsBy(subCount, 3));
    }
    return _GridSpec(columns: 4, rows: _rowsBy(subCount, 4));
  }

  _GridSpec _twoMainSubGridSpec(int totalCount) {
    final subCount = (totalCount - 2).clamp(0, 99);
    if (subCount <= 0) {
      return const _GridSpec(columns: 1, rows: 1);
    }
    if (subCount == 1) {
      return const _GridSpec(columns: 1, rows: 1);
    }
    if (subCount <= 4) {
      return _GridSpec(columns: 2, rows: _rowsBy(subCount, 2));
    }
    if (subCount <= 9) {
      return _GridSpec(columns: 3, rows: _rowsBy(subCount, 3));
    }
    return _GridSpec(columns: 4, rows: _rowsBy(subCount, 4));
  }

  double _estimateGridAspectRatio({
    required int itemCount,
    required int columns,
    required double containerWidth,
    required double containerHeight,
    required double spacing,
    double fallback = 16 / 9,
  }) {
    if (itemCount <= 0 || columns <= 0) {
      return fallback;
    }
    final rows = _rowsBy(itemCount, columns);
    final usableWidth = containerWidth - spacing * (columns - 1);
    final usableHeight = containerHeight - spacing * (rows - 1);
    if (usableWidth <= 0 || usableHeight <= 0) {
      return fallback;
    }
    final tileW = usableWidth / columns;
    final tileH = usableHeight / rows;
    if (tileW <= 0 || tileH <= 0) {
      return fallback;
    }
    return tileW / tileH;
  }

  List<LiveRoom> _availableRoomsToAdd() {
    final settings = controller.settings;
    final source = <LiveRoom>[];
    source.addAll(settings.favoriteRooms);
    source.addAll(settings.historyRooms);

    final uniq = <String>{};
    final rooms = <LiveRoom>[];
    for (final room in source) {
      final key = '${room.platform}_${room.roomId}';
      if (uniq.contains(key)) continue;
      if (controller.containsRoom(room)) continue;
      uniq.add(key);
      rooms.add(room);
    }
    return rooms;
  }

  List<LiveRoom> _favoriteRoomsToAdd() {
    final uniq = <String>{};
    final rooms = <LiveRoom>[];
    for (final room in controller.settings.favoriteRooms) {
      final key = '${room.platform}_${room.roomId}';
      if (uniq.contains(key) || controller.containsRoom(room)) continue;
      uniq.add(key);
      rooms.add(room);
    }
    return rooms;
  }

  List<LiveRoom> _historyRoomsToAdd() {
    final uniq = <String>{};
    final rooms = <LiveRoom>[];
    for (final room in controller.settings.historyRooms) {
      final key = '${room.platform}_${room.roomId}';
      if (uniq.contains(key) || controller.containsRoom(room)) continue;
      uniq.add(key);
      rooms.add(room);
    }
    return rooms;
  }

  List<LiveRoom> _queueRoomsToAdd() {
    final uniq = <String>{};
    final rooms = <LiveRoom>[];
    for (final room in controller.queueService.rooms) {
      final key = '${room.platform}_${room.roomId}';
      if (uniq.contains(key) || controller.containsRoom(room)) continue;
      uniq.add(key);
      rooms.add(room);
    }
    return rooms;
  }

  Widget _buildAddSourceList(List<LiveRoom> rooms) {
    if (rooms.isEmpty) {
      return const Center(child: Text('当前没有可添加房间'));
    }
    return ListView.separated(
      itemCount: rooms.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final room = rooms[index];
        return ListTile(
          title: Text(room.title ?? ''),
          subtitle: Text(
            '${room.platform?.toUpperCase() ?? ''} · ${room.nick ?? ''}',
          ),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () async {
            Navigator.of(context).pop();
            await controller.addRoom(room);
          },
        );
      },
    );
  }

  Future<void> _showAddRoomSheet(BuildContext context) async {
    if (controller.tiles.length >= controller.maxTiles) {
      SmartDialog.showToast('同屏数量已达上限(${controller.maxTiles})');
      return;
    }

    final rooms = _availableRoomsToAdd();
    if (rooms.isEmpty) {
      SmartDialog.showToast('没有可添加的直播间(可先收藏或播放后进入历史)');
      return;
    }

    final favoriteRooms = _favoriteRoomsToAdd();
    final historyRooms = _historyRoomsToAdd();
    final queueRooms = _queueRoomsToAdd();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: SafeArea(
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: '收藏'),
                    Tab(text: '历史'),
                    Tab(text: '队列'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAddSourceList(favoriteRooms),
                      _buildAddSourceList(historyRooms),
                      _buildAddSourceList(queueRooms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLayoutSheet(BuildContext context) async {
    final current = controller.layoutMode.value;
    final currentMainRatio = controller.mainRatio;
    int selected = current;
    double mainRatio = currentMainRatio;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '布局模式',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          selected: selected == 0,
                          label: const Text('等分布局'),
                          onSelected: (_) => setStateSheet(() => selected = 0),
                        ),
                        ChoiceChip(
                          selected: selected == 1,
                          label: const Text('1主多副'),
                          onSelected: (_) => setStateSheet(() => selected = 1),
                        ),
                        ChoiceChip(
                          selected: selected == 2,
                          label: const Text('2主多副'),
                          onSelected: (_) => setStateSheet(() => selected = 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '布局数量自适应：会根据当前窗格数量自动选择副屏网格。\n4窗格(1主多副)固定为右侧3个竖排。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (selected != 0) ...[
                      const SizedBox(height: 12),
                      Text('主屏比例: ${(mainRatio * 100).round()}%'),
                      Slider(
                        value: mainRatio,
                        min: 0.3,
                        max: 0.7,
                        divisions: 8,
                        label: '${(mainRatio * 100).round()}%',
                        onChanged: (value) {
                          setStateSheet(() => mainRatio = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            controller.setLayoutMode(selected);
                            controller.setMainRatio(mainRatio);
                            Navigator.of(context).pop();
                          },
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDialog({
    required String title,
    required String content,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(Get.context!).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(Get.context!).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _removeTileWithUndo(String tileId) async {
    final snapshot = await controller.removeTileWithUndoSnapshot(
      tileId: tileId,
      autoCloseWhenEmpty: false,
    );
    if (snapshot == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final closedReason = await messenger
        .showSnackBar(
          SnackBar(
            content: const Text('已移除直播窗格'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () {
                unawaited(controller.restoreTileFromSnapshot(snapshot));
              },
            ),
            duration: const Duration(seconds: 3),
          ),
        )
        .closed;

    if (!mounted) {
      return;
    }

    if (closedReason != SnackBarClosedReason.action &&
        controller.tiles.isEmpty) {
      Get.back();
    }
  }

  Widget _buildEqualGrid(int count) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isRealFullscreen = controller.isWindowFullscreen.value;
        final spacing = isRealFullscreen ? 0.0 : 8.0;
        final outerPadding = isRealFullscreen ? 0.0 : 8.0;
        final crossAxisCount = _equalColumns(count);
        final rows = (count / crossAxisCount).ceil();

        final usableWidth =
            constraints.maxWidth -
            (outerPadding * 2) -
            (spacing * (crossAxisCount - 1));
        final usableHeight =
            constraints.maxHeight - (outerPadding * 2) - (spacing * (rows - 1));
        final tileWidth = usableWidth / crossAxisCount;
        final tileHeight = usableHeight / rows;
        final ratio = (tileWidth > 0 && tileHeight > 0)
            ? tileWidth / tileHeight
            : (16 / 9);

        return GridView.builder(
          padding: EdgeInsets.all(outerPadding),
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            final tile = controller.tiles[index];
            return _MultiLiveTile(
              tile: tile,
              controller: controller,
              isMainTile: false,
            );
          },
        );
      },
    );
  }

  Widget _buildOneMainLayout(int count) {
    if (count <= 1) {
      return _buildEqualGrid(count);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = controller.tiles;
        final subCount = count - 1;
        final subSpec = _oneMainSubGridSpec(count);
        final mainFlex = (controller.mainRatio * 10).round().clamp(3, 7);
        final sideFlex = 10 - mainFlex;

        final bool isRealFullscreen = controller.isWindowFullscreen.value;
        final edgePadding = isRealFullscreen ? 0.0 : 8.0;
        final splitGap = isRealFullscreen ? 0.0 : 8.0;
        final contentWidth = constraints.maxWidth - edgePadding * 2;
        final contentHeight = constraints.maxHeight - edgePadding * 2;
        final sideWidth =
            (contentWidth - splitGap) * (sideFlex / (mainFlex + sideFlex));
        final sideHeight = contentHeight;
        final sideRatio = _estimateGridAspectRatio(
          itemCount: subCount,
          columns: subSpec.columns,
          containerWidth: sideWidth,
          containerHeight: sideHeight,
          spacing: splitGap,
          fallback: 9 / 16,
        );

        return Padding(
          padding: EdgeInsets.all(edgePadding),
          child: Row(
            children: [
              Expanded(
                flex: mainFlex,
                child: _MultiLiveTile(
                  tile: tiles[0],
                  controller: controller,
                  isMainTile: true,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final delta = details.delta.dx / constraints.maxWidth;
                    controller.setMainRatio(controller.mainRatio + delta);
                  },
                  child: SizedBox(width: splitGap),
                ),
              ),
              Expanded(
                flex: sideFlex,
                child: GridView.builder(
                  itemCount: subCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: subSpec.columns,
                    crossAxisSpacing: splitGap,
                    mainAxisSpacing: splitGap,
                    childAspectRatio: sideRatio,
                  ),
                  itemBuilder: (context, index) {
                    final tile = tiles[index + 1];
                    return _MultiLiveTile(
                      tile: tile,
                      controller: controller,
                      isMainTile: false,
                      onTileTap: () async {
                        await controller.promoteTileToMain(tile.tileId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTwoMainLayout(int count) {
    if (count <= 2) {
      return _buildEqualGrid(count);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = controller.tiles;
        final subCount = count - 2;
        final subSpec = _twoMainSubGridSpec(count);

        final mainHeightFlex = (controller.mainRatio * 10).round().clamp(3, 7);
        final subHeightFlex = 10 - mainHeightFlex;
        final bool isRealFullscreen = controller.isWindowFullscreen.value;
        final edgePadding = isRealFullscreen ? 0.0 : 8.0;
        final splitGap = isRealFullscreen ? 0.0 : 8.0;
        final contentWidth = constraints.maxWidth - edgePadding * 2;
        final contentHeight = constraints.maxHeight - edgePadding * 2;
        final subHeight =
            (contentHeight - splitGap) *
            (subHeightFlex / (mainHeightFlex + subHeightFlex));
        final subRatio = _estimateGridAspectRatio(
          itemCount: subCount,
          columns: subSpec.columns,
          containerWidth: contentWidth,
          containerHeight: subHeight,
          spacing: splitGap,
          fallback: 16 / 9,
        );

        return Padding(
          padding: EdgeInsets.all(edgePadding),
          child: Column(
            children: [
              Expanded(
                flex: mainHeightFlex,
                child: Row(
                  children: [
                    Expanded(
                      child: _MultiLiveTile(
                        tile: tiles[0],
                        controller: controller,
                        isMainTile: true,
                      ),
                    ),
                    SizedBox(width: splitGap),
                    Expanded(
                      child: _MultiLiveTile(
                        tile: tiles[1],
                        controller: controller,
                        isMainTile: true,
                      ),
                    ),
                  ],
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    final delta = details.delta.dy / constraints.maxHeight;
                    controller.setMainRatio(controller.mainRatio + delta);
                  },
                  child: SizedBox(height: splitGap),
                ),
              ),
              Expanded(
                flex: subHeightFlex,
                child: GridView.builder(
                  itemCount: subCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: subSpec.columns,
                    crossAxisSpacing: splitGap,
                    mainAxisSpacing: splitGap,
                    childAspectRatio: subRatio,
                  ),
                  itemBuilder: (context, index) {
                    final tile = tiles[index + 2];
                    return _MultiLiveTile(
                      tile: tile,
                      controller: controller,
                      isMainTile: false,
                      onTileTap: () async {
                        await controller.focusTile(tile.tileId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayoutByMode(int count) {
    if (controller.layoutMode.value == 1) {
      return _buildOneMainLayout(count);
    }
    if (controller.layoutMode.value == 2) {
      return _buildTwoMainLayout(count);
    }
    return _buildEqualGrid(count);
  }

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return {
      const SingleActivator(LogicalKeyboardKey.digit1):
          const _ActivateTileIntent(0),
      const SingleActivator(LogicalKeyboardKey.digit2):
          const _ActivateTileIntent(1),
      const SingleActivator(LogicalKeyboardKey.digit3):
          const _ActivateTileIntent(2),
      const SingleActivator(LogicalKeyboardKey.digit4):
          const _ActivateTileIntent(3),
      const SingleActivator(LogicalKeyboardKey.digit5):
          const _ActivateTileIntent(4),
      const SingleActivator(LogicalKeyboardKey.digit6):
          const _ActivateTileIntent(5),
      const SingleActivator(LogicalKeyboardKey.digit7):
          const _ActivateTileIntent(6),
      const SingleActivator(LogicalKeyboardKey.digit8):
          const _ActivateTileIntent(7),
      const SingleActivator(LogicalKeyboardKey.digit9):
          const _ActivateTileIntent(8),
      const SingleActivator(LogicalKeyboardKey.keyM): const _SimpleIntent(
        'mute',
      ),
      const SingleActivator(LogicalKeyboardKey.digit0): const _SimpleIntent(
        'toggle_mute',
      ),
      const SingleActivator(LogicalKeyboardKey.keyR): const _SimpleIntent(
        'refresh',
      ),
      const SingleActivator(LogicalKeyboardKey.equal): const _SimpleIntent(
        'volume_up',
      ),
      const SingleActivator(LogicalKeyboardKey.minus): const _SimpleIntent(
        'volume_down',
      ),
      const SingleActivator(LogicalKeyboardKey.equal, shift: true):
          const _SimpleIntent('global_volume_up'),
      const SingleActivator(LogicalKeyboardKey.minus, shift: true):
          const _SimpleIntent('global_volume_down'),
      const SingleActivator(LogicalKeyboardKey.delete): const _SimpleIntent(
        'remove',
      ),
    };
  }

  Map<Type, Action<Intent>> _buildActions() {
    return {
      _ActivateTileIntent: CallbackAction<_ActivateTileIntent>(
        onInvoke: (intent) {
          if (intent.index < controller.tiles.length) {
            final tileId = controller.tiles[intent.index].tileId;
            unawaited(controller.focusTile(tileId));
            if (controller.fullscreenTileId.value.isNotEmpty) {
              if (controller.fullscreenTileId.value != tileId) {
                controller.toggleFullscreenTile(tileId);
              }
              _pokeFullscreenToolbar();
            }
          }
          return null;
        },
      ),
      _SimpleIntent: CallbackAction<_SimpleIntent>(
        onInvoke: (intent) {
          switch (intent.action) {
            case 'mute':
              unawaited(controller.toggleMute(controller.activeTileId.value));
              break;
            case 'toggle_mute':
              if (controller.activeTileId.value.isNotEmpty) {
                unawaited(controller.toggleMute(controller.activeTileId.value));
              }
              break;
            case 'refresh':
              unawaited(controller.retryTile(controller.activeTileId.value));
              break;
            case 'volume_up':
              if (controller.activeTileId.value.isNotEmpty) {
                final tile = controller.tiles.firstWhereOrNull(
                  (item) => item.tileId == controller.activeTileId.value,
                );
                if (tile != null) {
                  unawaited(
                    controller.setTileVolume(
                      tile.tileId,
                      (tile.volume.value + 0.05).clamp(0.0, 1.0),
                    ),
                  );
                }
              }
              break;
            case 'volume_down':
              if (controller.activeTileId.value.isNotEmpty) {
                final tile = controller.tiles.firstWhereOrNull(
                  (item) => item.tileId == controller.activeTileId.value,
                );
                if (tile != null) {
                  unawaited(
                    controller.setTileVolume(
                      tile.tileId,
                      (tile.volume.value - 0.05).clamp(0.0, 1.0),
                    ),
                  );
                }
              }
              break;
            case 'global_volume_up':
              unawaited(
                controller.setGlobalVolume(
                  (controller.globalVolume.value + 0.05).clamp(0.0, 1.0),
                ),
              );
              break;
            case 'global_volume_down':
              unawaited(
                controller.setGlobalVolume(
                  (controller.globalVolume.value - 0.05).clamp(0.0, 1.0),
                ),
              );
              break;
            case 'remove':
              if (controller.activeTileId.value.isNotEmpty) {
                unawaited(_removeTileWithUndo(controller.activeTileId.value));
              }
              break;
          }
          return null;
        },
      ),
    };
  }

  Widget _buildToolBar(
    BuildContext context, {
    bool showExitFullscreenButton = false,
  }) {
    return Obx(() {
      final queueCount = controller.queueService.rooms.length;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
            ),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _showAddRoomSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: controller.addRoomsFromQueue,
                icon: const Icon(Icons.playlist_add),
                label: Text('队列($queueCount)'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: controller.muteAll,
                icon: const Icon(Icons.volume_off_rounded),
                label: const Text('全静音'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final confirmed = await _confirmDialog(
                    title: '确认全部刷新',
                    content: '是否刷新当前所有同屏直播间？',
                  );
                  if (confirmed) {
                    await controller.refreshAll();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('全刷新'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _showLayoutSheet(context),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: const Text('布局'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () async {
                  if (controller.isWindowFullscreen.value) {
                    await controller.exitRealFullscreen();
                    return;
                  }
                  await controller.enterRealFullscreen();
                  _pokeFullscreenToolbar();
                },
                icon: Icon(
                  controller.isWindowFullscreen.value
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                ),
                label: Text(
                  controller.isWindowFullscreen.value ? '退出全屏' : '真实全屏',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '总音量 ${(controller.globalVolume.value * 100).round()}%',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Slider(
                      value: controller.globalVolume.value,
                      onChanged: (value) {
                        unawaited(controller.setGlobalVolume(value));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SegmentedButton<MultiLiveAudioMode>(
                segments: const [
                  ButtonSegment(
                    value: MultiLiveAudioMode.focus,
                    label: Text('单焦点'),
                  ),
                  ButtonSegment(
                    value: MultiLiveAudioMode.mix,
                    label: Text('混音'),
                  ),
                  ButtonSegment(
                    value: MultiLiveAudioMode.mainPriority,
                    label: Text('主窗优先'),
                  ),
                ],
                selected: {controller.audioMode.value},
                onSelectionChanged: (selected) {
                  if (selected.isEmpty) return;
                  unawaited(controller.setAudioMode(selected.first));
                },
              ),
              if (showExitFullscreenButton) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => controller.exitRealFullscreen(),
                  icon: const Icon(Icons.close_fullscreen_rounded),
                  label: const Text('取消全屏'),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(
        actions: _buildActions(),
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          child: Obx(() {
            final isRealFullscreen = controller.isWindowFullscreen.value;
            return Scaffold(
              appBar: isRealFullscreen
                  ? null
                  : AppBar(
                      title: Text('同屏播放 (${controller.tiles.length})'),
                      actions: [
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'mode_keep') {
                              controller
                                      .settings
                                      .multiLiveQueueConsumeMode
                                      .value =
                                  'keep';
                            }
                            if (value == 'mode_remove') {
                              controller
                                      .settings
                                      .multiLiveQueueConsumeMode
                                      .value =
                                  'removeAdded';
                            }
                            if (value == 'mode_clear') {
                              controller
                                      .settings
                                      .multiLiveQueueConsumeMode
                                      .value =
                                  'clearAll';
                            }
                            if (value == 'clear_queue') {
                              _confirmDialog(
                                title: '确认清空队列',
                                content: '是否清空同屏队列？',
                              ).then((confirmed) {
                                if (confirmed) {
                                  controller.queueService.clear();
                                  SmartDialog.showToast('已清空同屏队列');
                                }
                              });
                            }
                            if (value == 'go_settings') {
                              Get.toNamed(RoutePath.kSettings);
                            }
                            if (value == 'show_help') {
                              _confirmDialog(
                                title: '快捷键帮助',
                                content:
                                    '1-9 切焦点\nM 静音\nR 刷新\nDelete 删除(可撤销)\n真实全屏请使用顶部按钮进入与退出',
                              );
                            }
                            if (value == 'show_about') {
                              _confirmDialog(
                                title: '同屏播放',
                                content: '当前为单窗口多屏同播模式，支持队列添加、布局切换、拖拽重排、真实全屏与快捷键。',
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'mode_keep',
                              child: Text('队列策略: 保持'),
                            ),
                            PopupMenuItem(
                              value: 'mode_remove',
                              child: Text('队列策略: 移除已添加'),
                            ),
                            PopupMenuItem(
                              value: 'mode_clear',
                              child: Text('队列策略: 全清空'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'clear_queue',
                              child: Text('清空同屏队列'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'go_settings',
                              child: Text('打开设置'),
                            ),
                            PopupMenuItem(
                              value: 'show_help',
                              child: Text('快捷键帮助'),
                            ),
                            PopupMenuItem(
                              value: 'show_about',
                              child: Text('关于同屏'),
                            ),
                          ],
                        ),
                      ],
                    ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      if (!isRealFullscreen) _buildToolBar(context),
                      Expanded(
                        child: Obx(() {
                          if (controller.tiles.isEmpty) {
                            return const Center(child: Text('暂无同屏房间'));
                          }
                          final fullscreenId = controller.fullscreenTileId.value;
                          if (fullscreenId.isNotEmpty) {
                            final fullscreenTile = controller.tiles
                                .firstWhereOrNull(
                                  (item) => item.tileId == fullscreenId,
                                );
                            if (fullscreenTile != null) {
                              final tilePadding = isRealFullscreen ? 0.0 : 8.0;
                              return Padding(
                                padding: EdgeInsets.all(tilePadding),
                                child: _MultiLiveTile(
                                  tile: fullscreenTile,
                                  controller: controller,
                                  isMainTile: true,
                                ),
                              );
                            }
                          }
                          return _buildLayoutByMode(controller.tiles.length);
                        }),
                      ),
                    ],
                  ),
                  if (isRealFullscreen)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: MouseRegion(
                        onEnter: (_) => _pokeFullscreenToolbar(),
                        child: const SizedBox(height: 16),
                      ),
                    ),
                  if (isRealFullscreen)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 200),
                        offset: _showFullscreenToolbar
                            ? Offset.zero
                            : const Offset(0, -1),
                        child: IgnorePointer(
                          ignoring: !_showFullscreenToolbar,
                          child: MouseRegion(
                            onEnter: (_) => _pokeFullscreenToolbar(),
                            child: _buildToolBar(
                              context,
                              showExitFullscreenButton: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullscreenToolbarTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }
}

class _MultiLiveTile extends StatefulWidget {
  const _MultiLiveTile({
    required this.tile,
    required this.controller,
    this.isMainTile = false,
    this.onTileTap,
  });

  final MultiLiveTileState tile;
  final MultiLiveController controller;
  final bool isMainTile;
  final Future<void> Function()? onTileTap;

  @override
  State<_MultiLiveTile> createState() => _MultiLiveTileState();
}

class _MultiLiveTileState extends State<_MultiLiveTile> {
  Timer? _hideTimer;

  MultiLiveTileState get tile => widget.tile;
  MultiLiveController get controller => widget.controller;

  bool get _isMainTile => widget.isMainTile;

  void _scheduleHideControls(bool isActive) {
    _hideTimer?.cancel();
    if (PlatformUtils.isDesktop || isActive) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      tile.showControls.value = false;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  String _errorTypeText(MultiLiveTileErrorType? type) {
    switch (type) {
      case MultiLiveTileErrorType.network:
        return '网络错误';
      case MultiLiveTileErrorType.auth:
        return '认证错误';
      case MultiLiveTileErrorType.sourceParse:
        return '播放源错误';
      case MultiLiveTileErrorType.timeout:
        return '超时';
      case MultiLiveTileErrorType.unknown:
      case null:
        return '未知错误';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isActive = controller.activeTileId.value == tile.tileId;
      final status = tile.status.value;

      final tileCard = _buildTileCard(context, isActive, status);
      return DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != tile.tileId,
        onAcceptWithDetails: (details) {
          controller.reorderTiles(details.data, tile.tileId);
        },
        builder: (context, candidates, rejected) => Draggable<String>(
          data: tile.tileId,
          feedback: SizedBox(
            width: 220,
            child: Material(
              color: Colors.transparent,
              child: _buildTileCard(
                context,
                isActive,
                status,
                showTopBar: false,
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: tileCard),
          child: tileCard,
        ),
      );
    });
  }

  Widget _buildTileCard(
    BuildContext context,
    bool isActive,
    MultiLiveTileStatus status, {
    bool showTopBar = true,
  }) {
    final bool highlightMain = _isMainTile && !isActive;
    final Color borderColor = isActive
        ? Theme.of(context).colorScheme.primary
        : (highlightMain
              ? Theme.of(context).colorScheme.tertiary
              : Colors.white24);
    final double borderWidth = isActive
        ? 2.5
        : (highlightMain ? 2.0 : 1.0);

    return MouseRegion(
      onEnter: (_) {
        tile.showControls.value = true;
        _hideTimer?.cancel();
      },
      onExit: (_) {
        if (!isActive) {
          tile.showControls.value = false;
        }
      },
      child: GestureDetector(
        onTap: () async {
          tile.showControls.value = true;
          _scheduleHideControls(isActive);
          if (widget.onTileTap != null) {
            await widget.onTileTap!.call();
            return;
          }
          await controller.focusTile(tile.tileId);
          _scheduleHideControls(true);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(child: _buildContent(status)),
              if (showTopBar && tile.showControls.value)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: _buildTopBar(context),
                ),
              if (status == MultiLiveTileStatus.error)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: FilledButton.tonalIcon(
                      onPressed: () => controller.retryTile(tile.tileId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(MultiLiveTileStatus status) {
    if (status == MultiLiveTileStatus.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (status == MultiLiveTileStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorTypeText(tile.errorType.value),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                tile.errorMessage.value.isEmpty
                    ? '播放失败'
                    : tile.errorMessage.value,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return tile.videoWidget.value ??
        const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tile.detail.value?.nick ?? tile.room.nick ?? '直播间',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<int>(
            tooltip: '清晰度',
            onSelected: (index) =>
                tile.switchQuality(controller.settings, index),
            itemBuilder: (context) {
              return List.generate(tile.qualities.length, (index) {
                return PopupMenuItem<int>(
                  value: index,
                  child: Text(tile.qualities[index].quality),
                );
              });
            },
            icon: const Icon(Icons.hd_rounded, size: 18, color: Colors.white),
          ),
          PopupMenuButton<int>(
            tooltip: '线路',
            onSelected: (index) => tile.switchLine(controller.settings, index),
            itemBuilder: (context) {
              return List.generate(tile.playUrls.length, (index) {
                return PopupMenuItem<int>(
                  value: index,
                  child: Text('线路 ${index + 1}'),
                );
              });
            },
            icon: const Icon(
              Icons.route_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          IconButton(
            tooltip: '静音切换',
            onPressed: () => controller.toggleMute(tile.tileId),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: Colors.white,
            icon: Icon(
              tile.isMuted.value
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
            ),
          ),
          IconButton(
            tooltip: '音量调节',
            onPressed: () async {
              double current = tile.volume.value;
              await showDialog<void>(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setStateDialog) {
                      return AlertDialog(
                        title: Text('窗格音量 ${(current * 100).round()}%'),
                        content: SizedBox(
                          width: 280,
                          child: Slider(
                            value: current,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            onChanged: (value) {
                              setStateDialog(() {
                                current = value;
                              });
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () {
                              unawaited(
                                controller.setTileVolume(tile.tileId, current),
                              );
                              Navigator.of(context).pop();
                            },
                            child: const Text('确定'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: Colors.white,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: () => controller.retryTile(tile.tileId),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: Colors.white,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: '移除',
            onPressed: () {
              final state = context
                  .findAncestorStateOfType<_MultiLivePageState>();
              if (state != null) {
                unawaited(state._removeTileWithUndo(tile.tileId));
              }
            },
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: Colors.white,
            icon: const Icon(Icons.close_rounded),
          ),
          IconButton(
            tooltip: '全屏',
            onPressed: () => controller.toggleFullscreenTile(tile.tileId),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            color: Colors.white,
            icon: Icon(
              controller.fullscreenTileId.value == tile.tileId
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
