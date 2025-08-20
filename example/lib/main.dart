import 'package:flutter/material.dart';
import 'package:df_tooltip/df_tooltip.dart';

void main() => runApp(const TooltipExampleApp());

/// Root app showcasing multiple DFTooltip usage scenarios.
class TooltipExampleApp extends StatelessWidget {
  const TooltipExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DFTooltip Demo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    ),
    home: const DemoHomePage(),
  );
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});
  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('DFTooltip Examples'),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Basic'),
          Tab(text: 'Directions'),
          Tab(text: 'List'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: const [BasicExamples(), DirectionExamples(), ListExamples()],
    ),
  );
}

/// Basic styling & customization showcase.
class BasicExamples extends StatelessWidget {
  const BasicExamples({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        DFTooltip(
          content: const Text(
            'Simple tooltip with default styling',
            style: TextStyle(color: Colors.white),
          ),
          child: ElevatedButton(onPressed: () {}, child: const Text('Default')),
        ),
        DFTooltip(
          preferredDirection: TooltipDirection.down,
          content: const Text(
            'Appears below (preferred down)',
            style: TextStyle(color: Colors.white),
          ),
          child: const Chip(label: Text('Down')),
        ),
        DFTooltip(
          duration: const Duration(seconds: 3),
          content: const Text(
            'Auto hides after 3 seconds',
            style: TextStyle(color: Colors.white),
          ),
          child: const Icon(Icons.timer_outlined, size: 32),
        ),
        DFTooltip(
          bgColor: Colors.blueGrey.shade900.withOpacity(.9),
          borderRadius: BorderRadius.circular(12),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.info, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Custom color & radius',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          child: const Icon(Icons.palette_outlined, size: 32),
        ),
        DFTooltip(
          upnDownTooltipWidth: 260,
          content: const Text(
            'Width override for up/down tooltips.',
            style: TextStyle(color: Colors.white),
          ),
          child: const Icon(Icons.width_full, size: 32),
        ),
        DFTooltip(
          sideTooltipWidth: 180,
          preferredDirection: TooltipDirection.right,
          content: const Text(
            'Custom width for side tooltip.',
            style: TextStyle(color: Colors.white),
          ),
          child: const Icon(Icons.swap_horiz, size: 32),
        ),
      ],
    ),
  );
}

/// Shows all directions (auto flips if not enough space).
class DirectionExamples extends StatelessWidget {
  const DirectionExamples({super.key});

  Widget _directionTile(String label, TooltipDirection dir, Color color) =>
      DFTooltip(
        preferredDirection: dir,
        content: Text(
          '$label tooltip',
          style: const TextStyle(color: Colors.white),
        ),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Center(
    child: Wrap(
      spacing: 32,
      runSpacing: 32,
      children: [
        _directionTile('Up', TooltipDirection.up, Colors.indigo.shade100),
        _directionTile('Down', TooltipDirection.down, Colors.indigo.shade100),
        _directionTile('Left', TooltipDirection.left, Colors.indigo.shade100),
        _directionTile('Right', TooltipDirection.right, Colors.indigo.shade100),
      ],
    ),
  );
}

/// Demonstrates auto-hide on scroll.
class ListExamples extends StatelessWidget {
  const ListExamples({super.key});

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: 25,
    separatorBuilder: (_, __) => const Divider(height: 0),
    itemBuilder: (context, index) => ListTile(
      title: Text('Item #$index'),
      trailing: DFTooltip(
        preferredDirection: TooltipDirection.left,
        content: Text(
          'Tooltip for item $index. Scroll to auto-hide.',
          style: const TextStyle(color: Colors.white),
        ),
        child: const Icon(Icons.info_outline),
      ),
    ),
  );
}
