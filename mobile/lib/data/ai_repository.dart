import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

/// "✨ AI bilen ýaz": Turkmen title, description and hashtags.
class AiRepository {
  AiRepository(this._api);
  final ApiClient _api;

  /// True when the server can ask Claude; false = template suggestions.
  Future<bool> enabled() async =>
      asBool(parseJson(await _api.get('/ai/status'))['enabled']);

  Future<Suggestion> suggest({
    required ListingType listingType,
    String category = '',
    String title = '',
    String notes = '',
    PickedImage? image,
  }) async {
    final form = FormData.fromMap({
      'listingType': listingType.value,
      'category': category,
      'title': title,
      'notes': notes,
      if (image != null) 'image': image.toMultipart(),
    });
    return Suggestion.fromJson(
      parseJson(await _api.post('/ai/suggest', data: form)),
    );
  }
}
