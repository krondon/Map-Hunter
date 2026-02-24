import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../mall/models/mall_store.dart';
import '../../mall/models/power_item.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class StoreEditDialog extends StatefulWidget {
  final MallStore? store;
  final String eventId;

  const StoreEditDialog({super.key, this.store, required this.eventId});

  @override
  State<StoreEditDialog> createState() => _StoreEditDialogState();
}

class _StoreEditDialogState extends State<StoreEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  XFile? _imageFile;
  Uint8List? _imageBytes; // For preview (Cross-platform)
  Map<String, int> _customCosts = {}; // Track custom costs
  
  final Set<String> _selectedProductIds = {};
  
  // Available products to toggle
  final List<PowerItem> _availableItems = PowerItem.getShopItems();

  @override
  void initState() {
    super.initState();
    _name = widget.store?.name ?? '';
    _description = widget.store?.description ?? '';
    
    if (widget.store != null) {
      for (var p in widget.store!.products) {
         _selectedProductIds.add(p.id);
         _customCosts[p.id] = p.cost; // Load existing custom costs
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    // MANDATORY IMAGE VALIDATION
    if (_imageFile == null && (widget.store?.imageUrl.isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ La imagen de la tienda es obligatoria')),
      );
      return;
    }

    _formKey.currentState!.save();
    
    // Construct products list with custom costs
    final List<PowerItem> selectedProducts = _selectedProductIds
        .map((id) {
           final baseItem = _availableItems.firstWhere((item) => item.id == id);
           final customCost = _customCosts[id];
           // If custom cost exists and differs, use it
           if (customCost != null) {
             return baseItem.copyWith(cost: customCost);
           }
           return baseItem;
        })
        .toList();

    // Create result object (image file is passed separate)
    final newStore = MallStore(
      id: widget.store?.id ?? '', // ID handled by provider for create
      eventId: widget.eventId,
      name: _name,
      description: _description,
      imageUrl: widget.store?.imageUrl ?? '', // Provider will update if file exists
      qrCodeData: widget.store?.qrCodeData ?? 'STORE:${widget.eventId}:${const Uuid().v4()}', // Same QR format as clues: STORE:{eventId}:{storeId}
      products: selectedProducts,
    );

    Navigator.pop(context, {
      'store': newStore,
      'imageFile': _imageFile, // Passing XFile (compatible with Web/Mobile)
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(widget.store == null ? 'Nueva Tienda' : 'Editar Tienda', style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      image: _imageBytes != null
                        ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                        : (widget.store?.imageUrl.isNotEmpty ?? false)
                            ? DecorationImage(image: NetworkImage(widget.store!.imageUrl), fit: BoxFit.cover)
                            : null,
                    ),
                    child: (_imageBytes == null && (widget.store?.imageUrl.isEmpty ?? true))
                        ? const Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.white54),
                              SizedBox(height: 5),
                              Text("Imagen Obligatoria", style: TextStyle(color: Colors.white54, fontSize: 12))
                            ],
                          ))
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  initialValue: _name,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nombre', labelStyle: TextStyle(color: Colors.white70)),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  onSaved: (v) => _name = v!,
                ),
                TextFormField(
                  initialValue: _description,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Descripción', labelStyle: TextStyle(color: Colors.white70)),
                  onSaved: (v) => _description = v!,
                ),
                const SizedBox(height: 20),
                const Text("Productos Disponibles:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._availableItems.map((item) {
                  final isSelected = _selectedProductIds.contains(item.id);
                  return Column(
                    children: [
                      CheckboxListTile(
                        title: Text(item.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          // Show custom cost if editing, else default
                          "Costo Base: ${item.cost}", 
                          style: const TextStyle(color: Colors.white54)
                        ),
                        secondary: Text(item.icon, style: const TextStyle(fontSize: 24)),
                        value: isSelected,
                        activeColor: AppTheme.primaryPurple,
                        checkColor: Colors.white,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedProductIds.add(item.id);
                              // Initialize with current or default cost if not set
                              if (!_customCosts.containsKey(item.id)) {
                                _customCosts[item.id] = item.cost;
                              }
                            } else {
                              _selectedProductIds.remove(item.id);
                            }
                          });
                        },
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(left: 70, right: 20, bottom: 10),
                          child: TextFormField(
                            initialValue: _customCosts[item.id]?.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.accentGold),
                            decoration: const InputDecoration(
                              labelText: 'Costo (Monedas)',
                              labelStyle: TextStyle(color: Colors.white54),
                              isDense: true,
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onChanged: (val) {
                                final newCost = int.tryParse(val);
                                if (newCost != null) {
                                  _customCosts[item.id] = newCost;
                                }
                            },
                          ),
                        )
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}
