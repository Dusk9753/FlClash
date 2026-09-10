part of '../action.dart';

@Riverpod(keepAlive: true)
class ProfilesAction extends _$ProfilesAction {
  static const String _systemProfileIdPrefsKey = 'xboard_system_profile_id';

  @override
  void build() {}

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final selectedMap = Map<String, String>.from(currentProfile.selectedMap)
        ..[groupName] = proxyName;
      ref
          .read(profilesProvider.notifier)
          .put(currentProfile.copyWith(selectedMap: selectedMap));
    }
  }

  Future<void> syncSystemProfile(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getInt(_systemProfileIdPrefsKey);
    final profiles = ref.read(profilesProvider);
    final existingProfile = profiles.getProfile(profileId) ??
        profiles.where((profile) => profile.url == url).firstOrNull;
    if (existingProfile != null) {
      if (prefs.getInt(_systemProfileIdPrefsKey) != existingProfile.id) {
        await prefs.setInt(_systemProfileIdPrefsKey, existingProfile.id);
      }
      await updateProfile(
        existingProfile.copyWith(url: url, autoUpdate: true),
        showLoading: true,
      );
      return;
    }

    final createdProfile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () => Profile.normal(url: url).update(),
      title: currentAppLocalizations.profiles,
    );
    if (createdProfile == null) {
      return;
    }
    putProfile(createdProfile);
    await prefs.setInt(_systemProfileIdPrefsKey, createdProfile.id);
  }

  Future<void> deleteProfile(int id) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_systemProfileIdPrefsKey) == id) {
      await prefs.remove(_systemProfileIdPrefsKey);
    }
    await ref.read(profilesProvider.notifier).del(id);
    await clearEffect(id);
    final currentProfileId = ref.read(currentProfileIdProvider);
    if (currentProfileId == id) {
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        ref.read(currentProfileIdProvider.notifier).value = updateId;
      } else {
        ref.read(currentProfileIdProvider.notifier).value = null;
        ref.read(setupActionProvider.notifier).setRunning(false);
      }
    }
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(profile.autoUpdateDuration)
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString(), logLevel: LogLevel.warning);
      }
    }
  }

  void putProfile(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (ref.read(currentProfileIdProvider) != null) return;
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<void> updateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) continue;
      await updateProfile(profile);
    }
  }

  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = true;
      }
      ref.read(profilesProvider.notifier).put(profile);
      final newProfile = await profile.update();
      ref.read(profilesProvider.notifier).put(newProfile);
      if (profile.id == ref.read(currentProfileIdProvider)) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
      }
    } finally {
      ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = false;
    }
  }

  void setProfileAndAutoApply(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (profile.id == ref.read(currentProfileIdProvider)) {
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    }
  }

  void reorder(List<Profile> profiles) {
    ref.read(profilesProvider.notifier).reorder(profiles);
  }

  Future<void> clearEffect(int profileId) async {
    final profilePath = await appPath.getProfilePath(profileId.toString());
    final profileFile = File(profilePath);
    final isExists = await profileFile.exists();
    if (isExists) {
      await profileFile.safeDelete(recursive: true);
    }
    final error = await coreController.clearEffect(profileId);
    if (error.isNotEmpty) {
      commonPrint.log(error, logLevel: LogLevel.warning);
    }
  }
}
