import 'package:flutter_test/flutter_test.dart';
import 'package:muzhir/services/label_loader.dart';
import 'package:muzhir/services/output_mapper.dart';

void main() {
  const labels = <int, LabelEntry>{
    0: LabelEntry(en: 'Corn Blight', ar: 'لفحة الذرة'),
    6: LabelEntry(en: 'Tomato Leaf Curling', ar: 'تجعد أوراق الطماطم'),
    7: LabelEntry(en: 'Tomato Mildiou', ar: 'البياض الزغبي'),
  };

  test('maps ultralytics flat boxes by class name', () {
    final detections = OutputMapper.map(
      [
        {
          'class': 'Tomato Leaf Curling',
          'className': 'Tomato Leaf Curling',
          'confidence': 0.82,
          'x1_norm': 0.1,
          'y1_norm': 0.2,
          'x2_norm': 0.6,
          'y2_norm': 0.7,
        },
      ],
      labels,
    );

    expect(detections, hasLength(1));
    expect(detections.single.classId, 6);
    expect(detections.single.labelEn, 'Tomato Leaf Curling');
    expect(detections.single.labelAr, 'تجعد أوراق الطماطم');
    expect(detections.single.confidence, 0.82);
    expect(detections.single.boundingBox.left, 0.1);
    expect(detections.single.boundingBox.top, 0.2);
    expect(detections.single.boundingBox.width, closeTo(0.5, 0.0001));
    expect(detections.single.boundingBox.height, closeTo(0.5, 0.0001));
  });

  test('maps legacy nested bounding boxes by class index', () {
    final detections = OutputMapper.map(
      [
        {
          'classIndex': 7,
          'confidence': 0.6,
          'boundingBox': {
            'left': 0.25,
            'top': 0.1,
            'width': 0.4,
            'height': 0.3,
          },
        },
      ],
      labels,
    );

    expect(detections, hasLength(1));
    expect(detections.single.classId, 7);
    expect(detections.single.labelEn, 'Tomato Mildiou');
    expect(detections.single.boundingBox.left, 0.25);
    expect(detections.single.boundingBox.width, 0.4);
  });

  test('filters low confidence boxes', () {
    final detections = OutputMapper.map(
      [
        {
          'className': 'Corn Blight',
          'confidence': 0.24,
          'x1_norm': 0.0,
          'y1_norm': 0.0,
          'x2_norm': 1.0,
          'y2_norm': 1.0,
        },
      ],
      labels,
    );

    expect(detections, isEmpty);
  });

  test('skips malformed boxes without failing the whole result', () {
    final detections = OutputMapper.map(
      [
        {
          'className': 'Corn Blight',
          'confidence': 0.9,
        },
        {
          'className': 'Corn Blight',
          'confidence': 0.7,
          'x1_norm': 0.1,
          'y1_norm': 0.1,
          'x2_norm': 0.4,
          'y2_norm': 0.4,
        },
      ],
      labels,
    );

    expect(detections, hasLength(1));
    expect(detections.single.classId, 0);
  });

  test('sorts detections by descending confidence', () {
    final detections = OutputMapper.map(
      [
        {
          'className': 'Corn Blight',
          'confidence': 0.55,
          'x1_norm': 0.1,
          'y1_norm': 0.1,
          'x2_norm': 0.2,
          'y2_norm': 0.2,
        },
        {
          'className': 'Tomato Mildiou',
          'confidence': 0.88,
          'x1_norm': 0.3,
          'y1_norm': 0.3,
          'x2_norm': 0.6,
          'y2_norm': 0.6,
        },
      ],
      labels,
    );

    expect(detections.map((d) => d.classId), [7, 0]);
  });
}
