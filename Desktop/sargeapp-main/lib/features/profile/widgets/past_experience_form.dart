import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_profile_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../team/models/team_models.dart';
import '../../team/providers/team_providers.dart';

const _uuid = Uuid();

/// AŞAMA 4.2 — RBAC-aware, dynamically cascading "Deneyim Ekle" form.
///
/// The visible options depend on the user's CURRENT privileges:
///
/// * **Yönetim Kurulu Deneyimi** — only for users whose effective roles include
///   `admin` or any Yönetim Kurulu role (Başkan / Başkan Yrd. / Üye).
///   Selecting it reveals a rank dropdown (Başkan / Başkan Yardımcısı / Üye).
/// * **Takım Deneyimi** — visible to EVERYONE, but captains and plain members
///   see ONLY this option (they cannot claim board experience).
///   Selecting it cascades: Takım → Sorumluluk → Birim.
///   "Takım Kaptanı" seçilirse "Birim" alanı GİZLENİR (kaptanın birimi olmaz);
///   "Birim Sorumlusu" / "Takım Üyesi" seçilirse birim GÖRÜNÜR ve ZORUNLUDUR.
///
/// Returns the created [PastExperience] through `Navigator.pop`; the parent
/// (profile editor) persists it on save.
class PastExperienceFormSheet extends ConsumerStatefulWidget {
  final AppUser currentUser;
  const PastExperienceFormSheet({super.key, required this.currentUser});

  @override
  ConsumerState<PastExperienceFormSheet> createState() =>
      _PastExperienceFormSheetState();
}

