import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../theme/app_theme.dart';
import 'auth_page.dart';

/// Үйл ажиллагааны дэлгэрэнгүй дэх сэтгэгдлийн хэсэг.
///
/// Post шиг: зураг хавсаргана, таалагдсан (like) дарна, хариу (reply) бичнэ.
class CommentsSection extends StatefulWidget {
  const CommentsSection({
    super.key,
    required this.eventId,
    required this.api,
    required this.service,
  });

  final String eventId;
  final AuthService api;
  final EventService service;

  @override
  State<CommentsSection> createState() => CommentsSectionState();
}

class CommentsSectionState extends State<CommentsSection> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _replyController = TextEditingController();

  List<EventComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  Uint8List? _imageBytes;
  String _imageName = '';

  int? _replyTo;
  Uint8List? _replyImageBytes;
  String _replyImageName = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _replyController.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _total => _comments.fold<int>(
    0,
    (sum, comment) => sum + 1 + comment.replies.length,
  );

  // ---------------------------------------------------------------- ачаалах

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await widget.service.comments(widget.eventId);
      if (mounted) setState(() => _comments = rows);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Сэтгэгдлийг уншиж чадсангүй.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ------------------------------------------------------------------ туслах

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureSignedIn() async {
    if (widget.api.currentSession != null) return true;

    await Navigator.of(context).push<AuthSession>(
      MaterialPageRoute(builder: (_) => AuthPage(authService: widget.api)),
    );

    return mounted && widget.api.currentSession != null;
  }

  Future<({Uint8List bytes, String name})?> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      if (bytes.length > EventService.maxImageBytes) {
        _toast('Зургийн хэмжээ 5MB-аас ихгүй байх ёстой.');
        return null;
      }
      return (bytes: bytes, name: picked.name);
    } catch (_) {
      _toast('Зураг сонгоход алдаа гарлаа.');
      return null;
    }
  }

  /// Жагсаалт доторх нэг сэтгэгдлийг (хариу ч байж болно) солино.
  void _replaceComment(EventComment updated) {
    setState(() {
      _comments = _comments.map((comment) {
        if (comment.id == updated.id) {
          return updated.copyWith(replies: comment.replies);
        }
        if (comment.replies.any((reply) => reply.id == updated.id)) {
          return comment.copyWith(
            replies: comment.replies
                .map((reply) => reply.id == updated.id ? updated : reply)
                .toList(),
          );
        }
        return comment;
      }).toList();
    });
  }

  void _removeComment(int id) {
    setState(() {
      _comments = _comments
          .where((comment) => comment.id != id)
          .map(
            (comment) => comment.replies.any((reply) => reply.id == id)
                ? comment.copyWith(
                    replies: comment.replies
                        .where((reply) => reply.id != id)
                        .toList(),
                  )
                : comment,
          )
          .toList();
    });
  }

  // ----------------------------------------------------------------- илгээх

  Future<void> _send({int? parentId}) async {
    if (_sending) return;

    final reply = parentId != null;
    final controller = reply ? _replyController : _controller;
    final bytes = reply ? _replyImageBytes : _imageBytes;
    final name = reply ? _replyImageName : _imageName;
    final text = controller.text.trim();

    if (text.isEmpty && bytes == null) {
      _toast('Сэтгэгдэл эсвэл зураг оруулна уу.');
      return;
    }

    if (!await _ensureSignedIn()) return;

    setState(() => _sending = true);

    try {
      String? imageUrl;
      if (bytes != null) {
        imageUrl = await widget.service.uploadImage(
          bytes,
          name.isEmpty ? 'comment.jpg' : name,
        );
      }

      final created = await widget.service.addComment(
        widget.eventId,
        content: text,
        imageUrl: imageUrl,
        parentId: parentId,
      );

      if (!mounted) return;

      setState(() {
        controller.clear();
        if (reply) {
          _replyImageBytes = null;
          _replyImageName = '';
          _replyTo = null;
          _comments = _comments
              .map(
                (comment) => comment.id == parentId
                    ? comment.copyWith(
                        replies: [...comment.replies, created],
                      )
                    : comment,
              )
              .toList();
        } else {
          _imageBytes = null;
          _imageName = '';
          _comments = [created, ..._comments];
        }
      });

      if (!reply) _focus.unfocus();
      _toast(reply ? 'Хариугаа үлдээлээ.' : 'Сэтгэгдлээ үлдээлээ. Баярлалаа!');
    } on AuthException catch (error) {
      _toast(error.message);
      if (error.statusCode == 401) await _ensureSignedIn();
    } catch (_) {
      _toast('Сэтгэгдэл илгээхэд алдаа гарлаа.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(EventComment comment) async {
    if (!await _ensureSignedIn()) return;

    // Шуурхай хариу үйлдэл: сервер хариулахаас өмнө дэлгэц дээр өөрчилнө.
    _replaceComment(
      comment.copyWith(
        likedByMe: !comment.likedByMe,
        likeCount: comment.likeCount + (comment.likedByMe ? -1 : 1),
      ),
    );

    try {
      final updated = await widget.service.likeComment(
        widget.eventId,
        comment.id,
      );
      if (mounted) _replaceComment(updated);
    } on AuthException catch (error) {
      if (mounted) {
        _replaceComment(comment); // буцаана
        _toast(error.message);
      }
    }
  }

  Future<void> _delete(EventComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Сэтгэгдлийг устгах уу?'),
        content: Text(
          comment.isReply
              ? 'Устгасан хариуг сэргээх боломжгүй.'
              : 'Устгасан сэтгэгдлийг болон түүний хариунуудыг сэргээх боломжгүй.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: brandDanger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.service.deleteComment(widget.eventId, comment.id);
      if (mounted) _removeComment(comment.id);
    } on AuthException catch (error) {
      _toast(error.message);
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return BrandGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 16),
          _composer(),
          const SizedBox(height: 20),
          _list(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.forum_rounded, color: brandInk, size: 20),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Text(
            'Сэтгэгдэл',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: brandInk,
            ),
          ),
        ),
        if (_total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '$_total',
              style: const TextStyle(
                color: brandInk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  /// Үндсэн бичих талбар.
  Widget _composer() {
    final signedIn = widget.api.currentSession != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: brandGradientSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            controller: _controller,
            focus: _focus,
            hint: signedIn
                ? 'Энэ үйл ажиллагааны талаар сэтгэгдлээ бичнэ үү...'
                : 'Сэтгэгдэл бичихийн тулд нэвтэрнэ үү.',
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 10),
            _attachmentPreview(
              _imageBytes!,
              () => setState(() {
                _imageBytes = null;
                _imageName = '';
              }),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _attachButton(
                onTap: _sending
                    ? null
                    : () async {
                        final picked = await _pickImage();
                        if (picked != null && mounted) {
                          setState(() {
                            _imageBytes = picked.bytes;
                            _imageName = picked.name;
                          });
                        }
                      },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BrandGradientButton(
                  height: 46,
                  radius: 15,
                  busy: _sending && _replyTo == null,
                  onPressed: _sending ? null : () => _send(),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: signedIn ? 'Илгээх' : 'Нэвтэрч бичих',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    FocusNode? focus,
    bool compact = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focus,
      minLines: compact ? 1 : 2,
      maxLines: 5,
      maxLength: compact ? null : EventService.maxCommentLength,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 14, height: 1.5, color: brandInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: brandInkSoft, fontSize: 13),
        counterStyle: const TextStyle(color: brandInkSoft, fontSize: 11),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandAquaDeep, width: 1.6),
        ),
      ),
    );
  }

  Widget _attachButton({VoidCallback? onTap}) {
    return Tooltip(
      message: 'Зураг хавсаргах',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: brandBorder),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: brandAquaDeep,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentPreview(Uint8List bytes, VoidCallback onRemove) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 18, color: brandInk),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list() {
    if (_loading && _comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: brandAquaDeep,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: brandInkSoft, fontSize: 13),
          ),
          TextButton(onPressed: load, child: const Text('Дахин оролдох')),
        ],
      );
    }

    if (_comments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          color: brandYellowSoft.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: brandYellowDeep,
              size: 32,
            ),
            SizedBox(height: 10),
            Text(
              'Одоогоор сэтгэгдэл алга.',
              style: TextStyle(color: brandInk, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'Хамгийн эхний сэтгэгдлийг та үлдээгээрэй!',
              style: TextStyle(color: brandInkSoft, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final comment in _comments) _commentCard(comment),
      ],
    );
  }

  Widget _commentCard(EventComment comment) {
    final replying = _replyTo == comment.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: brandCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: brandBorder),
        boxShadow: brandShadow(opacity: 0.07, blur: 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentBody(comment: comment, onDelete: () => _delete(comment)),

          const SizedBox(height: 10),

          Row(
            children: [
              _LikeButton(
                comment: comment,
                onTap: () => _toggleLike(comment),
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.reply_rounded,
                label: comment.replies.isEmpty
                    ? 'Хариу бичих'
                    : 'Хариу (${comment.replies.length})',
                active: replying,
                onTap: () => setState(() {
                  _replyTo = replying ? null : comment.id;
                  _replyController.clear();
                  _replyImageBytes = null;
                  _replyImageName = '';
                }),
              ),
            ],
          ),

          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: brandBorder, width: 2.5),
                ),
              ),
              child: Column(
                children: [
                  for (final reply in comment.replies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CommentBody(
                            comment: reply,
                            compact: true,
                            onDelete: () => _delete(reply),
                          ),
                          const SizedBox(height: 7),
                          _LikeButton(
                            comment: reply,
                            onTap: () => _toggleLike(reply),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (replying) ...[
            const SizedBox(height: 10),
            _replyComposer(comment),
          ],
        ],
      ),
    );
  }

  Widget _replyComposer(EventComment parent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brandAquaSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${parent.authorName}-д хариулж байна',
            style: const TextStyle(
              color: brandAquaDeep,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _field(
            controller: _replyController,
            hint: 'Хариугаа бичнэ үү...',
            compact: true,
          ),
          if (_replyImageBytes != null) ...[
            const SizedBox(height: 9),
            _attachmentPreview(
              _replyImageBytes!,
              () => setState(() {
                _replyImageBytes = null;
                _replyImageName = '';
              }),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              _attachButton(
                onTap: _sending
                    ? null
                    : () async {
                        final picked = await _pickImage();
                        if (picked != null && mounted) {
                          setState(() {
                            _replyImageBytes = picked.bytes;
                            _replyImageName = picked.name;
                          });
                        }
                      },
              ),
              const SizedBox(width: 9),
              Expanded(
                child: BrandGradientButton(
                  height: 44,
                  radius: 14,
                  busy: _sending && _replyTo == parent.id,
                  onPressed: _sending ? null : () => _send(parentId: parent.id),
                  icon: const Icon(Icons.send_rounded, size: 17),
                  label: 'Хариу илгээх',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- дэд widget-ууд

/// Нэг сэтгэгдлийн толгой, текст, зураг.
class _CommentBody extends StatelessWidget {
  const _CommentBody({
    required this.comment,
    required this.onDelete,
    this.compact = false,
  });

  final EventComment comment;
  final VoidCallback onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 42.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: brandGradient,
                shape: BoxShape.circle,
              ),
              child: Text(
                comment.initial,
                style: TextStyle(
                  color: brandInk,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 13 : 16,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: brandInk,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 12.5 : 14,
                          ),
                        ),
                      ),
                      if (comment.isMine) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: brandYellowSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Та',
                            style: TextStyle(
                              color: Color(0xFF8A6200),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        comment.timeLabel,
                        style: const TextStyle(
                          color: brandInkSoft,
                          fontSize: 11,
                        ),
                      ),
                      if (comment.isMine)
                        IconButton(
                          tooltip: 'Устгах',
                          onPressed: onDelete,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: brandInkSoft,
                          ),
                        ),
                    ],
                  ),
                  if (comment.content.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      comment.content,
                      style: TextStyle(
                        color: const Color(0xFF2E6472),
                        fontSize: compact ? 13 : 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (comment.hasImage) ...[
          const SizedBox(height: 11),
          Padding(
            padding: EdgeInsets.only(left: size + 11),
            child: _CommentImage(url: comment.imageUrl!),
          ),
        ],
      ],
    );
  }
}

/// Сэтгэгдэлд хавсаргасан зураг. Дарвал томоор нээнэ.
class _CommentImage extends StatelessWidget {
  const _CommentImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 190,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              height: 190,
              color: brandAquaSoft,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: brandAquaDeep,
                ),
              ),
            ),
      errorBuilder: (context, error, stackTrace) => Container(
        height: 110,
        color: brandAquaSoft,
        alignment: Alignment.center,
        child: const Text(
          'Зургийг уншиж чадсангүй.',
          style: TextStyle(color: brandInkSoft, fontSize: 12),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(18),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.close_rounded, color: brandInk),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: image,
      ),
    );
  }
}

/// Таалагдсан (like) товч.
class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.comment, required this.onTap});

  final EventComment comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final liked = comment.likedByMe;

    return _ActionChip(
      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      label: comment.likeCount == 0 ? 'Таалагдлаа' : '${comment.likeCount}',
      active: liked,
      activeColor: brandDanger,
      onTap: onTap,
    );
  }
}

/// Сэтгэгдлийн доорх жижиг үйлдлийн товч.
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = brandAquaDeep,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : brandInkSoft;

    return Material(
      color: active
          ? activeColor.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.35)
                  : brandBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
