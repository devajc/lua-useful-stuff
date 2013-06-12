describe("Tests dealing with stubs", function()
  local test = {}

  before_each(function()
    test = {key = function()
      return "derp"
    end}
  end)
  
  it("checks to see if stub keeps track of arguments", function()

    stub(test, "key")

    test.key("derp")
    assert.stub(test.key).was.called_with("derp")
    assert.errors(function() assert.stub(test.key).was.called_with("herp") end)
  end)

  it("checks to see if stub keeps track of number of calls", function()
     stub(test, "key")
     test.key()
     test.key("test")
     assert.stub(test.key).was.called(2)
  end)

  it("checks called() and called_with() assertions", function()
    local s = stub.new(test, "key")

    s(1, 2, 3)
    s("a", "b", "c")
    assert.stub(s).was.called()
    assert.stub(s).was.called(2) -- twice!
    assert.stub(s).was_not.called(3)
    assert.stub(s).was_not.called_with({1, 2, 3}) -- mind the accolades
    assert.stub(s).was.called_with(1, 2, 3)
    assert.has_error(function() assert.stub(s).was.called_with(5, 6) end)
  end)

  it("checks stub to fail when spying on non-callable elements", function()
    local s
    local testfunc = function()
      local t = { key = s}
      stub.new(t, "key")
    end
    -- try some types to fail
    s = "some string";  assert.has_error(testfunc)
    s = 10;             assert.has_error(testfunc)
    s = true;           assert.has_error(testfunc)
    -- try some types to succeed
    s = function() end; assert.has_no_error(testfunc)
    s = setmetatable( {}, { __call = function() end } ); assert.has_no_error(testfunc)
  end)

  it("checks reverting a stub call", function()
     local calls = 0
     local old = function() calls = calls + 1 end
     test.key = old
     local s = stub.new(test, "key")
     assert.is_table(s)
     s()
     s()
     assert.stub(s).was.called(2)  
     assert.are.equal(calls, 0)   -- its a stub, so no calls
     local old_s = s
     s = s:revert()
     s()
     assert.stub(old_s).was.called(2)  -- still two, stub was removed
     assert.are.equal(s, old)
     assert.are.equal(calls, 1)     -- restored, so now 1 call
  end)

  it("checks reverting a stub call on a nil value", function()
     test = {}
     local s = stub.new(test, "key")
     assert.is_table(s)
     s()
     s()
     assert.stub(s).was.called(2)  
     local old_s = s
     s = s:revert()
     assert.is_nil(s)
  end)

  it("checks creating and reverting a 'blank' stub", function()
     local s = stub.new()   -- use no parameters to create a blank
     assert.is_table(s)
     s()
     s()
     assert.stub(s).was.called(2)  
     local old_s = s
     s = s:revert()
     assert.is_nil(s)
  end)

end)
