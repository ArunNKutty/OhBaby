import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../auth/firebase_sign_in.dart';
import '../data/feeding_store.dart';
import '../sync/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// "3 days old", "5 weeks old", "1 month old", "2 years old".
String ageLabel(DateTime birth, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(birth.year, birth.month, birth.day)).inDays;
  if (days < 0) return '';
  if (days == 0) return 'Born today';
  String n(int v, String unit) => '$v $unit${v == 1 ? '' : 's'} old';
  if (days < 14) return n(days, 'day');
  var months = (now.year - birth.year) * 12 + now.month - birth.month;
  if (now.day < birth.day) months--;
  if (months < 2) return n(days ~/ 7, 'week');
  if (months < 24) return n(months, 'month');
  return n(months ~/ 12, 'year');
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.store, this.pickPhoto});

  final FeedingStore store;

  /// Replaces the photo picker in tests.
  final Future<XFile?> Function()? pickPhoto;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _error;

  FeedingStore get store => widget.store;

  Future<void> _choosePhoto() async {
    if (store.babyPhoto != null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.photo_outlined), title: const Text('Choose another photo'), onTap: () => Navigator.pop(context, 'pick')),
              ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove photo'), onTap: () => Navigator.pop(context, 'remove')),
            ],
          ),
        ),
      );
      if (action == 'remove') return store.setBabyPhoto(null);
      if (action != 'pick') return;
    }
    try {
      final file = await (widget.pickPhoto ?? () => ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80))();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // A photo that did not shrink (some browsers cannot resize HEIC) is still
      // kept, but not if it is too big for this phone's storage.
      if (bytes.length > 1500000) {
        setState(() => _error = 'That photo is too large. Try a smaller one.');
        return;
      }
      await store.setBabyPhoto(bytes);
      setState(() => _error = null);
    } catch (_) {
      setState(() => _error = 'The photo could not be added.');
    }
  }

  Future<void> _editName() async {
    final name = await askText(
      context,
      title: "Baby's name",
      initial: store.babyName == 'My baby' ? '' : store.babyName,
      hint: 'Name',
      done: 'Save',
      capitalization: TextCapitalization.words,
    );
    if (name == null) return;
    if (name.trim().isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    await store.setBabyName(name);
  }

  Future<void> _editBirthDate() async {
    final now = store.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: store.birthDate ?? now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) await store.setBirthDate(picked);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("Everything you've logged is saved to your account. This phone forgets it until you sign in again."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.performSync?.call();
    try {
      await signOutFirebase();
    } catch (_) {}
    await store.signOutLocal();
    _toLogin();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes the account and everything stored on the server, and signs you out of Google on this device. Entries on this phone are cleared too.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || store.accessToken == null) return;
    try {
      try {
        await deleteFirebaseAccount();
      } catch (_) {}
      await store.api?.deleteAccount(store.accessToken!);
      await signOutFirebase();
      await store.signOutLocal();
      _toLogin();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _toLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(store: store)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final birth = store.birthDate;
        final now = store.now();
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const AppHeader(),
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 18), child: Text('Profile', style: textTheme.headlineLarge)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                child: Column(
                  children: [
                    Semantics(
                      button: true,
                      label: store.babyPhoto == null ? 'Add a photo' : 'Change photo',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: _choosePhoto,
                        child: Stack(
                          children: [
                            BabyAvatar(photo: store.babyPhoto, size: 104),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: c.card, width: 3)),
                                child: Icon(Icons.photo_camera, size: 18, color: c.onPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(store.babyName, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                    if (birth != null) Text(ageLabel(birth, now), style: textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Photo stays on this phone', style: textTheme.bodySmall?.copyWith(color: c.muted)),
                    const SizedBox(height: 12),
                    const Divider(),
                    _ProfileRow(label: 'Name', value: store.babyName, onTap: _editName),
                    const Divider(),
                    _ProfileRow(
                      label: 'Date of birth',
                      value: birth == null ? 'Add' : DateFormat('d MMM y').format(birth),
                      onTap: _editBirthDate,
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Text(_error!, style: TextStyle(color: c.ink, fontWeight: FontWeight.w700))),
            const Padding(padding: EdgeInsets.fromLTRB(20, 26, 20, 10), child: SectionLabel('Appearance')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Segmented<ThemeMode>(
                expand: true,
                options: const {ThemeMode.system: 'Match phone', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'},
                selected: store.themeMode,
                onChanged: store.setThemeMode,
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(20, 26, 20, 10), child: SectionLabel('Account')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Signed in', style: textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      store.userEmail == null || store.userEmail!.isEmpty
                          ? "Everything you log is saved to your account."
                          : 'Everything you log is saved to ${store.userEmail}.',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 15),
                    ),
                    if (store.syncError != null) ...[
                      const SizedBox(height: 8),
                      Text(store.syncError!, style: TextStyle(color: c.ink)),
                    ],
                    if (store.syncing) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: _signOut, child: const Text('Log out')),
                    const SizedBox(height: 4),
                    TextButton(onPressed: _delete, child: const Text('Delete account')),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Share anonymous usage', style: textTheme.titleMedium),
                subtitle: const Text('Counts things like “a bottle was saved”, never the name, notes, or exact times. Off until you turn it on.'),
                value: store.analyticsEnabled,
                onChanged: store.setAnalyticsEnabled,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            Flexible(child: Text(value, style: TextStyle(color: c.muted, fontSize: 16), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: c.ink),
          ],
        ),
      ),
    );
  }
}
