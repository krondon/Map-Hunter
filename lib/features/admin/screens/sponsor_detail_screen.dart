import 'dart:io';
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sponsor.dart';
import '../services/sponsor_service.dart';

class SponsorDetailScreen extends StatefulWidget {
  final Sponsor? sponsor; // If null, creating new

  const SponsorDetailScreen({super.key, this.sponsor});

  @override
  State<SponsorDetailScreen> createState() => _SponsorDetailScreenState();
}

class _SponsorDetailScreenState extends State<SponsorDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sponsorService = SponsorService();
  final _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  String _selectedPlan = 'bronce';
  bool _isActive = true;

  // Selected Files
  // Selected Files
  XFile? _logoFile;
  Uint8List? _logoBytes;

  XFile? _bannerFile;
  Uint8List? _bannerBytes;

  XFile? _assetFile;
  Uint8List? _assetBytes;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sponsor?.name ?? '');
    _selectedPlan = widget.sponsor?.planType ?? 'bronce';
    _isActive = widget.sponsor?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        // --- Validation: Max 2MB ---
        final sizeInMb = bytes.lengthInBytes / (1024 * 1024);
        if (sizeInMb > 2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '⚠️ La imagen es muy grande (máx 2MB). Intenta comprimirla.',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: AppTheme.warningOrange,
              ),
            );
          }
          return;
        }

        setState(() {
          switch (type) {
            case 'logo':
              _logoFile = pickedFile;
              _logoBytes = bytes;
              break;
            case 'banner':
              _bannerFile = pickedFile;
              _bannerBytes = bytes;
              break;
            case 'asset':
              _assetFile = pickedFile;
              _assetBytes = bytes;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _saveSponsor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (widget.sponsor == null) {
        // CREATE
        await _sponsorService.createSponsor(
          name: _nameController.text.trim(),
          planType: _selectedPlan,
          isActive: _isActive,
          // Mobile Fallback
          logoFile:
              (!kIsWeb && _logoFile != null) ? File(_logoFile!.path) : null,
          bannerFile:
              (!kIsWeb && _bannerFile != null) ? File(_bannerFile!.path) : null,
          assetFile:
              (!kIsWeb && _assetFile != null) ? File(_assetFile!.path) : null,
          // Web Support
          logoBytes: kIsWeb ? _logoBytes : null,
          bannerBytes: kIsWeb ? _bannerBytes : null,
          assetBytes: kIsWeb ? _assetBytes : null,
          logoExtension: _logoFile?.name.split('.').last,
          bannerExtension: _bannerFile?.name.split('.').last,
          assetExtension: _assetFile?.name.split('.').last,
        );
      } else {
        // UPDATE
        await _sponsorService.updateSponsor(
          id: widget.sponsor!.id,
          name: _nameController.text.trim(),
          planType: _selectedPlan,
          isActive: _isActive,

          // Mobile Fallback
          logoFile:
              (!kIsWeb && _logoFile != null) ? File(_logoFile!.path) : null,
          bannerFile:
              (!kIsWeb && _bannerFile != null) ? File(_bannerFile!.path) : null,
          assetFile:
              (!kIsWeb && _assetFile != null) ? File(_assetFile!.path) : null,
          // Web Support
          logoBytes: kIsWeb ? _logoBytes : null,
          bannerBytes: kIsWeb ? _bannerBytes : null,
          assetBytes: kIsWeb ? _assetBytes : null,
          logoExtension: _logoFile?.name.split('.').last,
          bannerExtension: _bannerFile?.name.split('.').last,
          assetExtension: _assetFile?.name.split('.').last,

          currentLogoUrl: widget.sponsor!.logoUrl,
          currentBannerUrl: widget.sponsor!.bannerUrl,
          currentAssetUrl: widget.sponsor!.minigameAssetUrl,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patrocinador guardado correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.darkGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.sponsor == null
                ? "Nuevo Patrocinador"
                : "Editar Patrocinador",
            style: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Basic Info ---
                      _buildSectionTitle("Información Básica"),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Nombre de la Marca/Patrocinador",
                          hintText: "Ej. Coca-Cola, Nike...",
                          prefixIcon: Icon(Icons.abc, color: Colors.white60),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Por favor ingresa un nombre'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedPlan,
                        dropdownColor: AppTheme.dSurface2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Plan",
                          prefixIcon:
                              Icon(Icons.star, color: AppTheme.accentGold),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'bronce', child: Text("BRONCE (Básico)")),
                          DropdownMenuItem(
                              value: 'plata',
                              child: Text("PLATA (Intermedio)")),
                          DropdownMenuItem(
                              value: 'oro', child: Text("ORO (Premium)")),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedPlan = val ?? 'bronce'),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Switch(
                            value: _isActive,
                            onChanged: (val) => setState(() => _isActive = val),
                            activeColor: AppTheme.successGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isActive
                                ? "Activo (Visible en el juego)"
                                : "Inactivo",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // --- Images ---
                      _buildSectionTitle("Imágenes y Assets"),
                      const SizedBox(height: 8),
                      const Text(
                        "Sube las imágenes correspondientes para personalizar la experiencia.",
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      _buildImagePicker(
                        label: "Logo de la Marca",
                        description: "Visible en listas y créditos.",
                        type: 'logo',
                        file: _logoFile,
                        bytes: _logoBytes,
                        currentUrl: widget.sponsor?.logoUrl,
                      ),
                      const SizedBox(height: 24),

                      _buildImagePicker(
                        label: "Banner Publicitario",
                        description: "Banner horizontal para menús.",
                        type: 'banner',
                        file: _bannerFile,
                        bytes: _bannerBytes,
                        currentUrl: widget.sponsor?.bannerUrl,
                      ),
                      const SizedBox(height: 32),

                      // PNG ENFORCEMENT ALERT
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.warningOrange, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.warningOrange, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "REQUISITO CRÍTICO",
                                    style: TextStyle(
                                      color: AppTheme.warningOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    "El asset para minijuegos DEBE ser PNG con fondo transparente.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildImagePicker(
                        label: "Asset Minijuego (La Manzana)",
                        description:
                            "Imagen PNG con fondo transparente (64x64px recomendado).",
                        type: 'asset',
                        file: _assetFile,
                        bytes: _assetBytes,
                        currentUrl: widget.sponsor?.minigameAssetUrl,
                      ),

                      const SizedBox(height: 48),

                      // --- Save Button ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveSponsor,
                          icon: const Icon(Icons.save),
                          label: const Text("GUARDAR PATROCINADOR"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.accentGold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: Colors.white24),
      ],
    );
  }

  Widget _buildImagePicker({
    required String label,
    required String description,
    required String type,
    XFile? file,
    Uint8List? bytes,
    String? currentUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        Text(description,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _pickImage(type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white24, style: BorderStyle.solid),
            ),
            child: bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  )
                : file != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(file.path, fit: BoxFit.contain)
                            : Image.file(File(file.path), fit: BoxFit.contain),
                      )
                    : currentUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                Image.network(currentUrl, fit: BoxFit.contain),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate,
                                  color: Colors.white54, size: 40),
                              const SizedBox(height: 8),
                              Text("Toca para subir imagen",
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.5))),
                            ],
                          ),
          ),
        ),
      ],
    );
  }
}
