import 'package:nguyendu_tool/features/teaching_suite/application/ai_text_generation_service.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_plan_document.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/lesson_project_data.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/question_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/rubric_models.dart';
import 'package:nguyendu_tool/features/teaching_suite/domain/models/worksheet_models.dart';

/// Predictable and offline-capable fake AI provider for tests.
/// Moved out of production lib/ as required by Phase 6B-R.
class FakeAiTextGenerationService implements AiTextGenerationService {
  final bool shouldSimulateFailure;
  final String simulatedErrorMessage;
  final bool isConfigured;

  FakeAiTextGenerationService({
    this.shouldSimulateFailure = false,
    this.simulatedErrorMessage = 'Lỗi giả lập từ FakeAiTextGenerationService',
    this.isConfigured = true,
  });

  @override
  String get providerName => 'fake_ai';

  @override
  String get currentModel => 'fake-model-educational';

  @override
  Future<LessonPlanDocument> generateLessonPlan(
    LessonProjectData project, {
    String? customInstruction,
  }) async {
    if (shouldSimulateFailure) {
      throw FormatException(simulatedErrorMessage);
    }

    final markdown = '''
# KẾ HOẠCH BÀI DẠY: ${project.lessonTitle.isNotEmpty ? project.lessonTitle : 'Truyện Kiều - Nguyễn Du'}
**Môn học:** ${project.subject} | **Lớp:** ${project.grade} | **Thời lượng:** ${project.duration}
**Bộ sách:** ${project.bookSeries}

---

## I. MỤC TIÊU
1. **Về kiến thức:**
   - Học sinh nắm được cuộc đời, sự nghiệp của đại thi hào Nguyễn Du.
   - Hiểu được giá trị hiện thực và giá trị nhân đạo sâu sắc của kiệt tác Đoạn trường tân thanh.
2. **Về năng lực:**
   - *Năng lực chung:* Tự chủ tự học, giao tiếp thuyết trình, hợp tác nhóm.
   - *Năng lực đặc thù:* Năng lực cảm thụ văn học, phân tích hình tượng nhân vật và nghệ thuật miêu tả tâm lý.
3. **Về phẩm chất:**
   - Bồi dưỡng lòng nhân ái, sự đồng cảm trước những số phận bất hạnh.
   - Trân trọng và tự hào về di sản văn hóa tinh hoa của dân tộc.

## II. THIẾT BỊ DẠY HỌC VÀ HỌC LIỆU
1. **Giáo viên:** Máy chiếu, phiếu học tập số 1 & 2, tranh ảnh minh họa Truyện Kiều.
2. **Học sinh:** Sách giáo khoa, vở ghi chép, sản phẩm chuẩn bị bài trước ở nhà.

## III. TIẾN TRÌNH DẠY HỌC
### Hoạt động 1: Khởi động (Xác định nhiệm vụ)
- **Mục tiêu:** Tạo hứng thú và kết nối trải nghiệm của học sinh về văn học trung đại.
- **Nội dung:** Xem video ngắn hoặc ngâm một đoạn thơ Kiều và nêu cảm nhận.
- **Sản phẩm:** Câu trả lời nhanh và tâm thế sẵn sàng vào bài mới.
- **Tổ chức thực hiện:**
  - *Bước 1 (Chuyển giao):* GV đặt câu hỏi gợi mở về tác phẩm kinh điển của văn học dân tộc.
  - *Bước 2 (Thực hiện):* HS suy nghĩ và thảo luận nhanh theo bàn.
  - *Bước 3 (Báo cáo):* Đại diện 2 HS phát biểu ý kiến.
  - *Bước 4 (Kết luận):* GV dẫn dắt vào bài mới.

### Hoạt động 2: Hình thành kiến thức mới
- **Mục tiêu:** Phân tích nghệ thuật ước lệ tượng trưng và bút pháp tả người của Nguyễn Du.
- **Nội dung:** Đọc hiểu văn bản, phân tích chân dung Thúy Vân và Thúy Kiều.
- **Sản phẩm:** Phiếu học tập số 1 được hoàn thành với bảng so sánh chi tiết.
- **Tổ chức thực hiện:** GV hướng dẫn chia nhóm, HS thảo luận 10 phút và trình bày bảng tổng hợp.

### Hoạt động 3: Luyện tập
- **Mục tiêu:** Củng cố kiến thức thông qua bài tập trắc nghiệm và câu hỏi nhận định.
- **Nội dung:** Giải quyết 4 câu hỏi trắc nghiệm nhanh và 1 câu hỏi liên hệ.
- **Sản phẩm:** Đáp án chính xác trên phiếu luyện tập.
- **Tổ chức thực hiện:** Hoạt động cá nhân trong 7 phút, GV chữa điểm nhanh.

### Hoạt động 4: Vận dụng
- **Mục tiêu:** Vận dụng tri thức văn học để viết đoạn văn cảm thụ ngắn.
- **Nội dung:** Viết đoạn văn khoảng 150 chữ về vẻ đẹp tâm hồn của Thúy Kiều.
- **Sản phẩm:** Đoạn văn hoàn chỉnh trong vở bài tập.
- **Tổ chức thực hiện:** HS làm bài tại lớp hoặc hoàn thiện tại nhà.

## IV. ĐÁNH GIÁ & HỒ SƠ DẠY HỌC
- Đánh giá thường xuyên thông qua quan sát thảo luận nhóm và sản phẩm phiếu học tập.
- Sử dụng Rubric đánh giá năng lực cảm thụ văn học 4 mức độ.

## V. PHỤ LỤC
- Phiếu học tập số 1: So sánh nghệ thuật miêu tả Thúy Vân và Thúy Kiều.
''';

    return LessonPlanDocument.parseFromMarkdown(
      title: project.lessonTitle.isNotEmpty ? project.lessonTitle : 'Kế hoạch bài dạy',
      subject: project.subject,
      grade: project.grade,
      duration: project.duration,
      bookSeries: project.bookSeries,
      markdown: markdown,
    );
  }

