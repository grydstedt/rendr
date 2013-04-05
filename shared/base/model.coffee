syncer = require('../syncer')
fetcher = null

instanceStore = {}
instanceStoreCount = {}

INSTANCE_STORE_PURGE_TIMEOUT = 10000;

if not global.isServer
  setInterval ->
    for key, count of instanceStoreCount
      if count <= 0
        delete instanceStore[key]
        delete instanceStoreCount[key]
  , INSTANCE_STORE_PURGE_TIMEOUT

module.exports = class Base extends Backbone.Model

  constructor: (models, options = {}) ->
    if not global.isServer
      modelName = @constructor.id or @constructor.name
      if @id and modelName
        @_key = [modelName,'_',@.id].join('')
        obj = instanceStore[@._key]
        if obj
          instanceStoreCount[@_key]++
          return obj
        instanceStore[@._key] = this
        instanceStoreCount[@._key] = 1
    

    # Capture the options as instance variable.
    @options = options

    # Store a reference to the app instance.
    @app = @options.app

    super

    if !@app && @collection
      @app = @collection.app

    @on 'change', @store

  release: () -> 
    if not global.isServer and @_key
      instanceStoreCount[@_key]--;

  # Override 'add' to make sure models have '@app' attribute.
  add: (models, options) ->
    models = [models] unless _.isArray(models)

    model.app = @app for model in models

    super models, options

  # Idempotent parse
  parse: (resp) ->
    if @jsonKey
      resp[@jsonKey] || resp
    else
      resp

  checkFresh: syncer.checkFresh

  sync: syncer.getSync()

  getUrl: syncer.getUrl

  # Instance method to store in the modelStore.
  store: =>
    getFetcher().modelStore.set(@)

# Prevent circular dependency :-/.
getFetcher = ->
  fetcher ?= require('../fetcher')
