window.Shinen = angular.module 'Shinen', [
  'ngCookies',
  'ngRoute',
  'ngSanitize',
  'ngAnimate',
  'ui.bootstrap'
]

same = ( fst, snd ) ->
  return false unless fst
  distance = Levenshtein.get fst.toLowerCase(), snd.toLowerCase()
  distance < ( fst + snd ).length * 0.15

focus = ->
  setTimeout ( ->
    $('input:enabled').first().focus()
  ), 1000

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

Shinen.controller 'newsCtrl', ( $scope, $http ) ->
  $scope.news = {}

  loadArticle = ( id ) ->
    $http
      method: 'GET',
      url: "resources/#{ id }.out.json"
    .then ( response ) ->
      $scope.article = response.data

  loadArticle 'k10010595081000'

  $http
    method: 'GET',
    url: "resources/news-list.json"
  .then ( response ) ->
    $scope.news = {}
    for date, news of $scope.kanjis = response.data[ 0 ]
      $scope.news[ date ] = news.map( ( article ) -> { id: article.news_id, title: article.title } )

  $scope.setArticle = ( id ) ->
    console.log id
    $scope.openArticleID = id

Shinen.controller 'levelsCtrl', ( $scope, $http ) ->
  $scope.rocketMode = false

  resetLevel = ->
    $scope.touchedKanjis = {}
    $scope.meanings = {}
    $scope.kunyomis = {}
    $scope.onyomis = {}
    $scope.kanjis = []

    $scope.doneKanjis = { success: [], failed: [], mixed: [] }

    $scope.levelKanjis = $scope.kanjis.map( ( kanji ) -> kanji.name )

  resetLevel()

  findKanji = (kanjiName) ->
    $scope.kanjis.find( (kanji) -> kanji.name == kanjiName )

  $http
    method: 'GET',
    url: 'resources/levels.json'
  .then ( response ) ->
    $scope.levels = response.data

  $scope.shuffle = ->
    $scope.levelKanjis = shuffle $scope.levelKanjis

  $scope.pickLevel = ( level ) ->
    $scope.pickedLevel = level

    $http
      method: 'GET',
      url: "resources/kanji/#{ level }.json"
    .then ( response ) ->
      resetLevel()
      $scope.kanjis = response.data
      $scope.levelKanjis = $scope.kanjis.map( ( kanji ) -> kanji.name )
      focus()

  updateRowStatus = ( kanji ) ->
    stats = { failed: 0, success: 0 }
    kanjiName = kanji.name

    stats[ $scope.touchedKanjis[ kanjiName ].meaning ] += 1
    stats[ $scope.touchedKanjis[ kanjiName ].kunyomi ] += 1
    stats[ $scope.touchedKanjis[ kanjiName ].onyomi  ] += 1

    if stats.failed + stats.success == 3
      console.log stats
      switch stats.failed

        # All failed
        when 3
          $scope.touchedKanjis[ kanjiName ].status = 'failed'
          $scope.doneKanjis.failed.push kanjiName

        # All succeed
        when 0
          $scope.touchedKanjis[ kanjiName ].status = 'success'
          $scope.doneKanjis.success.push kanjiName

        # Mixed
        else
          $scope.touchedKanjis[ kanjiName ].status = 'mixed'
          $scope.doneKanjis.mixed.push kanjiName

      index = $scope.levelKanjis.indexOf kanjiName
      $scope.levelKanjis.splice index, 1

  setMeaningState = ( kanji, type, status ) ->
    $scope.touchedKanjis[ kanji.name ] ||= {}
    $scope.touchedKanjis[ kanji.name ][ type ] = status
    switch type
      when 'meaning' then $scope.meanings[ kanji.name ] = kanji.meanings.join( ', ' )
      when 'kunyomi' then $scope.kunyomis[ kanji.name ] = kanji.kunyomi.join( ', ' )
      when 'onyomi'  then $scope.onyomis[ kanji.name ]  = kanji.onyomi.join( ', ' )

    updateRowStatus kanji
    focus()

  $scope.revealMeaning = ( kanjiName ) ->
    unless $scope.meaningUpdated( kanjiName )
      kanji = findKanji kanjiName
      setMeaningState kanji, 'meaning', 'failed'

  $scope.kunyomiUpdated = ( kanji ) ->
    if $scope.rocketMode
      $scope.revealKunyomi kanji, true

  $scope.onyomiUpdated = ( kanji ) ->
    if $scope.rocketMode
      $scope.revealOnyomi kanji, true

  $scope.revealKunyomi = ( kanjiName, safeMode ) ->
    kanji = findKanji kanjiName
    val = wanakana.toKana( ( $scope.kunyomis[ kanji.name ] || '' ).toUpperCase() )

    anyMatches = kanji.kunyomi.some ( reading ) =>
      val == reading

    if anyMatches
      setMeaningState kanji, 'kunyomi', 'success'
    else if !safeMode
      setMeaningState kanji, 'kunyomi', 'failed'

  $scope.revealOnyomi = ( kanjiName, safeMode ) ->
    kanji = findKanji kanjiName
    val = wanakana.toKana( $scope.onyomis[ kanji.name ] || '' )

    anyMatches = kanji.onyomi.some ( reading ) =>
      val == reading

    if anyMatches
      setMeaningState kanji, 'onyomi', 'success'
    else if !safeMode
      setMeaningState kanji, 'onyomi', 'failed'

  $scope.meaningUpdated = ( kanjiName ) ->
    kanji = findKanji kanjiName
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
