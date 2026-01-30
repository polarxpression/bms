import 'package:flutter/material.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/core/utils/search_query_parser.dart';
import 'package:bms/ui/screens/battery_form_screen.dart';

class TableMapScreen extends StatefulWidget {
  const TableMapScreen({super.key});

  @override
  State<TableMapScreen> createState() => _TableMapScreenState();
}

class _TableMapScreenState extends State<TableMapScreen> {
  static const double cellSize = 120.0;
  static const double cellSpacing = 8.0;
  final TransformationController _transformationController =
      TransformationController();
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    // Center the view on the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCentered) {
        _centerMap();
        _hasCentered = true;
      }
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _centerMap() {
    final size = MediaQuery.of(context).size;
    // We want to center on the virtual origin (2000, 2000)
    // plus half a cell size to be perfectly centered on the "0,0" cell.
    const double targetX = 2000.0 + (cellSize / 2);
    const double targetY = 2000.0 + (cellSize / 2);

    // Calculate translation to bring target to center of screen
    // Note: The app bar height and status bar might affect exact Y, but this is close enough.
    final double x = -targetX + (size.width / 2);
    final double y =
        -targetY +
        ((size.height - kToolbarHeight - kBottomNavigationBarHeight) / 2);

    _transformationController.value = Matrix4.identity()
      ..setTranslationRaw(x, y, 0);
  }

  Widget _buildMapSelector(BuildContext context, AppState state) {
    if (state.maps.isEmpty) return const Text('Mapa da Mesa');

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: state.currentMap?.id,
        dropdownColor: const Color(0xFF1E1E1E),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        onChanged: (String? newId) {
          if (newId != null) {
            state.selectMap(newId);
          }
        },
        items: state.maps.map<DropdownMenuItem<String>>((map) {
          return DropdownMenuItem<String>(value: map.id, child: Text(map.name));
        }).toList(),
      ),
    );
  }

  void _showMapManager(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerenciar Mapas'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.maps.isEmpty) const Text('Nenhum mapa criado.'),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.maps.length,
                  itemBuilder: (ctx, idx) {
                    final map = state.maps[idx];
                    return ListTile(
                      title: Text(map.name),
                      subtitle: Text(map.purpose),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showMapForm(
                                context,
                                state,
                                mapId: map.id,
                                initName: map.name,
                                initPurpose: map.purpose,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // Confirm delete
                              showDialog(
                                context: context,
                                builder: (delCtx) => AlertDialog(
                                  title: const Text('Excluir Mapa?'),
                                  content: Text(
                                    'Tem certeza que deseja excluir "${map.name}"? Todas as posições serão perdidas.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(delCtx),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(delCtx); // Pop confirm
                                        await state.deleteMap(map.id);
                                        // Navigator.pop(ctx); // Keep manager open? Or close it. Let's keep it open or just refresh.
                                        // Since we popped confirm, we are back in manager. The list will rebuild if we use Stateful/AnimatedBuilder?
                                        // We are in AlertDialog which doesn't auto rebuild on provider change unless wrapped.
                                        // Let's close manager to be safe/simple.
                                        if (context.mounted) Navigator.pop(ctx);
                                      },
                                      child: const Text(
                                        'Excluir',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        state.selectMap(map.id);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Criar Novo Mapa'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showMapForm(context, state);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showMapForm(
    BuildContext context,
    AppState state, {
    String? mapId,
    String? initName,
    String? initPurpose,
  }) {
    final nameCtrl = TextEditingController(text: initName);
    final purpCtrl = TextEditingController(text: initPurpose);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(mapId == null ? 'Novo Mapa' : 'Editar Mapa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome do Mapa'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: purpCtrl,
              decoration: const InputDecoration(
                labelText: 'Propósito / Descrição',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;

              if (mapId == null) {
                await state.createMap(
                  nameCtrl.text.trim(),
                  purpCtrl.text.trim(),
                );
              } else {
                await state.updateMap(
                  mapId,
                  nameCtrl.text.trim(),
                  purpCtrl.text.trim(),
                );
              }
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final map = state.batteryMap;
    final batteries = state.batteries;

    // Calculate potential spots (neighbors of occupied cells)
    final Set<String> potentialSpots = {};
    if (map.isEmpty) {
      potentialSpots.add("0,0");
    } else {
      for (var key in map.keys) {
        final parts = key.split(',');
        final x = int.parse(parts[0]);
        final y = int.parse(parts[1]);

        final neighbors = [
          '${x + 1},$y',
          '${x - 1},$y',
          '$x,${y + 1}',
          '$x,${y - 1}',
        ];

        for (var n in neighbors) {
          if (!map.containsKey(n)) {
            potentialSpots.add(n);
          }
        }
      }
    }

    // Combine all cells to render
    final List<Widget> cellWidgets = [];

    // Helper to position cells
    // We'll center 0,0 at a large offset
    const double offsetX = 2000.0;
    const double offsetY = 2000.0;

    // Render Occupied Cells
    map.forEach((key, batteryId) {
      final parts = key.split(',');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);

      final battery = batteries.firstWhere(
        (b) => b.id == batteryId,
        orElse: () => Battery(
          id: 'unknown',
          name: 'Unknown',
          type: '?',
          brand: '?',
          model: '?',
          barcode: '',
          quantity: 0,
          purchaseDate: DateTime.now(),
          lastChanged: DateTime.now(),
        ),
      );

      cellWidgets.add(
        Positioned(
          left: offsetX + (x * (cellSize + cellSpacing)),
          top: offsetY + (y * (cellSize + cellSpacing)),
          child: _buildOccupiedCell(context, x, y, battery, state),
        ),
      );
    });

    // Render Potential Spots
    for (var key in potentialSpots) {
      final parts = key.split(',');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);

      cellWidgets.add(
        Positioned(
          left: offsetX + (x * (cellSize + cellSpacing)),
          top: offsetY + (y * (cellSize + cellSpacing)),
          child: _buildEmptyCell(context, x, y, state),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _buildMapSelector(context, state),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_location_alt),
            tooltip: 'Gerenciar Mapas',
            onPressed: () => _showMapManager(context, state),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerMap,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF141414), // Dark background
      body: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.all(2000),
        minScale: 0.1,
        maxScale: 2.0,
        constrained: false,
        child: SizedBox(
          width: 4000,
          height: 4000,
          child: Stack(
            children: [
              // Grid background reference (optional)
              Positioned.fill(child: CustomPaint(painter: _GridPainter())),
              ...cellWidgets,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOccupiedCell(
    BuildContext context,
    int x,
    int y,
    Battery battery,
    AppState state,
  ) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != '$x,$y',
      onAcceptWithDetails: (details) {
        final parts = details.data.split(',');
        final fromX = int.parse(parts[0]);
        final fromY = int.parse(parts[1]);
        state.swapBatteriesOnMap(fromX, fromY, x, y);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return LongPressDraggable<String>(
          data: '$x,$y',
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Transform.rotate(
            angle: 0.05,
            child: Transform.scale(
              scale: 1.05,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: _buildCellContent(battery, isFeedback: true),
              ),
            ),
          ),
          childWhenDragging: Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Center(
              child: Icon(
                Icons.drag_indicator,
                color: Colors.white10,
                size: 32,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () => _showCellDetails(context, x, y, battery, state),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                border: isHovered
                    ? Border.all(color: Colors.greenAccent, width: 3)
                    : null,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                children: [
                  _buildCellContent(battery),
                  if (isHovered)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                color: Colors.greenAccent,
                                size: 32,
                              ),
                              Text(
                                "TROCAR",
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCellContent(Battery battery, {bool isFeedback = false}) {
    return Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: isFeedback
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${battery.brand} • ${battery.type}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (battery.imageUrl.isNotEmpty)
                  Expanded(
                    child: Image.network(
                      battery.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.battery_std,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Icon(
                      Icons.battery_std,
                      size: 30,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  battery.model,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Pack x${battery.packSize} • Gôn: ${battery.gondolaQuantity}',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!isFeedback)
            const Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.drag_indicator,
                size: 16,
                color: Colors.white24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCell(BuildContext context, int x, int y, AppState state) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final parts = details.data.split(',');
        final fromX = int.parse(parts[0]);
        final fromY = int.parse(parts[1]);
        state.moveBatteryOnMap(fromX, fromY, x, y);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () => _showBatteryPicker(context, x, y, state),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: isHovered
                  ? Colors.blueAccent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered
                    ? Colors.blueAccent
                    : Colors.grey.withValues(alpha: 0.3),
                style: BorderStyle.solid,
                width: isHovered ? 2 : 1,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: AnimatedScale(
                scale: isHovered ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.add,
                  color: isHovered ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCellDetails(
    BuildContext context,
    int x,
    int y,
    Battery initialBattery,
    AppState state,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: state,
        builder: (context, child) {
          // Re-fetch battery to get live updates
          final battery = state.batteries.firstWhere(
            (b) => b.id == initialBattery.id,
            orElse: () => initialBattery,
          );

          // Resolve linked battery if any
          Battery? linkedStock;
          if (battery.linkedBatteryId != null) {
            linkedStock = state.batteries.firstWhere(
              (b) => b.id == battery.linkedBatteryId,
              orElse: () => Battery(
                id: 'unknown',
                name: 'Unknown Stock',
                type: '',
                brand: '',
                model: '',
                barcode: '',
                quantity: 0,
                purchaseDate: DateTime.now(),
                lastChanged: DateTime.now(),
              ),
            );
          }

          return Dialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Image
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            image: battery.imageUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(battery.imageUrl),
                                    fit: BoxFit.contain,
                                  )
                                : null,
                          ),
                          child: battery.imageUrl.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.battery_std,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                )
                              : null,
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                battery.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${battery.brand} • ${battery.model}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Details Grid
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _DetailBadge(
                                    label: 'Tipo',
                                    value: battery.type,
                                  ),
                                  _DetailBadge(
                                    label: 'Pack',
                                    value: 'x${battery.packSize}',
                                  ),
                                  if (battery.barcode.isNotEmpty)
                                    _DetailBadge(
                                      label: 'EAN',
                                      value: battery.barcode,
                                    ),
                                  if (linkedStock != null)
                                    _DetailBadge(
                                      label: 'Estoque (Link)',
                                      value:
                                          '${linkedStock.quantity} (x${linkedStock.packSize})',
                                    )
                                  else
                                    _DetailBadge(
                                      label: 'Estoque',
                                      value: '${battery.quantity}',
                                    ),
                                  _DetailBadge(label: 'Local', value: '$x, $y'),
                                ],
                              ),

                              const SizedBox(height: 16),
                              const Text(
                                'Qtd. Gôndola',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => state
                                          .adjustGondolaQuantity(battery, -1),
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '${battery.gondolaQuantity}',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (battery.gondolaLimit > 0)
                                          Text(
                                            '/${battery.gondolaLimit}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Colors.greenAccent,
                                      ),
                                      onPressed: () => state
                                          .adjustGondolaQuantity(battery, 1),
                                    ),
                                  ],
                                ),
                              ),

                              if (battery.notes.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Notas',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.yellowAccent.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.yellowAccent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    battery.notes,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(
                                height: 50,
                              ), // Padding for corner buttons
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close Button (Top Right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                      ),
                    ),
                  ),

                  // Edit Button (Bottom Left)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              BatteryFormScreen(batteryToEdit: battery),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),

                  // Remove Button (Bottom Right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        state.removeBatteryFromMap(x, y);
                        Navigator.pop(ctx);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBatteryPicker(BuildContext context, int x, int y, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _BatteryPickerContent(
              state: state,
              onSelected: (id) {
                state.placeBatteryOnMap(x, y, id);
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }
}

class _BatteryPickerContent extends StatefulWidget {
  final AppState state;
  final Function(String) onSelected;
  const _BatteryPickerContent({required this.state, required this.onSelected});

  @override
  State<_BatteryPickerContent> createState() => _BatteryPickerContentState();
}

class _BatteryPickerContentState extends State<_BatteryPickerContent> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gondolaItems = widget.state.batteries.where((b) {
      final loc = b.location.toLowerCase();
      final isGondola = loc.contains('gondola') || loc.contains('gôndola');
      return isGondola && SearchQueryParser.matches(b, _query);
    }).toList();

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const Text(
            'Selecionar Bateria (Gôndola)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Procurar baterias...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() => _query = '');
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: gondolaItems.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Nenhuma bateria de gôndola encontrada.'
                          : 'Nenhum resultado para "$_query"',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: gondolaItems.length,
                    itemBuilder: (ctx, idx) {
                      final b = gondolaItems[idx];
                      return ListTile(
                        leading: b.imageUrl.isNotEmpty
                            ? Image.network(
                                b.imageUrl,
                                width: 30,
                                height: 30,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.battery_std,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(Icons.battery_std, color: Colors.grey),
                        title: Text(
                          b.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${b.brand} • ${b.model} • ${b.type} • x${b.packSize}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          'Gôn: ${b.gondolaQuantity}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => widget.onSelected(b.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final String value;
  const _DetailBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Draw a large grid for reference (every 128px)
    // Centered at 2000, 2000
    const step = 128.0;
    const center = 2000.0;

    // Draw lines
    for (double i = center - 2000; i <= center + 2000; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, 4000), paint);
      canvas.drawLine(Offset(0, i), Offset(4000, i), paint);
    }

    // Draw Axis
    paint.color = Colors.blueAccent.withValues(alpha: 0.2);
    paint.strokeWidth = 2;
    canvas.drawLine(const Offset(center, 0), const Offset(center, 4000), paint);
    canvas.drawLine(const Offset(0, center), const Offset(4000, center), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
