import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../main.dart' show CommunityPost, MockData, appStateProvider;
import '../../services/comments_service.dart';
import '../auth/auth_guard.dart';
import '../comments/comments_section.dart';

/// Детальная страница поста в Юрте сообщества: автор, время, тип, текст,
/// связанная местность, лайк и блок комментариев.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(appStateProvider).posts;
    final CommunityPost? post = posts.cast<CommunityPost?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Пост')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Пост был удалён.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final place = post.placeId == null
        ? null
        : MockData.placeById(post.placeId!);
    return Scaffold(
      appBar: AppBar(title: const Text('Пост')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: post.color,
                        child: Text(
                          post.userName.isEmpty
                              ? '?'
                              : post.userName.characters.first
                                  .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm')
                                  .format(post.timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Chip(label: Text(post.type.label)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (place != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => context.push('/place/${place.id}'),
                      icon: const Icon(Icons.place),
                      label: Text(place.title),
                    ),
                  ],
                  const Divider(),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          if (await AuthGuard.requireOrPrompt(
                            context,
                            action: 'поставить лайк',
                          )) {
                            ref.read(appStateProvider).toggleLike(post.id);
                          }
                        },
                        icon: Icon(
                          post.liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: post.liked
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                        label: Text('${post.likeCount}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          CommentsSection(
            targetType: CommentTarget.post,
            targetId: post.id,
          ),
        ],
      ),
    );
  }
}
