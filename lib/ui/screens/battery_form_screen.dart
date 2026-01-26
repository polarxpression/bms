import 'package:flutter/material.dart';
import 'package:bms/core/models/battery.dart';
import 'package:bms/state/app_state.dart';
import 'package:bms/ui/screens/barcode_scanner_simple.dart';

class BatteryFormScreen extends StatefulWidget {
  final Battery? batteryToEdit;
  const BatteryFormScreen({super.key, this.batteryToEdit});
  @override
  State<BatteryFormScreen> createState() => _BatteryFormScreenState();
}

class _BatteryFormScreenState extends State<BatteryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Fields to edit
  late String _brand, _model, _type, _notes;
  late String _currentLocation; // 'Estoque' or 'Gôndola'
  bool _discontinued = false;

  // Quantities
  int _stockQty = 0;
  int _gondolaQty = 0;
  int _gondolaLimit = 0;

  // NEW: Min Stock Threshold
  int _minStockThreshold = 0;
  bool _useDefaultMinStock = true;
  
  // NEW: Linked Battery ID
  String? _linkedBatteryId;

  // Controllers
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  // Hidden/Defaulted fields preservation
  late String _name, _img, _voltage, _chemistry;
  late int _threshold, _packSize;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    final b = widget.batteryToEdit;

    _brand = b?.brand ?? 'Duracell';
    _model = b?.model ?? 'Alcalina';
    _type = b?.type ?? 'AA';
    _notes = b?.notes ?? '';
    _discontinued = b?.discontinued ?? false;
    _linkedBatteryId = b?.linkedBatteryId;

    // Location Logic
    String rawLoc = b?.location ?? '';
    if (rawLoc.toLowerCase().contains('gondola') ||
        rawLoc.toLowerCase().contains('gôndola')) {
      _currentLocation = 'Gôndola';
    } else {
      _currentLocation = 'Estoque';
    }

    _stockQty = b?.quantity ?? 0;
    _gondolaQty = b?.gondolaQuantity ?? 0;
    _gondolaLimit = b?.gondolaLimit ?? 0;
    _minStockThreshold = b?.minStockThreshold ?? 0;
    _useDefaultMinStock = b?.useDefaultMinStock ?? true;

    // Initialize controller based on current location
    _qtyController.text =
        (_currentLocation == 'Estoque' ? _stockQty : _gondolaQty).toString();

    // Preserve others
    _name = b?.name ?? '';
    _barcodeController.text = b?.barcode ?? '';
    _img = b?.imageUrl ?? '';
    _voltage = b?.voltage ?? '';
    _chemistry = b?.chemistry ?? '';
    _threshold = b?.lowStockThreshold ?? 2;
    _packSize = b?.packSize ?? 1;
    _expiryDate = b?.expiryDate;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _switchLocation(String? newLoc) {
    if (newLoc == null || newLoc == _currentLocation) return;

    // 1. Save current input to the OLD location variable
    int currentVal = int.tryParse(_qtyController.text) ?? 0;
    if (_currentLocation == 'Estoque') {
      _stockQty = currentVal;
    } else {
      _gondolaQty = currentVal;
    }

    // 2. Switch
    setState(() {
      _currentLocation = newLoc;
    });

    // 3. Update input with NEW location variable
    int newVal = (_currentLocation == 'Estoque' ? _stockQty : _gondolaQty);
    _qtyController.text = newVal.toString();
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerSimple()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    List<String> getOptions(
      List<Battery> allBatteries,
      String Function(Battery) extractor,
      String currentVal,
    ) {
      final Set<String> options = allBatteries
          .map(extractor)
          .where((s) => s.isNotEmpty)
          .toSet();
      if (currentVal.isNotEmpty) options.add(currentVal);
      return options.toList()..sort();
    }

    final existingBrands = getOptions(state.batteries, (b) => b.brand, _brand);
    final existingModels = getOptions(state.batteries, (b) => b.model, _model);
    final existingTypes = getOptions(state.batteries, (b) => b.type, _type);

    // Filter batteries for "Stock" linking
    // Exclude self and non-stock items
    final stockBatteries = state.batteries.where((b) {
      if (b.id == widget.batteryToEdit?.id) return false;
      return b.location == 'Estoque';
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.batteryToEdit == null
                        ? 'Nova Bateria'
                        : 'Editar Produto',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.batteryToEdit != null)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        AppStateProvider.of(
                          context,
                        ).deleteBattery(widget.batteryToEdit!.id);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _section('Identificação'),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdownField(
                            'Marca',
                            _brand,
                            existingBrands,
                            (v) => _brand = v,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dropdownField(
                            'Modelo',
                            _model,
                            existingModels,
                            (v) => _model = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _dropdownField(
                      'Tipo',
                      _type,
                      existingTypes,
                      (v) => _type = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Código de Barras (EAN)',
                        prefixIcon: const Icon(Icons.qr_code),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: _scanBarcode,
                        ),
                      ),
                    ),

                    _section('Localização & Quantidade'),
                    // Location Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _currentLocation,
                      items: const [
                        DropdownMenuItem(
                          value: 'Estoque',
                          child: Text('Estoque (Depósito)'),
                        ),
                        DropdownMenuItem(
                          value: 'Gôndola',
                          child: Text('Gôndola (Loja)'),
                        ),
                      ],
                      onChanged: _switchLocation,
                      decoration: const InputDecoration(
                        labelText: 'Localização Atual',
                      ),
                      dropdownColor: const Color(0xFF27272A),
                    ),
                    const SizedBox(height: 12),
                    
                    // NEW: Linked Battery Dropdown (Only if Gondola)
                    if (_currentLocation == 'Gôndola') ...[
                       DropdownButtonFormField<String>(
                        initialValue: _linkedBatteryId,
                        decoration: const InputDecoration(
                          labelText: 'Vincular ao Estoque (Opcional)',
                          helperText: 'Selecionar produto correspondente no estoque',
                          prefixIcon: Icon(Icons.link),
                        ),
                        dropdownColor: const Color(0xFF27272A),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Sem vínculo (Nenhum)'),
                          ),
                          ...stockBatteries.map((b) {
                            return DropdownMenuItem<String>(
                              value: b.id,
                              child: Text(
                                '${b.name} (Qtd: ${b.quantity})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _linkedBatteryId = v),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Quantity Field (Dynamic)
                    TextFormField(
                      controller: _qtyController,
                      decoration: InputDecoration(
                        labelText: 'Quantidade em $_currentLocation',
                        helperText: _currentLocation == 'Estoque'
                            ? 'Itens guardados no estoque'
                            : 'Itens expostos na loja',
                        suffixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      // We don't use onSaved here because we handle it in _save manually
                    ),

                    // Gondola Limit (Conditional)
                    if (_currentLocation == 'Gôndola') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _gondolaLimit.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Capacidade Máxima da Gôndola',
                          helperText:
                              'Opcional. Padrão definido nos ajustes se 0.',
                        ),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => _gondolaLimit = int.tryParse(v!) ?? 0,
                      ),
                    ],

                    // Stock Min Threshold (Conditional - Only for Stock? User said "if on stock")
                    // We'll show it generally but clarify it's for Stock.
                    if (_currentLocation == 'Estoque') ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Usar limite padrão do sistema (${state.defaultMinStockThreshold})',
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: _useDefaultMinStock,
                        onChanged: (v) => setState(() {
                          _useDefaultMinStock = v ?? true;
                          if (_useDefaultMinStock) {
                            _minStockThreshold = 0; // Or whatever, ignored
                          }
                        }),
                        activeColor: const Color(0xFFEC4899),
                      ),
                      if (!_useDefaultMinStock)
                        TextFormField(
                          initialValue: _minStockThreshold.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Estoque Mínimo Personalizado',
                            helperText:
                                'Defina 0 para "Nenhum" (não alertar).',
                          ),
                          keyboardType: TextInputType.number,
                          onSaved: (v) =>
                              _minStockThreshold = int.tryParse(v!) ?? 0,
                        ),
                    ],

                    _section('Outros'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Produto Descontinuado'),
                      subtitle: const Text('Marcar se não for mais vendido'),
                      value: _discontinued,
                      activeThumbColor: const Color(0xFFEC4899),
                      onChanged: (v) => setState(() => _discontinued = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Notas / Observações',
                      ),
                      maxLines: 2,
                      onSaved: (v) => _notes = v!,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Salvar Alterações'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFEC4899),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _dropdownField(
    String label,
    String currentVal,
    List<String> options,
    Function(String) updateCallback,
  ) {
    String? dropdownValue =
        currentVal.isNotEmpty && options.contains(currentVal)
        ? currentVal
        : null;

    return DropdownButtonFormField<String>(
      initialValue: dropdownValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      dropdownColor: const Color(0xFF27272A),
      items: options.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) setState(() => updateCallback(newValue));
      },
      onSaved: (v) => updateCallback(v ?? ''),
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFEC4899)),
      selectedItemBuilder: (BuildContext context) {
        return options.map<Widget>((String value) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }).toList();
      },
    );
  }

  void _save() {
    _formKey.currentState!.save();

    // Manually save the quantity from controller to the current location variable
    int finalQtyInput = int.tryParse(_qtyController.text) ?? 0;
    if (_currentLocation == 'Estoque') {
      _stockQty = finalQtyInput;
    } else {
      _gondolaQty = finalQtyInput;
    }

    final state = AppStateProvider.of(context);
    final bat = Battery(
      id: widget.batteryToEdit?.id ?? '',
      name: _name.isNotEmpty ? _name : '$_brand $_model',
      type: _type,
      brand: _brand,
      model: _model,
      barcode: _barcodeController.text, // Use the controller text
      imageUrl: _img,
      quantity: _stockQty,
      lowStockThreshold: _threshold,
      minStockThreshold: _minStockThreshold, // NEW
      useDefaultMinStock: _useDefaultMinStock, // NEW
      purchaseDate: widget.batteryToEdit?.purchaseDate ?? DateTime.now(),
      lastChanged: DateTime.now(),
      voltage: _voltage,
      chemistry: _chemistry,
      notes: _notes,
      expiryDate: _expiryDate,
      location: _currentLocation, // Save the selected location string
      gondolaLimit: _gondolaLimit,
      gondolaQuantity: _gondolaQty,
      packSize: _packSize,
      discontinued: _discontinued,
      linkedBatteryId: _linkedBatteryId, // NEW
    );
    if (widget.batteryToEdit == null) {
      state.addBattery(bat);
    } else {
      state.updateBattery(bat);
    }
    Navigator.pop(context);
  }
}