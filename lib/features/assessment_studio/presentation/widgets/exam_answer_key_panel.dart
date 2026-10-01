import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../application/exam_code_notifier.dart';
import '../../domain/models/exam_answer_key.dart';

/// Tab 6: Bảng Đáp án và Hướng dẫn chấm chi tiết (Sections 37, 68).
class ExamAnswerKeyPanel extends ConsumerWidget {
  const ExamAnswerKeyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeState = ref.watch(examCodeNotifierProvider);
    final codes = codeState.codes;
    final keys = codeState.answerKeys;

    if (codes.isEmpty) {
      return const Center(
        child: Text('Vui lòng sinh mã đề tại tab "Mã đề" để xem bảng đáp án.'),
      );
    }

    final int questionCount = codes.first.questionCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              const Text(
                'BẢNG ĐÁP ÁN TỔNG HỢP CÁC MÃ ĐỀ THI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${codes.length} MÃ ĐỀ ĐỒNG BỘ',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cross-Code Answer Matrix Table
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.1)),
                columns: [
                  const DataColumn(label: Text('Câu hỏi', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...codes.map((c) => DataColumn(
                        label: Text('Mã ${c.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      )),
                  const DataColumn(label: Text('Điểm', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('Trích yếu câu hỏi', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List.generate(questionCount, (qIndex) {
                  final qNum = qIndex + 1;
                  String snippet = '';
                  double score = 0.25;

                  final cells = <DataCell>[
                    DataCell(Text('Câu $qNum', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ];

                  for (final code in codes) {
                    final key = keys[code.code];
                    final item = key?.items.firstWhere(
                      (it) => it.questionNumber == qNum,
                      orElse: () => ExamAnswerKeyItem(
                        questionNumber: qNum,
                        correctDisplayAnswer: '-',
                        score: 0.25,
                        questionId: '',
                        promptSnippet: '',
                      ),
                    );

                    snippet = item?.promptSnippet ?? snippet;
                    score = item?.score ?? score;

                    cells.add(
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item?.correctDisplayAnswer ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  cells.add(DataCell(Text('${score.toStringAsFixed(2)} đ')));
                  cells.add(
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: Text(snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  );

                  return DataRow(cells: cells);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
