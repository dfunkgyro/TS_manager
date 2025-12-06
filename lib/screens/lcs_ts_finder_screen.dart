import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:track_sections_manager/models/lcs_ts_models.dart';
import 'package:track_sections_manager/services/lcs_ts_service.dart';

/// Main screen for LCS Track Section Finder with tabs for LCS and Platform search
class LcsTsFinderScreen extends StatefulWidget {
  const LcsTsFinderScreen({super.key});

  @override
  State<LcsTsFinderScreen> createState() => _LcsTsFinderScreenState();
}

class _LcsTsFinderScreenState extends State<LcsTsFinderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<LcsTsAppData> _dataFuture;
  final LcsTsService _service = LcsTsService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dataFuture = _service.loadAppData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Section Tools'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.route), text: 'By LCS'),
            Tab(icon: Icon(Icons.train), text: 'By Platform'),
          ],
        ),
      ),
      body: FutureBuilder<LcsTsAppData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load data: ${snapshot.error}',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _dataFuture = _service.loadAppData();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;

            return TabBarView(
              controller: _tabController,
              children: [
                _LcsSearchTab(data: data, service: _service),
                _PlatformSearchTab(data: data),
              ],
            );
          },
        ),
    );
  }
}

/// Tab for LCS-based track section search
class _LcsSearchTab extends StatefulWidget {
  final LcsTsAppData data;
  final LcsTsService service;

  const _LcsSearchTab({
    required this.data,
    required this.service,
  });

  @override
  State<_LcsSearchTab> createState() => _LcsSearchTabState();
}

class _LcsSearchTabState extends State<_LcsSearchTab> {
  LcsRecord? _selectedLcs;
  final TextEditingController _lcsController = TextEditingController();
  final TextEditingController _startController = TextEditingController(text: '0');
  final TextEditingController _endController = TextEditingController(text: '0');
  List<TsRecord> _results = [];
  double? _absStart;
  double? _absEnd;
  String? _error;

  @override
  void dispose() {
    _lcsController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() {
      _error = null;
      _results = [];
      _absStart = null;
      _absEnd = null;
    });

    final lcsCodeInput = _lcsController.text.trim();
    if (lcsCodeInput.isEmpty) {
      setState(() => _error = 'Please enter an LCS code.');
      return;
    }

    final lcs = widget.service.findLcsByCode(lcsCodeInput, widget.data);
    if (lcs == null) {
      setState(() => _error = 'LCS "$lcsCodeInput" not found.');
      return;
    }

    double? startM = double.tryParse(_startController.text.replaceAll(',', '.'));
    double? endM = double.tryParse(_endController.text.replaceAll(',', '.'));

    if (startM == null || endM == null) {
      setState(() => _error = 'Start and End meterage must be numbers.');
      return;
    }

    if (endM > lcs.lcsLength && lcs.lcsLength > 0) {
      _error =
          'Warning: End meterage (${endM.toStringAsFixed(2)} m) is beyond LCS length (${lcs.lcsLength.toStringAsFixed(2)} m). Results may be partial.';
    }

    final matching = widget.service.findTrackSections(
      lcs: lcs,
      startMeterage: startM,
      endMeterage: endM,
      data: widget.data,
    );

    final absStart = lcs.chainageStart + startM;
    final absEnd = lcs.chainageStart + endM;

