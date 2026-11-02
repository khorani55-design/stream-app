#!/bin/bash
set -e

APP_NAME="streaming_app"
ORG="com.streamapp"
PKG="stream_app"

echo "▶ ایجاد پروژه Flutter..."
if [ ! -d "$APP_NAME" ]; then
  flutter create --org "$ORG" --project-name "$PKG" \
    --platforms=android,ios,web "$APP_NAME"
fi

cd "$APP_NAME"
mkdir -p lib/{core,models,services,providers,pages,widgets}
mkdir -p android/app/src/main/res/{drawable,values}

# ============================================================
# 1) pubspec.yaml
# ============================================================
cat > pubspec.yaml << '__PUBSPEC__'
name: stream_app
description: Complete streaming app for movies and series
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  go_router: ^14.2.0
  provider: ^6.1.2
  shared_preferences: ^2.2.3
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_video: ^1.0.4
  background_downloader: ^8.6.0
  cached_network_image: ^3.4.1
  intl: ^0.19.0

dev_dependencies:
  flutter_lints: ^4.0.0
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
__PUBSPEC__

# ============================================================
# 2) lib/main.dart
# ============================================================
cat > lib/main.dart << '__MAIN__'
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/home_provider.dart';
import 'providers/download_provider.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final api = ApiService();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider(create: (_) => HomeProvider(api)..load()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()..load()),
      ],
      child: const StreamApp(),
    ),
  );
}
__MAIN__

# ============================================================
# 3) lib/app.dart
# ============================================================
cat > lib/app.dart << '__APP__'
import 'package:flutter/material.dart';
import 'core/router.dart';
import 'core/theme.dart';

class StreamApp extends StatelessWidget {
  const StreamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StreamApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
__APP__

# ============================================================
# 4) lib/core/theme.dart
# ============================================================
cat > lib/core/theme.dart << '__THEME__'
import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color primary = Color(0xFFE50914);
  static const Color text = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: text, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: text),
        ),
      );
}
__THEME__

# ============================================================
# 5) lib/core/router.dart
# ============================================================
cat > lib/core/router.dart << '__ROUTER__'
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/search_page.dart';
import '../pages/detail_page.dart';
import '../pages/player_page.dart';
import '../pages/downloads_page.dart';
import '../pages/profile_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
    GoRoute(path: '/downloads', builder: (_, __) => const DownloadsPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(
      path: '/detail/:id',
      builder: (_, s) => DetailPage(movieId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/player',
      builder: (_, s) {
        final url = s.uri.queryParameters['url']!;
        final title = s.uri.queryParameters['title'] ?? '';
        final sub = s.uri.queryParameters['sub'];
        return PlayerPage(videoUrl: url, title: title, subtitleUrl: sub);
      },
    ),
  ],
);
__ROUTER__

# ============================================================
# 6) lib/models/movie.dart
# ============================================================
cat > lib/models/movie.dart << '__MOVIE_MODEL__'
class Episode {
  final int number;
  final String title;
  final Duration duration;
  final String streamUrl;
  final String? subtitleUrl;
  const Episode({
    required this.number,
    required this.title,
    required this.duration,
    required this.streamUrl,
    this.subtitleUrl,
  });
}

class Season {
  final int number;
  final List<Episode> episodes;
  const Season({required this.number, required this.episodes});
}

class Movie {
  final String id;
  final String title;
  final String? originalTitle;
  final String overview;
  final String poster;
  final String? backdrop;
  final int year;
  final double rating;
  final List<String> genres;
  final List<String> tags;
  final String type; // 'movie' | 'series'
  final String? country;
  final String? language;
  final bool hasPersianDub;
  final bool hasPersianSub;
  final Duration? duration;
  final List<Season> seasons;
  final String streamUrl;
  final String? subtitleUrl;

