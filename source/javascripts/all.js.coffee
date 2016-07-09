window.Shinen = angular.module 'Shinen', []

same = ( fst, snd ) ->
  return false unless fst
  distance = Levenshtein.get fst.toLowerCase(), snd.toLowerCase()
  distance < ( fst + snd ).length * 0.15

focus = ->
  setTimeout ( ->
    $('input:enabled').first().focus()
  ), 100

shuffle = (array) ->
  currentIndex = array.length

  # While there remain elements to shuffle...
  while (0 != currentIndex)
    # Pick a remaining element...
    randomIndex = Math.floor(Math.random() * currentIndex)
    currentIndex -= 1

    # And swap it with the current element.
    temporaryValue = array[currentIndex]
    array[currentIndex] = array[randomIndex]
    array[randomIndex] = temporaryValue

  return array

Shinen.controller 'levelsCtrl', ( $scope, $http ) ->
  $scope.rocketMode = false

  resetLevel = ->
    $scope.touchedKanjis = {}
    $scope.meanings = {}
    $scope.kunyomis = {}
    $scope.onyomis = {}
    $scope.kanjis = []

  resetLevel()

  $http
    method: 'GET',
    url: 'resources/levels.json'
  .then ( response ) ->
    $scope.levels = response.data

  $scope.shuffle = ->
    $scope.kanjis = shuffle $scope.kanjis

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

  $scope.kunyomiUpdated = ( kanji ) ->
    if $scope.rocketMode
      $scope.revealKunyomi kanji, true

  $scope.onyomiUpdated = ( kanji ) ->
    if $scope.rocketMode
      $scope.revealOnyomi kanji, true

  $scope.revealKunyomi = ( kanji, safeMode ) ->
    val = wanakana.toKana( ( $scope.kunyomis[ kanji.name ] || '' ).toUpperCase() )

    anyMatches = kanji.kunyomi.some ( reading ) =>
      val == reading

    if anyMatches
      setMeaningState kanji, 'kunyomi', 'success'
    else if !safeMode
      setMeaningState kanji, 'kunyomi', 'failed'

  $scope.revealOnyomi = ( kanji, safeMode ) ->
    val = wanakana.toKana( $scope.onyomis[ kanji.name ] || '' )

    anyMatches = kanji.onyomi.some ( reading ) =>
      val == reading

    if anyMatches
      setMeaningState kanji, 'onyomi', 'success'
    else if !safeMode
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
