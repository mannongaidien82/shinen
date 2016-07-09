(function() {
  var focus, same, shuffle;

  window.Shinen = angular.module('Shinen', []);

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
    }), 100);
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

  Shinen.controller('levelsCtrl', function($scope, $http) {
    var resetLevel, setMeaningState, updateRowStatus;
    $scope.rocketMode = false;
    resetLevel = function() {
      $scope.touchedKanjis = {};
      $scope.meanings = {};
      $scope.kunyomis = {};
      $scope.onyomis = {};
      return $scope.kanjis = [];
    };
    resetLevel();
    $http({
      method: 'GET',
      url: 'resources/levels.json'
    }).then(function(response) {
      return $scope.levels = response.data;
    });
    $scope.shuffle = function() {
      return $scope.kanjis = shuffle($scope.kanjis);
    };
    $scope.pickLevel = function(level) {
      $scope.pickedLevel = level;
      return $http({
        method: 'GET',
        url: "resources/kanji/" + level + ".json"
      }).then(function(response) {
        resetLevel();
        $scope.kanjis = response.data;
        return focus();
      });
    };
    updateRowStatus = function(kanji) {
      var stats;
      stats = {
        failed: 0,
        success: 0
      };
      stats[$scope.touchedKanjis[kanji.name].meaning] += 1;
      stats[$scope.touchedKanjis[kanji.name].kunyomi] += 1;
      stats[$scope.touchedKanjis[kanji.name].onyomi] += 1;
      if (stats.failed + stats.success === 3) {
        console.log(stats);
        switch (stats.failed) {
          case 3:
            return $scope.touchedKanjis[kanji.name].status = 'failed';
          case 0:
            return $scope.touchedKanjis[kanji.name].status = 'success';
          default:
            return $scope.touchedKanjis[kanji.name].status = 'mixed';
        }
      }
    };
    setMeaningState = function(kanji, type, status) {
      var base, name;
      (base = $scope.touchedKanjis)[name = kanji.name] || (base[name] = {});
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
    $scope.revealMeaning = function(kanji) {
      if (!$scope.meaningUpdated(kanji)) {
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
    $scope.revealKunyomi = function(kanji, safeMode) {
      var anyMatches, val;
      val = wanakana.toKana(($scope.kunyomis[kanji.name] || '').toUpperCase());
      anyMatches = kanji.kunyomi.some((function(_this) {
        return function(reading) {
          return val === reading;
        };
      })(this));
      if (anyMatches) {
        return setMeaningState(kanji, 'kunyomi', 'success');
      } else if (!safeMode) {
        return setMeaningState(kanji, 'kunyomi', 'failed');
      }
    };
    $scope.revealOnyomi = function(kanji, safeMode) {
      var anyMatches, val;
      val = wanakana.toKana($scope.onyomis[kanji.name] || '');
      anyMatches = kanji.onyomi.some((function(_this) {
        return function(reading) {
          return val === reading;
        };
      })(this));
      if (anyMatches) {
        return setMeaningState(kanji, 'onyomi', 'success');
      } else if (!safeMode) {
        return setMeaningState(kanji, 'onyomi', 'failed');
      }
    };
    return $scope.meaningUpdated = function(kanji) {
      var anyMatches;
      anyMatches = kanji.meanings.some((function(_this) {
        return function(meaning) {
          return same($scope.meanings[kanji.name], meaning);
        };
      })(this));
      if (anyMatches) {
        setMeaningState(kanji, 'meaning', 'success');
        return true;
      } else {
        return false;
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
        return scope.$watch(attrs.ngModel, (function(_this) {
          return function(value) {
            var raw;
            raw = value || '';
            ngModel.$setViewValue(wanakana.toKana(raw.toUpperCase(), {
              IMEMode: true
            }));
            return ngModel.$render();
          };
        })(this));
      }
    };
  });

  Shinen.directive('toHiragana', function() {
    return {
      restrict: 'A',
      require: 'ngModel',
      link: function(scope, element, attrs, ngModel) {
        return scope.$watch(attrs.ngModel, (function(_this) {
          return function(value) {
            var raw;
            raw = value || '';
            ngModel.$setViewValue(wanakana.toKana(raw, {
              IMEMode: true
            }));
            return ngModel.$render();
          };
        })(this));
      }
    };
  });

}).call(this);
