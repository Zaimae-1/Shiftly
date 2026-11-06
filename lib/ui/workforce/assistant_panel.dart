import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/face_recognizer.dart';
import '../../utils/scanner_camera.dart';
import '../../utils/workforce_data.dart';
import '../../utils/work_assistant.dart';
import '../attendance_history/attendance_history_screen.dart';
import 'leave_request_form.dart';
import 'ui_motion.dart';
import 'shiftly_brand.dart';

class AssistantLauncher extends StatelessWidget {
  final VoidCallback onPressed;
  const AssistantLauncher({super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => TouchFeedback(
    hoverScale: 1.06,
    child: FloatingActionButton(
      key: const ValueKey('open-work-assistant'),
      tooltip: 'Shiftly Assist',
      onPressed: onPressed,
      backgroundColor: const Color(0xFF2F61C2),
      foregroundColor: Colors.white,
      elevation: 4,
      hoverElevation: 9,
      highlightElevation: 2,
      shape: const CircleBorder(),
      child: const Icon(Icons.chat_bubble_outline_rounded),
    ),
  );
}

Future<void> showWorkAssistant(
  BuildContext context, {
  AdminSession? session,
  required FaceRecognizer recognizer,
  ScannerCamera Function()? cameraFactory,
  Future<void> Function(PreviewStudent?)? editWorker,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Tutup asisten',
  barrierColor: const Color(0x660E1621),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 280),
  pageBuilder: (_, animation, secondary) => _AssistantPanel(
    session: session,
    recognizer: recognizer,
    cameraFactory: cameraFactory,
    editWorker: editWorker,
  ),
  transitionBuilder: (context, animation, secondary, child) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .07),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  },
);

