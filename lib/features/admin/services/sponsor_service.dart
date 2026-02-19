import 'dart:io';
import 'dart:typed_data'; // Add this for Uint8List
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sponsor.dart';

class SponsorService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'sponsor-assets';

  // --- Fetch Methods ---

  Future<List<Sponsor>> getSponsors() async {
    final response = await _supabase
        .from('sponsors')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) => Sponsor.fromJson(json)).toList();
  }

  Future<Sponsor?> getActiveSponsor() async {
    try {
      final response = await _supabase
          .from('sponsors')
          .select()
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return Sponsor.fromJson(response);
    } catch (e) {
      print("Error fetching active sponsor: $e");
      return null;
    }
  }

  Future<Sponsor?> getSponsorForEvent(String eventId) async {
    try {
      // 1. Get sponsor_id from event
      final eventResponse = await _supabase
          .from('events')
          .select('sponsor_id')
          .eq('id', eventId)
          .maybeSingle();

      if (eventResponse == null || eventResponse['sponsor_id'] == null) {
        return null;
      }

      final String sponsorId = eventResponse['sponsor_id'] as String;

      // 2. Get sponsor details
      final sponsorResponse = await _supabase
          .from('sponsors')
          .select()
          .eq('id', sponsorId)
          .maybeSingle();

      if (sponsorResponse == null) return null;

      return Sponsor.fromJson(sponsorResponse);
    } catch (e) {
      debugPrint("Error fetching sponsor for event: $e");
      return null;
    }
  }

  // --- Modification Methods ---

  Future<void> createSponsor({
    required String name,
    required String planType,
    required bool isActive,
    File? logoFile,
    File? bannerFile,
    File? assetFile,
    // Web support
    Uint8List? logoBytes,
    Uint8List? bannerBytes,
    Uint8List? assetBytes,
    String? logoExtension,
    String? bannerExtension,
    String? assetExtension,
  }) async {
    String? logoUrl;
    String? bannerUrl;
    String? assetUrl;

    if (isActive) {
      // Deactivate others if this one is active (optional logic, but usually only one sponsor is active at a time)
      await _deactivateAllSponsors();
    }

    if (logoFile != null || logoBytes != null) {
      if (logoBytes != null) {
        logoUrl = await _uploadFile(
            bytes: logoBytes, folder: 'logos', extension: logoExtension);
      } else {
        logoUrl = await _uploadFile(
            file: logoFile, folder: 'logos', extension: logoExtension);
      }
    }
    if (bannerFile != null || bannerBytes != null) {
      if (bannerBytes != null) {
        bannerUrl = await _uploadFile(
            bytes: bannerBytes, folder: 'banners', extension: bannerExtension);
      } else {
        bannerUrl = await _uploadFile(
            file: bannerFile, folder: 'banners', extension: bannerExtension);
      }
    }
    if (assetFile != null || assetBytes != null) {
      if (assetBytes != null) {
        assetUrl = await _uploadFile(
            bytes: assetBytes, folder: 'assets', extension: assetExtension);
      } else {
        assetUrl = await _uploadFile(
            file: assetFile, folder: 'assets', extension: assetExtension);
      }
    }

    await _supabase.from('sponsors').insert({
      'name': name,
      'plan_type': planType,
      'is_active': isActive,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'minigame_asset_url': assetUrl,
    });
  }

  Future<void> updateSponsor({
    required String id,
    String? name,
    String? planType,
    bool? isActive,
    File? logoFile,
    File? bannerFile,
    File? assetFile,
    // Web support
    Uint8List? logoBytes,
    Uint8List? bannerBytes,
    Uint8List? assetBytes,
    String? logoExtension,
    String? bannerExtension,
    String? assetExtension,
    // Original URLs to keep if no new file is uploaded
    String? currentLogoUrl,
    String? currentBannerUrl,
    String? currentAssetUrl,
  }) async {
    String? logoUrl = currentLogoUrl;
    String? bannerUrl = currentBannerUrl;
    String? assetUrl = currentAssetUrl;

    if (isActive == true) {
      await _deactivateAllSponsors(excludeId: id);
    }

    if (logoFile != null || logoBytes != null) {
      if (logoBytes != null) {
        logoUrl = await _uploadFile(
            bytes: logoBytes, folder: 'logos', extension: logoExtension);
      } else {
        logoUrl = await _uploadFile(
            file: logoFile, folder: 'logos', extension: logoExtension);
      }
    }
    if (bannerFile != null || bannerBytes != null) {
      if (bannerBytes != null) {
        bannerUrl = await _uploadFile(
            bytes: bannerBytes, folder: 'banners', extension: bannerExtension);
      } else {
        bannerUrl = await _uploadFile(
            file: bannerFile, folder: 'banners', extension: bannerExtension);
      }
    }
    if (assetFile != null || assetBytes != null) {
      if (assetBytes != null) {
        assetUrl = await _uploadFile(
            bytes: assetBytes, folder: 'assets', extension: assetExtension);
      } else {
        assetUrl = await _uploadFile(
            file: assetFile, folder: 'assets', extension: assetExtension);
      }
    }

    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (planType != null) updates['plan_type'] = planType;
    if (isActive != null) updates['is_active'] = isActive;
    updates['logo_url'] = logoUrl;
    updates['banner_url'] = bannerUrl;
    updates['minigame_asset_url'] = assetUrl;
    updates['updated_at'] = DateTime.now().toIso8601String();

    await _supabase.from('sponsors').update(updates).eq('id', id);
  }

  Future<void> deleteSponsor(String id) async {
    await _supabase.from('sponsors').delete().eq('id', id);
  }

  // --- Helper Methods ---

  Future<void> _deactivateAllSponsors({String? excludeId}) async {
    var query = _supabase
        .from('sponsors')
        .update({'is_active': false}).eq('is_active', true);

    if (excludeId != null) {
      query = query.neq('id', excludeId);
    }

    await query;
  }

  Future<String> _uploadFile(
      {File? file,
      Uint8List? bytes,
      required String folder,
      String? extension}) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${extension ?? 'png'}';
    final path = '$folder/$fileName';

    if (bytes != null) {
      // Web Upload
      await _supabase.storage.from(_bucketName).uploadBinary(path, bytes);
    } else if (file != null) {
      // Mobile Upload
      await _supabase.storage.from(_bucketName).upload(path, file);
    } else {
      throw Exception("No file or bytes provided");
    }

    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }
}