class _PastExperienceFormSheetState
    extends ConsumerState<PastExperienceFormSheet> {
  static const _kindBoard = PastExperience.kindBoard;
  static const _kindTeam = PastExperience.kindTeam;

  String? _kind;
  String? _boardRole;
  ClubTeam? _team;
  String? _unitName;
  String? _teamRole;

  late int _startYear = DateTime.now().year;
  int? _endYear;

  /// Whether the user may record Yönetim Kurulu experience: requires Admin or a
  /// Yönetim Kurulu role. Captains and plain members are excluded.
  bool get _canAddBoardExperience {
    final user = widget.currentUser;
    final isAdmin = user.role == TitleType.admin || user.isAdmin;
    final isBoard = TitleType.isBoardTitle(user.role) || user.isBoardMember;
    return isAdmin || isBoard;
  }

  List<int> get _years {
    final now = DateTime.now().year;
    return [for (var y = now; y >= now - 40; y--) y];
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(clubTeamsProvider);
    final teams = teamsAsync.valueOrNull ?? const <ClubTeam>[];
    final units = _team == null
        ? const <Map<String, dynamic>>[]
        : (ref.watch(teamUnitsProvider(_team!.id)).valueOrNull ??
            const <Map<String, dynamic>>[]);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Deneyim Ekle',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildKindDropdown(),
                    const SizedBox(height: 12),
                    if (_kind == _kindBoard) _buildBoardFields(),
                    if (_kind == _kindTeam) _buildTeamFields(teams, units),
                    const SizedBox(height: 12),
                    _buildYearFields(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sargeGold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        AppColors.sargeGold.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Listeye Ekle',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Seçenek 1 / Seçenek 2 — RBAC filtered top-level dropdown.
  Widget _buildKindDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _kind,
      dropdownColor: AppColors.surface2,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: _decoration('Deneyim Türü', Icons.category_outlined),
      items: [
        if (_canAddBoardExperience)
          const DropdownMenuItem(
            value: _kindBoard,
            child: Text('Yönetim Kurulu Deneyimi'),
          ),
        const DropdownMenuItem(
          value: _kindTeam,
          child: Text('Takım Deneyimi'),
        ),
      ],
      onChanged: (v) => setState(() {
        _kind = v;
        _boardRole = null;
        _team = null;
        _unitName = null;
        _teamRole = null;
      }),
    );
  }

  Widget _buildBoardFields() {
    return DropdownButtonFormField<String>(
      initialValue: _boardRole,
      dropdownColor: AppColors.surface2,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: _decoration('Rütbe Seç', Icons.workspace_premium_outlined),
      items: const [
        DropdownMenuItem(
          value: TitleType.boardPresident,
          child: Text('Başkan'),
        ),
        DropdownMenuItem(
          value: TitleType.boardVicePresident,
          child: Text('Başkan Yardımcısı'),
        ),
        DropdownMenuItem(
          value: TitleType.boardMember,
          child: Text('Üye'),
        ),
      ],
      onChanged: (v) => setState(() => _boardRole = v),
    );
  }

  /// Kademeli akış: Takım → Sorumluluk → Birim.
  ///
  /// Kural (Madde 5): "Takım Kaptanı" seçilirse birim ALANI HİÇ GÖSTERİLMEZ
  /// (kaptanın birimi olmaz). "Birim Sorumlusu" veya "Takım Üyesi" seçilirse
  /// "Birim Seç" alanı GÖRÜNÜR ve ZORUNLUDUR.
  Widget _buildTeamFields(
      List<ClubTeam> teams, List<Map<String, dynamic>> units) {
    final roleRequiresUnit =
        _teamRole != null && _teamRole != TitleType.captain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _team?.id,
          isExpanded: true,
          dropdownColor: AppColors.surface2,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: _decoration('Takım Seç', Icons.groups_outlined),
          items: teams
              .map((t) => DropdownMenuItem<String>(
                    value: t.id,
                    child: Text(t.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() {
            _team = teams.where((t) => t.id == v).firstOrNull;
            _unitName = null;
          }),
        ),
        const SizedBox(height: 12),
        // 1) Sorumluluk — takım seçildikten sonra İLK gelen alan.
        DropdownButtonFormField<String>(
          initialValue: _teamRole,
          dropdownColor: AppColors.surface2,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: _decoration('Sorumluluk Seç', Icons.badge_outlined),
          items: const [
            DropdownMenuItem(
              value: TitleType.captain,
              child: Text('Takım Kaptanı'),
            ),
            DropdownMenuItem(
              value: TitleType.unitLead,
              child: Text('Birim Sorumlusu'),
            ),
            DropdownMenuItem(
              value: TitleType.member,
              child: Text('Takım Üyesi'),
            ),
          ],
          onChanged: _team == null
              ? null
              : (v) => setState(() {
                    _teamRole = v;
                    // Kaptanın birimi yoktur → birim seçimini temizle.
                    if (v == TitleType.captain) _unitName = null;
                  }),
        ),
        // 2) Birim — yalnızca Birim Sorumlusu / Takım Üyesi için ve ZORUNLU.
        if (roleRequiresUnit) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unitName,
            isExpanded: true,
            dropdownColor: AppColors.surface2,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _decoration('Birim Seçiniz', Icons.folder_outlined),
            items: units.map((u) {
              final name = u['name'] as String? ?? '';
              return DropdownMenuItem<String>(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (v) => setState(() => _unitName = v),
          ),
        ],
      ],
    );
  }

  Widget _buildYearFields() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _startYear,
            dropdownColor: AppColors.surface2,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _decoration('Başlangıç', Icons.login_outlined),
            items: _years
                .map((y) => DropdownMenuItem<int>(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() {
              _startYear = v ?? _startYear;
              if (_endYear != null && _endYear! < _startYear) _endYear = null;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _endYear,
            dropdownColor: AppColors.surface2,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _decoration('Bitiş', Icons.logout_outlined),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Devam ediyor'),
              ),
              ..._years
                  .where((y) => y >= _startYear)
                  .map((y) => DropdownMenuItem<int?>(
                        value: y,
                        child: Text('$y'),
                      )),
            ],
            onChanged: (v) => setState(() => _endYear = v),
          ),
        ),
      ],
    );
  }

  bool get _canSubmit {
    if (_kind == _kindBoard) return _boardRole != null;
    if (_kind == _kindTeam) {
      if (_team == null || _teamRole == null) return false;
      // Kaptanın birimi yoktur; diğer sorumluluklar için birim ZORUNLUDUR.
      if (_teamRole == TitleType.captain) return true;
      return _unitName != null && _unitName!.isNotEmpty;
    }
    return false;
  }

  void _submit() {
    final isBoard = _kind == _kindBoard;
    final isCaptain = !isBoard && _teamRole == TitleType.captain;
    final entry = PastExperience(
      id: _uuid.v4(),
      kind: isBoard ? PastExperience.kindBoard : PastExperience.kindTeam,
      roleType: isBoard ? _boardRole! : _teamRole!,
      teamId: isBoard ? null : _team?.id,
      teamName: isBoard ? null : _team?.name,
      // Takım Kaptanı için birim daima null'dur.
      unitName: (isBoard || isCaptain) ? null : _unitName,
      startYear: _startYear,
      endYear: _endYear,
    );
    Navigator.pop(context, entry);
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 19, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        borderSide: const BorderSide(color: AppColors.sargeGold, width: 1.4),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: AppColors.sargeGold),
    );
  }
}