  @override
  Future<String> regenerateSection({
    required String sectionKey,
    required String currentContent,
    required LessonProjectData project,
  }) async {
    if (shouldSimulateFailure) {
      throw FormatException(simulatedErrorMessage);
    }
    return 'Nội dung mục "$sectionKey" đã được làm mới phù hợp với mục tiêu phát triển phẩm chất, năng lực của học sinh.';
  }

  @override
  Future<WorksheetModel> generateWorksheet({
    required LessonProjectData project,
    required WorksheetPreset preset,
    required int taskCount,
  }) async {
    if (shouldSimulateFailure) {
      throw FormatException(simulatedErrorMessage);
    }

    final tasks = <WorksheetTask>[
      const WorksheetTask(
        id: 'task_1',
        instruction: 'Điền từ còn thiếu vào chỗ trống để hoàn chỉnh câu thơ miêu tả vẻ đẹp của Thúy Kiều:',
        content: '“Làn thu thủy nét ... / Hoa ghen thua thắm liễu hờn kém ...”',
        hint: 'Gợi ý: chú ý các từ chỉ đường nét khuôn mặt và sắc màu.',
        taskType: WorksheetTaskType.fillBlank,
        points: 2,
      ),
      const WorksheetTask(
        id: 'task_2',
        instruction: 'Trả lời ngắn câu hỏi sau về nghệ thuật ước lệ cổ điển:',
        content: 'Nghệ thuật ước lệ trong câu "Mai cốt cách, tuyết tinh thần" có ý nghĩa biểu đạt điều gì?',
        hint: 'Liên hệ giữa cốt cách thanh cao của hoa mai và vẻ trắng trong của tuyết.',
        taskType: WorksheetTaskType.shortAnswer,
        points: 3,
      ),
      const WorksheetTask(
        id: 'task_3',
        instruction: 'Thảo luận nhóm và phân tích:',
        content: 'Vì sao khi miêu tả Thúy Kiều, tác giả lại tập trung sâu vào đôi mắt ("Làn thu thủy")?',
        hint: 'Đôi mắt là cửa sổ tâm hồn, thể hiện chiều sâu trí tuệ và linh cảm về một số phận đa đoan.',
        taskType: WorksheetTaskType.discussion,
        points: 5,
      ),
    ];

    return WorksheetModel(
      id: 'ws_fake_01',
      title: 'Phiếu học tập (${preset.label}): ${project.lessonTitle.isNotEmpty ? project.lessonTitle : "Truyện Kiều"}',
      subject: project.subject,
      grade: project.grade,
      preset: preset,
      durationMinutes: 15,
      tasks: tasks.take(taskCount).toList(),
      teacherNotes: 'Giáo viên phát phiếu vào đầu hoạt động luyện tập, dành 10 phút làm bài và 5 phút nhận xét.',
    );
  }

