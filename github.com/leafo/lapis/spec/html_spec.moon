
import render_html, Widget from require "lapis.html"

render_widget = (w) ->
  buffer = {}
  w buffer
  table.concat buffer

describe "lapis.html", ->
  it "should render html", ->
    input = render_html ->
      b "what is going on?"

      div ->
        pre class: "cool", -> span "hello world"

      text capture -> div "this is captured"

      raw "<div>raw test</div>"
      text "<div>raw test</div>"

      html_5 ->
        div "what is going on there?"

    assert.same input, [[<b>what is going on?</b><div><pre class="cool"><span>hello world</span></pre></div>&lt;div&gt;this is captured&lt;/div&gt;<div>raw test</div>&lt;div&gt;raw test&lt;/div&gt;<!DOCTYPE HTML><html lang="en"><div>what is going on there?</div></html>]]

  it "should render the widget", ->
    class TestWidget extends Widget
      content: =>
        div class: "hello", @message
        @content_for "inner"

    input = render_widget TestWidget message: "Hello World!", inner: -> b "Stay Safe"
    assert.same input, [[<div class="hello">Hello World!</div><b>Stay Safe</b>]]

  it "should render widget with inheritance", ->
    class BaseWidget extends Widget
      value: 100
      another_value: => 200

      content: =>
        div class: "base_widget", ->
          @inner!

      inner: => error "implement me"

    class TestWidget extends BaseWidget
      inner: =>
        text "Widget speaking, value: #{@value}, another_value: #{@another_value!}"

    input = render_widget TestWidget!
    assert.same input, [[<div class="base_widget">Widget speaking, value: 100, another_value: 200</div>]]


  it "should include widget helper", ->
    class Test extends Widget
      content: =>
        div "What's up! #{@hello!}"

    w = Test!
    w\include_helper {
      id: 10
      hello: => "id: #{@id}"
    }

    input = render_widget w
    assert.same input, [[<div>What&#039;s up! id: 10</div>]]


  it "helpers should resolve correctly ", ->
    class Base extends Widget
      one: 1
      two: 2
      three: 3

    class Sub extends Base
      two: 20
      three: 30
      four: 40

      content: =>
        text @one
        text @two
        text @three
        text @four
        text @five

    w = Sub!
    w\include_helper {
      one: 100
      two: 200
      four: 400
      five: 500
    }

    buff = {}
    w\render buff

    assert.same {"1", "20", "30", "40", "500"}, buff

