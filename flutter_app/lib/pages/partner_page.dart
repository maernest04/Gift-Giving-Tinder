import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../utils/open_url_stub.dart' if (dart.library.html) '../utils/open_url_web.dart' as url_util;
import '../models/user_model.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/adaptive_recommender.dart';
import '../services/ml_gift_recommender.dart';

class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key});

  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  final _codeController = TextEditingController();
  final _authService = AuthService();
  late final MLGiftRecommender _mlRecommender = MLGiftRecommender(
    vectorRecommender: AdaptiveRecommender(d: 10),
  );

  bool _loading = false;
  String? _error;
  int _partnerRefreshKey = 0;

  Future<void> _onPartnerRefresh() async {
    setState(() => _partnerRefreshKey++);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest(UserModel me, UserModel them) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.sendPartnerRequest(me.id, them.id);
      if (!mounted) return;
      setState(() => _loading = false);
      _codeController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not send request. Try again.';
      });
    }
  }

  Future<void> _acceptRequest(String myUid, String theirUid, String requestDocId) async {
    setState(() => _loading = true);
    try {
      await _authService.acceptPartnerRequest(myUid, theirUid, requestDocId);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not accept. Try again.';
      });
    }
  }

  Future<void> _declineRequest(String myUid, String theirUid, String requestDocId) async {
    setState(() => _loading = true);
    try {
      await _authService.declinePartnerRequest(myUid, theirUid, requestDocId);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _cancelRequest(String myUid, String theirUid) async {
    setState(() => _loading = true);
    try {
      await _authService.cancelPartnerRequest(myUid, theirUid);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _removePartner(String myUid, String partnerUid) async {
    setState(() => _loading = true);
    try {
      await _authService.removePartner(myUid, partnerUid);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not remove partner. Try again.';
      });
    }
  }

  static const _storeSearchUrls = {
    'Amazon': 'https://www.amazon.com/s?k=',
    'Target': 'https://www.target.com/s?searchTerm=',
    'Walmart': 'https://www.walmart.com/search?q=',
  };

  Future<void> _openStoreSearch(BuildContext context, String chipText) async {
    // Gift ideas are "Theme: Item1 & Item2" – use the part after ":" for product search
    final query = chipText.contains(': ')
        ? chipText.split(': ').skip(1).join(' ').replaceAll(' & ', ' ')
        : chipText;
    final encoded = Uri.encodeComponent(query.trim());
    if (encoded.isEmpty) return;

    if (!context.mounted) return;
    final store = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Search online',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getSecondaryTextColor(),
                ),
              ),
              const SizedBox(height: 12),
              ..._storeSearchUrls.keys.map((name) => ListTile(
                    leading: Icon(Icons.shopping_bag_outlined,
                        color: AppColors.getTextColor()),
                    title: Text(name, style: TextStyle(color: AppColors.getTextColor())),
                    onTap: () => Navigator.pop(ctx, name),
                  )),
            ],
          ),
        ),
      ),
    );
    if (store == null) return;
    final base = _storeSearchUrls[store]!;
    final url = '$base$encoded';
    try {
      await url_util.openUrl(url);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final cardBg = themeService.isGlass
            ? Colors.white.withOpacity(0.7)
            : AppColors.bgCard;
        final inputBg = themeService.isGlass
            ? Colors.black.withOpacity(0.03)
            : AppColors.bgDark;
        final borderColor = themeService.isGlass
            ? Colors.black.withOpacity(0.05)
            : AppColors.borderColor;

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return Center(
            child: Text(
              'Sign in to use the partner section.',
              style: TextStyle(color: AppColors.getSecondaryTextColor()),
            ),
          );
        }

        return StreamBuilder<UserModel?>(
          stream: _authService.streamUser(user.uid),
          builder: (context, snapshot) {
            final me = snapshot.data;
            if (me == null && !snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.getSecondaryTextColor(),
                  strokeWidth: 2,
                ),
              );
            }
            if (me == null) {
              return Center(
                child: Text(
                  'Could not load profile.',
                  style: TextStyle(color: AppColors.getSecondaryTextColor()),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                // Linked partner: whole page scrolls, pull-to-refresh above the card
                if (me.partnerId != null) {
                  return RefreshIndicator(
                    onRefresh: _onPartnerRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        24,
                        24,
                        24 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: _buildLinkedPartnerSection(
                        me,
                        cardBg,
                        borderColor,
                        inputBg,
                        refreshKey: _partnerRefreshKey,
                        onRefresh: _onPartnerRefresh,
                      ),
                    ),
                  );
                }
                // Other states: centered scrollable content (pull to refresh)
                return RefreshIndicator(
                  onRefresh: _onPartnerRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildYourCodeCard(me, cardBg, borderColor),
                        const SizedBox(height: 16),
                        if (me.pendingRequestToId != null)
                          _buildPendingOutgoingCard(
                            me,
                            me.pendingRequestToId!,
                            cardBg,
                            borderColor,
                          )
                        else
                          StreamBuilder<Map<String, String>?>(
                            stream: _authService.streamIncomingRequest(me.id),
                            builder: (context, reqSnap) {
                              if (reqSnap.hasError) {
                                final err = reqSnap.error;
                                final msg = err?.toString() ?? 'Unknown error';
                                return _buildIncomingRequestErrorCard(
                                  msg,
                                  cardBg,
                                  borderColor,
                                );
                              }
                              final incoming = reqSnap.data;
                              if (incoming != null &&
                                  incoming['requestId'] != null &&
                                  incoming['fromUid'] != null) {
                                return _buildIncomingRequestCard(
                                  me,
                                  incoming['fromUid']!,
                                  incoming['requestId']!,
                                  cardBg,
                                  borderColor,
                                );
                              }
                              return _buildEnterCodeCard(
                                me,
                                cardBg,
                                borderColor,
                                inputBg,
                              );
                            },
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildYourCodeCard(UserModel me, Color cardBg, Color borderColor) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your code',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getSecondaryTextColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      me.partnerCode,
                      style: AppTextStyles.h3.copyWith(
                        letterSpacing: 2,
                        color: AppColors.getTextColor(),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: me.partnerCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy code',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnterCodeCard(
    UserModel me,
    Color cardBg,
    Color borderColor,
    Color inputBg,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: themeService.isGlass
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              const Text("🔗", style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                "Connect with Partner",
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your partner's code to send a link request. They'll need to accept before you can see each other's interests.",
                style: AppTextStyles.body.copyWith(
                  color: AppColors.getSecondaryTextColor(),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFff4d6d).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFff4d6d),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(16),
                  border: themeService.isGlass
                      ? Border.all(color: borderColor)
                      : null,
                ),
                child: TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3.copyWith(
                    letterSpacing: 2,
                    color: AppColors.getTextColor(),
                  ),
                  decoration: InputDecoration(
                    hintText: "ENTER CODE",
                    hintStyle: TextStyle(
                      color: AppColors.getSecondaryTextColor(),
                      fontSize: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _onSendRequest(me),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Send link request",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSendRequest(UserModel me) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final them = await _authService.findUserByPartnerCode(code);
      if (!mounted) return;
      if (them == null) {
        setState(() {
          _loading = false;
          _error = 'No one found with that code. Check and try again.';
        });
        return;
      }
      if (them.id == me.id) {
        setState(() {
          _loading = false;
          _error = "That's your own code. Enter your partner's code.";
        });
        return;
      }
      await _authService.sendPartnerRequest(me.id, them.id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
      _codeController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not send request. Try again.';
      });
    }
  }

  Widget _buildPendingOutgoingCard(
    UserModel me,
    String theirUid,
    Color cardBg,
    Color borderColor,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: FutureBuilder<UserModel?>(
          future: _authService.getUser(theirUid),
          builder: (context, snapshot) {
            final them = snapshot.data;
            final name = them?.name ?? 'Partner';
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  const Text("⏳", style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    'Request sent to $name',
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'They need to accept in their Partner section. You can cancel the request below.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.getSecondaryTextColor(),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _cancelRequest(me.id, theirUid),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.getSecondaryTextColor(),
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.getSecondaryTextColor(),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Cancel request'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIncomingRequestCard(
    UserModel me,
    String theirUid,
    String requestDocId,
    Color cardBg,
    Color borderColor,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: FutureBuilder<UserModel?>(
          future: _authService.getUser(theirUid),
          builder: (context, snapshot) {
            final them = snapshot.data;
            final name = them?.name ?? 'Someone';
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  const Text("👋", style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    '$name wants to link',
                    style: AppTextStyles.h2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Accept to see each other\'s interests.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.getSecondaryTextColor(),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => _declineRequest(me.id, theirUid, requestDocId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.getSecondaryTextColor(),
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : () => _acceptRequest(me.id, theirUid, requestDocId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIncomingRequestErrorCard(
    String errorMessage,
    Color cardBg,
    Color borderColor,
  ) {
    final isIndexError = errorMessage.contains('index') ||
        errorMessage.contains('FAILED_PRECONDITION') ||
        errorMessage.contains('indexes');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Couldn\'t load partner requests',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.getSecondaryTextColor(),
                  fontSize: 12,
                ),
              ),
              if (isIndexError) ...[
                const SizedBox(height: 16),
                Text(
                  'Create the missing index: Firebase Console → Firestore → Indexes, or run: firebase deploy --only firestore:indexes',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.getSecondaryTextColor(),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedPartnerSection(
    UserModel me,
    Color cardBg,
    Color borderColor,
    Color inputBg, {
    required int refreshKey,
    required Future<void> Function() onRefresh,
  }) {
    final partnerUid = me.partnerId!;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: FutureBuilder<UserModel?>(
          key: ValueKey(refreshKey),
          future: _authService.getUser(partnerUid),
          builder: (context, partnerSnapshot) {
            final partner = partnerSnapshot.data;
            if (partner == null) {
              return SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.getSecondaryTextColor(),
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            return _LinkedPartnerContent(
              me: me,
              partner: partner,
              cardBg: cardBg,
              borderColor: borderColor,
              mlRecommender: _mlRecommender,
              loading: _loading,
              onRemove: () => _removePartner(me.id, partnerUid),
              onSearchOnline: (query) => _openStoreSearch(context, query),
              refreshKey: refreshKey,
              onRefresh: onRefresh,
            );
          },
        ),
      ),
    );
  }
}

class _LinkedPartnerContent extends StatelessWidget {
  final UserModel me;
  final UserModel partner;
  final Color cardBg;
  final Color borderColor;
  final MLGiftRecommender mlRecommender;
  final bool loading;
  final VoidCallback onRemove;
  final void Function(String query)? onSearchOnline;
  final int refreshKey;
  final Future<void> Function() onRefresh;

  const _LinkedPartnerContent({
    required this.me,
    required this.partner,
    required this.cardBg,
    required this.borderColor,
    required this.mlRecommender,
    required this.loading,
    required this.onRemove,
    this.onSearchOnline,
    required this.refreshKey,
    required this.onRefresh,
  });

  static const int _maxTopCategories = 8;
  static const int _maxGiftIdeas = 6;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(refreshKey),
      future: _loadPartnerData(),
      builder: (context, dataSnapshot) {
        final likedTitles = dataSnapshot.hasData
            ? List<String>.from(
                dataSnapshot.data!['likedTitles'] ?? const <String>[])
            : <String>[];
        final narrowed = dataSnapshot.hasData
            ? List<String>.from(
                dataSnapshot.data!['narrowedCategories'] ?? const <String>[])
            : <String>[];
        final combinations = dataSnapshot.hasData
            ? List<String>.from(
                dataSnapshot.data!['combinations'] ?? const <String>[])
            : <String>[];

        final topCategories = narrowed.take(_maxTopCategories).toList();
        final giftIdeas = combinations.take(_maxGiftIdeas).toList();
        final hasAny = likedTitles.isNotEmpty ||
            topCategories.isNotEmpty ||
            giftIdeas.isNotEmpty;

        final isEmptyState = !hasAny;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor,
              width: isEmptyState ? 1.5 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            boxShadow: themeService.isGlass
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment:
                isEmptyState ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "${partner.name}'s interests",
                      style: AppTextStyles.h2,
                      textAlign: isEmptyState ? TextAlign.center : TextAlign.left,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppColors.getSecondaryTextColor(),
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_remove_outlined,
                              size: 20,
                              color: const Color(0xFFff4d6d),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Remove partner',
                              style: TextStyle(
                                color: const Color(0xFFff4d6d),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              isEmptyState
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.card_giftcard_rounded,
                              size: 56,
                              color: AppColors.getSecondaryTextColor()
                                  .withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No interests yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Your partner hasn\'t shared any interests yet. Ask them to swipe on some categories so you can see gift ideas here!',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 15,
                                  color: AppColors.getSecondaryTextColor(),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      if (topCategories.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Top categories for gifts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          onSearchOnline != null
                              ? 'Tap a category to search online'
                              : 'Best bets based on their interests',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getSecondaryTextColor(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topCategories
                              .map<Widget>((t) => ActionChip(
                                    label: Text(t,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.getTextColor())),
                                    backgroundColor: const Color(0xFF667eea)
                                        .withOpacity(0.2),
                                    onPressed: onSearchOnline != null
                                        ? () => onSearchOnline!(t)
                                        : null,
                                  ))
                              .toList(),
                        ),
                      ],
                      if (giftIdeas.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Gift ideas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          onSearchOnline != null
                              ? 'Tap any idea to search Amazon, Target, or Walmart'
                              : 'Combinations they\'re likely to love',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getSecondaryTextColor(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: giftIdeas
                              .map<Widget>((t) => ActionChip(
                                    label: Text(t,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.getTextColor())),
                                    backgroundColor: const Color(0xFF764ba2)
                                        .withOpacity(0.2),
                                    onPressed: onSearchOnline != null
                                        ? () => onSearchOnline!(t)
                                        : null,
                                  ))
                              .toList(),
                        ),
                      ],
                      if (likedTitles.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            expansionTileTheme: ExpansionTileThemeData(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(
                                  top: 8, bottom: 8),
                            ),
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 8),
                            title: Text(
                              'View all liked categories (${likedTitles.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getSecondaryTextColor(),
                              ),
                            ),
                            trailing: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.getSecondaryTextColor(),
                              size: 24,
                            ),
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: likedTitles
                                    .map((t) => Chip(
                                          label: Text(t,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.getTextColor())),
                                          backgroundColor: AppColors
                                              .getSecondaryTextColor()
                                              .withOpacity(0.12),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadPartnerData() async {
    final recs = await mlRecommender.getRecommendationsForUser(partner.id);
    final prefDoc = await FirebaseFirestore.instance
        .collection('userPreferences')
        .doc(partner.id)
        .get();
    final data = prefDoc.data();
    return {
      'likedTitles': data != null
          ? List<String>.from(data['likedTitles'] ?? const <String>[])
          : <String>[],
      'likedTags': data != null
          ? List<String>.from(data['likedTags'] ?? const <String>[])
          : <String>[],
      'narrowedCategories': recs['narrowedCategories'] ?? [],
      'combinations': recs['combinations'] ?? [],
    };
  }
}
