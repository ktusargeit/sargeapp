import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/permissions/permission_system.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/platform_image.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';
import '../../team/screens/team_screen.dart' show boardMemberLabel;

// ═══════════════════════════════════════════════════════════════════════
// ADD TASK DIALOG — Takım → Birim → Kişi (+ görsel)
// ═══════════════════════════════════════════════════════════════════════

enum TaskAssignmentMode { single, team, unit, board }

class AddTaskDialog extends ConsumerStatefulWidget {
  const AddTaskDialog({super.key});

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '10');

  ClubTeam? _selectedTeam;
  Map<String, dynamic>? _selectedUnit;
  String? _selectedUid;
  String? _selectedName;
  PickedImage? _pickedImage;
  bool _loading = false;
  TaskAssignmentMode _mode = TaskAssignmentMode.single;

  /// Yönetim Kurulu modu: `true` ise görev TÜM kurula atanır; `false` ise
  /// `_selectedBoardUids` içinde seçilen kişilere atanır.
  bool _boardAll = true;

  /// "Kuruldan Belirli Kişileri Seç" tercihinde seçilen kurul üyelerinin uid'leri.
  final Set<String> _selectedBoardUids = <String>{};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await PickedImage.pick(ImageSource.gallery);
    if (img != null && mounted) setState(() => _pickedImage = img);
  }

  List<ClubTeam> _visibleTeams(List<ClubTeam> teams) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final appUser = ref.read(currentAppUserProvider).valueOrNull;
    if (appUser?.isAdmin ?? false) return teams;
    if (uid == null) return const [];

    final led = teams.where((t) => t.leadUid == uid).toList();
    if (led.isNotEmpty) return led;

    final allUnits = ref.read(teamUnitListProvider).valueOrNull ?? const [];
    final ledTeamIds = allUnits
        .where((u) => u['unitLeadUid'] == uid)
        .map((u) => u['teamId'] as String)
        .toSet();
    return teams.where((t) => ledTeamIds.contains(t.id)).toList();
  }

  /// Whether the current user may create "Yönetim Kurulu" (board) tasks.
  bool get _isBoardCreator {
    final appUser = ref.read(currentAppUserProvider).valueOrNull;
    return appUser != null && (userIsBoard(appUser) || appUser.isAdmin);
  }

  Set<String> _allowedUnitIdsFor(String teamId) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final appUser = ref.read(currentAppUserProvider).valueOrNull;
    final allUnits = ref.read(teamUnitListProvider).valueOrNull ?? const [];
    final teamScoped =
        allUnits.where((u) => u['teamId'] == teamId).toList();

    if (appUser?.isAdmin ?? false) {
      return teamScoped.map((u) => u['id'] as String).toSet();
    }
    if (uid == null) return const {};

    final isCaptain = ref
        .read(clubTeamsProvider)
        .valueOrNull
        ?.any((t) => t.id == teamId && t.leadUid == uid) ??
        false;
    if (isCaptain) return teamScoped.map((u) => u['id'] as String).toSet();

    return teamScoped
        .where((u) => u['unitLeadUid'] == uid)
        .map((u) => u['id'] as String)
        .toSet();
  }

  /// Yönetim Kurulu görevinde kapsam tercihi: "Tüm Yönetim Kurulu" (varsayılan)
  /// veya "Kuruldan Belirli Kişileri Seç" (çoklu seçim, checkbox listesi).
  Widget _buildBoardScopeSelector() {
    final membersAsync = ref.watch(boardMembersProvider);
    final members = membersAsync.valueOrNull ?? const <AppUser>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kime atanacak?',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('Tüm Yönetim Kurulu'),
              icon: Icon(Icons.groups, size: 16),
            ),
            ButtonSegment(
              value: false,
              label: Text('Kuruldan Belirli Kişileri Seç'),
              icon: Icon(Icons.checklist, size: 16),
            ),
          ],
          selected: {_boardAll},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            _boardAll = s.first;
            if (_boardAll) _selectedBoardUids.clear();
          }),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ),
        if (!_boardAll) ...[
          const SizedBox(height: 8),
          if (membersAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (membersAsync.hasError)
            const Text('Yönetim Kurulu listesi yüklenemedi',
                style: TextStyle(color: AppColors.error, fontSize: 13))
          else if (members.isEmpty)
            Text('Yönetim Kurulu üyesi bulunamadı.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            // CRITICAL: this list MUST have a bounded height.
            //
            // The old version used `Container(maxHeight: 220)` +
            // `ListView(shrinkWrap: true)`. Inside an `AlertDialog` that
            // combination throws:
            //   "RenderShrinkWrappingViewport does not support returning
            //    intrinsic dimensions."
            // because the dialog lays its content out with intrinsic
            // measurements and a shrink-wrapping viewport cannot report them.
            //
            // Fix: give the viewport a FINITE height (`SizedBox(height: 250)`)
            // and let the ListView scroll normally (NO `shrinkWrap`). The
            // dialog then never needs an intrinsic pass through the viewport.
            SizedBox(
              width: double.maxFinite,
              height: 250,
              child: Material(
                // CRITICAL: opaque bir `Container` arkaplanı, `CheckboxListTile`
                // ink splash'ini görünmez kılar ve Flutter debug modda
                //   "ListTile background color or ink splashes may be invisible."
                // assertion'ını fırlatır. Bu yüzden kutu bir `Material`'a
                // çevrildi: hem arkaplanı (rengi/köşe/border'ı) hem de ink
                // katmanını aynı widget sağlar. `Material` ALTINDAKI
                // `CheckboxListTile`'a dokunma — ink katmanı ondan gelir.
                color: AppColors.surface2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final m = members[index];
                    return CheckboxListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.sargeGold,
                      value: _selectedBoardUids.contains(m.uid),
                      title: Text(
                        m.displayName,
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 13),
                      ),
                      subtitle: Text(
                        boardMemberLabel(m),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selectedBoardUids.add(m.uid);
                        } else {
                          _selectedBoardUids.remove(m.uid);
                        }
                      }),
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);

    final assignmentSegments = <ButtonSegment<TaskAssignmentMode>>[
      const ButtonSegment(
        value: TaskAssignmentMode.single,
        label: Text('Tekil Üye'),
        icon: Icon(Icons.person, size: 16),
      ),
      const ButtonSegment(
        value: TaskAssignmentMode.team,
        label: Text('Tüm Takım'),
        icon: Icon(Icons.groups, size: 16),
      ),
      const ButtonSegment(
        value: TaskAssignmentMode.unit,
        label: Text('Birim'),
        icon: Icon(Icons.apartment, size: 16),
      ),
      if (_isBoardCreator)
        const ButtonSegment(
          value: TaskAssignmentMode.board,
          label: Text('Yönetim Kurulu'),
          icon: Icon(Icons.workspace_premium, size: 16),
        ),
    ];

    return AlertDialog(
      title: const Text('Yeni Görev Ata'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_mode != TaskAssignmentMode.board)
                teamsAsync.when(
                  data: (teams) {
                    final availableTeams = _visibleTeams(teams);
                    if (availableTeams.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Görev atayabileceğiniz bir takım yok.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      );
                    }
                    return DropdownButtonFormField<ClubTeam>(
                      dropdownColor: AppColors.surface2,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                          labelText: 'Takım *', hintText: 'Takım seçin'),
                      initialValue: _selectedTeam,
                      items: availableTeams
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedTeam = v;
                        _selectedUnit = null;
                        _selectedUid = null;
                        _selectedName = null;
                      }),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Hata: $e'),
                ),
              const SizedBox(height: 12),
              SegmentedButton<TaskAssignmentMode>(
                segments: assignmentSegments,
                selected: {_mode},
                onSelectionChanged: (s) => setState(() {
                  _mode = s.first;
                  _selectedUid = null;
                  _selectedName = null;
                  _selectedUnit = null;
                  _boardAll = true;
                  _selectedBoardUids.clear();
                  if (_mode == TaskAssignmentMode.board) {
                    _selectedTeam = null;
                  }
                }),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ),
              if (_mode == TaskAssignmentMode.board) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.goldDark,
                        AppColors.gold,
                        AppColors.goldLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu görev yalnızca Yönetim Kurulu üyelerine atanır.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildBoardScopeSelector(),
              ],
              const SizedBox(height: 12),
              if (_selectedTeam != null && _mode == TaskAssignmentMode.single)
                TaskTeamMemberSelector(
                  teamId: _selectedTeam!.id,
                  selectedUid: _selectedUid,
                  onChanged: (uid, name) => setState(() {
                    _selectedUid = uid;
                    _selectedName = name;
                  }),
                ),
              if (_selectedTeam != null && _mode == TaskAssignmentMode.unit)
                TaskTeamUnitSelector(
                  teamId: _selectedTeam!.id,
                  value: _selectedUnit,
                  allowedUnitIds: _allowedUnitIdsFor(_selectedTeam!.id),
                  onChanged: (u) => setState(() {
                    _selectedUnit = u;
                    _selectedUid = null;
                    _selectedName = null;
                  }),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Görev Başlığı *', hintText: 'Örn: Atölye temizliği'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                    labelText: 'Açıklama', hintText: 'Görev detayı (isteğe bağlı)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pointsCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Puan', hintText: '10'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: Text(_pickedImage != null ? 'Görsel Seçildi' : 'Görsel Ekle'),
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PlatformImageFile(
                      bytes: _pickedImage!.bytes,
                      file: _pickedImage!.dartFile,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('İptal')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ata'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final requiresPerson =
        _mode == TaskAssignmentMode.single && _selectedUid == null;
    final requiresUnit =
        _mode == TaskAssignmentMode.unit && _selectedUnit == null;

    if (_selectedUnit != null &&
        _selectedTeam != null &&
        !_allowedUnitIdsFor(_selectedTeam!.id).contains(_selectedUnit!['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bu birime görev atama yetkiniz yok.'),
          backgroundColor: AppColors.error));
      return;
    }

    final isBoardMode = _mode == TaskAssignmentMode.board;
    if (isBoardMode) {
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Görev başlığı zorunludur'),
            backgroundColor: AppColors.error));
        return;
      }
      if (!_isBoardCreator) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Yönetim Kurulu görevi atama yetkiniz yok.'),
            backgroundColor: AppColors.error));
        return;
      }
      if (!_boardAll && _selectedBoardUids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('En az bir Yönetim Kurulu üyesi seçmelisiniz'),
            backgroundColor: AppColors.error));
        return;
      }
    } else {
      if (title.isEmpty || (_selectedTeam == null) || requiresPerson) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Takım ve başlık zorunludur'),
            backgroundColor: AppColors.error));
        return;
      }
      if (requiresUnit) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Birim seçmelisiniz'),
            backgroundColor: AppColors.error));
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      final firestore = ref.read(firestoreProvider);
      final notifService = ref.read(notificationServiceProvider);
      final points = int.tryParse(_pointsCtrl.text.trim()) ?? 10;

      final recipients = <({String uid, String name})>[];
       if (isBoardMode) {
         final boardSnap = await firestore
             .collection('users')
             .where('role',
                 whereIn: [
                   'board_president',
                   'board_vice_president',
                   'board_member',
                 ])
             .get();
         for (final doc in boardSnap.docs) {
           recipients.add((
             uid: doc.id,
             name: (doc.data()['displayName'] as String?) ?? 'Üye',
           ));
         }
         // Ayrıca titles array'inde board_member/board_president olan kullanıcıları da ekle
         final titlesSnap = await firestore
             .collection('users')
             .get();
         for (final doc in titlesSnap.docs) {
           final titles = (doc.data()['titles'] as List?) ?? [];
           final hasBoard = titles.any((t) {
             final map = t as Map;
             final titleType = map['titleType'] as String?;
             final isActive = map['isActive'] as bool? ?? true;
             return isActive && TitleType.isBoardTitle(titleType);
           });
           if (hasBoard && !recipients.any((r) => r.uid == doc.id)) {
             recipients.add((
               uid: doc.id,
               name: (doc.data()['displayName'] as String?) ?? 'Üye',
             ));
           }
         }
         // "Kuruldan Belirli Kişileri Seç" tercihinde yalnızca seçilenlere ata.
         if (!_boardAll) {
           recipients.removeWhere((r) => !_selectedBoardUids.contains(r.uid));
         }
         if (recipients.isEmpty) {
           setState(() => _loading = false);
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text(_boardAll
                     ? 'Yönetim Kurulu üyesi bulunamadı.'
                     : 'Seçilen kişiler Yönetim Kurulu üyesi olarak bulunamadı.'),
                 backgroundColor: AppColors.warning));
           }
           return;
         }
         recipients.sort((a, b) => a.name.compareTo(b.name));
      } else if (_mode == TaskAssignmentMode.unit) {
        final unitDoc =
            await firestore.collection('units').doc(_selectedUnit!['id'] as String).get();
        final memberUids = (unitDoc.data()?['memberUids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        if (memberUids.isNotEmpty) {
          for (var i = 0; i < memberUids.length; i += 10) {
            final chunk = memberUids.sublist(
                i,
                i + 10 > memberUids.length ? memberUids.length : i + 10);
            final snap = await firestore
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (final doc in snap.docs) {
              final data = doc.data();
              recipients.add((
                uid: doc.id,
                name: (data['displayName'] as String?) ?? 'Üye',
              ));
            }
          }
          recipients.sort((a, b) => a.name.compareTo(b.name));
        }
        if (recipients.isEmpty) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bu birimde görev atanacak üye yok.'),
                backgroundColor: AppColors.warning));
          }
          return;
        }
      } else if (_mode == TaskAssignmentMode.team) {
        final members = ref.read(teamMembersProvider(_selectedTeam!.id)).valueOrNull;
        if (members == null || members.isEmpty) {
          final teamDoc =
              await firestore.collection('teams').doc(_selectedTeam!.id).get();
          final memberIds = (teamDoc.data()?['memberIds'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [];
          for (final uid in memberIds) {
            final doc = await firestore.collection('users').doc(uid).get();
            recipients.add((
              uid: uid,
              name: (doc.data()?['displayName'] as String?) ?? 'Üye',
            ));
          }
        } else {
          for (final m in members) {
            recipients.add((uid: m.uid, name: m.displayName));
          }
        }
        if (recipients.isEmpty) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bu takımda görev atanacak üye yok.'),
                backgroundColor: AppColors.warning));
          }
          return;
        }
      } else {
        recipients.add((uid: _selectedUid!, name: _selectedName ?? 'Üye'));
      }

      String? imageUrl;
      if (_pickedImage != null) {
        final tempId = 'task_${DateTime.now().microsecondsSinceEpoch}';
        final storageRef =
            FirebaseStorage.instance.ref().child('tasks/$tempId.jpg');
        final compressed = await _pickedImage!.compressedUploadBytes();
        if (compressed.isNotEmpty) {
          await storageRef.putData(compressed);
        } else if (_pickedImage!.dartFile != null) {
          await storageRef.putFile(_pickedImage!.dartFile!);
        } else if (_pickedImage!.bytes != null) {
          await storageRef.putData(_pickedImage!.bytes!);
        }
        imageUrl = await storageRef.getDownloadURL();
      }

      final bulkGroupId = _mode != TaskAssignmentMode.single
          ? 'bulk_${DateTime.now().microsecondsSinceEpoch}'
          : null;

      for (final recipient in recipients) {
        final docRef = await firestore.collection('tasks').add({
          'title': title,
          'description': _descCtrl.text.trim(),
          'assignedTo': recipient.uid,
          'assignedToName': recipient.name,
          'assignedByName': user?.displayName ?? 'Admin',
          'assignedBy': user?.uid,
          'points': points,
          'status': 'assigned',
          'createdAt': FieldValue.serverTimestamp(),
          'teamId': _selectedTeam?.id,
          'teamName': _selectedTeam?.name,
          'unitId': _selectedUnit?['id'],
          'unitName': _selectedUnit?['name'],
          'pointsAwarded': false,
          'imageUrl': imageUrl,
          'bulkGroupId': bulkGroupId,
          'assignmentMode': _mode.name,
        });
        await notifService.send(
          recipientId: recipient.uid,
          title: 'Yeni görev atandı',
          body: 'Sana "$title" görevi atandı. +$points puan',
          type: 'task_assigned',
          relatedId: docRef.id,
        );
      }

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(recipients.length > 1
                ? '${recipients.length} kişiye görev atandı.'
                : 'Görev atandı.'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}

