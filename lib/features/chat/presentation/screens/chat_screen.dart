import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/home/presentation/controllers/home_providers.dart';
import '../../../../features/employees/presentation/controllers/employee_providers.dart';
import '../../data/models/chat_model.dart';
import '../controllers/chat_providers.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ChatScreen — used as a tab body inside ProjectDetailsScreen
// ══════════════════════════════════════════════════════════════════════════════

class ChatScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;
  final String officeId;

  const ChatScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.officeId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  // Tracks the chat we've already marked as seen — prevents the infinite
  // rebuild loop: markSeen → Firestore write → stream emits → rebuild → markSeen → …
  String? _markedSeenChatId;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Scroll to bottom after messages load / send ──────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Update lastSeen when the tab is shown ────────────────────────────────
  void _markSeen(String chatId, String userId) {
    ref.read(chatRepositoryProvider).updateLastSeen(chatId, userId);
  }

  // ── Send text ────────────────────────────────────────────────────────────
  Future<void> _sendText(String chatId) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    _textCtrl.clear();
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        chatId,
        senderId: user.uid,
        senderName: user.name,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Pick & send image (🖼 button) ────────────────────────────────────────
  Future<void> _pickAndSendImage(String chatId) async {
    // Pick file first — before touching spinner state
    XFile? xFile;
    try {
      xFile = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker: $e'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (xFile == null) return; // user cancelled

    // Now start the upload with explicit spinner management
    setState(() => _sending = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;
      final bytes = await xFile.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}';
      final url = await ref
          .read(chatRepositoryProvider)
          .uploadFile(chatId, bytes, fileName);
      await ref.read(chatRepositoryProvider).sendMessage(
        chatId,
        senderId: user.uid,
        senderName: user.name,
        fileUrl: url,
        fileType: 'image', // always 'image' from the image picker
        fileName: xFile.name,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Pick & send file (📎 button) ─────────────────────────────────────────
  Future<void> _pickAndSendFile(String chatId) async {
    // Pick file first — before touching spinner state
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (result == null || result.files.isEmpty) return; // user cancelled
    final file = result.files.first;
    if (file.bytes == null) return;

    // Detect type — treat image extensions as 'image' so they render inline
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'};
    final ext = file.extension?.toLowerCase() ?? '';
    final fileType = imageExts.contains(ext)
        ? 'image'
        : (ext == 'pdf' ? 'pdf' : 'other');

    setState(() => _sending = true);
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final url = await ref
          .read(chatRepositoryProvider)
          .uploadFile(chatId, file.bytes!, fileName);
      await ref.read(chatRepositoryProvider).sendMessage(
        chatId,
        senderId: user.uid,
        senderName: user.name,
        fileUrl: url,
        fileType: fileType,
        fileName: file.name,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File upload failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Long-press: delete message ───────────────────────────────────────────
  void _showMessageMenu(
    BuildContext context,
    ChatMessageModel msg,
    ChatModel chat,
    String currentUserId,
    bool isAdmin,
  ) {
    final canDelete = isAdmin ||
        msg.senderId == currentUserId ||
        chat.createdBy == currentUserId;
    if (!canDelete) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text('Delete message', style: TextStyle(color: Colors.red)),
          onTap: () async {
            Navigator.pop(context);
            try {
              await ref
                  .read(chatRepositoryProvider)
                  .softDeleteMessage(chat.id, msg.id);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delete failed: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  // ── Create chat ──────────────────────────────────────────────────────────
  Future<void> _createChat(List<String> assignedMembers) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    try {
      await ref.read(chatRepositoryProvider).createChat(
        projectId: widget.projectId,
        officeId: widget.officeId,
        createdBy: user.uid,
        name: '${widget.projectName} — Chat',
        members: assignedMembers,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create chat: $e')),
        );
      }
    }
  }

  // ── Manage members bottom sheet ──────────────────────────────────────────
  void _showManageMembers(BuildContext context, ChatModel chat) {
    // selected is declared outside so it survives Consumer/StatefulBuilder rebuilds
    final selected = Set<String>.from(chat.members);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Consumer watches employeesProvider live — fixes the infinite spinner that
      // occurred when ref.read() was used and the provider hadn't loaded yet.
      builder: (ctx) => Consumer(
        builder: (ctx, innerRef, _) {
          final employeesAsync = innerRef.watch(employeesProvider);
          return StatefulBuilder(
            builder: (ctx, setModalState) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollCtrl) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                    child: Row(
                      children: [
                        const Text('Manage Members',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await innerRef
                                  .read(chatRepositoryProvider)
                                  .updateMembers(chat.id, selected.toList());
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Update failed: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Save'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete chat',
                          onPressed: () => _confirmDeleteChat(ctx, chat),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: employeesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Failed to load members: $e',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      data: (allEmployees) => allEmployees.isEmpty
                          ? const Center(child: Text('No employees found'))
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount: allEmployees.length,
                              itemBuilder: (_, i) {
                                final emp = allEmployees[i];
                                final checked = selected.contains(emp.uid);
                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(emp.name),
                                  subtitle: Text(emp.roleLabel),
                                  onChanged: (v) => setModalState(() {
                                    if (v == true) {
                                      selected.add(emp.uid);
                                    } else {
                                      selected.remove(emp.uid);
                                    }
                                  }),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteChat(BuildContext ctx, ChatModel chat) {
    Navigator.pop(ctx);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
            'All messages will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatRepositoryProvider).deleteChat(chat.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatForProjectProvider(widget.projectId));
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const SizedBox.shrink();

    return chatAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        // permission-denied means the user is not a member of this chat
        if (e.toString().contains('permission-denied')) {
          return const _NotMemberView();
        }
        return Center(child: Text('Error: $e'));
      },
      data: (chat) {
        if (chat == null) {
          return _NoChatView(
            onStart: () async {
              // Pre-populate with the current user as the only member;
              // admin can add more via manage members
              await _createChat([user.uid]);
            },
          );
        }

        // Membership gate: only members, creator, or admins can participate.
        // (Admins can read the chat via the Firestore rule but may not be in members[].)
        final isMember = user.isAdmin ||
            chat.members.contains(user.uid) ||
            chat.createdBy == user.uid;
        if (!isMember) {
          return const _NotMemberView();
        }

        // Mark read once per chat (not on every rebuild — that causes an
        // infinite loop: write → stream emits → rebuild → write → …)
        if (_markedSeenChatId != chat.id) {
          _markedSeenChatId = chat.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _markSeen(chat.id, user.uid);
          });
        }

        final canManage = user.isAdmin || chat.createdBy == user.uid;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('${widget.projectName} — Chat',
                style: const TextStyle(fontSize: 14)),
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.group_outlined),
                  tooltip: 'Manage members',
                  onPressed: () => _showManageMembers(context, chat),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _MessageList(
                chat: chat,
                currentUserId: user.uid,
                isAdmin: user.isAdmin,
                scrollCtrl: _scrollCtrl,
                onScrollToBottom: _scrollToBottom,
                onLongPress: (msg) =>
                    _showMessageMenu(context, msg, chat, user.uid, user.isAdmin),
              )),
              _InputBar(
                textCtrl: _textCtrl,
                sending: _sending,
                onSend: () => _sendText(chat.id),
                onPickImage: () => _pickAndSendImage(chat.id),
                onPickFile: () => _pickAndSendFile(chat.id),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── No chat yet view ──────────────────────────────────────────────────────────
class _NoChatView extends StatelessWidget {
  final VoidCallback onStart;
  const _NoChatView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64, color: cs.subtleText),
            const SizedBox(height: 16),
            Text(
              'No chat yet for this project.',
              style: TextStyle(color: cs.subtleText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Start Project Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Not a member view ────────────────────────────────────────────────────────
class _NotMemberView extends StatelessWidget {
  const _NotMemberView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 64, color: cs.subtleText),
            const SizedBox(height: 16),
            Text(
              'You are not a member of this chat.',
              style: TextStyle(color: cs.subtleText, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask a project admin to add you.',
              style: TextStyle(fontSize: 13, color: cs.subtleText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message list ──────────────────────────────────────────────────────────────
class _MessageList extends ConsumerWidget {
  final ChatModel chat;
  final String currentUserId;
  final bool isAdmin;
  final ScrollController scrollCtrl;
  final VoidCallback onScrollToBottom;
  final void Function(ChatMessageModel) onLongPress;

  const _MessageList({
    required this.chat,
    required this.currentUserId,
    required this.isAdmin,
    required this.scrollCtrl,
    required this.onScrollToBottom,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgsAsync = ref.watch(chatMessagesProvider(chat.id));

    return msgsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (messages) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onScrollToBottom());
        if (messages.isEmpty) {
          return Center(
            child: Text('No messages yet. Say hello! 👋',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.subtleText)),
          );
        }
        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i];
            final isMine = msg.senderId == currentUserId;
            return GestureDetector(
              onLongPress: () => onLongPress(msg),
              child: _MessageBubble(
                msg: msg,
                isMine: isMine,
                canDelete: isAdmin ||
                    msg.senderId == currentUserId ||
                    chat.createdBy == currentUserId,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessageModel msg;
  final bool isMine;
  final bool canDelete;

  const _MessageBubble({
    required this.msg,
    required this.isMine,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primary.withOpacity(0.15),
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                style: TextStyle(
                    fontSize: 12, color: cs.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.subtleText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine ? cs.primary : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: msg.isDeleted
                      ? Text(
                          'This message was deleted',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: isMine
                                ? Colors.white.withOpacity(0.6)
                                : cs.subtleText,
                            fontSize: 13,
                          ),
                        )
                      : _BubbleContent(msg: msg, isMine: isMine),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    timeStr,
                    style: TextStyle(fontSize: 10, color: cs.subtleText),
                  ),
                ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Bubble content (text / image / file) ─────────────────────────────────────
class _BubbleContent extends StatelessWidget {
  final ChatMessageModel msg;
  final bool isMine;
  const _BubbleContent({required this.msg, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final textColor = isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;

    if (msg.fileType == 'image' && msg.fileUrl != null) {
      return GestureDetector(
        onTap: () => _showFullImage(context, msg.fileUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            msg.fileUrl!,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null
                    ? child
                    : const SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 48),
          ),
        ),
      );
    }

    if ((msg.fileType == 'pdf' || msg.fileType == 'other') &&
        msg.fileUrl != null) {
      return InkWell(
        onTap: () => _openUrl(msg.fileUrl!),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              msg.fileType == 'pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              color: textColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                msg.fileName ?? 'File',
                style: TextStyle(
                  color: textColor,
                  decoration: TextDecoration.underline,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      msg.text ?? '',
      style: TextStyle(color: textColor, fontSize: 14),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Input bar ────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController textCtrl;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;

  const _InputBar({
    required this.textCtrl,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file_rounded, color: cs.primary),
              tooltip: 'Attach file',
              onPressed: sending ? null : onPickFile,
            ),
            IconButton(
              icon: Icon(Icons.image_outlined, color: cs.primary),
              tooltip: 'Send image',
              onPressed: sending ? null : onPickImage,
            ),
            Expanded(
              child: TextField(
                controller: textCtrl,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                ),
              ),
            ),
            const SizedBox(width: 6),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send_rounded, color: cs.primary),
                    onPressed: onSend,
                  ),
          ],
        ),
      ),
    );
  }
}
