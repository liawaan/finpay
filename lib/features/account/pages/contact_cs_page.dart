import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/support_chat_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/services/account_service.dart';
import '../../../data/services/support_chat_service.dart';
import '../../../data/services/transaction_service.dart';
import '../../../shared/widgets/pill_badge.dart';
import '../widgets/sub_page_scaffold.dart';

/// Hubungi CS: Live Chat Customer Support terintegrasi dua arah dengan FinPay Admin Web Portal.
class ContactCsPage extends StatefulWidget {
  const ContactCsPage({super.key});

  @override
  State<ContactCsPage> createState() => _ContactCsPageState();
}

class _ContactCsPageState extends State<ContactCsPage> {
  static const List<String> _quickReplies = [
    'Top up belum masuk',
    'Kendala pembayaran QRIS',
    'Kendala transfer antar bank',
    'Lupa PIN transaksi',
    'Pertanyaan limit harian',
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _liveChatTimer;
  bool _isPolling = false;
  int _lastMessageCount = 0;

  UserProfileModel get _activeUser => AccountService.instance.currentUser;

  String get _activeUserId {
    final uid = _activeUser.userId.trim();
    return uid.isNotEmpty ? uid : FirebaseFirestoreConfig.defaultUserId;
  }

  @override
  void initState() {
    super.initState();
    SupportChatService.instance.ensureWelcomeMessageForUser(
      userId: _activeUserId,
      userName: _activeUser.fullName,
    );
    SupportChatService.instance.markMessagesAsRead(
      _activeUserId,
      readByAdmin: false,
    );
    _pollChatRealtime();
    _liveChatTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollChatRealtime(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _liveChatTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pollChatRealtime() async {
    if (_isPolling) return;
    _isPolling = true;
    try {
      final msgs = await SupportChatService.instance.fetchMessagesFromFirebase(
        userId: _activeUserId,
      );
      SupportChatService.instance.markMessagesAsRead(
        _activeUserId,
        readByAdmin: false,
      );
      if (mounted && msgs.length > _lastMessageCount) {
        _lastMessageCount = msgs.length;
        _scrollToEnd();
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    final userId = _activeUserId;
    final userName = _activeUser.fullName;

    _controller.clear();
    await SupportChatService.instance.sendMessage(
      userId: userId,
      userName: userName,
      text: text,
      isFromAdmin: false,
    );
    _scrollToEnd();

    await SupportChatService.instance.sendAutoReplyForUserMessage(
      userId: userId,
      userName: userName,
      userText: text,
    );
    SupportChatService.instance.markMessagesAsRead(
      userId,
      readByAdmin: false,
    );
    if (!mounted) return;
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Bantuan & Live CS',
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: AppSpacing.page),
          child: Center(
            child: PillBadge(
              label: 'CS Online',
              leadingIcon: Icons.circle,
              backgroundColor: AppColors.successLight,
              foregroundColor: AppColors.success,
            ),
          ),
        ),
      ],
      body: ValueListenableBuilder<UserProfileModel>(
        valueListenable: AccountService.instance.userNotifier,
        builder: (context, user, _) {
          final currentUid = user.userId.trim().isNotEmpty
              ? user.userId.trim()
              : FirebaseFirestoreConfig.defaultUserId;
          SupportChatService.instance.ensureWelcomeMessageForUser(
            userId: currentUid,
            userName: user.fullName,
          );

          return ValueListenableBuilder<List<SupportMessageModel>>(
            valueListenable: SupportChatService.instance.messagesNotifier,
            builder: (context, allMessages, _) {
              final userMessages = SupportChatService.instance
                  .getMessagesForUser(currentUid);

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  AppSpacing.xs,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Terhubung sebagai ${user.fullName} • ${user.phoneNumber}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.md,
                  ),
                  itemCount: userMessages.length,
                  itemBuilder: (context, index) {
                    return _Bubble(message: userMessages[index]);
                  },
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  itemCount: _quickReplies.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) => ActionChip(
                    label: Text(_quickReplies[i]),
                    onPressed: () => _send(_quickReplies[i]),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle:
                        AppTextStyles.label.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              _buildInputBar(),
            ],
          );
            },
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Tulis pesan untuk Admin FinPay...',
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textTertiary),
                fillColor: AppColors.surface,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.pillAll,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.pillAll,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.pillAll,
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: () => _send(_controller.text),
            icon: const Icon(Icons.send_rounded, size: AppSizes.iconMd),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final SupportMessageModel message;

  @override
  Widget build(BuildContext context) {
    final fromUser = !message.isFromAdmin;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: fromUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(fromUser ? AppRadius.lg : 0),
                  bottomRight: Radius.circular(fromUser ? 0 : AppRadius.lg),
                ),
                border: fromUser ? null : Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment:
                    fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!fromUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Admin FinPay',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ),
                  Text(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: fromUser ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.timeFormatted,
                        style: AppTextStyles.caption.copyWith(
                          color: fromUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                      if (fromUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 13,
                          color: message.isRead
                              ? AppColors.mint
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (fromUser) const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
