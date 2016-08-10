(function() {
  var LOCAL_MODE, cors, firstKey, focus, same, shuffle;

  LOCAL_MODE = false;

  window.Shinen = angular.module('Shinen', ['ngCookies', 'ngRoute', 'ngSanitize', 'ngAnimate', 'ui.bootstrap']);

  same = function(fst, snd) {
    var distance;
    if (!fst) {
      return false;
    }
    distance = Levenshtein.get(fst.toLowerCase(), snd.toLowerCase());
    return distance < (fst + snd).length * 0.15;
  };

  focus = function() {
    return setTimeout((function() {
      return $('input:enabled').first().focus();
    }), 1000);
  };

  firstKey = function(obj) {
    return obj[Object.keys(obj)[0]];
  };

  shuffle = function(array) {
    var currentIndex, randomIndex, temporaryValue;
    currentIndex = array.length;
    while (0 !== currentIndex) {
      randomIndex = Math.floor(Math.random() * currentIndex);
      currentIndex -= 1;
      temporaryValue = array[currentIndex];
      array[currentIndex] = array[randomIndex];
      array[randomIndex] = temporaryValue;
    }
    return array;
  };

  cors = function(link) {
    return "https://crossorigin.me/" + link;
  };

  Shinen.filter('unsafe', function($sce) {
    return $sce.trustAsHtml;
  });

  Shinen.controller('newsCtrl', function($scope, $http, $sce) {
    var loadArticle, loadDictionary, wordTranslations;
    $scope.news = {};
    $scope.article = {};
    $scope.highlightMode = true;
    $scope.furiganaMode = true;
    $scope.spacingMode = false;
    $scope.showSidebar = true;
    $scope.clickMode = 'dictionary';
    $scope.article = {
      raw: {},
      dic: {}
    };
    wordTranslations = {};
    $scope.getTranslation = function(word) {
      return wordTranslations[word];
    };
    $scope.setTranslation = function(word, translation) {
      return wordTranslations[word] = translation;
    };
    $scope.getDefinition = function(word) {
      return $scope.article.dic[word];
    };
    loadArticle = function(id) {
      return $http({
        method: 'GET',
        url: (LOCAL_MODE ? "resources/" + id + ".out.json" : cors("http://www3.nhk.or.jp/news/easy/" + id + "/" + id + ".out.json"))
      }).then(function(response) {
        var chunk, chunks;
        $scope.article = {
          raw: response.data,
          dic: {}
        };
        chunks = [];
        chunk = [];
        loadDictionary(id);
        response.data.morph.forEach(function(x) {
          switch (x.word) {
            case '<S>':
              return chunk = [];
            case '</S>':
              if (chunk.length) {
                chunks.push(chunk);
                return chunk = [];
              }
              break;
            default:
              return chunk.push(x);
          }
        });
        return $scope.article['chunks'] = chunks;
      });
    };
    loadDictionary = function(id) {
      return $http({
        method: 'GET',
        url: (LOCAL_MODE ? "resources/" + id + ".out.dic" : cors("http://www3.nhk.or.jp/news/easy/" + id + "/" + id + ".out.dic"))
      }).then(function(response) {
        var html, ref, results, val;
        $scope.article.dic = {};
        ref = response.data.reikai.entries;
        results = [];
        for (id in ref) {
          val = ref[id];
          html = val.map(function(v) {
            return v.def;
          }).join("<br>");
          results.push($scope.article.dic["BE-" + id] = html);
        }
        return results;
      });
    };
    $http({
      method: 'GET',
      url: (LOCAL_MODE ? "resources/news-list.json" : cors("http://www3.nhk.or.jp/news/easy/news-list.json"))
    }).then(function(response) {
      var date, firstNewsID, news, ref;
      $scope.news = {};
      ref = $scope.kanjis = response.data[0];
      for (date in ref) {
        news = ref[date];
        $scope.news[date] = news.map(function(article) {
          return {
            id: article.news_id,
            title: article.title
          };
        });
      }
      firstNewsID = firstKey($scope.news)[0].id;
      return $scope.setArticle(firstNewsID);
    });
    return $scope.setArticle = function(id) {
      $scope.openArticleID = id;
      return loadArticle(id);
    };
  });

  Shinen.controller('levelsCtrl', function($scope, $http) {
    var resetLevel, setMeaningState, updateRowStatus;
    $scope.rocketMode = false;
    $scope.checkMeaning = true;
    $scope.checkOnyomi = true;
    $scope.checkKunyomi = true;
    $scope.kanjiSize = 0;
    resetLevel = function() {
      $scope.touchedKanjis = {};
      $scope.meanings = {};
      $scope.kunyomis = {};
      $scope.onyomis = {};
      $scope.kanjis = [];
      $scope.doneKanjis = {
        success: [],
        failed: [],
        mixed: []
      };
      return $scope.levelKanjis = $scope.kanjis.map(function(kanji) {
        return kanji.name;
      });
    };
    resetLevel();
    $scope.findKanji = function(kanjiName) {
      return $scope.kanjis.find(function(kanji) {
        return kanji.name === kanjiName;
      });
    };
    $http({
      method: 'GET',
      url: 'resources/levels.json'
    }).then(function(response) {
      return $scope.levels = response.data;
    });
    $scope.shuffle = function() {
      return $scope.levelKanjis = shuffle($scope.levelKanjis);
    };
    $scope.pickLevel = function(level) {
      $scope.pickedLevel = level;
      return $http({
        method: 'GET',
        url: "resources/kanji/" + level + ".json"
      }).then(function(response) {
        resetLevel();
        $scope.kanjis = response.data;
        $scope.levelKanjis = $scope.kanjis.map(function(kanji) {
          return kanji.name;
        });
        return focus();
      });
    };
    $scope.pickLevel("test");
    $scope.kanjiMaxPoints = function(kanjiName) {
      var kanji, maxPoints;
      kanji = $scope.findKanji(kanjiName);
      maxPoints = 0;
      if ($scope.checkMeaning) {
        maxPoints += 1;
      }
      if ($scope.checkKunyomi && kanji.kunyomi.length) {
        maxPoints += 1;
      }
      if ($scope.checkOnyomi && kanji.onyomi.length) {
        maxPoints += 1;
      }
      return maxPoints;
    };
    updateRowStatus = function(kanji) {
      var index, kanjiName, maxPoints, stats;
      stats = {
        failed: 0,
        success: 0
      };
      kanjiName = kanji.name;
      stats[$scope.touchedKanjis[kanjiName].meaning] += 1;
      stats[$scope.touchedKanjis[kanjiName].kunyomi] += 1;
      stats[$scope.touchedKanjis[kanjiName].onyomi] += 1;
      maxPoints = $scope.kanjiMaxPoints(kanjiName);
      if (stats.failed + stats.success === maxPoints) {
        switch (stats.failed) {
          case maxPoints:
            $scope.touchedKanjis[kanjiName].status = 'failed';
            $scope.doneKanjis.failed.push(kanjiName);
            break;
          case 0:
            $scope.touchedKanjis[kanjiName].status = 'success';
            $scope.doneKanjis.success.push(kanjiName);
            break;
          default:
            $scope.touchedKanjis[kanjiName].status = 'mixed';
            $scope.doneKanjis.mixed.push(kanjiName);
        }
        index = $scope.levelKanjis.indexOf(kanjiName);
        return setTimeout(function() {
          return $scope.levelKanjis.splice(index, 1);
        }, 100);
      }
    };
    $scope.resetDone = function(level) {
      if ("all" === level) {
        $scope.resetDone('success');
        $scope.resetDone('mixed');
        $scope.resetDone('failed');
        return $scope.shuffle();
      } else {
        $scope.doneKanjis[level].forEach(function(kanjiName) {
          $scope.touchedKanjis[kanjiName] = {};
          $scope.meanings[kanjiName] = void 0;
          $scope.kunyomis[kanjiName] = void 0;
          return $scope.onyomis[kanjiName] = void 0;
        });
        $scope.levelKanjis = $scope.levelKanjis.concat($scope.doneKanjis[level]);
        return $scope.doneKanjis[level] = [];
      }
    };
    setMeaningState = function(kanji, type, status) {
      var base, name;
      (base = $scope.touchedKanjis)[name = kanji.name] || (base[name] = {});
      if ($scope.touchedKanjis[kanji.name][type]) {
        return;
      }
      $scope.touchedKanjis[kanji.name][type] = status;
      switch (type) {
        case 'meaning':
          $scope.meanings[kanji.name] = kanji.meanings.join(', ');
          break;
        case 'kunyomi':
          $scope.kunyomis[kanji.name] = kanji.kunyomi.join(', ');
          break;
        case 'onyomi':
          $scope.onyomis[kanji.name] = kanji.onyomi.join(', ');
      }
      updateRowStatus(kanji);
      return focus();
    };
    $scope.revealMeaning = function(kanjiName) {
      var kanji;
      if (!$scope.meaningUpdated(kanjiName)) {
        kanji = $scope.findKanji(kanjiName);
        return setMeaningState(kanji, 'meaning', 'failed');
      }
    };
    $scope.kunyomiUpdated = function(kanji) {
      if ($scope.rocketMode) {
        return $scope.revealKunyomi(kanji, true);
      }
    };
    $scope.onyomiUpdated = function(kanji) {
      if ($scope.rocketMode) {
        return $scope.revealOnyomi(kanji, true);
      }
    };
    $scope.revealKunyomi = function(kanjiName, safeMode) {
      var anyMatches, kanji, val;
      kanji = $scope.findKanji(kanjiName);
      val = wanakana.toKana(($scope.kunyomis[kanji.name] || '').toUpperCase());
      anyMatches = kanji.kunyomi.some(function(reading) {
        return (val === reading) || (val === reading.replace(/-/g, '').split('.')[0]) || (val === reading.replace(/[.-]/g, ''));
      });
      if (anyMatches) {
        return setMeaningState(kanji, 'kunyomi', 'success');
      } else if (!safeMode) {
        return setMeaningState(kanji, 'kunyomi', 'failed');
      }
    };
    $scope.revealOnyomi = function(kanjiName, safeMode) {
      var anyMatches, kanji, val;
      kanji = $scope.findKanji(kanjiName);
      val = wanakana.toKana($scope.onyomis[kanji.name] || '');
      anyMatches = kanji.onyomi.some(function(reading) {
        return val === reading;
      });
      if (anyMatches) {
        return setMeaningState(kanji, 'onyomi', 'success');
      } else if (!safeMode) {
        return setMeaningState(kanji, 'onyomi', 'failed');
      }
    };
    return $scope.meaningUpdated = function(kanjiName, auto) {
      var anyMatches, kanji;
      if (auto == null) {
        auto = false;
      }
      if (auto && !$scope.rocketMode) {
        return;
      }
      kanji = $scope.findKanji(kanjiName);
      if (auto) {
        anyMatches = kanji.meanings.some(function(meaning) {
          return $scope.meanings[kanji.name].toLowerCase() === meaning.toLowerCase();
        });
      } else {
        anyMatches = kanji.meanings.some(function(meaning) {
          return same($scope.meanings[kanji.name], meaning);
        });
      }
      if (anyMatches) {
        setMeaningState(kanji, 'meaning', 'success');
        return true;
      } else {
        return false;
      }
    };
  });

  Shinen.directive('shWord', function($http) {
    return {
      restrict: 'E',
      templateUrl: 'word-template',
      scope: {
        popUpMode: '=',
        unit: '=',
        getDefinition: '&',
        getTranslation: '&',
        setTranslation: '&'
      },
      link: function(scope, element, attrs) {
        var word;
        word = scope.unit.word;
        scope.popUpContent = function() {
          if (scope.popUpMode === 'dictionary') {
            return scope.getDefinition()(scope.unit.dicid) || 'Loading...';
          } else {
            return scope.getTranslation()(word) || 'Loading...';
          }
        };
        scope.wordClass = (function() {
          switch (scope.unit["class"]) {
            case 'L':
              return 'word-location';
            case 'C':
              return 'word-company';
            case 'B':
              return 'word-base';
            case 'F':
              return 'word-foreign';
            case '0':
            case '1':
            case '2':
            case '3':
            case '4':
              return 'word-leveled';
            default:
              return 'word-unknown';
          }
        })();
        return scope.findDef = function() {
          if (scope.getTranslation()(word)) {
            return;
          }
          return $http({
            url: cors("http://jisho.org/api/v1/search/words?keyword=" + word + ".json")
          }).then(function(response) {
            var translation;
            translation = response.data.data.map(function(def, i, datum) {
              var english_defs, prefix;
              if (datum.length > 1) {
                prefix = (i + 1) + ") ";
              } else {
                prefix = '';
              }
              english_defs = def.senses.map(function(sense) {
                return sense.english_definitions.join(', ');
              });
              return "" + prefix + (english_defs.join(', '));
            }).slice(0, 3).join('<br>');
            return scope.setTranslation()(word, translation);
          }, function(response) {
            return scope.setTranslation()(word, 'Failed to find translation');
          });
        };
      }
    };
  });

  Shinen.directive('onEnter', function() {
    return function(scope, element, attrs) {
      return element.bind('keydown keypress', function(event) {
        if (event.which === 13) {
          scope.$apply(function() {
            return scope.$eval(attrs.onEnter);
          });
          return event.preventDefault();
        }
      });
    };
  });

  Shinen.directive('toKatakana', function() {
    return {
      restrict: 'A',
      require: 'ngModel',
      link: function(scope, element, attrs, ngModel) {
        return scope.$watch(attrs.ngModel, function(value) {
          var raw;
          raw = value || '';
          ngModel.$setViewValue(wanakana.toKana(raw.toUpperCase(), {
            IMEMode: true
          }));
          return ngModel.$render();
        });
      }
    };
  });

  Shinen.directive('toHiragana', function() {
    return {
      restrict: 'A',
      require: 'ngModel',
      link: function(scope, element, attrs, ngModel) {
        return scope.$watch(attrs.ngModel, function(value) {
          var raw;
          raw = value || '';
          ngModel.$setViewValue(wanakana.toKana(raw, {
            IMEMode: true
          }));
          return ngModel.$render();
        });
      }
    };
  });

}).call(this);