  const Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    required this.overview,
    required this.poster,
    this.backdrop,
    required this.year,
    required this.rating,
    required this.genres,
    required this.tags,
    required this.type,
    this.country,
    this.language,
    this.hasPersianDub = false,
    this.hasPersianSub = false,
    this.duration,
    this.seasons = const [],
    required this.streamUrl,
    this.subtitleUrl,
  });

  bool get isSeries => type == 'series';
}
__MOVIE_MODEL__

# ============================================================
# 7) lib/models/download_task.dart
# ============================================================
cat > lib/models/download_task.dart << '__DL_MODEL__'
enum DownloadStatus { pending, scheduled, downloading, completed, failed, canceled }

class DownloadItem {
  final String id;
  final String movieId;
  final String title;
  final String streamUrl;
  final String? poster;
  final DateTime? scheduledAt;
  DownloadStatus status;
  double progress;
  String? error;
  String? localPath;

  DownloadItem({
    required this.id,
    required this.movieId,
    required this.title,
    required this.streamUrl,
    this.poster,
    this.scheduledAt,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.error,
    this.localPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'movieId': movieId,
        'title': title,
        'streamUrl': streamUrl,
        'poster': poster,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'status': status.name,
        'progress': progress,
        'error': error,
        'localPath': localPath,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> j) => DownloadItem(
        id: j['id'],
        movieId: j['movieId'],
        title: j['title'],
        streamUrl: j['streamUrl'],
        poster: j['poster'],
        scheduledAt: j['scheduledAt'] != null
            ? DateTime.parse(j['scheduledAt'])
            : null,
        status: DownloadStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => DownloadStatus.pending,
        ),
        progress: (j['progress'] ?? 0).toDouble(),
        error: j['error'],
        localPath: j['localPath'],
      );
}
__DL_MODEL__

# ============================================================
# 8) lib/services/api_service.dart  (Mock + Real ready)
# ============================================================
cat > lib/services/api_service.dart << '__API__'
import '../models/movie.dart';

class ApiService {
  // در آینده: Dio به https://api.example.com/v1 بزن
  static const String _testStream =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static const String _testSub =
      'https://raw.githubusercontent.com/mozilla/vtt.js/master/tests/data/captions.vtt';

  Future<List<Movie>> fetchCatalog() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockCatalog;
  }

  Future<Movie?> fetchMovieById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _mockCatalog.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<Movie>> search(String q) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (q.trim().isEmpty) return [];
    final lq = q.toLowerCase();
    return _mockCatalog.where((m) {
      return m.title.toLowerCase().contains(lq) ||
          m.overview.toLowerCase().contains(lq) ||
          m.genres.any((g) => g.toLowerCase().contains(lq));
    }).toList();
  }

  Future<List<Movie>> recommendationsFor(Movie base) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _mockCatalog
        .where((m) =>
            m.id != base.id &&
            m.genres.any((g) => base.genres.contains(g)))
        .take(10)
        .toList();
  }

  // -------- Mock data --------
  static const _imgs = [
    'https://picsum.photos/seed/a/400/600',
    'https://picsum.photos/seed/b/400/600',
    'https://picsum.photos/seed/c/400/600',
    'https://picsum.photos/seed/d/400/600',
    'https://picsum.photos/seed/e/400/600',
    'https://picsum.photos/seed/f/400/600',
    'https://picsum.photos/seed/g/400/600',
    'https://picsum.photos/seed/h/400/600',
  ];

  static final List<Movie> _mockCatalog = List.generate(16, (i) {
    final isSeries = i % 3 == 0;
    return Movie(
      id: 'm$i',
      title: 'نمونه شماره $i',
      originalTitle: 'Sample Title $i',
      overview:
          'توضیحات کوتاه درباره این اثر. یک داستان جذاب با بازیگران حرفه‌ای و کارگردانی متفاوت. مناسب تماشای خانوادگی.',
      poster: _imgs[i % _imgs.length],
      backdrop: _imgs[(i + 3) % _imgs.length],
      year: 2020 + (i % 5),
      rating: 6.5 + (i % 4),
      genres: ['درام', 'اکشن', 'کمدی', 'ترسناک'][i % 4] == 'درام'
          ? ['درام', 'اکشن']
          : [['اکشن', 'کمدی'], ['ترسناک', 'درام'], ['کمدی'], ['اکشن']][i % 4],
      tags: ['دوبله فارسی', 'زیرنویس فارسی', 'HD'],
      type: isSeries ? 'series' : 'movie',
      country: 'آمریکا',
      language: 'انگلیسی',
      hasPersianDub: true,
      hasPersianSub: true,
      duration: Duration(minutes: 90 + i * 5),
      seasons: isSeries
          ? [
              Season(
                number: 1,
                episodes: List.generate(
                  6,
                  (e) => Episode(
                    number: e + 1,
                    title: 'قسمت ${e + 1}',
                    duration: Duration(minutes: 40 + e),
                    streamUrl: _testStream,
                    subtitleUrl: _testSub,
                  ),
                ),
              )
            ]
          : const [],
      streamUrl: _testStream,
      subtitleUrl: _testSub,
    );
  });
}
__API__

