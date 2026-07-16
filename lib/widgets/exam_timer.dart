import 'package:flutter/material.dart';

class ExamTimer extends StatelessWidget {
  final DateTime endTime;
  const ExamTimer({super.key, required this.endTime});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final remaining = endTime.difference(DateTime.now());
        final total = remaining.isNegative ? Duration.zero : remaining;

        final minutes = total.inMinutes.toString().padLeft(2, '0');
        final seconds = (total.inSeconds % 60).toString().padLeft(2, '0');

        return Text(
          '$minutes:$seconds',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: total.inMinutes < 5 ? cs.error : cs.onPrimary,
          ),
        );
      },
    );
  }
}
