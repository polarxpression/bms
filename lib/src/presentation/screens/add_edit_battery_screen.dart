import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:bms/src/data/models/battery.dart';
import 'package:bms/src/providers/battery_providers.dart';

// Simple provider for Uuid instance
final uuidProvider = Provider((ref) => const Uuid());

class AddEditBatteryScreen extends ConsumerStatefulWidget {
  final Battery? battery;

  const AddEditBatteryScreen({super.key, this.battery});

  @override
  ConsumerState<AddEditBatteryScreen> createState() =>
      _AddEditBatteryScreenState();
}

class _AddEditBatteryScreenState extends ConsumerState<AddEditBatteryScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _modelController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _packSizeController;
  BatteryLocation _location = BatteryLocation.stock;

  bool get _isEditMode => widget.battery != null;

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController(text: widget.battery?.model);
    _brandController = TextEditingController(text: widget.battery?.brand);
    _barcodeController = TextEditingController(text: widget.battery?.barcode);
    _quantityController = TextEditingController(
      text: widget.battery?.quantity.toString(),
    );
    _packSizeController = TextEditingController(
      text: widget.battery?.packSize.toString(),
    );
    _location = widget.battery?.location ?? BatteryLocation.stock;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _packSizeController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final firestoreService = ref.read(firestoreServiceProvider);
      final id = _isEditMode ? widget.battery!.id : ref.read(uuidProvider).v4();

      final batteryToSave = Battery(
        id: id,
        model: _modelController.text,
        brand: _brandController.text,
        barcode: _barcodeController.text,
        quantity: num.tryParse(_quantityController.text) ?? 0,
        packSize: int.tryParse(_packSizeController.text) ?? 1,
        location: _location,
        // Preserve other fields when editing
        createdAt: _isEditMode ? widget.battery!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      try {
        if (_isEditMode) {
          await firestoreService.updateBattery(batteryToSave);
        } else {
          await firestoreService.addBattery(batteryToSave);
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving battery: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Battery' : 'Add Battery'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveForm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Model'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a model' : null,
              ),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a brand' : null,
              ),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a barcode' : null,
              ),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a quantity' : null,
              ),
              TextFormField(
                controller: _packSizeController,
                decoration: const InputDecoration(labelText: 'Pack Size'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a pack size' : null,
              ),
              const SizedBox(height: 20),
              const Text('Location'),
              SegmentedButton<BatteryLocation>(
                segments: const [
                  ButtonSegment(
                    value: BatteryLocation.gondola,
                    label: Text('Gondola'),
                  ),
                  ButtonSegment(
                    value: BatteryLocation.stock,
                    label: Text('Stock'),
                  ),
                ],
                selected: {_location},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _location = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
