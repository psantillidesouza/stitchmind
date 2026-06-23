/// Avaliações reais agregadas das lojas (App Store + Google Play).
class StoreReview {
  const StoreReview({
    required this.author,
    required this.rating,
    required this.text,
    required this.store,
    this.title,
  });

  final String author;
  final int rating;
  final String? title;
  final String text;
  final String store; // 'appstore' | 'googleplay'

  factory StoreReview.fromJson(Map<String, dynamic> j) => StoreReview(
        author: (j['author'] ?? 'User').toString(),
        rating: (j['rating'] as num?)?.toInt() ?? 5,
        title: j['title']?.toString(),
        text: (j['text'] ?? '').toString(),
        store: (j['store'] ?? 'appstore').toString(),
      );
}

class StoreReviews {
  const StoreReviews({
    required this.rating,
    required this.count,
    required this.reviews,
  });

  final double rating; // média ponderada das duas lojas
  final int count; // total de avaliações
  final List<StoreReview> reviews; // só as que têm texto

  bool get hasRating => count > 0 && rating > 0;

  factory StoreReviews.fromJson(Map<String, dynamic> j) => StoreReviews(
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        reviews: ((j['reviews'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(StoreReview.fromJson)
            .toList(),
      );

  static const empty = StoreReviews(rating: 0, count: 0, reviews: []);
}
