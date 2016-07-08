window.Shinen = angular.module 'Shinen', []

same = ( fst, snd ) ->
  return false unless fst
  distance = Levenshtein.get fst.toLowerCase(), snd.toLowerCase()
  distance < ( fst + snd ).length * 0.15

focus = ->
  setTimeout ( ->
    $('input:enabled').first().focus()
  ), 100

Shinen.controller 'levelsCtrl', ( $scope, $http ) ->
  resetLevel = ->
    $scope.touchedKanjis = {}
    $scope.meanings = {}
    $scope.kunyomis = {}
    $scope.onyomis = {}

  $http
    method: 'GET',
    url: 'resources/levels.json'
  .then ( response ) ->
    $scope.levels = response.data

  $scope.pickLevel = ( level ) ->
    $scope.pickedLevel = level

    $http
      method: 'GET',
      url: "resources/kanji/#{ level }.json"
    .then ( response ) ->
      resetLevel()
      $scope.kanjis = response.data
      focus()

  updateRowStatus = ( kanji ) ->
    stats = { failed: 0, success: 0 }

    stats[ $scope.touchedKanjis[ kanji.name ].meaning ] += 1
    stats[ $scope.touchedKanjis[ kanji.name ].kunyomi ] += 1
    stats[ $scope.touchedKanjis[ kanji.name ].onyomi  ] += 1

    if stats.failed + stats.success == 3
      console.log stats
      switch stats.failed
        # All failed
        when 3 then $scope.touchedKanjis[ kanji.name ].status = 'failed'
        # All succeed
        when 0 then $scope.touchedKanjis[ kanji.name ].status = 'success'
        # Mixed
        else        $scope.touchedKanjis[ kanji.name ].status = 'mixed'

  setMeaningState = ( kanji, type, status ) ->
    $scope.touchedKanjis[ kanji.name ] ||= {}
    $scope.touchedKanjis[ kanji.name ][ type ] = status
    switch type
      when 'meaning' then $scope.meanings[ kanji.name ] = kanji.meanings.join( ', ' )
      when 'kunyomi' then $scope.kunyomis[ kanji.name ] = kanji.kunyomi.join( ', ' )
      when 'onyomi'  then $scope.onyomis[ kanji.name ]  = kanji.onyomi.join( ', ' )

    updateRowStatus kanji
    focus()

  $scope.revealMeaning = ( kanji ) ->
    unless $scope.meaningUpdated( kanji )
      setMeaningState kanji, 'meaning', 'failed'

  $scope.revealKunyomi = ( kanji ) ->
    val = wanakana.toKana( ( $scope.kunyomis[ kanji.name ] || '' ).toUpperCase() )

    anyMatches = kanji.kunyomi.some ( reading ) =>
      val == reading

    if anyMatches
      setMeaningState kanji, 'kunyomi', 'success'
    else
      setMeaningState kanji, 'kunyomi', 'failed'

  $scope.revealOnyomi = ( kanji ) ->
    val = wanakana.toKana( $scope.kunyomis[ kanji.name ] || '' )

    anyMatches = kanji.onyomi.some ( reading ) =>
      val == reading

    if anyMatches
      setMeaningState kanji, 'onyomi', 'success'
    else
      setMeaningState kanji, 'onyomi', 'failed'

  $scope.meaningUpdated = ( kanji ) ->
    anyMatches = kanji.meanings.some ( meaning ) =>
      same $scope.meanings[ kanji.name ], meaning

    if anyMatches
      setMeaningState kanji, 'meaning', 'success'
      true
    else
      false

Shinen.directive 'onEnter', ->
  return (scope, element, attrs) ->
    element.bind 'keydown keypress', (event) ->
      if event.which == 13
        scope.$apply ->
          scope.$eval( attrs.onEnter )
        event.preventDefault()

Shinen.directive 'toKatakana', ->
  restrict: 'A'
  require: 'ngModel'
  link: ( scope, element, attrs, ngModel ) ->
    scope.$watch attrs.ngModel, ( value ) =>
      raw = value || ''
      ngModel.$setViewValue wanakana.toKana( raw.toUpperCase(), IMEMode: true )
      ngModel.$render()

Shinen.directive 'toHiragana', ->
  restrict: 'A'
  require: 'ngModel'
  link: ( scope, element, attrs, ngModel ) ->
    scope.$watch attrs.ngModel, ( value ) =>
      raw = value || ''
      ngModel.$setViewValue wanakana.toKana( raw, IMEMode: true )
      ngModel.$render()