  @override
  Future<List<QuestionItem>> generateQuestions({
    required LessonProjectData project,
    required int count,
    QuestionDifficulty? difficulty,
    QuestionType? type,
  }) async {
    if (shouldSimulateFailure) {
      throw FormatException(simulatedErrorMessage);
    }

    final allItems = <QuestionItem>[
      const QuestionItem(
        id: 'q_fake_1',
        type: QuestionType.multipleChoice,
        prompt: 'Đoạn trích "Chị em Thúy Kiều" nằm ở phần nào của tác phẩm Truyện Kiều?',
        choices: [
          'A. Gặp gỡ và đính ước',
          'B. Gia biến và lưu lạc',
          'C. Đoàn tụ',
          'D. Phần kết thúc',
        ],
        correctAnswer: 'A',
        explanation: 'Đoạn trích nằm ở đầu tác phẩm, thuộc phần Mở đầu (Gặp gỡ và đính ước).',
        difficulty: QuestionDifficulty.nhanBiet,
        learningObjective: 'M1.1',
        tags: ['truyen_kieu', 'ngu_van_9'],
      ),
      const QuestionItem(
        id: 'q_fake_2',
        type: QuestionType.multipleChoice,
        prompt: 'Bút pháp nghệ thuật nổi bật nhất được Nguyễn Du sử dụng khi khắc họa chân dung Thúy Vân và Thúy Kiều là gì?',
        choices: [
          'A. Tả thực và phóng đại',
          'B. Ước lệ tượng trưng lấy vẻ đẹp thiên nhiên làm chuẩn mực',
          'C. Nhân hóa và so sánh ngầm',
          'D. Tương phản đối lập gay gắt',
        ],
        correctAnswer: 'B',
        explanation: 'Nguyễn Du sử dụng hình ảnh thiên nhiên (mai, tuyết, mây, tuyết, hoa, liễu) làm quy chuẩn thẩm mỹ.',
        difficulty: QuestionDifficulty.thongHieu,
        learningObjective: 'M1.2',
        tags: ['nghe_thuat', 'ngu_van_9'],
      ),
      const QuestionItem(
        id: 'q_fake_3',
        type: QuestionType.multipleChoice,
        prompt: 'Từ ngữ nào dự báo số phận bình lặng, êm ấm trong bức chân dung Thúy Vân?',
        choices: [
          'A. Sắc sảo, mặn mà',
          'B. Mây thua nước tóc, tuyết nhường màu da',
          'C. Hoa ghen thua thắm, liễu hờn kém xanh',
          'D. Làn thu thủy, nét xuân sơn',
        ],
        correctAnswer: 'B',
        explanation: 'Thiên nhiên "thua", "nhường" thể hiện sự bao dung, hòa hợp, dự báo cuộc đời an lành.',
        difficulty: QuestionDifficulty.vanDung,
        learningObjective: 'M2.1',
        tags: ['thuy_van', 'ngu_van_9'],
      ),
      const QuestionItem(
        id: 'q_fake_4',
        type: QuestionType.trueFalse,
        prompt: 'Nguyễn Du miêu tả chân dung Thúy Vân trước, Thúy Kiều sau là để tạo hiệu ứng đòn bẩy làm nổi bật vẻ đẹp tuyệt đỉnh của Kiều.',
        choices: [
          'A. Đúng',
          'B. Sai',
        ],
        correctAnswer: 'A',
        explanation: 'Vân đã là tuyệt sắc giai nhân, Kiều lại "sắc sảo mặn mà" hơn Vân nên càng nổi bật vẻ đẹp nghiêng nước nghiêng thành.',
        difficulty: QuestionDifficulty.thongHieu,
        learningObjective: 'M1.2',
        tags: ['don_bay', 'ngu_van_9'],
      ),
    ];

    return allItems.take(count).toList();
  }

