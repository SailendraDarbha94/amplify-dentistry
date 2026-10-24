import 'package:ampdent_core/ampdent_core.dart';
import 'package:ampdent_mobile/core/app_strings.dart';
import 'package:ampdent_mobile/core/providers.dart';
import 'package:ampdent_ui/ampdent_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chairs (operatories) that appointments are booked against.
class ChairsPage extends ConsumerWidget {
  /// Creates the page.
  const ChairsPage({super.key});

  Future<String?> _askName(BuildContext context, {String? initial}) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial == null ? 'Add chair' : 'Rename chair'),
        content: TextField(
          key: const ValueKey('chair-name'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Chair name'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            key: const ValueKey('chair-save'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.strings.save),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final chairs = ref.read(chairsProvider).value ?? const <Chair>[];
    final name = await _askName(context);
    if (name == null || name.isEmpty) return;
    final ctx = ref.read(actorContextProvider);
    await ref
        .read(clinicRepositoryProvider)
        .upsertChair(
          ctx,
          Chair(
            id: newId(),
            clinicId: ctx.clinicId,
            name: name,
            sortOrder: chairs.length,
          ),
        );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Chair chair) async {
    final name = await _askName(context, initial: chair.name);
    if (name == null || name.isEmpty || name == chair.name) return;
    await ref
        .read(clinicRepositoryProvider)
        .upsertChair(
          ref.read(actorContextProvider),
          chair.copyWith(name: name),
        );
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    Chair chair,
  ) async {
    final ok = await ConfirmSheet.show(
      context,
      title: 'Deactivate ${chair.name}?',
      message: 'Past appointments keep the chair; new ones cannot use it.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(clinicRepositoryProvider)
        .deactivateChair(ref.read(actorContextProvider), chair.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final chairs = ref.watch(chairsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chairs')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('chairs-add'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(s.add),
      ),
      body: chairs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.chair_outlined,
                title: s.nothingHere,
                message: 'Add at least one chair to book appointments.',
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    key: ValueKey('chair-row-${c.id}'),
                    leading: const Icon(Icons.chair_outlined),
                    title: Text(c.name),
                    subtitle: Text('Order ${c.sortOrder + 1}'),
                    trailing: list.length > 1
                        ? IconButton(
                            tooltip: 'Deactivate',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _deactivate(context, ref, c),
                          )
                        : null,
                    onTap: () => _rename(context, ref, c),
                  );
                },
              ),
      ),
    );
  }
}
