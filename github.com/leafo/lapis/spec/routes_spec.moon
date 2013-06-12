
import Router from require "lapis.router"

describe "basic route matching", ->
  local r
  handler = (...) -> { ... }

  before_each ->
    r = Router!
    r\add_route "/hello", handler
    r\add_route "/hello/:name", handler
    r\add_route "/hello/:name/world", handler
    r\add_route "/static/*", handler
    r\add_route "/x/:color/:height/*", handler

    r.default_route = -> "failed to find route"

  it "should match static route", ->
    out = r\resolve "/hello"
    assert.same out, { {}, "/hello" }

  it "should match param route", ->
    out = r\resolve "/hello/world2323"
    assert.same out, {
      { name: "world2323" },
      "/hello/:name"
    }

  it "should match param route", ->
    out = r\resolve "/hello/the-parameter/world"
    assert.same out, {
      { name: "the-parameter" },
      "/hello/:name/world"
    }

  it "should match splat", ->
    out = r\resolve "/static/hello/world/343434/foo%20bar.png"
    assert.same out, {
      { splat: 'hello/world/343434/foo%20bar.png' }
      "/static/*"
    }

  it "should match all", ->
    out = r\resolve "/x/greenthing/123px/ahhhhwwwhwhh.txt"
    assert.same out, {
      {
        splat: 'ahhhhwwwhwhh.txt'
        height: '123px'
        color: 'greenthing'
      }
      "/x/:color/:height/*"
    }

  it "should match nothing", ->
    assert.same r\resolve("/what-the-heck"), "failed to find route"

  it "should match nothing", ->
    assert.same r\resolve("/hello//world"), "failed to find route"


describe "named routes", ->
  local r
  handler = (...) -> { ... }

  before_each ->
    r = Router!
    r\add_route { homepage: "/home" }, handler
    r\add_route { profile: "/profile/:name" }, handler
    r\add_route { profile_settings: "/profile/:name/settings" }, handler
    r\add_route { game: "/game/:user_slug/:game_slug" }, handler
    r\add_route { splatted: "/page/:slug/*" }, handler

    r.default_route = -> "failed to find route"

  it "should match", ->
    out = r\resolve "/home"
    assert.same out, {
      {}, "/home", "homepage"
    }

  it "should generate correct url", ->
    url = r\url_for "homepage"
    assert.same url, "/home"

  it "should generate correct url", ->
    url = r\url_for "profile", name: "adam"
    assert.same url, "/profile/adam"

  it "should generate correct url", ->
    url = r\url_for "game", user_slug: "leafo", game_slug: "x-moon"
    assert.same url, "/game/leafo/x-moon"

  -- TODO: this is incorrect
  it "should generate correct url", ->
    url = r\url_for "splatted", slug: "cool", splat: "hello"
    assert.same url, "/page/cool/*"

  it "should create param from object", ->
    user = {
      url_key: (route_name, param_name) =>
        assert.same route_name, "profile_settings"
        assert.same param_name, "name"
        "adam"
    }

    url = r\url_for "profile_settings", name: user
    assert.same url, "/profile/adam/settings"

  it "should not build url", ->
    assert.has_error (-> r\url_for "fake_url", name: user),
      "Missing route named fake_url"