# ============================================================
# 9) lib/services/history_service.dart
# ============================================================
cat > lib/services/history_service.dart << '__HISTORY__'
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String movieId;
  final String title;
  final String poster;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  HistoryEntry({
    required this.movieId,
    required this.title,
    required this.poster,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  double get progress =>
      duration.inSeconds == 0 ? 0 : position.inSeconds / duration.inSeconds;

  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'title': title,
        'poster': poster,
        'position': position.inSeconds,
        'duration': duration.inSeconds,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        movieId: j['movieId'],
        title: j['title'],
        poster: j['poster'],
        position: Duration(seconds: j['position']),
        duration: Duration(seconds: j['duration']),
        updatedAt: DateTime.parse(j['updatedAt']),
      );
}

class HistoryService {
  static const _key = 'watch_history_v1';

  Future<List<HistoryEntry>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final items = list.map(HistoryEntry.fromJson).toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<void> upsert(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await list();
    current.removeWhere((e) => e.movieId == entry.movieId);
    current.insert(0, entry);
    final trimmed = current.take(50).toList();
    await prefs.setString(
        _key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
__HISTORY__

# ============================================================
# 10) lib/providers/home_provider.dart
# ============================================================
cat > lib/providers/home_provider.dart << '__HOMEPROV__'
import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../services/api_service.dart';

class HomeProvider extends ChangeNotifier {
  final ApiService _api;
  HomeProvider(this._api);

  bool loading = true;
  String? error;
  List<Movie> catalog = [];

  List<Movie> get featured => catalog.take(3).toList();
  List<Movie> get latest => catalog.take(10).toList();
  List<Movie> get series =>
      catalog.where((m) => m.isSeries).toList();
  List<Movie> get movies =>
      catalog.where((m) => !m.isSeries).toList();
  List<Movie> get dubbed =>
      catalog.where((m) => m.hasPersianDub).toList();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      catalog = await _api.fetchCatalog();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Movie? byId(String id) {
    try {
      return catalog.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}
__HOMEPROV__

# ============================================================
# 11) lib/providers/download_provider.dart
# ============================================================
cat > lib/providers/download_provider.dart << '__DLPROV__'
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_task.dart';

class DownloadProvider extends ChangeNotifier {
  static const _key = 'downloads_v1';
  final List<DownloadItem> items = [];
  Timer? _scheduler;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      items
        ..clear()
        ..addAll(list.map(DownloadItem.fromJson));
    }
    // پل‌های دانلود بعد از راه‌اندازی
    _wireCallbacks();
    // شروع تایمر بررسی دانلودهای زمان‌بندی شده
    _scheduler?.cancel();
    _scheduler = Timer.periodic(
        const Duration(seconds: 30), (_) => _checkScheduled());
    _checkScheduled();
    notifyListeners();
  }

  void _wireCallbacks() {
    FileDownloader().updates.listen((update) {
      if (update is TaskProgressUpdate) {
        final idx = items.indexWhere((e) => e.id == update.taskId);
        if (idx >= 0) {
          items[idx].status = DownloadStatus.downloading;
          items[idx].progress = update.progress;
          notifyListeners();
        }
      } else if (update is TaskStatusUpdate) {
        final idx = items.indexWhere((e) => e.id == update.taskId);
        if (idx < 0) return;
        switch (update.status) {
          case TaskStatus.complete:
            items[idx].status = DownloadStatus.completed;
            items[idx].progress = 1.0;
            items[idx].localPath = update.task.filePath();
            break;
          case TaskStatus.failed:
            items[idx].status = DownloadStatus.failed;
            items[idx].error = update.exception?.description ?? 'خطا';
            break;
          case TaskStatus.canceled:
            items[idx].status = DownloadStatus.canceled;
            break;
          default:
            break;
        }
        _persist();
        notifyListeners();
      }
    });
  }

  Future<void> add({
    required String movieId,
    required String title,
    required String streamUrl,
    String? poster,
    DateTime? scheduledAt,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final item = DownloadItem(
      id: id,
      movieId: movieId,
      title: title,
      streamUrl: streamUrl,
      poster: poster,
      scheduledAt: scheduledAt,
      status: scheduledAt != null && scheduledAt.isAfter(DateTime.now())
          ? DownloadStatus.scheduled
          : DownloadStatus.pending,
    );
    items.insert(0, item);
    _persist();
    notifyListeners();
    if (item.status == DownloadStatus.pending) {
      await _startDownload(item);
    }
  }

  Future<void> _startDownload(DownloadItem item) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName =
          '${item.title.replaceAll(RegExp(r'[^\w\u0600-\u06FF]+'), '_')}.mp4';
      final task = DownloadTask(
        taskId: item.id,
        url: item.streamUrl,
        filename: safeName,
        directory: dir.path,
        updates: Updates.statusAndProgress,
        retries: 3,
      );
      item.status = DownloadStatus.downloading;
      notifyListeners();
      await FileDownloader().enqueue(task);
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _checkScheduled() async {
    final now = DateTime.now();
    for (final item in items) {
      if (item.status == DownloadStatus.scheduled &&
          item.scheduledAt != null &&
          !item.scheduledAt!.isAfter(now)) {
        await _startDownload(item);
      }
    }
  }

  Future<void> cancel(String id) async {
    await FileDownloader().cancelTaskWithId(id);
    final idx = items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      items[idx].status = DownloadStatus.canceled;
      _persist();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    _persist();
    notifyListeners();
  }

  Future<void> openItem(DownloadItem item) async {
    final path = item.localPath;
    if (path != null && await File(path).exists()) {
      if (Platform.isAndroid) {
        // برای سادگی: از video_player استفاده می‌کنیم اما مسیر را می‌دهیم
        // TODO: open via intent یا نمایش در صفحه پلیر داخلی
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
__DLPROV__

# ============================================================
# 12) lib/widgets/focusable_card.dart
# ============================================================
cat > lib/widgets/focusable_card.dart << '__FCARD__'
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/movie.dart';

class FocusableMovieCard extends StatefulWidget {
  final Movie movie;
  final VoidCallback onTap;
  final double width;
  const FocusableMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.width = 160,
  });

  @override
  State<FocusableMovieCard> createState() => _FocusableMovieCardState();
}

class _FocusableMovieCardState extends State<FocusableMovieCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.width,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focused ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 20,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.movie.poster,
                    fit: BoxFit.cover,
                    height: widget.width * 1.45,
                    placeholder: (_, __) => Container(
                      color: AppTheme.surface,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surface,
                      child: const Icon(Icons.movie, color: Colors.white24),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.85)
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.movie.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                widget.movie.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              if (widget.movie.hasPersianDub)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('دوبله',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 9)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
__FCARD__

# ============================================================
# 13) lib/widgets/movie_row.dart
# ============================================================
cat > lib/widgets/movie_row.dart << '__MROW__'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/movie.dart';
import 'focusable_card.dart';

class MovieRow extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  const MovieRow({super.key, required this.title, required this.movies});

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/search'),
                child: const Text('همه',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 270,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: movies.length,
            itemBuilder: (_, i) => FocusableMovieCard(
              movie: movies[i],
              onTap: () => context.go('/detail/${movies[i].id}'),
            ),
          ),
        ),
      ],
    );
  }
}
__MROW__

# ============================================================
# 14) lib/widgets/hero_banner.dart
# ============================================================
cat > lib/widgets/hero_banner.dart << '__HERO__'
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/movie.dart';

class HeroBanner extends StatelessWidget {
  final Movie movie;
  const HeroBanner({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: movie.backdrop ?? movie.poster,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                Container(color: AppTheme.surface),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppTheme.bg],
                stops: [0.3, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(' ${movie.rating.toStringAsFixed(1)}  ',
                        style: const TextStyle(color: Colors.white)),
                    Text('${movie.year}  ',
                        style: const TextStyle(color: Colors.white70)),
                    Text(movie.isSeries ? 'سریال' : 'فیلم',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  movie.overview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        context.go(
                          '/player?url=${Uri.encodeComponent(movie.streamUrl)}'
                          '&title=${Uri.encodeComponent(movie.title)}'
                          '${movie.subtitleUrl != null ? '&sub=${Uri.encodeComponent(movie.subtitleUrl!)}' : ''}',
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('تماشا'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/detail/${movie.id}'),
                      icon: const Icon(Icons.info_outline,
                          color: Colors.white),
                      label: const Text('جزئیات',
                          style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
__HERO__

# ============================================================
# 15) lib/widgets/bottom_nav.dart
# ============================================================
cat > lib/widgets/bottom_nav.dart << '__BNAV__'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/search');
            break;
          case 2:
            context.go('/downloads');
            break;
          case 3:
            context.go('/profile');
            break;
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'خانه'),
        NavigationDestination(icon: Icon(Icons.search), label: 'جستجو'),
        NavigationDestination(icon: Icon(Icons.download), label: 'دانلود'),
        NavigationDestination(icon: Icon(Icons.person), label: 'پروفایل'),
      ],
    );
  }
}
__BNAV__

# ============================================================
# 16) lib/pages/home_page.dart
# ============================================================
cat > lib/pages/home_page.dart << '__HOME__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/hero_banner.dart';
import '../widgets/movie_row.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final hp = context.watch<HomeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamApp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: hp.loading
          ? const Center(child: CircularProgressIndicator())
          : hp.error != null
              ? Center(child: Text('خطا: ${hp.error}'))
              : ListView(
                  children: [
                    if (hp.featured.isNotEmpty)
                      HeroBanner(movie: hp.featured.first),
                    MovieRow(title: 'جدیدترین‌ها', movies: hp.latest),
                    MovieRow(title: 'سریال‌ها', movies: hp.series),
                    MovieRow(title: 'فیلم‌ها', movies: hp.movies),
                    MovieRow(title: 'دوبله فارسی', movies: hp.dubbed),
                    const SizedBox(height: 20),
                  ],
                ),
    );
  }
}
__HOME__

