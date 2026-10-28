import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/texter_ui.dart';

/// Pick one or more people. Pops with the list of chosen user ids.
class UserPickerScreen extends StatefulWidget {
  const UserPickerScreen({
    super.key,
    required this.title,
    required this.loader,
    this.actionLabel = 'Add',
    this.multi = true,
    this.emptyText = 'No one to show',
  });

  final String title;
  final Future<List<models.Document>> Function() loader;
  final String actionLabel;
  final bool multi;
  final String emptyText;

  @override
  State<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<UserPickerScreen> {
  List<models.Document> _users = [];
  final Set<String> _selected = {};
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = await widget.loader();
      if (mounted) setState(() => _users = u);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final list = _users
        .where((d) => _query.isEmpty || (d.data['name'] ?? '').toString().toLowerCase().contains(_query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.multi)
            TextButton(
              onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
              child: Text(
                '${widget.actionLabel}${_selected.isEmpty ? '' : ' (${_selected.length})'}',
                style: TextStyle(color: _selected.isEmpty ? u.subtext : u.accent, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    style: AppTheme.body(color: u.text),
                    decoration: InputDecoration(
                      hintText: 'Search people',
                      prefixIcon: Icon(Icons.search, color: u.subtext),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? Center(child: Text(widget.emptyText, style: AppTheme.body(color: u.subtext)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final d = list[i];
                            final name = (d.data['name'] ?? '').toString();
                            final picked = _selected.contains(d.$id);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: picked ? u.accent.withOpacity(0.10) : u.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: picked ? u.accent : u.border),
                              ),
                              child: ListTile(
                                onTap: () {
                                  if (!widget.multi) {
                                    Navigator.pop(context, [d.$id]);
                                    return;
                                  }
                                  setState(() => picked ? _selected.remove(d.$id) : _selected.add(d.$id));
                                },
                                leading: TexterAvatar(name: name, url: (d.data['avatarUrl'] ?? '').toString(), size: 42),
                                title: Text(name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: u.text)),
                                trailing: widget.multi
                                    ? Icon(picked ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: picked ? u.accent : u.subtext)
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