class _AssistantPanel extends StatefulWidget {
  final AdminSession? session;
  final FaceRecognizer recognizer;
  final ScannerCamera Function()? cameraFactory;
  final Future<void> Function(PreviewStudent?)? editWorker;
  const _AssistantPanel({
    this.session,
    required this.recognizer,
    this.cameraFactory,
    this.editWorker,
  });
  @override
  State<_AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<_AssistantPanel> {
  final _input = TextEditingController(), _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _busy = false, _leave = false;
  late final WorkAssistant _assistant = WorkAssistant(session: widget.session);
  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        text:
            'Hai, selamat datang! Aku di sini buat bantu urusan presensimu. Mau cek kabar tim atau mengajukan izin? Pilih di bawah, atau langsung cerita aja ya.',
        user: false,
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? quick]) async {
    final text = (quick ?? _input.text).trim();
    if (_busy || text.isEmpty) return;
    _input.clear();
    setState(() {
      _busy = true;
      _messages.add(_ChatMessage(text: text, user: true));
    });
    try {
      final reply = await _assistant.respond(text);
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: reply.text,
            user: false,
            summary: reply.summary,
            people: reply.people,
          ),
        );
        if (reply.action == AssistantAction.leaveForm) _leave = true;
      });
      if (reply.action == AssistantAction.newWorker ||
          reply.action == AssistantAction.editWorker) {
        if (widget.session?.active == true) {
          await widget.editWorker?.call(reply.worker);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _messages.add(
            _ChatMessage(
              text: error is StateError
                  ? error.message.toString()
                  : 'Sepertinya ada kendala sebentar. Coba kirim lagi ya, aku bantu cek.',
              user: false,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context),
        mobile = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      backgroundColor: const Color(0xFFF2F4F8),
      alignment: mobile ? Alignment.bottomCenter : Alignment.center,
      insetPadding: mobile
          ? EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 10)
          : const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: mobile
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const ValueKey('assistant-panel'),
        width: mobile ? size.width : 510,
        height: mobile ? size.height : math.min(740, size.height - 48),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _chatHeader(mobile),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(mobile ? 14 : 20),
                  children: [
                    for (var index = 0; index < _messages.length; index++)
                      RevealIn(
                        key: ValueKey('message-$index'),
                        child: _bubble(_messages[index], size.width, mobile),
                      ),
                    if (_messages.length == 1 && !_leave)
                      RevealIn(
                        key: const ValueKey('assistant-shortcuts'),
                        child: _shortcuts(),
                      ),
                    if (_leave)
                      RevealIn(
                        key: const ValueKey('assistant-leave-panel'),
                        child: LeaveRequestForm(
                          recognizer: widget.recognizer,
                          cameraFactory: widget.cameraFactory,
                        ),
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.more_horiz_rounded,
                              color: Color(0xFF356CD4),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sebentar ya, aku cek dulu…',
                              style: TextStyle(
                                color: Color(0xFF71809A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatHeader(bool mobile) => Container(
    padding: EdgeInsets.fromLTRB(18, mobile ? 12 : 18, 12, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2D5CB5), Color(0xFF5587DD)],
      ),
    ),
    child: Column(
      children: [
        if (mobile) ...[
          Container(
            width: 32,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
        Row(
          children: [
            const ShiftlyMark(size: 44, light: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shiftly Assist',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _assistant.isAdmin
                        ? 'Mode admin · siap membantu'
                        : 'Teman bantu presensi harianmu',
                    style: const TextStyle(
                      color: Color(0xFFCED8E6),
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            TouchFeedback(
              child: IconButton(
                tooltip: 'Tutup asisten',
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .08),
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _bubble(_ChatMessage message, double width, bool mobile) => Align(
    alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(
            message.user ? 350 : 440,
            width - (mobile ? 28 : 88),
          ),
        ),
        child: TouchFeedback(
          hoverScale: 1,
          child: Container(
            padding: EdgeInsets.all(message.user ? 15 : 18),
            decoration: BoxDecoration(
              color: message.user ? const Color(0xFF356CD4) : Colors.white,
              border: Border.all(
                color: message.user
                    ? const Color(0xFF356CD4)
                    : const Color(0xFFE0E8F4),
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(message.user ? 22 : 6),
                bottomRight: Radius.circular(message.user ? 6 : 22),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF294B85,
                  ).withValues(alpha: message.user ? .12 : .035),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.user) ...[
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: Color(0xFF5684DB),
                      ),
                      SizedBox(width: 7),
                      Text(
                        'SHIFTLY ASSIST',
                        style: TextStyle(
                          color: Color(0xFF6581AC),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                SelectableText(
                  message.text,
                  style: TextStyle(
                    color: message.user
                        ? Colors.white
                        : const Color(0xFF283B59),
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
                if (message.summary != null) ...[
                  const SizedBox(height: 16),
                  _summaryCard(message.summary!),
                ],
                if (message.people.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final person in message.people) _personCard(person),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _summaryCard(WorkAssistantSummary summary) => LayoutBuilder(
    builder: (context, constraints) {
      final items = <(String, int, IconData, Color)>[
        (
          'Terdaftar',
          summary.total,
          Icons.groups_2_outlined,
          const Color(0xFF356CD4),
        ),
        (
          'Sedang bekerja',
          summary.working,
          Icons.work_outline_rounded,
          const Color(0xFF356CD4),
        ),
        (
          'Sudah pulang',
          summary.finished,
          Icons.home_outlined,
          const Color(0xFF6581AC),
        ),
        (
          'Izin / sakit',
          summary.leave,
          Icons.medical_services_outlined,
          const Color(0xFFAB793E),
        ),
        (
          'Belum absen',
          summary.unrecorded,
          Icons.schedule_rounded,
          const Color(0xFF6581AC),
        ),
        (
          'Alpha aktif',
          summary.alpha,
          Icons.event_busy_outlined,
          const Color(0xFFB46C60),
        ),
      ];
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            SizedBox(
              width: (constraints.maxWidth - 8) / 2,
              child: TouchFeedback(
                hoverLift: 3,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.$4.withValues(alpha: .065),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: item.$4.withValues(alpha: .1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.$3, size: 17, color: item.$4),
                          const Spacer(),
                          Text(
                            '${item.$2}',
                            style: const TextStyle(
                              color: Color(0xFF263B5C),
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: Color(0xFF6B7E9B),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _personCard(WorkAssistantPerson person) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7FD),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE1E8F5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 38,
                height: 38,
                child: person.photo == null
                    ? const ColoredBox(
                        color: Color(0xFFE5EDFC),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF5684DB),
                          size: 23,
                        ),
                      )
                    : Image.memory(
                        person.photo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF5684DB),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      color: Color(0xFF243653),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    '@${person.username}',
                    style: const TextStyle(
                      color: Color(0xFF71809A),
                      fontSize: 10,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE7EEFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            person.status,
            style: const TextStyle(
              color: Color(0xFF356CD4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final detail in person.details.entries)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    detail.key,
                    style: const TextStyle(
                      color: Color(0xFF71809A),
                      fontSize: 10,
                      height: 1.6,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    detail.value,
                    style: const TextStyle(
                      color: Color(0xFF344B6D),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _shortcuts() => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MAU DIBANTU APA HARI INI?',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Color(0xFF5378AB),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in <(String, IconData)>[
              ('Saya mau izin', Icons.medical_services_outlined),
              ('Jumlah pekerja', Icons.groups_outlined),
              ('Berapa yang bekerja?', Icons.work_outline_rounded),
              ('Jumlah Alpha', Icons.event_busy_outlined),
              ('Cari pekerja', Icons.search_rounded),
            ])
              TouchFeedback(
                enabled: !_busy,
                child: ActionChip(
                  avatar: Icon(
                    item.$2,
                    size: 17,
                    color: const Color(0xFF356CD4),
                  ),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  side: const BorderSide(color: Color(0xFFD2DBE8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  label: Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _busy ? null : () => _send(item.$1),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: const BoxDecoration(
      color: Color(0xFFF6F8FB),
      border: Border(top: BorderSide(color: Color(0xFFD8E0EB))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('assistant-input'),
            controller: _input,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: _busy ? null : (_) => _send(),
            style: const TextStyle(fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Tulis pesanmu di sini…',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFE7ECF2),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFD7DFEB)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TouchFeedback(
          enabled: !_busy,
          child: IconButton.filled(
            key: const ValueKey('assistant-send'),
            tooltip: 'Kirim pesan',
            onPressed: _busy ? null : () => _send(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF356CD4),
              minimumSize: const Size(47, 47),
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
        ),
      ],
    ),
  );
}

class _ChatMessage {
  final String text;
  final bool user;
  final WorkAssistantSummary? summary;
  final List<WorkAssistantPerson> people;
  const _ChatMessage({
    required this.text,
    required this.user,
    this.summary,
    this.people = const [],
  });
}