/// Dropdown for selecting a unit within a team.
class TaskTeamUnitSelector extends ConsumerWidget {
  final String teamId;
  final Map<String, dynamic>? value;
  final Set<String>? allowedUnitIds;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const TaskTeamUnitSelector({
    super.key,
    required this.teamId,
    required this.value,
    this.allowedUnitIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(teamUnitsProvider(teamId));
    return unitsAsync.when(
      data: (units) {
        final visible = allowedUnitIds == null
            ? units
            : units.where((u) => allowedUnitIds!.contains(u['id'])).toList();
        return DropdownButtonFormField<Map<String, dynamic>>(
          dropdownColor: AppColors.surface2,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
              labelText: 'Birim', hintText: 'Birim seçin (isteğe bağlı)'),
          initialValue: value,
          items: [
            DropdownMenuItem<Map<String, dynamic>>(
              value: null,
              child: Text('Birim seçilmedi',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ...visible.map((u) => DropdownMenuItem(
                value: u, child: Text(u['name'] as String? ?? ''))),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Dropdown for selecting a team member.
class TaskTeamMemberSelector extends ConsumerWidget {
  final String teamId;
  final String? selectedUid;
  final void Function(String uid, String name) onChanged;

  const TaskTeamMemberSelector({
    super.key,
    required this.teamId,
    required this.selectedUid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    return membersAsync.when(
      data: (members) => DropdownButtonFormField<String>(
        dropdownColor: AppColors.surface2,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
            labelText: 'Kişi *', hintText: 'Görev atanacak kişi'),
        initialValue: selectedUid,
        items: members
            .map((u) => DropdownMenuItem(value: u.uid, child: Text(u.displayName)))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            final m = members.firstWhere((m) => m.uid == v);
            onChanged(v, m.displayName);
          }
        },
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Üyeler yüklenemedi',
          style: TextStyle(color: AppColors.error)),
    );
  }
}