    setState(() {
      _selectedLcs = lcs;
      _absStart = absStart;
      _absEnd = absEnd;
      _results = matching;
    });
  }

  void _copyResults() {
    if (_results.isEmpty) return;

    final tsIds = _results.map((ts) => ts.tsId.toString()).join(', ');
    Clipboard.setData(ClipboardData(text: tsIds));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Track Section IDs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allLcsCodes = widget.data.lcsList
        .map((l) => l.displayCode)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        final content = isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildInputCard(allLcsCodes)),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _buildResultsCard()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInputCard(allLcsCodes),
                  const SizedBox(height: 16),
                  _buildResultsCard(),
                ],
              );

        return content;
      },
    );
  }

  Widget _buildInputCard(List<String> allLcsCodes) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Input',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return allLcsCodes.where((String option) =>
                    option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _lcsController.text = selection;
                final lcs = widget.service.findLcsByCode(selection, widget.data);
                setState(() {
                  _selectedLcs = lcs;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                controller.text = _lcsController.text;
                _lcsController.addListener(() {
                  if (controller.text != _lcsController.text) {
                    controller.text = _lcsController.text;
                  }
                });
                return TextField(
                  controller: _lcsController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'LCS code',
                    helperText: 'e.g. M134/MIRLO',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedLcs = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            if (_selectedLcs != null) ...[
              Text(
                _selectedLcs!.shortDescription.isNotEmpty
                    ? _selectedLcs!.shortDescription
                    : 'LCS on VCC ${_selectedLcs!.vcc.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              Text(
                'LCS length: ${_selectedLcs!.lcsLength.toStringAsFixed(2)} m '
                '(chainage ${_selectedLcs!.chainageStart.toStringAsFixed(3)}'
                ' → ${_selectedLcs!.chainageEnd.toStringAsFixed(3)})',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Start meterage (m)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _endController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'End meterage (m)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: _error!.startsWith('Warning') ? Colors.orange : Colors.red,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _runSearch,
                icon: const Icon(Icons.search),
                label: const Text('Find Track Sections'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _results.isEmpty
            ? const Center(
                child: Text(
                  'No results yet.\nEnter an LCS and meterage range, then press "Find Track Sections".',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Results',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copyResults,
                        tooltip: 'Copy TS IDs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedLcs != null && _absStart != null && _absEnd != null)
                    Text(
                      'LCS: ${_selectedLcs!.displayCode} '
                      '(VCC ${_selectedLcs!.vcc.toStringAsFixed(0)})\n'
                      'Absolute chainage: ${_absStart!.toStringAsFixed(3)} → ${_absEnd!.toStringAsFixed(3)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Matching Track Sections: ${_results.length}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 500),
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('TS')),
                              const DataColumn(label: Text('Segment')),
                              const DataColumn(label: Text('Chainage Start')),
                              if (widget.data.platformsByTs.isNotEmpty)
                                const DataColumn(label: Text('Platforms')),
                            ],
                            rows: _results.map((ts) {
                              final plats = widget.data.platformsByTs[ts.tsId] ?? const [];
                              final platformsText = plats.isEmpty ? '-' : plats.join(', ');
                              return DataRow(
                                cells: [
                                  DataCell(Text(ts.tsId.toString())),
                                  DataCell(Text(ts.segment)),
                                  DataCell(Text(ts.chainageStart.toStringAsFixed(3))),
                                  if (widget.data.platformsByTs.isNotEmpty)
                                    DataCell(
                                      Tooltip(
                                        message: platformsText,
                                        child: Text(
                                          platformsText,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tab for Platform-based track section search
class _PlatformSearchTab extends StatefulWidget {
  final LcsTsAppData data;

  const _PlatformSearchTab({required this.data});

  @override
  State<_PlatformSearchTab> createState() => _PlatformSearchTabState();
}

class _PlatformSearchTabState extends State<_PlatformSearchTab> {
  String _query = '';
  PlatformRecord? _selected;

  @override
  Widget build(BuildContext context) {
    final platforms = widget.data.platformList;
    final names = platforms.map((p) => p.platform).toList()..sort();

    final filtered = _query.isEmpty
        ? platforms
        : platforms
            .where((p) =>
                p.platform.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Platform → Track Sections',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue value) {
                      if (value.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return names.where((n) =>
                          n.toLowerCase().contains(value.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      setState(() {
                        _query = selection;
                        _selected = platforms.firstWhere(
                            (p) => p.platform.toLowerCase() == selection.toLowerCase());
                      });
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      controller.text = _query;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Platform name',
                          helperText: 'e.g. Edgware Road plt 1 (WB)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                            _selected = null;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Platforms matched: ${filtered.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No platforms match your search.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final selected = _selected?.platform == p.platform;
                          return ExpansionTile(
                            initiallyExpanded: selected,
                            title: Text(
                              p.platform,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Track Sections: ${p.trackSections.length}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: p.trackSections
                                      .map((ts) => Chip(
                                            label: Text(ts.toString()),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ))
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

