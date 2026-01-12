import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mall_store.dart';
import 'package:image_picker/image_picker.dart';

class StoreProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  List<MallStore> _stores = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<MallStore> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStores(String eventId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('mall_stores')
          .select()
          .eq('event_id', eventId)
          .order('created_at');

      _stores = (response as List).map((e) => MallStore.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching stores: $e');
      _errorMessage = 'Error cargando tiendas';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createStore(MallStore store, dynamic imageFile) async {
    _isLoading = true;
    notifyListeners();

    try {
      String? imageUrl;

      // 1. Upload Image if exists
      if (imageFile != null) {
        final fileExt = 'jpg'; // Default extension
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'store-images/$fileName';
        
        if (imageFile is XFile) {
            final bytes = await imageFile.readAsBytes();
             await _supabase.storage
              .from('events-images')
              .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
             
             imageUrl = _supabase.storage.from('events-images').getPublicUrl(filePath);
        }
      }

      // 2. Insert Store
      final storeData = store.toMap();
      if (imageUrl != null) {
        storeData['image_url'] = imageUrl;
      }

      await _supabase.from('mall_stores').insert(storeData);

      // Refresh
      if (store.eventId != null) {
        await fetchStores(store.eventId!);
      }
    } catch (e) {
      debugPrint('Error creating store: $e');
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
    Future<void> updateStore(MallStore store, dynamic newImageFile) async {
    _isLoading = true;
    notifyListeners();

    try {
      String? imageUrl = store.imageUrl;

      if (newImageFile != null) {
         final fileExt = 'jpg'; 
         final fileName = '${DateTime.now().millisecondsSinceEpoch}_updated.$fileExt';
         final filePath = 'store-images/$fileName';
         
          // Simple handling for now, adapt based on image picker result type
         if (newImageFile is XFile) {
             final bytes = await newImageFile.readAsBytes();
             await _supabase.storage
              .from('events-images')
              .uploadBinary(filePath, bytes, fileOptions: const FileOptions(upsert: true));
              
             imageUrl = _supabase.storage.from('events-images').getPublicUrl(filePath);
         }
      }

      final data = store.toMap();
      data['image_url'] = imageUrl;

      await _supabase
          .from('mall_stores')
          .update(data)
          .eq('id', store.id);

      if (store.eventId != null) {
        await fetchStores(store.eventId!);
      }
    } catch (e) {
      debugPrint('Error updating store: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteStore(String storeId, String eventId) async {
    try {
      await _supabase.from('mall_stores').delete().eq('id', storeId);
      await fetchStores(eventId); // Refresh list
    } catch (e) {
      debugPrint("Error deleting store: $e");
      rethrow;
    }
  }
}
