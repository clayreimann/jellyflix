import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/providers/database_provider.dart';
import 'package:tentacle/tentacle.dart';
import 'package:transparent_image/transparent_image.dart';

/// Image cache for server artwork. Much larger and longer-lived than the
/// default (200 images, 30 days) so posters stay available offline.
class JfxImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'jellyflixImageCache';
  static final JfxImageCacheManager instance = JfxImageCacheManager._();

  JfxImageCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 365),
          maxNrOfCacheObjects: 20000,
        ));

  /// Downloads the given images into the cache if they aren't there yet.
  static Future<void> prefetch(
      Iterable<String> urls, Map<String, String> headers) async {
    for (var url in urls) {
      try {
        if (await instance.getFileFromCache(url) != null) continue;
        await instance.downloadFile(url, authHeaders: headers);
      } catch (_) {
        // missing artwork is fine
      }
    }
  }
}

class JellyfinImage extends HookConsumerWidget {
  final String id;
  final ImageType type;
  final String? blurHash;
  final int? cacheHeight;
  final BorderRadius? borderRadius;

  const JellyfinImage(
      {super.key,
      required this.id,
      required this.type,
      this.blurHash,
      this.cacheHeight,
      this.borderRadius});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While loading, draw one plain rounded block that the skeleton paints
    // as a bone. Loading the placeholder's image or blur hash here made
    // the block change look (light, then a dark blur) as it decoded.
    if (Skeletonizer.maybeOf(context)?.enabled ?? false) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius ?? BorderRadius.circular(10.0),
        ),
      );
    }
    String url = ref.read(apiProvider).getImageUrl(id, type);
    bool disableImageCaching =
        ref.read(databaseProvider("settings")).get("disableImageCaching") ??
            false;
    if (disableImageCaching == true) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(10.0),
        // BlurHash has an issue the generates bad state in some cases
        // https://github.com/fluttercommunity/flutter_blurhash/issues/40
        child: BlurHash(
          hash: blurHash ?? "L5H2EC=PM+yV0g-mq.wG9GofR*of",
          imageFit: BoxFit.cover,
          httpHeaders: ref.read(apiProvider).headers,
          image: url,
          errorBuilder: (context, error, stackTrace) {
            return Image.memory(kTransparentImage, fit: BoxFit.cover);
          },
        ),
      );
    }

    return CachedNetworkImage(
      cacheManager: JfxImageCacheManager.instance,
      width: double.infinity,
      imageUrl: url,
      httpHeaders: ref.read(apiProvider).headers,
      fit: BoxFit.cover,
      memCacheHeight: cacheHeight,
      maxHeightDiskCache: cacheHeight,
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(10.0),
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: blurHash == null
          ? null
          : (context, url) {
              return ClipRRect(
                borderRadius: borderRadius ?? BorderRadius.circular(10.0),
                child: BlurHash(
                  hash: blurHash!,
                  imageFit: BoxFit.cover,
                ),
              );
            },
      errorWidget: (context, url, error) {
        return const SizedBox();
      },
      errorListener: (value) {
        //! Errors can't be caught right now
        //! There is a pr to fix this: https://github.com/Baseflow/flutter_cached_network_image/pull/777
      },
    );
  }
}
