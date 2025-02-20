import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:project_3s_mobile/models/api_request.dart';
import 'package:project_3s_mobile/models/api_response.dart';
import 'package:project_3s_mobile/models/entities/answer.dart';
import 'package:project_3s_mobile/models/entities/hotel.dart';
import 'package:project_3s_mobile/models/entities/quiz.dart';
import 'package:project_3s_mobile/models/quiz_loader.dart';
import 'package:project_3s_mobile/utils/constants.dart';
import 'package:project_3s_mobile/utils/device_info.dart';
import 'package:project_3s_mobile/utils/geo_location.dart';
import 'package:project_3s_mobile/utils/logger.dart';

class Model extends ChangeNotifier {
  final QuizLoader quizLoader;

  List<Quiz> _quizList;

  bool _quizListLoaded = false;
  int _index = 0;
  final Hotel selectedHotel;
  final _answers = <Answer>[];
  final _answered = StreamController<bool>();

  Model({
    @required this.quizLoader,
    @required this.selectedHotel,
  }) {
    _load();
  }

  Stream<bool> get answered => _answered.stream;

  ProgressKind get current => progress[_index];

  Answer get currentAnswer =>
      current == ProgressKind.already ? _answers[_index] : null;

  bool get hasQuiz => _hasQuiz;

  bool get isLast => _index >= 0 && _index == (_quizList.length - 1 ?? -1);

  List<ProgressKind> get progress => _quizList
      .asMap()
      .map<int, ProgressKind>((index, quiz) => MapEntry<int, ProgressKind>(
            index,
            index >= 0 && index < _answers.length
                ? (_answers[index] != null
                    ? ProgressKind.already
                    : ProgressKind.notYet) //if there is a skip option
                : _index == index ? ProgressKind.current : ProgressKind.notYet,
          ))
      .values
      .toList();

  Quiz get quiz => _hasQuiz ? _quizList[_index] : null;

  bool get quizListLoaded => _quizListLoaded;

  bool get _hasQuiz => _index >= 0 && _index < (_quizList?.length ?? 0);

  answer(Answer answer) {
    _answers.add(answer);
    answer.answer != null ? _answered.add(true) : _answered.add(false);
    notifyListeners();
  }

  @override
  dispose() {
    _answered.close();

    super.dispose();
  }

  next() async {
    _index++;
    if (!_hasQuiz) {
      await _sendAnswers();
      logger.info('not more quiz');
      return;
    }
    logger.info('changed to next quiz');
    notifyListeners(); // call quiz_page initStage()
  }

  _load() async {
    // TODO(mono): くるくる出したいのでとりあえず
    await Future<void>.delayed(Duration(seconds: 1));
    await quizLoader.load().then((_receivedQuizList) {
      if (_receivedQuizList != null) {
        _quizList = _receivedQuizList;
        _quizListLoaded = true;
        notifyListeners();
      }
    });
  }

  _sendAnswers() async {
    List _answerListAsJson = List();
    const String _url = APIConstants.API_BASE_URL + APIRoutes.CREATE_REVIEW;
    _answers.map((answer) => _answerListAsJson.add(answer.toJson())).toList();
    await getDeviceInfo().then((info) async {
      await GeoLocation().locationToJson().then((jsonLocation) async {
        final body = jsonEncode({
          'question_and_answers': _answerListAsJson,
          'device_signature': info,
          'geo_location': jsonLocation,
          'hotel_id': selectedHotel.hotelId,
        });
        print(body);
        http.Response _response = await ApiRequest().apiPostRequest(_url, body);
        ApiResponse().handleCreateReviewResponse(_response);
      });
    });
  }
}

enum ProgressKind {
  already,
  current,
  notYet,
}