  @override
  Future<RubricModel> generateRubric({
    required LessonProjectData project,
    int levelCount = 4,
  }) async {
    if (shouldSimulateFailure) {
      throw FormatException(simulatedErrorMessage);
    }

    final criteria = [
      const RubricCriterion(
        id: 'crit_1',
        name: 'Mức độ nắm vững kiến thức tác phẩm',
        weight: 40.0,
        objectiveId: 'M1',
        levels: [
          RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Phân tích sâu sắc, dẫn chứng trích xuất chính xác 100%.'),
          RubricLevel(name: 'Tốt', score: 3.0, description: 'Nắm chắc cốt truyện, dẫn chứng cơ bản chính xác.'),
          RubricLevel(name: 'Đạt', score: 2.0, description: 'Nhớ được nội dung chính nhưng phân tích còn sơ lược.'),
          RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Chưa nhớ được chi tiết và còn nhầm lẫn kiến thức.'),
        ],
      ),
      const RubricCriterion(
        id: 'crit_2',
        name: 'Kỹ năng cảm thụ và diễn đạt ngôn ngữ',
        weight: 30.0,
        objectiveId: 'M2',
        levels: [
          RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Văn phong truyền cảm, ngôn ngữ trong sáng, giàu chất văn.'),
          RubricLevel(name: 'Tốt', score: 3.0, description: 'Diễn đạt lưu loát, bố cục rõ ràng, ít lỗi chính tả.'),
          RubricLevel(name: 'Đạt', score: 2.0, description: 'Diễn đạt được ý nhưng còn lủng củng, lặp từ.'),
          RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Mắc nhiều lỗi câu từ và lỗi chính tả căn bản.'),
        ],
      ),
      const RubricCriterion(
        id: 'crit_3',
        name: 'Thái độ hợp tác và tích cực trong giờ học',
        weight: 30.0,
        objectiveId: 'M3',
        levels: [
          RubricLevel(name: 'Xuất sắc', score: 4.0, description: 'Chủ động tham gia phát biểu, hợp tác nhóm gương mẫu.'),
          RubricLevel(name: 'Tốt', score: 3.0, description: 'Tích cực làm bài và lắng nghe hướng dẫn của giáo viên.'),
          RubricLevel(name: 'Đạt', score: 2.0, description: 'Hoàn thành nhiệm vụ nhưng còn thụ động.'),
          RubricLevel(name: 'Cần cố gắng', score: 1.0, description: 'Chưa tập trung, không hoàn thành nhiệm vụ được giao.'),
        ],
      ),
    ];

    return RubricModel(
      id: 'rub_fake_01',
      projectId: '',
      title: 'Rubric đánh giá năng lực: ${project.lessonTitle.isNotEmpty ? project.lessonTitle : "Truyện Kiều"}',
      criteria: criteria,
    );
  }

  @override
  Future<AiConnectionTestResult> testConnection() async {
    if (!isConfigured) {
      return const AiConnectionTestResult(
        status: AiConnectionStatus.notConfigured,
        provider: 'fake_ai',
        model: 'fake-model-educational',
        message: 'Fake provider chưa được cấu hình.',
      );
    }
    if (shouldSimulateFailure) {
      return AiConnectionTestResult(
        status: AiConnectionStatus.authFailed,
        provider: 'fake_ai',
        model: 'fake-model-educational',
        message: simulatedErrorMessage,
      );
    }
    return const AiConnectionTestResult(
      status: AiConnectionStatus.ok,
      provider: 'fake_ai',
      model: 'fake-model-educational',
      message: 'Kết nối giả lập thành công (OK).',
      latencyMs: 15,
    );
  }
}
