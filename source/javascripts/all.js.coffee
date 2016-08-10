LOCAL_MODE = false

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

firstKey = ( obj ) ->
  obj[ Object.keys( obj )[ 0 ] ]

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

cors = ( link ) ->
  "https://crossorigin.me/#{ link }"

Shinen.filter 'unsafe', ($sce) -> $sce.trustAsHtml

Shinen.controller 'newsCtrl', ( $scope, $http, $sce ) ->
  $scope.news = {}
  $scope.article = {}
  $scope.highlightMode = true
  $scope.furiganaMode = true
  $scope.spacingMode = false
  $scope.showSidebar = true
  $scope.clickMode = 'dictionary'
  $scope.article = { raw: {}, dic: {} }

  wordTranslations = {}
  $scope.getTranslation = ( word ) -> wordTranslations[ word ]
  $scope.setTranslation = ( word, translation ) -> wordTranslations[ word ] = translation

  $scope.getDefinition = ( word ) ->
    $scope.article.dic[ word ]

  loadArticle = ( id ) ->
    $http
      method: 'GET',
      url: ( if LOCAL_MODE then "resources/#{ id }.out.json" else cors "http://www3.nhk.or.jp/news/easy/#{ id }/#{ id }.out.json" )
    .then ( response ) ->
      $scope.article = { raw: response.data, dic: {} }
      chunks = []
      chunk = []

      loadDictionary( id )

      response.data.morph.forEach ( x ) ->
        switch x.word
          when '<S>'
            chunk = []
          when '</S>'
            if chunk.length
              chunks.push chunk
              chunk = []
          else
            chunk.push x
      $scope.article[ 'chunks' ] = chunks

  loadDictionary = ( id ) ->
    $http
      method: 'GET',
      url: ( if LOCAL_MODE then "resources/#{ id }.out.dic" else cors "http://www3.nhk.or.jp/news/easy/#{ id }/#{ id }.out.dic" )
    .then ( response ) ->
      $scope.article.dic = {}

      for id, val of response.data.reikai.entries
        html = val.map( (v) -> v.def ).join( "<br>" )
        # $scope.article.dic[ "BE-#{ id }" ] = $sce.trustAsHtml( html )
        $scope.article.dic[ "BE-#{ id }" ] = html

  $http
    method: 'GET',
    url: ( if LOCAL_MODE then "resources/news-list.json" else cors "http://www3.nhk.or.jp/news/easy/news-list.json" )
  .then ( response ) ->
    $scope.news = {}
    for date, news of $scope.kanjis = response.data[ 0 ]
      $scope.news[ date ] = news.map( ( article ) -> { id: article.news_id, title: article.title } )
    firstNewsID = firstKey( $scope.news )[ 0 ].id
    $scope.setArticle firstNewsID

  $scope.setArticle = ( id ) ->
    $scope.openArticleID = id
    loadArticle id

