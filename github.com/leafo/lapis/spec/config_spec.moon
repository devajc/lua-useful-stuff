
config = require "lapis.config"

_G.do_nothing = ->

extend = (first, ...) ->
  for i = 1, select "#", ...
    for k,v in pairs select i, ...
      first[k] = v

  first

with_default = (c) ->
  extend {}, config.default_config, c

describe "lapis.config", ->
  before_each ->
    config.reset true

  it "should create empty config", ->
    assert.same config.get"hello", with_default { _name: "hello" }

  it "should create correct object", ->
    f = ->
      burly "dad"
      color "blue"

    config "basic", ->
      do_nothing!
      color "red"
      port 80

      things ->
        cool "yes"
        yes "really"

      include ->
        height "10px"

      set "not", "yeah"

      set many: "things", are: "set"

      include f

    input = config.get "basic"
    assert.same input, with_default {
      _name: "basic"

      color: "blue"
      are: "set"
      burly: "dad"
      things: {
        yes: "really"
        cool: "yes"
      }
      not: "yeah"
      many: "things"
      height: "10px"
      port: 80
    }

  it "should create correct object", ->
    config "cool", ->
      hello {
        one: "thing"
        leads: "another"
        nest: {
          egg: true
          grass: true
        }
      }

      hello {
        dad: "son"
         nest: {
           bird: false
           grass: false
         }
      }

    input = config.get "cool"
    assert.same input, with_default {
      _name: "cool"
      hello: {
        nest: {
          grass: false
          egg: true
          bird: false
        }
        dad: "son"
        one: "thing"
        leads: "another"
      }
    }

  it "should unset", ->
    config "yeah", ->
      hello "world"
      hello!

      one "two"
      three "four"

      unset "one", "four", "three"

    assert.same config.get"yeah", with_default { _name: "yeah" }

  it "should set multiple environments", ->
    config {"multi_a", "multi_b"}, ->
      pants "cool"

    assert.same config.get"multi_a".pants, "cool"
    assert.same config.get"multi_b".pants, "cool"




