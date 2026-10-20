import 'package:flutter/material.dart';
import '../../../l10n/genesis_localizations.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../state/mini_phone_store.dart';
import '../shared/mini_phone_ui.dart';
import '../shared/mini_phone_controls.dart';
import '../../../components/common/genesis_image_viewer_overlay.dart';
import '../../../ui/components/genesis_list_image.dart';
import 'mini_phone_post_thumbnail.dart';

class MiniPhonePostContent extends StatelessWidget {
  const MiniPhonePostContent({
    super.key,
    required this.phone,
    required this.onOpenPost,
    required this.id,
    required this.author,
    required this.text,
    required this.image,
    required this.time,
    required this.likeCount,
    required this.isLiked,
    this.commentCount,
    this.previews = const [],
    this.detail = false,
  });
  final MiniPhoneStore phone;
  final ValueChanged<int> onOpenPost;
  final int id, likeCount;
  final int? commentCount;
  final PhonePerson author;
  final String text, image, time;
  final bool isLiked, detail;
  final List<PhoneComment> previews;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: miniPageInset,
      vertical: 12,
    ),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: miniDivider, width: .5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        miniPhonePersonAvatar(author, 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: miniStyle(14, FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Text(
                      time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: miniStyle(12, FontWeight.w400, miniSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (text.isNotEmpty) Text(text, style: miniStyle(14)),
              if (image.isNotEmpty)
                if (detail)
                  _liveImage(context, image, maxWidth: 170, maxHeight: 180)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MiniPhonePostThumbnail(
                      imageUrl: image,
                      onTap: (preview, source) => showGenesisImageViewer(
                        context,
                        imageUrls: [image],
                        previewImageProviders: [preview],
                        source: source,
                      ),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    miniPhonePostAction(
                      'messages',
                      'Comments',
                      commentCount,
                      () => onOpenPost(id),
                    ),
                    const SizedBox(width: 20),
                    miniPhonePostAction(
                      'heart',
                      'Like',
                      likeCount,
                      () => phone.setLiked(
                        id,
                        !(phone.likeTargets[id] ?? isLiked),
                        source: detail ? 'comments' : 'posts',
                      ),
                      selected: isLiked,
                    ),
                  ],
                ),
              ),
              if (!detail)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onOpenPost(id),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 6),
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in previews.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${c.author.name}  ',
                                    style: miniStyle(12, FontWeight.w600),
                                  ),
                                  if (c.replyToCharId != null)
                                    TextSpan(
                                      text:
                                          '@${phone.person(c.replyToCharId!).name} ',
                                      style: miniStyle(
                                        12,
                                        FontWeight.w600,
                                        miniPink,
                                      ),
                                    ),
                                  TextSpan(
                                    text: c.text,
                                    style: miniStyle(
                                      12,
                                      FontWeight.w400,
                                      miniSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (previews.length > 3) ...[
                          const SizedBox(height: 3),
                          Text(
                            context.l10n.miniPhoneViewAllComments,
                            style: miniStyle(12, FontWeight.w400, miniPink),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _liveImage(
    BuildContext context,
    String url, {
    double maxHeight = 300,
    double maxWidth = 290,
  }) => GestureDetector(
    onTap: () => showGenesisImageViewer(context, imageUrls: [url]),
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
          child: GenesisListImage(
            imageUrl: url,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    ),
  );
}