Shinen.controller 'levelsCtrl', ( $scope, $http ) ->
  $scope.rocketMode = false
  $scope.checkMeaning = true
  $scope.checkOnyomi = true
  $scope.checkKunyomi = true
  $scope.kanjiSize = 0

  resetLevel = ->
    $scope.touchedKanjis = {}
    $scope.meanings = {}
    $scope.kunyomis = {}
    $scope.onyomis = {}
    $scope.kanjis = []

    $scope.doneKanjis = { success: [], failed: [], mixed: [] }

    $scope.levelKanjis = $scope.kanjis.map( ( kanji ) -> kanji.name )

  resetLevel()

  $scope.findKanji = (kanjiName) ->
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

  $scope.pickLevel "test"

  $scope.kanjiMaxPoints = ( kanjiName ) ->
    kanji = $scope.findKanji kanjiName

    maxPoints = 0
    maxPoints += 1 if $scope.checkMeaning
    maxPoints += 1 if $scope.checkKunyomi && kanji.kunyomi.length
    maxPoints += 1 if $scope.checkOnyomi && kanji.onyomi.length

    maxPoints

  updateRowStatus = ( kanji ) ->
    stats = { failed: 0, success: 0 }
    kanjiName = kanji.name

    stats[ $scope.touchedKanjis[ kanjiName ].meaning ] += 1
    stats[ $scope.touchedKanjis[ kanjiName ].kunyomi ] += 1
    stats[ $scope.touchedKanjis[ kanjiName ].onyomi  ] += 1

    maxPoints = $scope.kanjiMaxPoints( kanjiName )

    if stats.failed + stats.success == maxPoints
      switch stats.failed

        # All failed
        when maxPoints
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
      setTimeout ->
        $scope.levelKanjis.splice index, 1
      , 100

  $scope.resetDone = (level) ->
    if "all" == level
      $scope.resetDone( 'success' )
      $scope.resetDone( 'mixed' )
      $scope.resetDone( 'failed' )
      $scope.shuffle()
    else
      $scope.doneKanjis[ level ].forEach (kanjiName) ->
        $scope.touchedKanjis[ kanjiName ] = {}
        $scope.meanings[ kanjiName ] = undefined
        $scope.kunyomis[ kanjiName ] = undefined
        $scope.onyomis[ kanjiName ] = undefined

      $scope.levelKanjis = $scope.levelKanjis.concat( $scope.doneKanjis[ level ] )
      $scope.doneKanjis[ level ] = []

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
      kanji = $scope.findKanji kanjiName
      setMeaningState kanji, 'meaning', 'failed'

  $scope.kunyomiUpdated = ( kanji ) ->
    if $scope.rocketMode
      $scope.revealKunyomi kanji, true

  $scope.onyomiUpdated = ( kanji ) ->
    if $scope.rocketMode
      $scope.revealOnyomi kanji, true

  $scope.revealKunyomi = ( kanjiName, safeMode ) ->
    kanji = $scope.findKanji kanjiName
    val = wanakana.toKana( ( $scope.kunyomis[ kanji.name ] || '' ).toUpperCase() )

    anyMatches = kanji.kunyomi.some ( reading ) ->
      ( val == reading ) ||
        ( val == reading.replace( /-/g, '' ).split( '.' )[ 0 ] ) ||
        ( val == reading.replace( /[.-]/g, '' ) )

    if anyMatches
      setMeaningState kanji, 'kunyomi', 'success'
    else if !safeMode
      setMeaningState kanji, 'kunyomi', 'failed'

  $scope.revealOnyomi = ( kanjiName, safeMode ) ->
    kanji = $scope.findKanji kanjiName
    val = wanakana.toKana( $scope.onyomis[ kanji.name ] || '' )

    anyMatches = kanji.onyomi.some ( reading ) ->
      val == reading

    if anyMatches
      setMeaningState kanji, 'onyomi', 'success'
    else if !safeMode
      setMeaningState kanji, 'onyomi', 'failed'

  $scope.meaningUpdated = ( kanjiName ) ->
    kanji = $scope.findKanji kanjiName
    anyMatches = kanji.meanings.some ( meaning ) ->
      same $scope.meanings[ kanji.name ], meaning

    if anyMatches
      setMeaningState kanji, 'meaning', 'success'
      true
    else
      false

Shinen.directive 'shWord', ( $http ) ->
  restrict: 'E'
  templateUrl: 'word-template'
  scope:
    popUpMode: '='
    unit: '='
    getDefinition: '&'
    getTranslation: '&'
    setTranslation: '&'
  link: ( scope, element, attrs ) ->
    word = scope.unit.word

    scope.popUpContent = ->
      if scope.popUpMode == 'dictionary'
        scope.getDefinition()( scope.unit.dicid ) || 'Loading...'
      else
        scope.getTranslation()( word ) || 'Loading...'

    scope.wordClass = switch scope.unit.class
      when 'L' then 'word-location'
      when 'C' then 'word-company'
      when 'B' then 'word-base'
      when 'F' then 'word-foreign'
      when '0', '1', '2', '3', '4' then 'word-leveled'
      else 'word-unknown'

    scope.findDef = () ->
      return if scope.getTranslation() word

      $http( url: cors( "http://jisho.org/api/v1/search/words?keyword=#{ word }.json" ) )
        .then ( response ) ->
          translation = response.data.data.map( ( def, i, datum ) ->
            if datum.length > 1
              prefix = "#{ i + 1 }) "
            else
              prefix = ''

            english_defs = def.senses.map( ( sense ) -> sense.english_definitions.join( ', ' ) )

            "#{ prefix }#{ english_defs.join( ', ' ) }"
          ).slice( 0, 3 ).join( '<br>' )
          scope.setTranslation() word, translation
        , ( response ) ->
          scope.setTranslation() word, 'Failed to find translation'

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
    scope.$watch attrs.ngModel, ( value ) ->
      raw = value || ''
      ngModel.$setViewValue wanakana.toKana( raw.toUpperCase(), IMEMode: true )
      ngModel.$render()

Shinen.directive 'toHiragana', ->
  restrict: 'A'
  require: 'ngModel'
  link: ( scope, element, attrs, ngModel ) ->
    scope.$watch attrs.ngModel, ( value ) ->
      raw = value || ''
      ngModel.$setViewValue wanakana.toKana( raw, IMEMode: true )
      ngModel.$render()