# ============================================================
# 17) lib/pages/search_page.dart
# ============================================================
cat > lib/pages/search_page.dart << '__SEARCH__'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/focusable_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<Movie> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final res = await context.read<ApiService>().search(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جستجو')),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'نام فیلم یا سریال...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _results = []);
                  },
                ),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text('نتیجه‌ای یافت نشد',
                        style: TextStyle(color: Colors.white54)))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => FocusableMovieCard(
                      movie: _results[i],
                      onTap: () => context.go('/detail/${_results[i].id}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
__SEARCH__

# ============================================================
# 18) lib/pages/detail_page.dart
# ============================================================
cat > lib/pages/detail_page.dart << '__DETAIL__'
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/movie.dart';
import '../providers/download_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/movie_row.dart';

class DetailPage extends StatelessWidget {
  final String movieId;
  const DetailPage({super.key, required this.movieId});

  @override
  Widget build(BuildContext context) {
    final hp = context.watch<HomeProvider>();
    final movie = hp.byId(movieId);
    if (movie == null) {
      return const Scaffold(body: Center(child: Text('یافت نشد')));
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.bg,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: movie.backdrop ?? movie.poster,
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppTheme.bg],
                        stops: [0.4, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(' ${movie.rating.toStringAsFixed(1)}  '),
                      Text('${movie.year}  ',
                          style: const TextStyle(color: Colors.white70)),
                      Text(movie.country ?? '',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: movie.tags
                        .map((t) => Chip(
                              label: Text(t,
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(movie.overview,
                      style: const TextStyle(
                          color: Colors.white70, height: 1.6)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final ep = movie.isSeries &&
                                    movie.seasons.isNotEmpty &&
                                    movie.seasons.first.episodes.isNotEmpty
                                ? movie.seasons.first.episodes.first
                                : null;
                            final url = ep?.streamUrl ?? movie.streamUrl;
                            final sub = ep?.subtitleUrl ?? movie.subtitleUrl;
                            context.go(
                              '/player?url=${Uri.encodeComponent(url)}'
                              '&title=${Uri.encodeComponent(movie.title)}'
                              '${sub != null ? '&sub=${Uri.encodeComponent(sub)}' : ''}',
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(movie.isSeries ? 'پخش قسمت 1' : 'پخش'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () {
                          context.read<DownloadProvider>().add(
                                movieId: movie.id,
                                title: movie.title,
                                streamUrl: movie.streamUrl,
                                poster: movie.poster,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('به لیست دانلود اضافه شد')),
                          );
                        },
                        icon: const Icon(Icons.download),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked == null || !context.mounted) return;
                          final now = DateTime.now();
                          var at = DateTime(now.year, now.month, now.day,
                              picked.hour, picked.minute);
                          if (at.isBefore(now)) {
                            at = at.add(const Duration(days: 1));
                          }
                          if (!context.mounted) return;
                          context.read<DownloadProvider>().add(
                                movieId: movie.id,
                                title: movie.title,
                                streamUrl: movie.streamUrl,
                                poster: movie.poster,
                                scheduledAt: at,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'دانلود برای ${picked.format(context)} زمان‌بندی شد')),
                          );
                        },
                        icon: const Icon(Icons.schedule),
                      ),
                    ],
                  ),
                  if (movie.isSeries && movie.seasons.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('قسمت‌ها',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...movie.seasons.first.episodes.map((ep) => Card(
                          color: AppTheme.surface,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              child: Text('${ep.number}',
                                  style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(ep.title),
                            subtitle: Text(
                                '${ep.duration.inMinutes} دقیقه',
                                style:
                                    const TextStyle(color: Colors.white54)),
                            trailing:
                                const Icon(Icons.play_circle_outline),
                            onTap: () {
                              context.go(
                                '/player?url=${Uri.encodeComponent(ep.streamUrl)}'
                                '&title=${Uri.encodeComponent('${movie.title} - ${ep.title}')}'
                                '${ep.subtitleUrl != null ? '&sub=${Uri.encodeComponent(ep.subtitleUrl!)}' : ''}',
                              );
                            },
                          ),
                        )),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<Movie>>(
              future: context
                  .read<HomeProvider>()
                  .catalog
                  .where((m) =>
                      m.id != movie.id &&
                      m.genres.any((g) => movie.genres.contains(g)))
                  .toList()
                  .let(Future.value),
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) return const SizedBox.shrink();
                return MovieRow(title: 'مشابه‌ها', movies: list.take(10).toList());
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) op) => op(this);
}
__DETAIL__

# ============================================================
# 19) lib/pages/player_page.dart
# ============================================================
cat > lib/pages/player_page.dart << '__PLAYER__'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../services/history_service.dart';

class PlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? subtitleUrl;
  const PlayerPage({
    super.key,
    required this.videoUrl,
    required this.title,
    this.subtitleUrl,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _subOn = true;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player = Player();
    _controller = VideoController(_player);
    _init();
  }

  Future<void> _init() async {
    await _player.open(Media(widget.videoUrl));
    if (widget.subtitleUrl != null) {
      await _player.setSubtitleTrack(
        SubtitleTrack.uri(widget.subtitleUrl!, title: 'فارسی'),
      );
    }
    _player.stream.position.listen((pos) {
      // ذخیره تاریخچه هر 15 ثانیه
      if (pos.inSeconds % 15 == 0) _saveHistory(pos);
    });
  }

  Future<void> _saveHistory(Duration pos) async {
    final dur = _player.state.duration;
    if (dur.inSeconds == 0) return;
    final hp = context.read<HomeProvider>();
    final match = hp.catalog.firstWhere(
      (m) => widget.title.startsWith(m.title),
      orElse: () => hp.catalog.isEmpty ? throw Exception() : hp.catalog.first,
    );
    if (hp.catalog.isEmpty) return;
    await HistoryService().upsert(HistoryEntry(
      movieId: match.id,
      title: match.title,
      poster: match.poster,
      position: pos,
      duration: dur,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () {
            _player.playOrPause();
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            _player.seek(_player.state.position + const Duration(seconds: 10));
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            _player.seek(_player.state.position - const Duration(seconds: 10));
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            Navigator.pop(context);
          },
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(controller: _controller),
                  ),
                ),
                if (_controlsVisible) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppBar(
                      backgroundColor: Colors.black54,
                      title: Text(widget.title),
                      actions: [
                        IconButton(
                          icon: Icon(
                              _subOn ? Icons.subtitles : Icons.subtitles_off),
                          onPressed: () async {
                            setState(() => _subOn = !_subOn);
                            if (!_subOn) {
                              await _player.setSubtitleTrack(
                                  SubtitleTrack.no());
                            } else if (widget.subtitleUrl != null) {
                              await _player.setSubtitleTrack(
                                SubtitleTrack.uri(widget.subtitleUrl!,
                                    title: 'فارسی'),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.speed),
                          onPressed: () {
                            _player.setRate(
                                _player.state.rate == 1.0 ? 1.5 : 1.0);
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          StreamBuilder<Duration>(
                            stream: _player.stream.position,
                            builder: (_, posSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final dur = _player.state.duration;
                              final max = dur.inMilliseconds.toDouble();
                              final val = pos.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, max);
                              return Expanded(
                                child: Slider(
                                  value: max > 0 ? val : 0,
                                  max: max > 0 ? max : 1,
                                  onChanged: (v) => _player.seek(
                                      Duration(milliseconds: v.round())),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
__PLAYER__

# ============================================================
# 20) lib/pages/downloads_page.dart
# ============================================================
cat > lib/pages/downloads_page.dart << '__DOWNLOADS__'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../widgets/bottom_nav.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DownloadProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('دانلودها')),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: dp.items.isEmpty
          ? const Center(
              child: Text('لیست دانلود خالی است',
                  style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: dp.items.length,
              itemBuilder: (_, i) {
                final item = dp.items[i];
                return Card(
                  color: const Color(0xFF161B22),
                  child: ListTile(
                    leading: const Icon(Icons.movie, color: Colors.white54),
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusLabel(item),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                        if (item.status == DownloadStatus.downloading ||
                            item.status == DownloadStatus.scheduled)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(
                                value: item.status == DownloadStatus.downloading
                                    ? item.progress
                                    : null),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'cancel') dp.cancel(item.id);
                        if (v == 'remove') dp.remove(item.id);
                      },
                      itemBuilder: (_) => [
                        if (item.status == DownloadStatus.downloading ||
                            item.status == DownloadStatus.scheduled)
                          const PopupMenuItem(
                              value: 'cancel', child: Text('لغو')),
                        const PopupMenuItem(
                            value: 'remove', child: Text('حذف')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _statusLabel(DownloadItem item) {
    switch (item.status) {
      case DownloadStatus.pending:
        return 'در انتظار';
      case DownloadStatus.scheduled:
        return 'زمان‌بندی شده: ${item.scheduledAt}';
      case DownloadStatus.downloading:
        return 'در حال دانلود ${(item.progress * 100).toStringAsFixed(0)}%';
      case DownloadStatus.completed:
        return 'تکمیل شده ✓';
      case DownloadStatus.failed:
        return 'خطا: ${item.error ?? ""}';
      case DownloadStatus.canceled:
        return 'لغو شده';
    }
  }
}
__DOWNLOADS__

# ============================================================
# 21) lib/pages/profile_page.dart
# ============================================================
cat > lib/pages/profile_page.dart << '__PROFILE__'
import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../widgets/bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await HistoryService().list();
    if (!mounted) return;
    setState(() => _history = h);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل')),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFFE50914),
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('کاربر مهمان',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('بدون ورود',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text('تاریخچه تماشا',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('تاریخچه خالی است',
                  style: TextStyle(color: Colors.white54)),
            )
          else
            ..._history.map((h) => ListTile(
                  leading: Icon(Icons.movie, color: Colors.white54),
                  title: Text(h.title),
                  subtitle: LinearProgressIndicator(value: h.progress),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await HistoryService().clear();
                      _load();
                    },
                  ),
                )),
        ],
      ),
    );
  }
}
__PROFILE__

# ============================================================
# 22) AndroidManifest.xml
# ============================================================
cat > android/app/src/main/AndroidManifest.xml << '__MANIFEST__'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />

    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />

    <application
        android:label="StreamApp"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:banner="@drawable/tv_banner"
        android:usesCleartextTraffic="true">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
                <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
__MANIFEST__

# ============================================================
# 23) tv_banner.xml
# ============================================================
cat > android/app/src/main/res/drawable/tv_banner.xml << '__TVBANNER__'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#E50914"/>
        </shape>
    </item>
    <item android:gravity="center">
        <shape android:shape="rectangle">
            <size android:width="1dp" android:height="1dp"/>
            <solid android:color="#FFFFFF"/>
        </shape>
    </item>
</layer-list>
__TVBANNER__

# ============================================================
# 24) minSdk fix در build.gradle
# ============================================================
GRADLE_FILE="android/app/build.gradle"
if [ -f "$GRADLE_FILE" ]; then
  sed -i 's/minSdkVersion.*/minSdkVersion 21/' "$GRADLE_FILE" || true
fi
GRADLE_KTS="android/app/build.gradle.kts"
if [ -f "$GRADLE_KTS" ]; then
  sed -i 's/minSdk = .*/minSdk = 21/' "$GRADLE_KTS" || true
fi

# ============================================================
# 25) README.md
# ============================================================
cat > README.md << '__README__'
# StreamApp – اپلیکیشن کامل استریم فیلم و سریال

اپلیکیشن Flutter با پشتیبانی از **Android Mobile / Android TV / Android Box / iOS / Web**.
UI بهینه‌شده برای D-Pad و ریموت TV، پلیر HLS، زیرنویس فارسی، دانلودر پس‌زمینه، دانلود زمان‌بندی‌شده، تاریخچه تماشا و پیشنهاد هوشمند.

## اجرا

```bash
flutter pub get
flutter run
